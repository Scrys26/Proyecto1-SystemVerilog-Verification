`timescale 1ns/1ps

//=====================================================================
// top_smoke.sv - Prueba de humo del DUT bs_gnrtr_n_rbtr
//
// NO usa clases, mailboxes ni el ambiente. Solo reloj, reset y un
// estimulo manual, para confirmar tres cosas:
//   1. que Library.sv compila sin fifo.sv
//   2. que la interfaz se conecta bien al DUT
//   3. que el bus efectivamente mueve un paquete de una terminal a otra
//=====================================================================

module top_smoke;

  localparam int BITS      = 1;
  localparam int DRVRS     = 4;
  localparam int PCKG_SZ   = 16;
  localparam bit [7:0] BROADCAST = 8'hFF;

  localparam int CLK_HALF = 5;   // medio periodo -> periodo de 10 ns

  // ------------------------------------------------------------------
  // Reloj
  // ------------------------------------------------------------------
  logic clk = 1'b0;
  always #CLK_HALF clk = ~clk;

  // ------------------------------------------------------------------
  // Interfaz y DUT
  // ------------------------------------------------------------------
  bus_if #(BITS, DRVRS, PCKG_SZ) vif (.clk(clk));

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

  // ------------------------------------------------------------------
  // Parametros del estimulo, ajustables por plusarg
  // ------------------------------------------------------------------
  int unsigned max_cycles = 400;
  bit          do_dump    = 0;

  // Paquete de prueba: destino en los 8 MSB, payload en los 8 LSB
  localparam int unsigned SRC_T = 0;              // terminal que envia
  localparam bit [7:0]    DST_T = 8'd1;           // terminal destino
  localparam bit [7:0]    PAYLD = 8'hA5;
  localparam bit [PCKG_SZ-1:0] PKT = {DST_T, PAYLD};

  // ------------------------------------------------------------------
  // Contadores de actividad
  // ------------------------------------------------------------------
  int unsigned n_pop  [DRVRS];
  int unsigned n_push [DRVRS];
  bit          visto_push = 0;

  always @(posedge clk) begin
    if (!vif.reset) begin
      for (int i = 0; i < DRVRS; i++) begin
        if (vif.pop[0][i] === 1'b1) begin
          n_pop[i]++;
          $display("[%0t] POP  en terminal %0d  (D_pop=0x%0h)",
                   $time, i, vif.D_pop[0][i]);
        end
        if (vif.push[0][i] === 1'b1) begin
          n_push[i]++;
          visto_push = 1;
          $display("[%0t] PUSH en terminal %0d  (D_push=0x%0h)",
                   $time, i, vif.D_push[0][i]);
        end
      end
    end
  end

  // ------------------------------------------------------------------
  // Secuencia principal
  // ------------------------------------------------------------------
  initial begin
    void'($value$plusargs("max_cycles=%d", max_cycles));
    void'($value$plusargs("dump=%d", do_dump));

    if (do_dump) begin
      $dumpfile("smoke.vcd");
      $dumpvars(0, top_smoke);
    end

    foreach (n_pop[i])  n_pop[i]  = 0;
    foreach (n_push[i]) n_push[i] = 0;

    // --- Reset -------------------------------------------------------
    vif.reset = 1'b1;
    for (int b = 0; b < BITS; b++)
      for (int i = 0; i < DRVRS; i++) begin
        vif.pndng[b][i] = 1'b0;
        vif.D_pop[b][i] = '0;
      end

    repeat (5) @(posedge clk);
    vif.reset = 1'b0;
    $display("[%0t] reset liberado", $time);
    repeat (2) @(posedge clk);

    // --- Estimulo: terminal 0 tiene un paquete para la terminal 1 ----
    $display("[%0t] terminal %0d presenta paquete 0x%0h (dst=%0d)",
             $time, SRC_T, PKT, DST_T);
    vif.D_pop[0][SRC_T] <= PKT;
    vif.pndng[0][SRC_T] <= 1'b1;

    // Se mantiene pndng hasta que el DUT haga el pop
    wait (vif.pop[0][SRC_T] === 1'b1);
    @(posedge clk);
    vif.pndng[0][SRC_T] <= 1'b0;
    $display("[%0t] el DUT consumio el paquete, pndng abajo", $time);

    // Espera a que el paquete salga serializado por el bus
    repeat (PCKG_SZ * 6) @(posedge clk);

    reporte();
    $finish;
  end

  // ------------------------------------------------------------------
  // Watchdog: si algo se cuelga, no deja la simulacion corriendo
  // ------------------------------------------------------------------
  initial begin
    repeat (max_cycles) @(posedge clk);
    $display("[%0t] WATCHDOG: se agotaron los %0d ciclos", $time, max_cycles);
    reporte();
    $finish;
  end

  task automatic reporte();
    $display("");
    $display("==========================================");
    $display("           SMOKE TEST REPORT");
    $display("==========================================");
    for (int i = 0; i < DRVRS; i++)
      $display("  T%0d: pop=%0d push=%0d", i, n_pop[i], n_push[i]);
    $display("------------------------------------------");
    if (n_pop[SRC_T] == 0)
      $display("  RESULTADO: FALLO - el DUT nunca hizo pop");
    else if (!visto_push)
      $display("  RESULTADO: PARCIAL - hubo pop pero ningun push");
    else if (n_push[DST_T] > 0)
      $display("  RESULTADO: OK - el paquete llego a la terminal %0d", DST_T);
    else
      $display("  RESULTADO: REVISAR - hubo push, pero no en la terminal %0d", DST_T);
    $display("==========================================");
    $display("");
  endtask

endmodule
