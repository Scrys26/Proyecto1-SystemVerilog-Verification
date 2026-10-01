//Parametros
interface bus_if #(
    parameter int BITS    = 1,   // cantidad de buses en paralelo
    parameter int DRVRS   = 4,   // terminales por bus 
    parameter int PCKG_SZ = 16   // ancho del paquete
) (
    input logic clk //Clk generado por tb
);

  logic reset;

  
  logic pndng [BITS-1:0][DRVRS-1:0];   // TB  -> DUT
  wire  pop   [BITS-1:0][DRVRS-1:0];   // DUT -> TB
  wire  push  [BITS-1:0][DRVRS-1:0];   // DUT -> TB

  logic [PCKG_SZ-1:0] D_pop  [BITS-1:0][DRVRS-1:0];  // TB  -> DUT
  wire  [PCKG_SZ-1:0] D_push [BITS-1:0][DRVRS-1:0];  // DUT -> TB

  // Clocking block del driver (evita que la señal se maneje justo en el
  // flanco)
  clocking drv_cb @(posedge clk);
    default input #1step output #1;
    output pndng;
    output D_pop;
    input  pop;
    input  push;
    input  D_push;
  endclocking

  //Clocking block del driver (todo es pasivo)
  clocking mon_cb @(posedge clk);
    default input #1step;
    input reset;
    input pndng;
    input pop;
    input push;
    input D_pop;
    input D_push;
  endclocking

  //Vista de la interfaz, es lo que recibe el driver
  modport DRV (
    clocking drv_cb,
    output   reset
  );

  //Modport para el monitor y que no pase datos cuando hay reset
  modport MON (
    clocking mon_cb,
    input    reset
  );

  // Modport para conectar el DUT con senales crudas y  sin clocking.
  modport DUT (
    input  reset,
    input  pndng,
    input  D_pop,
    output pop,
    output push,
    output D_push
  );

endinterface
