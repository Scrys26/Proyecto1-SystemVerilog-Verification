`timescale 1ns/1ps

module TestTP2;

  import Paquete::*;

  localparam int CLK_HALF = 5;
  localparam int TOTAL_RUTAS = DRVRS * (DRVRS - 1);

  logic clk = 1'b0;
  always #CLK_HALF clk = ~clk;

  bus_if #(.BITS    (BITS),.DRVRS   (DRVRS),.PCKG_SZ (PCKG_SZ)) vif ( .clk(clk));

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

  int unsigned max_intentos = 100;
  int unsigned max_cycles   = 10000;
  int unsigned drain_cycles = 5000;

  bit drenaje_ok       = 0;
  bit death_time       = 0;
  bit prueba_terminada = 0;

  int unsigned ciclos = 0;
  int unsigned rutas_encontradas = 0;

  bit rutas_vistas [DRVRS][DRVRS];

  always @(posedge clk)
    ciclos++;

  bit c1;
  bit c2;
  bit c3;
  bit c4;
  bit c5;
  bit c6;

  initial begin
    void'($value$plusargs("max_intentos=%d",max_intentos));
    void'($value$plusargs("max_cycles=%d",max_cycles));
    void'($value$plusargs("drain_cycles=%d",drain_cycles));
    encabezado();
    configurar_escenario();
    env = new(vif.DRV, vif.MON);
    env.build();
    env.chk.abrir_csv("latencias_TP2.csv");
    configurar_agentes();
    inicializar_rutas();
    env.reset();
    env.arrancar();
    fork
      begin
        generar_rutas();
        $display("[%0t] [TP02] generacion terminada. Rutas encontradas=%0d/%0d",$time,rutas_encontradas,TOTAL_RUTAS);
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
          $display("[%0t] [TP02] DEATH_TIME: %0d ciclos",$time,max_cycles);
          evaluar_criterios();
          env.chk.cerrar_csv();
        end
      end
    join_any
    disable fork;
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
      env.agentes[i].n_txn = 1;
    end

  endtask
  task automatic inicializar_rutas();

    rutas_encontradas = 0;

    for (int src = 0; src < DRVRS; src++) begin
      for (int dst = 0; dst < DRVRS; dst++) begin
        rutas_vistas[src][dst] = 0;
      end
    end

  endtask
  task automatic generar_rutas();
    int unsigned intentos;
    int unsigned rutas_src;
    int unsigned dst;

    for (int src = 0; src < DRVRS; src++) begin
      intentos = 0;
      rutas_src = 0;

      $display("[%0t] [TP02] buscando rutas desde T%0d",$time,src);
      while ((rutas_src < (DRVRS - 1)) && (intentos < max_intentos)) begin
        env.agentes[src].run();

        dst = env.agentes[src].blueprint.dst;
        intentos++;

        if ((dst < DRVRS) && (dst != src) && !rutas_vistas[src][dst]) begin
          rutas_vistas[src][dst] = 1;
          rutas_src++;
          rutas_encontradas++;
          $display("[%0t] [TP02] nueva ruta T%0d -> T%0d  (%0d/%0d)",$time,src,dst,rutas_encontradas,TOTAL_RUTAS);
        end
      end
      if (rutas_src != (DRVRS - 1)) begin
        $display("[%0t] [TP02] no se cubrieron todas las rutas desde T%0d despues de %0d intentos",$time,src,intentos);
      end
    end
  endtask

  task automatic evaluar_criterios();

    int unsigned generadas;
    int unsigned enviadas;
    int unsigned pendientes;

    bit veredicto;
    env.chk.final_check();
    generadas  = env.total_generadas();
    enviadas   = env.total_enviadas();
    pendientes = env.total_pendientes();
    // C1: se observaron todas las rutas validas
    c1 = (rutas_encontradas == TOTAL_RUTAS);
    for (int src = 0; src < DRVRS; src++) begin
      for (int dst = 0; dst < DRVRS; dst++) begin
        if (src != dst) c1 &= rutas_vistas[src][dst];
      end
    end
    // C2: todas las transacciones generadas fueron consumidas
    c2 = (enviadas == generadas) && (env.chk.n_pops == generadas);
    // C3: todas las transacciones fueron entregadas
    c3 = (env.chk.n_pushes == generadas) && (env.chk.n_completed == generadas);
    // C4: Scoreboard registro todas las transferencias validas
    c4 = (env.sb.n_consumidas == generadas) && (env.sb.n_entregas_creadas == generadas) && (env.sb.n_entregas_retiradas == generadas) && (env.sb.n_broadcast == 0) && (env.sb.n_invalidas == 0);
    // C5: contenido y protocolo correctos
    c5 = (env.chk.n_pop_mismatch == 0) && (env.chk.n_push_unexp == 0) && (env.chk.n_pop_empty == 0) && (env.total_pop_vacia() == 0);
    // C6: prueba termino sin pendientes
    c6 = (pendientes == 0) && drenaje_ok && !death_time && (env.chk.n_errors == 0);
    veredicto = c1 && c2 && c3 && c4 && c5 && c6;

    env.reportar();

    $display("");
    $display("   TP-02: TODAS LAS RUTAS VALIDAS");
    $display("   Terminales            : %0d",DRVRS);
    $display("   Rutas esperadas       : %0d",TOTAL_RUTAS);
    $display("   Rutas encontradas     : %0d",rutas_encontradas);
    $display("   PCKG_SZ               : %0d",PCKG_SZ);
    $display("---------------------------------------------------------");
    $display("   Generadas             : %0d",generadas);
    $display("   POP totales           : %0d",env.chk.n_pops);
    $display("   PUSH totales          : %0d",env.chk.n_pushes);
    $display("   Entregas confirmadas  : %0d",env.chk.n_completed);
    $display("   Pendientes            : %0d",pendientes);
    $display("   Ciclos simulados      : %0d",ciclos);
    $display("---------------------------------------------------------");

    mostrar_rutas();

    $display("---------------------------------------------------------");
    linea_criterio("C1 Todas las rutas validas fueron utilizadas ",c1);
    linea_criterio("C2 Todas las transacciones fueron consumidas ",c2);
    linea_criterio("C3 Todas las transacciones fueron entregadas ",c3);
    linea_criterio("C4 Scoreboard registro todas las entregas ",c4);
    linea_criterio("C5 Contenido y protocolo correctos ",c5);
    linea_criterio("C6 Sin elementos pendientes al finalizar ",c6);

    $display("---------------------------------------------------------");
    $display("Errores Checker  : %0d",env.chk.n_errors);
    $display("=========================================================");

    if (veredicto) begin
      $display("   RESULTADO TP-02: PASS");
    end
    else begin
      $display("   RESULTADO TP-02: FAIL");
    end

    $display("=========================================================");
    $display("");

  endtask
  task automatic mostrar_rutas();

    for (int src = 0; src < DRVRS; src++) begin
      for (int dst = 0; dst < DRVRS; dst++) begin
        if (src != dst) begin
          $display("   Ruta T%0d -> T%0d : %s",src,dst,rutas_vistas[src][dst] ? "OK" : "NO VISTA");
        end

      end
    end

  endtask

  function automatic void linea_criterio(string texto,bit ok );
    $display(" [%s] %s",ok ? "PASS" : "FAIL",texto);
  endfunction


  function automatic void encabezado();

    $display("");
    $display("=========================================================");
    $display("   TP-02: COBERTURA DE TODAS LAS RUTAS VALIDAS");
    $display("=========================================================");

  endfunction

endmodule