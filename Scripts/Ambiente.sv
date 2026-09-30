class Ambiente #(
    parameter int       BITS              = 1,
    parameter int       PCKG_SZ           = 16,
    parameter int       DRVRS             = 4,
    parameter bit [7:0] BROADCAST         = 8'hFF,
    parameter bit       BROADCAST_TO_SELF = 1'b0
);

  //Definiciones del ambiente 
  typedef bus_txn     #(PCKG_SZ, DRVRS, BROADCAST)                txn_t;
  typedef bus_mon_txn #(PCKG_SZ, DRVRS)                           mon_txn_t;
  typedef Agente      #(PCKG_SZ, DRVRS, BROADCAST)                agente_t;
  typedef driver      #(BITS, PCKG_SZ, DRVRS, BROADCAST)          driver_t;
  typedef monitor     #(BITS, PCKG_SZ, DRVRS)                     monitor_t;
  typedef Scoreboard  #(PCKG_SZ, DRVRS, BROADCAST, BROADCAST_TO_SELF) sb_t;
  typedef Checker     #(PCKG_SZ, DRVRS, BROADCAST, BROADCAST_TO_SELF) chk_t;

  // Handles a la interfaz.
  virtual bus_if #(BITS, DRVRS, PCKG_SZ).DRV vif_drv;
  virtual bus_if #(BITS, DRVRS, PCKG_SZ).MON vif_mon;

  //Creacion del mbx 
  mailbox #(txn_t)     agnt2drv;   // agentes  -> driver
  mailbox #(txn_t)     agnt2sb;    // agentes  -> scoreboard
  mailbox #(mon_txn_t) mon2chk;    // monitor  -> checker
  mailbox #(txn_t) drv2sb;

 //Declaracion de los handles
  bus_config cfg;
  agente_t   agentes [DRVRS];
  driver_t   drv;
  monitor_t  mon;
  sb_t       sb;
  chk_t      chk;

  // Constructor para guardar los handles 
  function new(virtual bus_if #(BITS, DRVRS, PCKG_SZ).DRV vif_drv,
               virtual bus_if #(BITS, DRVRS, PCKG_SZ).MON vif_mon);
    this.vif_drv = vif_drv;
    this.vif_mon = vif_mon;
    this.cfg     = bus_config::get();
  endfunction
	
  //El build se encarga de crear los canales, construir los componentes y conectarlos 
  function void build();
    agnt2drv = new();
    agnt2sb  = new();
    drv2sb   = new();
    mon2chk  = new();

    drv = new(vif_drv, agnt2drv, 0, drv2sb);
    mon = new(vif_mon, mon2chk);
    sb  = new(agnt2sb, drv2sb);
    chk = new(mon2chk, sb);   // el checker consulta al scoreboard

    foreach (agentes[i]) agentes[i] = new(i, agnt2drv, agnt2sb);
  endfunction

  // reset: delega en el driver, que es quien maneja la interfaz.
  task reset();
    drv.reset();
  endtask

 //Procedimientos permanentes de loop 
  task arrancar();
    fork
      drv.run();
      mon.run();
      sb.run();
      chk.run();
    join_none

    // Un ciclo para que cada hilo llegue a su primer bloqueo
    @(vif_drv.drv_cb);
  endtask

  //Corre cuatro agentes en paralelo y espera a que terminen
  task correr_agentes();
    fork
      begin
        foreach (agentes[i]) begin
          automatic int k = i;
          fork
            agentes[k].run();
          join_none
        end
        wait fork;
      end
    join
  endtask

  //No queda trabajo pendiente en ninguna capa 
  function bit nada_en_transito();
    return (drv.vacio() && sb.vacio() && mon2chk.num() == 0);
  endfunction

  //Espera a que el bus termine
  task esperar_drenaje(input int unsigned limite, output bit ok);
    int unsigned k = 0;
    ok = 0;

    $display("[%0t] [ENV] esperando drenaje del bus...", $time);

    while (k < limite) begin
      @(vif_drv.drv_cb);
      k++;
      if (nada_en_transito()) begin
        $display("[%0t] [ENV] bus drenado tras %0d ciclos", $time, k);
        ok = 1;
        return;
      end
    end

    $display("[%0t] [ENV] drenaje AGOTADO tras %0d ciclos", $time, k);
  endtask

  //Consultas agregadas, info que vive en otros modulos 

  // Transacciones que produjeron los agentes
  function int unsigned total_generadas();
    total_generadas = 0;
    foreach (agentes[i]) total_generadas += agentes[i].n_generated;
  endfunction

  // Transacciones que el DUT saco por pop
  function int unsigned total_enviadas();
    total_enviadas = 0;
    foreach (drv.hijos[i]) total_enviadas += drv.hijos[i].n_enviados;
  endfunction

  // Elementos que quedaron sin procesar en el modelo
  function int unsigned total_pendientes();
    total_pendientes = 0;
    foreach (sb.fifo_esperada[i]) total_pendientes += sb.fifo_esperada[i].size();
    total_pendientes += sb.entregas_pendientes.size();
  endfunction

  // Violaciones de protocolo que vio el driver
  function int unsigned total_pop_vacia();
    total_pop_vacia = 0;
    foreach (drv.hijos[i]) total_pop_vacia += drv.hijos[i].n_pop_vacia;
  endfunction

  //Reportes de cada modulo
  function void reportar();
    drv.reporte();
    mon.reporte();
    sb.reporte();
    chk.reporte();
  endfunction

endclass
