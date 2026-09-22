// HIJO: Clase que simula la fifo de entrada
class fifo_in;
  
  virtual bus_if #(BITS, DRVRS, PCKG_SZ).DRV vif;   // Handle a la interfaz
  
  int unsigned profundidad;               // Profundidad maxima de la FIFO
  int id;                                 // Numero de device
  
  mailbox #(bus_txn #(PCKG_SZ, DRVRS, BROADCAST)) padre2hijo; // Mailbox de padre a hijo
  
  bus_txn #(PCKG_SZ, DRVRS, BROADCAST) fifo[$];               // Creacion de la cola
  
  int unsigned en_espera = 0;             // Sacados del mbx pero esperando restraso 
  int unsigned n_enviados = 0;            // pop (DUT ya consumio)
  int unsigned n_llena = 0;               // ciclos que se espero porque la FIFO ya estaba llena 
  
  // Constructor
  function new (int id, virtual bus_if #(BITS, DRVRS, PCKG_SZ).DRV vif, int unsigned profundidad = 0);
    this.id = id;
    this.vif = vif;
    this.profundidad = profundidad;
    this.padre2hijo = new(); // El hijo crea su propio mailbox privado
  endfunction
  
  // Crea los dos hilos de la terminal
  task run(); 
    fork
      llenar();  // Mbx -> Espera -> FIFO
      atender(); // DUT <- FIFO
    join_none 
  endtask 
  
  // Hilo 1: mailbox -> retardo -> FIFO. Push de una FIFO real
  task llenar ();
    bus_txn #(PCKG_SZ, DRVRS, BROADCAST) tr;
    forever begin
      padre2hijo.get(tr); // Si no hay nada en el mbx, el hilo se duerme aqui
      en_espera++;        // Salio mbx pero aun no esta en la FIFO
      
      repeat (tr.delay) @(vif.drv_cb); // Tiempo aleatorio entre transacciones
      
      // Espera a que haya espacio dentro de la FIFO
      while (profundidad != 0 && fifo.size() >= profundidad) begin       
        n_llena++;
        @(vif.drv_cb);        
      end 
      
      // Cuando haya espacio mete el dato en la fifo
      fifo.push_back(tr);
      en_espera--; // Ya entro a la FIFO, deja de estar en transito
    end 
  endtask 
  
  // Segundo hilo: Cada ciclo actualizo el estado de pop y visualizacion de la FIFO
  task atender();
    forever begin
      // Espera un flanco del clocking block 
      @(vif.drv_cb);
     
      // Si hay un pop entonces ejecuta consumir()
      if (vif.drv_cb.pop[0][id]) consumir(); 
      presentar(); // Actualiza el valor que está viendo el DUT
    end 
  endtask 
  
  function void consumir();
    bus_txn #(PCKG_SZ, DRVRS, BROADCAST) tr;
    // pop con la FIFO vacia es una violacion de protocolo del DUT
    if (fifo.size() == 0) begin
      $display("[DRV%0d] se intentó hacer un POP con la FIFO vacía", id);
      return;
    end
    
    tr = fifo.pop_front();       // Saca el primer valor
    n_enviados++;
  endfunction
 
  // Mostrar al DUT el estado actual de la FIFO
  function void presentar();
    // Si aun hay datos dentro de la FIFO entonces pone pndng en 1
    if (fifo.size() > 0) begin
      vif.drv_cb.pndng[0][id] <= 1'b1;
      vif.drv_cb.D_pop[0][id] <= fifo[0].packet; // El paquete ya armado por el agente
    end else begin
      // Si la FIFO está vacia entonces pone pndng en 0
      vif.drv_cb.pndng[0][id] <= 1'b0;
    end
  endfunction
 
  // Devuelve 1 si no hay nada en mbx, retardo ni FIFO
  function bit vacio();
    return (fifo.size() == 0 && padre2hijo.num() == 0 && en_espera == 0);
  endfunction
 
endclass
 
//Padre. Recibe del agente y comparte las transacciones con los hijos
class driver;
 
  virtual bus_if #(BITS, DRVRS, PCKG_SZ).DRV vif;   // handle a la interfaz
  mailbox #(bus_txn #(PCKG_SZ, DRVRS, BROADCAST)) agnt2drv; // entrada desde el agente
  
  fifo_in        hijos[DRVRS];                  // un hijo por terminal
  int unsigned       ciclos_reset = 5;
 
  // Constructor
  function new(virtual bus_if #(BITS, DRVRS, PCKG_SZ).DRV vif, 
               mailbox #(bus_txn #(PCKG_SZ, DRVRS, BROADCAST)) agnt2drv, 
               int unsigned profundidad = 0);
    
    this.vif      = vif;
    this.agnt2drv = agnt2drv;
    
    // Crea cada hijo en su device
    foreach (hijos[i]) hijos[i] = new(i, vif, profundidad);
  endfunction
 
  // Reset de la interfaz
  task reset();
    $display("[%0t] [DRV] aplicando reset", $time);
    
    // Activa el reset asincrono
    vif.reset <= 1'b1;
    
    // Pone en cero pndng y valores de la FIFO
    for (int i = 0; i < DRVRS; i++) begin
      vif.drv_cb.pndng[0][i] <= 1'b0;
      vif.drv_cb.D_pop[0][i] <= '0;     // '0 = todos los bits en cero
    end
    
    repeat (ciclos_reset) @(vif.drv_cb);
    vif.reset <= 1'b0;
    
    // Un ciclo extra para que el DUT salga limpio del reset
    @(vif.drv_cb);
    $display("[%0t] [DRV] reset liberado", $time);
  endtask
 
  // Main loop
  task run();
    bus_txn #(PCKG_SZ, DRVRS, BROADCAST) tr;
    
    // CRITICO: Arrancar los hilos de cada hijo
    foreach (hijos[i]) hijos[i].run();
    
    forever begin
      // Espera a la transaccion del agente
      agnt2drv.get(tr);
      
      // Verifica que no este buscando un device fuera de rango
      if (tr.src >= DRVRS)
        $error("[DRV] origen %0d fuera de rango", tr.src);
      else
        // Entregarla al hijo de su terminal de origen
        hijos[tr.src].padre2hijo.put(tr);
    end
  endtask
 
  // Avisa si el driver padre y los hijos estan vacios 
  function bit vacio();
    if (agnt2drv.num() != 0) return 0;
    foreach (hijos[i]) if (!hijos[i].vacio()) return 0;
    return 1;
  endfunction
 
  // Resumen al final de la simulacion
  function void reporte();
    foreach (hijos[i])
      $display("[DRV%0d] enviados=%0d ciclos_fifo_llena=%0d",
               i, hijos[i].n_enviados, hijos[i].n_llena);
  endfunction
  
endclass
