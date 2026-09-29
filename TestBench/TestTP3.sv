`timescale 1ns/1ps

module TestTP3;

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

  int unsigned n_txn        = 8;
  int unsigned max_cycles   = 10000;
  int unsigned drain_cycles = 5000;

  bit drenaje_ok       = 0;
  bit death_time       = 0;
  bit prueba_terminada = 0;
  bit contencion_vista = 0;

  int unsigned ciclos = 0;
  int unsigned pop_simultaneos = 0;

  int pop_seq[$];

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
    configurar_agentes();
    env.reset();
    env.arrancar();
    fork
      begin
        $display("[%0t] [TP03] iniciando contencion con %0d paquetes por terminal",$time,n_txn);
        env.correr_agentes();
        $display("[%0t] [TP03] generacion terminada",$time);
        env.esperar_drenaje(drain_cycles,drenaje_ok);
        repeat (10) @(posedge clk);
        evaluar_criterios();
        prueba_terminada = 1;
      end
      begin
        capturar_arbitraje();
      end
      begin
        repeat (max_cycles) @(posedge clk);

        if (!prueba_terminada) begin
          death_time = 1;
          $display("");
          $display("[%0t] [TP03] DEATH_TIME: %0d ciclos",$time,max_cycles);
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

    cfg.wt_valid        = 100;
    cfg.wt_broadcast    = 0;
    cfg.wt_invalid      = 0;
    cfg.allow_self_send = 0;

    cfg.min_delay = 0;
    cfg.max_delay = 0;

    cfg.validate();
    cfg.print();

  endtask
  task automatic configurar_agentes();

    for (int src = 0; src < DRVRS; src++) begin

      env.agentes[src].n_txn = n_txn;

      env.agentes[src].blueprint.dst_type.rand_mode(0);
      env.agentes[src].blueprint.dst.rand_mode(0);

      env.agentes[src].blueprint.dst_type = DST_VALID;
      env.agentes[src].blueprint.dst = (src + 1) % DRVRS;

    end
  endtask
  task automatic capturar_arbitraje();

    int pending_count;
    int pop_count;
    int src_pop;

    forever begin

      @(vif.mon_cb);

      if (!vif.reset) begin

        pending_count = 0;
        pop_count = 0;
        src_pop = -1;

        for (int i = 0; i < DRVRS; i++) begin
          if (vif.mon_cb.pndng[0][i]) pending_count++;
          if (vif.mon_cb.pop[0][i]) begin
            pop_count++;
            src_pop = i;
          end
        end

        if (!contencion_vista && pending_count == DRVRS) begin
          contencion_vista = 1;
          $display("[%0t] [TP03] contencion detectada: todos los terminales tienen PNDNG",$time);
        end

        if (pop_count > 1) begin
          pop_simultaneos++;
          $display("[%0t] [TP03] ERROR: %0d POP simultaneos",$time,pop_count);
        end

        if (contencion_vista && pop_count == 1) pop_seq.push_back(src_pop);

      end

    end
endtask

  function automatic bit verificar_round_robin();

    int paso;
    int esperado;

    if (pop_seq.size() < DRVRS * 2) return 0;

    paso = (pop_seq[1] - pop_seq[0] + DRVRS) % DRVRS;

    if ((paso != 1) && (paso != (DRVRS - 1))) return 0;

    for (int i = 1; i < pop_seq.size(); i++) begin

      esperado = (pop_seq[i-1] + paso) % DRVRS;

      if (pop_seq[i] != esperado) return 0;

    end
    return 1;
  endfunction

  task automatic evaluar_criterios();

    int unsigned generadas;
    int unsigned enviadas;
    int unsigned pendientes;
    int unsigned total_txn;

    bit veredicto;

    env.chk.final_check();

    total_txn  = n_txn * DRVRS;
    generadas  = env.total_generadas();
    enviadas   = env.total_enviadas();
    pendientes = env.total_pendientes();

    // C1: todos los agentes generaron la misma cantidad
    c1 = (generadas == total_txn);
    for (int i = 0; i < DRVRS; i++) begin
      c1 &= (env.agentes[i].n_generated == n_txn);
    end
    // C2: existio contencion real entre todos los terminales
    c2 = contencion_vista && (pop_simultaneos == 0);
    // C3: el orden de servicio cumple Round Robin
    c3 = verificar_round_robin();
    // C4: todos los paquetes fueron consumidos y entregados
    c4 = (enviadas == total_txn) && (env.chk.n_pops == total_txn) && (env.chk.n_pushes == total_txn) && (env.chk.n_completed == total_txn);
    for (int i = 0; i < DRVRS; i++) begin
      c4 &= (env.mon.hijos[i].n_pop == n_txn);
      c4 &= (env.mon.hijos[i].n_push == n_txn);
    end
    // C5: contenido y protocolo correctos
    c5 = (env.chk.n_pop_mismatch == 0) && (env.chk.n_push_unexp == 0) && (env.chk.n_pop_empty == 0) && (env.total_pop_vacia() == 0);
    // C6: prueba termino sin elementos pendientes
    c6 = (pendientes == 0) && drenaje_ok && !death_time && (env.chk.n_errors == 0);
    veredicto = c1 && c2 && c3 && c4 && c5 && c6;

    env.reportar();

    $display("");
    $display("   TP-03: CONTENCION Y ARBITRAJE ROUND ROBIN");
    $display("   Terminales            : %0d",DRVRS);
    $display("   Paquetes/terminal     : %0d",n_txn);
    $display("   Total esperado        : %0d",total_txn);
    $display("   PCKG_SZ               : %0d",PCKG_SZ);
    $display("---------------------------------------------------------");
    $display("   Generadas             : %0d",generadas);
    $display("   POP totales           : %0d",env.chk.n_pops);
    $display("   PUSH totales          : %0d",env.chk.n_pushes);
    $display("   Entregas confirmadas  : %0d",env.chk.n_completed);
    $display("   POP capturados RR     : %0d",pop_seq.size());
    $display("   POP simultaneos       : %0d",pop_simultaneos);
    $display("   Pendientes            : %0d",pendientes);
    $display("   Ciclos simulados      : %0d",ciclos);
    $display("---------------------------------------------------------");

    mostrar_secuencia();

    $display("---------------------------------------------------------");
    linea_criterio("C1 Todos los agentes generaron N paquetes ",c1);
    linea_criterio("C2 Existio contencion entre terminales ",c2);
    linea_criterio("C3 El arbitraje mantuvo orden Round Robin ",c3);
    linea_criterio("C4 Todos los paquetes fueron entregados ",c4);
    linea_criterio("C5 Contenido y protocolo correctos ",c5);
    linea_criterio("C6 Sin elementos pendientes al finalizar ",c6);
    $display("---------------------------------------------------------");
    $display("Errores Checker  : %0d",env.chk.n_errors);
    $display("=========================================================");
    if (veredicto) begin
      $display("   RESULTADO TP-03: PASS");
    end
    else begin
      $display("   RESULTADO TP-03: FAIL");
    end
    $display("=========================================================");
    $display("");

  endtask

  task automatic mostrar_secuencia();

    int limite;

    limite = pop_seq.size();

    if (limite > 32) limite = 32;

    $write("   Secuencia POP         : ");

    for (int i = 0; i < limite; i++) begin
      $write("T%0d ",pop_seq[i]);
    end

    if (pop_seq.size() > limite) $write("...");

    $display("");

  endtask

  function automatic void linea_criterio( string texto,bit ok );
    $display(" [%s] %s",ok ? "PASS" : "FAIL",texto);

  endfunction

  function automatic void encabezado();

    $display("");
    $display("=========================================================");
    $display("   TP-03: CONTENCION Y ARBITRAJE ROUND ROBIN");
    $display("=========================================================");

  endfunction

endmodule