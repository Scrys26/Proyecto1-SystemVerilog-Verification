class Agente #(
    parameter int PCKG_SZ = 16,
    parameter int DRVRS   = 4,
    parameter bit [7:0] BROADCAST = 8'hFF
);
    int unsigned terminal_id;

    bus_config cfg;

    mailbox #(
        bus_txn #(PCKG_SZ, DRVRS, BROADCAST)
    ) agnt2drv;

    mailbox #(
        bus_txn #(PCKG_SZ, DRVRS, BROADCAST)
    ) agnt2sb;

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
        ) agnt2drv,

        mailbox #(
            bus_txn #(PCKG_SZ, DRVRS, BROADCAST)
        ) agnt2sb
    );

        this.terminal_id = terminal_id;
        this.agnt2drv    = agnt2drv;
        this.agnt2sb     = agnt2sb;

        cfg = bus_config::get();

        blueprint = new(terminal_id);

        n_generated = 0;

    endfunction

    task run();

        bus_txn #(
            PCKG_SZ,
            DRVRS,
            BROADCAST
        ) tr_drv;

        bus_txn #(
            PCKG_SZ,
            DRVRS,
            BROADCAST
        ) tr_sb;


        $display(
            "[%0t] [AGNT%0d] iniciado",
            $time,
            terminal_id
        );

        repeat (cfg.n_txn_per_terminal) begin

            if (!blueprint.randomize()) begin

                $fatal(
                    1,
                    "[%0t] [AGNT%0d] fallo randomize()",
                    $time,
                    terminal_id
                );

            end

            tr_drv = blueprint.copy();
            tr_sb  = blueprint.copy();

            n_generated++;


            if (cfg.verbose) begin

                tr_drv.print(
                    $sformatf(
                        "AGNT%0d",
                        terminal_id
                    )
                );

            end

             agnt2sb.put(tr_sb);

            agnt2drv.put(tr_drv);
       

        end


        $display(
            "[%0t] [AGNT%0d] termino. Generadas=%0d",
            $time,
            terminal_id,
            n_generated
        );

    endtask

endclass