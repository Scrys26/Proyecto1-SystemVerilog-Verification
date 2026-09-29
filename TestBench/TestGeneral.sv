`timescale 1ns/1ps

module test_general;

  import Paquete::*;

  localparam int CLK_HALF = 5;    // medio periodo -> 10 ns

  logic clk = 1'b0;
  always #CLK_HALF clk = ~clk;

  //Instancia de la interfaz y DUT
  bus_if #(
    .BITS    (BITS),
    .DRVRS   (DRVRS),
    .PCKG_SZ (PCKG_SZ)
  ) vif (.clk(clk));

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

  //Environment 
  Ambiente #(BITS, PCKG_SZ, DRVRS, BROADCAST, BROADCAST_TO_SELF) env;

  //Parametros del test
  int unsigned n_txn_min    = 10;      //Rango de la canidad de terminales 
  int unsigned n_txn_max    = 30;
  int unsigned max_cycles   = 50000;   // death_time 
  int unsigned drain_cycles = 20000;   // limite de espera del drenaje
  bit          dump_waves   = 0;

  int unsigned ciclos = 0;
  always @(posedge clk) ciclos++;

  // Estado de los criterios
  bit c1, c2, c3, c4, c5, c6;
  bit death_time = 0;
  bit drenaje_ok       = 0;

  //Procedimiento
  initial begin
    void'($value$plusargs("max_cycles=%d",   max_cycles));
    void'($value$plusargs("drain_cycles=%d", drain_cycles));
    void'($value$plusargs("n_txn_min=%d",    n_txn_min));
    void'($value$plusargs("n_txn_max=%d",    n_txn_max));
    void'($value$plusargs("dump=%d",         dump_waves));

    if (dump_waves) begin
      $dumpfile("test_general.vcd");
      $dumpvars(0, test_general);
    end

    encabezado();

    // 1. Definir el escenario
    configurar_escenario();

    // 2. Construir el ambiente
    env = new(vif.DRV, vif.MON);
    env.build();

    // 3. Carga por terminal: cada una con su propia cantidad
    repartir_carga();

    // 4. Reset
    env.reset();

    // 5. Procesos permanentes
    env.arrancar();

    // 6. Generacion de trafico
    $display("[%0t] [TEST] generando trafico", $time);
    env.correr_agentes();
    $display("[%0t] [TEST] generacion terminada", $time);

    // 7. Drenaje
    env.esperar_drenaje(drain_cycles, drenaje_ok);

    // 8. Evaluacion
    repeat (10) @(posedge clk);
    evaluar_criterios();
    $finish;
  end

  //Configuracion del escenario
  task automatic configurar_escenario();
    int unsigned v_min, v_max, v_vrb;
    bus_config cfg = bus_config::get();

    cfg.wt_valid        = 100;   // solo destinos validos
    cfg.wt_broadcast    = 0;     // broadcast: otro escenario
    cfg.wt_invalid      = 0;     // destino invalido: otro escenario
    cfg.allow_self_send = 0;     // sin self-send

    cfg.min_delay = 0;
    cfg.max_delay = 5;

    // Se lee en locales y luego se asigna: no todos los simuladores
    // aceptan una propiedad de clase como salida de $value$plusargs.
    v_min = cfg.min_delay;
    v_max = cfg.max_delay;
    v_vrb = cfg.verbose;
    void'($value$plusargs("min_delay=%d", v_min));
    void'($value$plusargs("max_delay=%d", v_max));
    void'($value$plusargs("verbose=%d",   v_vrb));
    cfg.min_delay = v_min;
    cfg.max_delay = v_max;
    cfg.verbose   = v_vrb[0];

    cfg.validate();
    cfg.print();
  endtask

  //Reparot de cantidad de datos por terminal
  task automatic repartir_carga();
    foreach (env.agentes[i])
      env.agentes[i].n_txn = $urandom_range(n_txn_max, n_txn_min);
  endtask

  //Evaluacion de criterios para PASS/FAIL
  task automatic evaluar_criterios();

    int unsigned generadas, enviadas, pendientes;
    bit          veredicto;

    env.chk.final_check();
	
    generadas  = env.total_generadas();
    enviadas   = env.total_enviadas();
    pendientes = env.total_pendientes();

    // C1 - Todos los paquetes fueron procesados por el bus.
    c1 = (generadas == enviadas) && (enviadas == env.sb.n_consumidas);

    // C2 - Sin perdida: toda entrega esperada fue observada.
    c2 = (env.sb.n_entregas_creadas == env.sb.n_entregas_retiradas) &&
         (env.sb.n_entregas_retiradas == env.chk.n_completed);

    // C3 - Sin duplicacion ni destino incorrecto.
    c3 = (env.chk.n_push_unexp == 0) &&
         (env.chk.n_pushes == env.sb.n_entregas_creadas);

    // C4 - Contenido conservado sin modificacion.
    c4 = (env.chk.n_pop_mismatch == 0);

    // C5 - Protocolo pndng/pop/push respetado.
    c5 = (env.chk.n_pop_empty == 0) && (env.total_pop_vacia() == 0);

    // C6 - Nada pendiente al finalizar, y la prueba llego a su fin.
    c6 = (pendientes == 0) && drenaje_ok && !death_time;

    veredicto = c1 && c2 && c3 && c4 && c5 && c6 &&
                (env.chk.n_errors == 0);

    env.reportar();

    $display("=========================================================");
    $display("   ESCENARIO: PRUEBA GENERAL");
    $display("=========================================================");
    $display(" CONFIGURACION");
    $display("   bits=%0d  drvrs=%0d  pckg_sz=%0d  broadcast=0x%0h",
             BITS, DRVRS, PCKG_SZ, BROADCAST);
    $display("   txn sorteadas por terminal:");
    foreach (env.agentes[i])
      $display("      T%0d : %0d", i, env.agentes[i].n_txn);
    $display("---------------------------------------------------------");
    $display(" CONTEOS");
    $display("   Generadas por los agentes    : %0d", generadas);
    $display("   Sacadas por pop              : %0d", enviadas);
    $display("   Entregas esperadas creadas   : %0d", env.sb.n_entregas_creadas);
    $display("   Push observados              : %0d", env.chk.n_pushes);
    $display("   Entregas confirmadas         : %0d", env.chk.n_completed);
    $display("   Pendientes al final          : %0d", pendientes);
    $display("   Ciclos simulados             : %0d", ciclos);
    $display("---------------------------------------------------------");
    $display(" CRITERIOS");
    linea_criterio("C1 Todos los paquetes procesados por el bus", c1);
    linea_criterio("C2 Sin perdida: toda entrega esperada llego", c2);
    linea_criterio("C3 Sin duplicacion ni destino incorrecto   ", c3);
    linea_criterio("C4 Contenido conservado sin modificacion   ", c4);
    linea_criterio("C5 Protocolo pndng/pop/push respetado      ", c5);
    linea_criterio("C6 Sin transacciones pendientes al final   ", c6);
    $display("---------------------------------------------------------");
    $display("   Errores reportados por el Checker : %0d", env.chk.n_errors);
    $display("=========================================================");
    if (veredicto)
      $display("   RESULTADO: PASS");
    else begin
      $display("   RESULTADO: FAIL");
      diagnostico(generadas, enviadas, pendientes);
    end
    $display("=========================================================");
    $display("");
  endtask

  //-------------------------------------------------------------------
  function automatic void linea_criterio(string texto, bit ok);
    $display("   [%s] %s", ok ? "PASS" : "FAIL", texto);
  endfunction

  //-------------------------------------------------------------------
  // Explica que fallo, para no tener que leer todo el log
  //-------------------------------------------------------------------
  function automatic void diagnostico(int unsigned generadas,
                                      int unsigned enviadas,
                                      int unsigned pendientes);
    $display("---------------------------------------------------------");
    $display(" DIAGNOSTICO");
    if (death_time)
      $display("   - El death_time corto la simulacion. Subir +max_cycles.");
    if (!drenaje_ok && !death_time)
      $display("   - El bus no dreno en %0d ciclos. Subir +drain_cycles.",
               drain_cycles);
    if (!c1)
      $display("   - Faltaron pops: generadas=%0d vs sacadas=%0d.",
               generadas, enviadas);
    if (!c2)
      $display("   - Paquetes perdidos: creadas=%0d vs retiradas=%0d.",
               env.sb.n_entregas_creadas, env.sb.n_entregas_retiradas);
    if (!c3)
      $display("   - Push inesperados=%0d (duplicado o destino incorrecto).",
               env.chk.n_push_unexp);
    if (!c4)
      $display("   - D_pop incorrectos=%0d (contenido alterado).",
               env.chk.n_pop_mismatch);
    if (!c5)
      $display("   - Violacion de protocolo: pop_sin_pndng=%0d pop_fifo_vacia=%0d.",
               env.chk.n_pop_empty, env.total_pop_vacia());
    if (!c6)
      $display("   - Quedaron %0d elementos sin procesar.", pendientes);
  endfunction

  //-------------------------------------------------------------------
  function automatic void encabezado();
    $display("");
    $display("=========================================================");
    $display("   ESCENARIO: PRUEBA GENERAL");
    $display("   Trafico aleatorio, solo destinos validos");
    $display("=========================================================");
  endfunction

  //-------------------------------------------------------------------
  // death_time: corre en paralelo. El primero que llegue a $finish
  // termina la simulacion.
  //-------------------------------------------------------------------
  initial begin
    repeat (max_cycles) @(posedge clk);
    death_time = 1;
    $display("");
    $display("[%0t] [TEST] death_time: se agotaron %0d ciclos",
             $time, max_cycles);
    evaluar_criterios();
    $finish;
  end

endmodule
