//=====================================================================
// bus_if.sv - Interfaz PROVISIONAL para el DUT bs_gnrtr_n_rbtr
//
// Hecha para que el driver y el monitor existentes compilen y corran
// mientras llega la interfaz definitiva del equipo.
//
// Nombres que el TB actual ya asume y que NO se pueden cambiar:
//   - modports        : DRV, MON
//   - clocking blocks : drv_cb, mon_cb
//   - senales         : reset, pndng, pop, push, D_pop, D_push
//   - indexado        : senal[0][id]   (primer indice = bus, segundo = terminal)
//   - parametros      : #(BITS, DRVRS, PCKG_SZ)  en ese orden
//=====================================================================

interface bus_if #(
    parameter int BITS    = 1,   // cantidad de buses en paralelo
    parameter int DRVRS   = 4,   // terminales por bus
    parameter int PCKG_SZ = 16   // ancho del paquete
) (
    input logic clk
);

  // -------------------------------------------------------------------
  // Senales. Las dimensiones replican exactamente los puertos del DUT:
  //    input  pndng [bits-1:0][drvrs-1:0]
  //    output push  [bits-1:0][drvrs-1:0]
  //    output pop   [bits-1:0][drvrs-1:0]
  //    input  [pckg_sz-1:0] D_pop  [bits-1:0][drvrs-1:0]
  //    output [pckg_sz-1:0] D_push [bits-1:0][drvrs-1:0]
  // -------------------------------------------------------------------
  logic reset;

  // Las que maneja el TB son variables; las que maneja el DUT son wires,
  // porque un puerto de salida conectado a una variable a traves de un
  // arreglo desempaquetado no lo resuelven todos los simuladores.
  logic pndng [BITS-1:0][DRVRS-1:0];   // TB  -> DUT
  wire  pop   [BITS-1:0][DRVRS-1:0];   // DUT -> TB
  wire  push  [BITS-1:0][DRVRS-1:0];   // DUT -> TB

  logic [PCKG_SZ-1:0] D_pop  [BITS-1:0][DRVRS-1:0];  // TB  -> DUT
  wire  [PCKG_SZ-1:0] D_push [BITS-1:0][DRVRS-1:0];  // DUT -> TB

  // -------------------------------------------------------------------
  // Clocking block del driver.
  // El skew de salida #1 evita manejar la senal justo en el flanco.
  // El de entrada #1step muestrea el valor previo al flanco, o sea el
  // valor estable, que es lo que evita las carreras.
  // -------------------------------------------------------------------
  clocking drv_cb @(posedge clk);
    default input #1step output #1;
    output pndng;
    output D_pop;
    input  pop;
    input  push;
    input  D_push;
  endclocking

  // -------------------------------------------------------------------
  // Clocking block del monitor: todo entrada, es pasivo.
  // -------------------------------------------------------------------
  clocking mon_cb @(posedge clk);
    default input #1step;
    input reset;
    input pndng;
    input pop;
    input push;
    input D_pop;
    input D_push;
  endclocking

  // -------------------------------------------------------------------
  // Modports.
  // DRV lleva reset como salida porque driver::reset() hace
  // "vif.reset <= 1'b1" directo, fuera del clocking block.
  // -------------------------------------------------------------------
  modport DRV (
    clocking drv_cb,
    output   reset
  );

  modport MON (
    clocking mon_cb,
    input    reset
  );

  // Modport para conectar el DUT: senales crudas, sin clocking.
  modport DUT (
    input  reset,
    input  pndng,
    input  D_pop,
    output pop,
    output push,
    output D_push
  );

endinterface
