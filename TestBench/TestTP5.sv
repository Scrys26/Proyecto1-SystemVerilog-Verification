`timescale 1ns/1ps

module TestTP5;

  import Paquete::*;

  localparam int CLK_HALF = 5;
  localparam int SRC = 0;
  localparam bit [7:0] INVALID_DST = 8'h20;

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

  int unsigned n_txn        = 5;
  int unsigned max_cycles   = 10000;
  int unsigned drain_cycles = 5000;

  bit drenaje_ok       = 0;
  bit death_time       = 0;
  bit prueba_terminada = 0;

  int unsigned ciclos = 0;

  always @(posedge clk)
    ciclos++;

  bit c1;
  bit c2;
  bit c3;
  bit c4;
  bit c5;
  bit c6;

  initial begin

    void'($value$plusargs("n_txn=%d",n_txn));
    void'($value$plusargs("max_cycles=%d",max_cycles));
    void'($value$plusargs("drain_cycles=%d",drain_cycles));

    encabezado();
    configurar_escenario();

    env = new(vif.DRV,vif.MON);
    env.build();

    configurar_agente();

    env.reset();
    env.arrancar();

    fork

      begin

        $display("[%0t] [TP05] enviando %0d paquetes con destino invalido 0x%0h desde T%0d",$time,n_txn,INVALID_DST,SRC);

        env.agentes[SRC].run();

        $display("[%0t] [TP05] generacion terminada",$time);

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
          $display("[%0t] [TP05] DEATH_TIME: %0d ciclos",$time,max_cycles);
          evaluar_criterios();
        end

      end

    join_any

    disable fork;
    $finish;

  end


  task automatic configurar_escenario();

    bus_config cfg;

    cfg = bus_config::get();

    cfg.wt_valid        = 0;
    cfg.wt_broadcast    = 0;
    cfg.wt_invalid      = 100;
    cfg.allow_self_send = 0;

    cfg.min_delay = 0;
    cfg.max_delay = 5;

    cfg.validate();
    cfg.print();

  endtask


  task automatic configurar_agente();

    env.agentes[SRC].n_txn = n_txn;

    env.agentes[SRC].blueprint.dst_type.rand_mode(0);
    env.agentes[SRC].blueprint.dst.rand_mode(0);

    env.agentes[SRC].blueprint.dst_type = DST_INVALID;
    env.agentes[SRC].blueprint.dst = INVALID_DST;

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

    // C1: solamente T0 genero los paquetes invalidos
    c1 = (generadas == n_txn) && (env.agentes[SRC].n_generated == n_txn);

    for (int i = 0; i < DRVRS; i++) begin
      if (i != SRC) c1 &= (env.agentes[i].n_generated == 0);
    end

    // C2: cada paquete invalido fue consumido una sola vez desde T0
    c2 = (enviadas == n_txn) && (env.chk.n_pops == n_txn) && (env.mon.hijos[SRC].n_pop == n_txn);

    for (int i = 0; i < DRVRS; i++) begin
      if (i != SRC) c2 &= (env.mon.hijos[i].n_pop == 0);
    end

    // C3: ningun paquete invalido produjo PUSH
    c3 = (env.chk.n_pushes == 0) && (env.chk.n_completed == 0);

    for (int i = 0; i < DRVRS; i++) begin
      c3 &= (env.mon.hijos[i].n_push == 0);
    end

    // C4: Scoreboard identifico todos los destinos invalidos y no creo entregas
    c4 = (env.sb.n_consumidas == n_txn) && (env.sb.n_invalidas == n_txn) && (env.sb.n_entregas_creadas == 0) && (env.sb.n_entregas_retiradas == 0) && (env.sb.n_broadcast == 0);

    // C5: contenido y protocolo correctos
    c5 = (env.chk.n_pop_mismatch == 0) && (env.chk.n_push_unexp == 0) && (env.chk.n_pop_empty == 0) && (env.total_pop_vacia() == 0);

    // C6: prueba termino completamente
    c6 = (pendientes == 0) && drenaje_ok && !death_time && (env.chk.n_errors == 0);

    veredicto = c1 && c2 && c3 && c4 && c5 && c6;

    env.reportar();

    $display("");
    $display("   TP-05: DESTINO INVALIDO");
    $display("   Origen                : T%0d",SRC);
    $display("   Destino invalido      : 0x%0h",INVALID_DST);
    $display("   Paquetes              : %0d",n_txn);
    $display("   PCKG_SZ               : %0d",PCKG_SZ);
    $display("---------------------------------------------------------");
    $display("   Generadas             : %0d",generadas);
    $display("   POP totales           : %0d",env.chk.n_pops);
    $display("   PUSH totales          : %0d",env.chk.n_pushes);
    $display("   Entregas confirmadas  : %0d",env.chk.n_completed);
    $display("   Invalidas Scoreboard  : %0d",env.sb.n_invalidas);
    $display("   Pendientes            : %0d",pendientes);
    $display("   Ciclos simulados      : %0d",ciclos);
    $display("---------------------------------------------------------");

    mostrar_terminales();

    $display("---------------------------------------------------------");
    linea_criterio("C1 Solo T0 genero paquetes invalidos ",c1);
    linea_criterio("C2 Cada paquete invalido produjo un POP en T0 ",c2);
    linea_criterio("C3 Ningun paquete invalido produjo PUSH ",c3);
    linea_criterio("C4 Scoreboard detecto todos los destinos invalidos ",c4);
    linea_criterio("C5 Contenido y protocolo correctos ",c5);
    linea_criterio("C6 Sin elementos pendientes al finalizar ",c6);

    $display("---------------------------------------------------------");
    $display("Errores Checker  : %0d",env.chk.n_errors);
    $display("=========================================================");

    if (veredicto) begin
      $display("   RESULTADO TP-05: PASS");
    end
    else begin
      $display("   RESULTADO TP-05: FAIL");
    end

    $display("=========================================================");
    $display("");

  endtask


  task automatic mostrar_terminales();

    for (int i = 0; i < DRVRS; i++) begin
      $display("   T%0d -> POP: %0d  PUSH: %0d",i,env.mon.hijos[i].n_pop,env.mon.hijos[i].n_push);
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
    $display("   TP-05: VERIFICACION DE DESTINO INVALIDO");
    $display("=========================================================");

  endfunction

endmodule