//Monitor hijo 
class mon_hijo;

  virtual bus_if #(BITS, DRVRS, PCKG_SZ).MON vif;  // modport MON: solo lectura
  int          id;                                 // numero de terminal
  int unsigned n_push = 0;                         // paquetes recibidos por terminal
  int unsigned n_pop  = 0;                         // paquetes que salieron de terminal

  //Constructor 
  function new(int id, virtual bus_if #(BITS, DRVRS, PCKG_SZ).MON vif);
    this.id  = id;
    this.vif = vif;
  endfunction

  //Copia los valores en la "foto"
  function void muestrear(bus_mon_txn #(PCKG_SZ, DRVRS) m);
    m.pndng [id] = vif.mon_cb.pndng [0][id];
    m.pop   [id] = vif.mon_cb.pop   [0][id];
    m.push  [id] = vif.mon_cb.push  [0][id];
    m.D_pop [id] = vif.mon_cb.D_pop [0][id];
    m.D_push[id] = vif.mon_cb.D_push[0][id];

    //Si hubo actividad entonces suma en el contador
    if (m.pop [id]) n_pop++;
    if (m.push[id]) n_push++;
  endfunction

endclass


//Monitor Padre
class monitor;

  virtual bus_if #(BITS, DRVRS, PCKG_SZ).MON vif;
  mailbox #(bus_mon_txn #(PCKG_SZ, DRVRS))   mon2chk;   // hacia el Checker
  bus_config                                 cfg;//**
  mon_hijo                                   hijos[DRVRS]; //Arreglo de hijos

  bit          solo_actividad = 0; //Switch para depuracion, en 0 se manda cad ciclo y en 1 los que tienen pop o push **

  int unsigned n_muestras = 0;   // cantidad de "fotos entregadas"
  int unsigned n_ciclos   = 0;   // ciclos observados

  //Constructor
  function new(virtual bus_if #(BITS, DRVRS, PCKG_SZ).MON vif, mailbox #(bus_mon_txn #(PCKG_SZ, DRVRS)) mon2chk);
    this.vif     = vif;
    this.mon2chk = mon2chk;
    this.cfg     = bus_config::get();//Devuelve la misma instancia**
    foreach (hijos[i]) hijos[i] = new(i, vif);
  endfunction

  // Main loop: una foto por ciclo
  task run();
    bus_mon_txn #(PCKG_SZ, DRVRS) m; //Handle donde se guarda la foto 
    $display("[%0t] [MON] iniciado", $time);
    
    forever begin
      @(vif.mon_cb);          // una muestra por reloj
      n_ciclos++;

      //Un objeto nuevo cada ciclo 
      m       = new();
      m.t     = $time;
      
      m.reset = vif.reset;//Estado de reset

      // Cada hijo llena su parte de la foto
      foreach (hijos[i]) hijos[i].muestrear(m);

      //Decide si la foto se entrega o se descarta
      if (!solo_actividad || m.reset || hay_actividad(m)) begin
        mon2chk.put(m);
        n_muestras++;
      end
    end
  endtask

  // Revisa si hubo un pop o push durante el ciclo
  function bit hay_actividad(bus_mon_txn #(PCKG_SZ, DRVRS) m);
    for (int i = 0; i < DRVRS; i++)
      if (m.pop[i] || m.push[i]) return 1;
    return 0;
  endfunction

  //Reporte
  function void reporte();
    int unsigned tot_pop = 0, tot_push = 0;
    $display("-------REPORTE DEL MONITOR-------");
    $display("Ciclos observados        : %0d", n_ciclos);
    $display("Muestras entregadas      : %0d", n_muestras);
    foreach (hijos[i]) begin
      $display("T%0d: pop=%0d push=%0d", i, hijos[i].n_pop, hijos[i].n_push);
      tot_pop  += hijos[i].n_pop;
      tot_push += hijos[i].n_push;
    end
    $display("Total pop  : %0d", tot_pop);
    $display("Total push : %0d", tot_push);
  endfunction

endclass
