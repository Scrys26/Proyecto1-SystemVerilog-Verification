class bus_agent #(
    parameter int PCKG_SZ = 16,
    parameter int DRVRS   = 4,
    parameter bit [7:0] BROADCAST = 8'hFF
);

    int unsigned terminal_id;

    bus_config cfg;

    mailbox #(
        bus_txn #(PCKG_SZ, DRVRS, BROADCAST)
    ) agnt2drv;

    bus_txn #(
        PCKG_SZ,
        DRVRS,
        BROADCAST
    ) blueprint;

    int unsigned n_generated;


    function new(
        int unsigned terminal_id,

        mailbox #(
            bus_txn #(PCKG_SZ, DRVRS, BROADCAST)
        ) agnt2drv
    );

        this.terminal_id = terminal_id;
        this.agnt2drv    = agnt2drv;

        cfg = bus_config::get();

        blueprint = new(terminal_id);

        n_generated = 0;

    endfunction


    task run();

        bus_txn #(
            PCKG_SZ,
            DRVRS,
            BROADCAST
        ) tr;

        $display(
            "[%0t] Agent[%0d] iniciado",
            $time,
            terminal_id
        );

        repeat (cfg.n_txn_per_terminal) begin

            if (!blueprint.randomize()) begin

                $fatal(
                    1,
                    "[%0t] Agent[%0d]: fallo randomize()",
                    $time,
                    terminal_id
                );

            end

            tr = blueprint.copy();

            n_generated++;

            if (cfg.verbose) begin

                tr.print(
                    $sformatf(
                        "Agent[%0d]",
                        terminal_id
                    )
                );

            end

            agnt2drv.put(tr);

        end

        $display(
            "[%0t] Agent[%0d] termino. Generadas=%0d",
            $time,
            terminal_id,
            n_generated
        );

    endtask

endclass