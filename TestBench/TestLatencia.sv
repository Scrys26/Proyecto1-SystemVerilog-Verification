`timescale 1ns/1ps

module TestLatencia;

  import Paquete::*;

  localparam int CLK_HALF = 5;

  logic clk = 1'b0;
  always #CLK_HALF clk = ~clk;

  bus_if #(
    .BITS    (BITS),
    .DRVRS   (DRVRS),
    .PCKG_SZ (PCKG_SZ)
  ) vif (
    .clk(clk)
  );

  bs_gnrtr_n_rbtr #(
    .bits      (BITS),
    .drvrs     (DRVRS),
    .pckg_sz   (PCKG_SZ),
    .broadcast (BROADCAST)
  ) dut (
    .clk    (clk),
    .reset  (vif.reset),
    .pndng  (vif.pndng),
    .push   (vif.push),
    .pop    (vif.pop),
    .D_pop  (vif.D_pop),
    .D_push (vif.D_push)
  );

  Ambiente #(
    BITS,
    PCKG_SZ,
    DRVRS,
    BROADCAST,
    BROADCAST_TO_SELF
  ) env;

  int unsigned n_txn        = 50;
  int unsigned max_cycles   = 100000;
  int unsigned drain_cycles = 50000;

  string csv_nombre = "latencias.csv";

  bit drenaje_ok       = 0;
  bit death_time       = 0;
  bit prueba_terminada = 0;

  int unsigned ciclos = 0;

  bit c1;
  bit c2;
  bit c3;
  bit c4;
  bit c5;
  bit c6;
  always @(posedge clk)
    ciclos++;

  initial begin
    void'($value$plusargs("n_txn=%d",n_txn));
    void'($value$plusargs("max_cycles=%d",max_cycles));
    void'($value$plusargs("drain_cycles=%d",drain_cycles));
    void'($value$plusargs("csv=%s",csv_nombre));
    encabezado();
    configurar_escenario();

    env = new(vif.DRV,vif.MON);
    env.build();

    configurar_agentes();

    env.chk.abrir_csv(csv_nombre);

    env.reset();
    env.arrancar();
    fork

      begin
        $display("[%0t] [LAT] iniciando trafico: %0d transacciones por terminal",$time,n_txn);

        env.correr_agentes();

        $display("[%0t] [LAT] todos los agentes terminaron de generar",$time);

        env.esperar_drenaje(drain_cycles,drenaje_ok);

        repeat (10) @(posedge clk);

        evaluar_criterios();

        prueba_terminada = 1;
      end
      begin

        repeat (max_cycles) @(posedge clk);

        if (!prueba_terminada) begin
          death_time = 1;
          $display("");
          $display("[%0t] [LAT] DEATH_TIME: %0d ciclos",$time,max_cycles);
          evaluar_criterios();
        end
      end
    join_any
    disable fork;

    env.chk.cerrar_csv();
    $finish;
  end

  task automatic configurar_escenario();
    bus_config cfg;

    cfg = bus_config::get();

    cfg.wt_valid        = 100;
    cfg.wt_broadcast    = 0;
    cfg.wt_invalid      = 0;
    cfg.allow_self_send = 0;

    cfg.min_delay = 0;
    cfg.max_delay = 5;

    cfg.validate();
    cfg.print();

  endtask
  task automatic configurar_agentes();

    for (int i = 0; i < DRVRS; i++) begin
      env.agentes[i].n_txn = n_txn;
    end

  endtask


  task automatic evaluar_criterios();

    int unsigned esperadas;
    int unsigned generadas;
    int unsigned enviadas;
    int unsigned pendientes;

    bit veredicto;

    esperadas  = n_txn * DRVRS;
    generadas  = env.total_generadas();
    enviadas   = env.total_enviadas();
    pendientes = env.total_pendientes();
    env.chk.final_check();
    // C1: todos los agentes generaron la cantidad esperada
    c1 = (generadas == esperadas);
    for (int i = 0; i < DRVRS; i++) begin
      c1 &= (env.agentes[i].n_generated == n_txn);
    end
    // C2: todas las transacciones fueron consumidas por el DUT
    c2 = (enviadas == esperadas) && (env.chk.n_pops == esperadas);

    for (int i = 0; i < DRVRS; i++) begin
      c2 &= (env.mon.hijos[i].n_pop == n_txn);
    end
    // C3: cada paquete valido produjo exactamente una entrega
    c3 = (env.chk.n_pushes == esperadas) && (env.chk.n_completed == esperadas);
    // C4: Scoreboard proceso correctamente todas las transacciones
    c4 = (env.sb.n_recibidas == esperadas) && (env.sb.n_consumidas == esperadas) && (env.sb.n_entregas_creadas == esperadas) && (env.sb.n_entregas_retiradas == esperadas) && (env.sb.n_broadcast == 0) && (env.sb.n_invalidas == 0);
    // C5: no hubo errores de contenido ni protocolo
    c5 = (env.chk.n_pop_mismatch == 0) && (env.chk.n_push_unexp == 0) && (env.chk.n_pop_empty == 0) && (env.total_pop_vacia() == 0);
    // C6: el bus termino completamente drenado
    c6 = (pendientes == 0) && drenaje_ok && !death_time && (env.chk.n_errors == 0);
    veredicto = c1 && c2 && c3 && c4 && c5 && c6;
    env.reportar();
    $display("");
    $display("=========================================================");
    $display("   TEST DE LATENCIA");
    $display("=========================================================");
    $display("   Terminales             : %0d",DRVRS);
    $display("   Transacciones/terminal : %0d",n_txn);
    $display("   Transacciones totales  : %0d",esperadas);
    $display("   Archivo CSV            : %s",csv_nombre);
    $display("   Delay aleatorio        : [0:5]");
    $display("   PCKG_SZ                : %0d",PCKG_SZ);
    $display("---------------------------------------------------------");
    $display("   Generadas              : %0d",generadas);
    $display("   Enviadas               : %0d",enviadas);
    $display("   POP totales            : %0d",env.chk.n_pops);
    $display("   PUSH totales           : %0d",env.chk.n_pushes);
    $display("   Entregas confirmadas   : %0d",env.chk.n_completed);
    $display("   Pendientes             : %0d",pendientes);
    $display("   Ciclos simulados       : %0d",ciclos);
    $display("---------------------------------------------------------");
    mostrar_terminales();
    $display("---------------------------------------------------------");
    linea_criterio("C1 Todos los agentes generaron sus transacciones ",c1);
    linea_criterio("C2 Todas las transacciones produjeron POP ",c2);
    linea_criterio("C3 Cada paquete valido produjo una entrega ",c3);
    linea_criterio("C4 Scoreboard proceso todas las transacciones ",c4);
    linea_criterio("C5 Contenido y protocolo correctos ",c5);
    linea_criterio("C6 Bus drenado sin elementos pendientes ",c6);
    $display("---------------------------------------------------------");
    $display("Errores Checker  : %0d",env.chk.n_errors);
    $display("=========================================================");
    if (veredicto)
      $display("   RESULTADO TEST LATENCIA: PASS");
    else
      $display("   RESULTADO TEST LATENCIA: FAIL");

    $display("=========================================================");
    $display("");
  endtask

  task automatic mostrar_terminales();

    for (int i = 0; i < DRVRS; i++) begin
      $display("   T%0d -> Generadas: %0d  POP: %0d  PUSH: %0d",i,env.agentes[i].n_generated,env.mon.hijos[i].n_pop,env.mon.hijos[i].n_push);
    end

  endtask

  function automatic void linea_criterio(
    string texto,
    bit ok
  );
    $display(" [%s] %s",ok ? "PASS" : "FAIL",texto);

  endfunction

  function automatic void encabezado();

    $display("");
    $display("=========================================================");
    $display("   MEDICION DE LATENCIA DEL BUS");
    $display("=========================================================");

  endfunction

endmodule