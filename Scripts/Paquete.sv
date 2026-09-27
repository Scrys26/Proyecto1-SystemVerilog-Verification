`ifndef TB_PKG_SV
`define TB_PKG_SV

`ifndef TB_BITS
    `define TB_BITS 1
`endif

`ifndef TB_DRVRS
    `define TB_DRVRS 4
`endif

`ifndef TB_PCKG_SZ
    `define TB_PCKG_SZ 16
`endif

`ifndef TB_BROADCAST
    `define TB_BROADCAST 8'hFF
`endif

package tb_pkg;
    // PARAMETROS ESTRUCTURALES
    parameter int BITS = `TB_BITS;

    parameter int DRVRS = `TB_DRVRS;

    parameter int PCKG_SZ = `TB_PCKG_SZ;

    parameter bit [7:0] BROADCAST = `TB_BROADCAST;

    parameter bit BROADCAST_TO_SELF = 1'b0;
    // CLASES BASE
    `include "bus_config.svh"
    `include "bus_txn.svh"
    `include "bus_mon_txn.svh"
    `include "bus_expec_item.svh"

    // CAPA DE COMANDOS
    `include "driver.svh"
    `include "Monitor.sv"
    // CAPA FUNCIONAL
  
    `include "Agente.sv"
    `include "Scoreboard.svh"
    `include "Checker.svh"
endpackage
`endif