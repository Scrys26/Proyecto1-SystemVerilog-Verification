`timescale 1ns/1ps

`include "bus_config.svh"
`include "bus_txn.svh"

module tb_bus_txn;

    bus_config cfg;

    bus_txn #(
        16,
        4,
        8'hFF
    ) tr;

    initial begin

        $display("       TEST DE bus_txn");
      
        cfg = bus_config::get();

        cfg.n_txn_per_terminal = 10;

        cfg.min_delay = 0;
        cfg.max_delay = 5;

        cfg.wt_valid     = 100;
        cfg.wt_broadcast = 0;
        cfg.wt_invalid   = 0;

        cfg.allow_self_send = 0;

        cfg.validate();
        cfg.print();

        tr = new(0);

        repeat (10) begin

            if (!tr.randomize()) begin
                $fatal("Fallo en randomize()");
            end

            tr.print("TEST_TXN");
        end

        $display("       FIN DEL TEST");

        $finish;

    end

endmodule
