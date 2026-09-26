`timescale 1ns/1ps

`include "bus_config.svh"
`include "bus_txn.svh"
`include "Agente.sv"

module tb_agente;

    localparam int PCKG_SZ = 16;
    localparam int DRVRS   = 4;
    localparam bit [7:0] BROADCAST = 8'hFF;

    bus_config cfg;

    mailbox #(
        bus_txn #(PCKG_SZ, DRVRS, BROADCAST)
    ) agnt2drv;

    mailbox #(
        bus_txn #(PCKG_SZ, DRVRS, BROADCAST)
    ) agnt2sb;

    Agente #(
        PCKG_SZ,
        DRVRS,
        BROADCAST
    ) agnt;

    bus_txn #(PCKG_SZ, DRVRS, BROADCAST) tr_drv;
    bus_txn #(PCKG_SZ, DRVRS, BROADCAST) tr_sb;

    int errores = 0;

    initial begin

        $display("====================================");
        $display("          TEST DE Agente");
        $display("====================================");

        // Configuracion compartida
        cfg = bus_config::get();

        cfg.n_txn_per_terminal = 10;

        cfg.min_delay = 0;
        cfg.max_delay = 5;

        cfg.wt_valid     = 100;
        cfg.wt_broadcast = 0;
        cfg.wt_invalid   = 0;

        cfg.allow_self_send = 0;

        // Para que el log sea mas limpio
        cfg.verbose = 0;

        cfg.validate();
        cfg.print();

        // Crear mailboxes
        agnt2drv = new();
        agnt2sb  = new();


        // Este agente representa la terminal 2
        agnt = new( 2,agnt2drv, agnt2sb);
        agnt.run();

        if (agnt2drv.num() != cfg.n_txn_per_terminal) begin

            $error("agnt2drv contiene %0d transacciones, se esperaban %0d",agnt2drv.num(),cfg.n_txn_per_terminal
            );
            errores++;
        end

        if (agnt2sb.num() != cfg.n_txn_per_terminal) begin
            $error("agnt2sb contiene %0d transacciones, se esperaban %0d",agnt2sb.num(),cfg.n_txn_per_terminal
            );
            errores++;
        end

        repeat (cfg.n_txn_per_terminal) begin

            agnt2drv.get(tr_drv);
            agnt2sb.get(tr_sb);

            $display("");
            $display("Comparando transaccion id=%0d", tr_drv.id);

            tr_drv.print("DRV");
            tr_sb.print("SB");

            if (tr_drv.id != tr_sb.id) begin
                $error("ID diferente");
                errores++;
            end
            if (tr_drv.src != tr_sb.src) begin
                $error("SRC diferente");
                errores++;
            end
            if (tr_drv.dst_type != tr_sb.dst_type) begin
                $error("DST_TYPE diferente");
                errores++;
            end
            if (tr_drv.dst != tr_sb.dst) begin
                $error("DST diferente");
                errores++;
            end
            if (tr_drv.payload != tr_sb.payload) begin
                $error("PAYLOAD diferente");
                errores++;
            end

            if (tr_drv.delay != tr_sb.delay) begin
                $error("DELAY diferente");
                errores++;
            end

            if (tr_drv.packet != tr_sb.packet) begin
                $error("PACKET diferente");
                errores++;
            end

            if (tr_drv == tr_sb) begin
                $error("Driver y Scoreboard recibieron el mismo handle");
                errores++;
            end

            if (tr_drv.src != 2) begin
                $error("Origen incorrecto: esperado=2 obtenido=%0d",tr_drv.src);
                errores++;
            end
        end

        $display("");

        if (errores == 0) begin
            $display(" TEST Agente: PASS");
        end
        else begin
            $display("TEST Agente: FAIL (%0d errores)",errores );
        end

        $finish;

    end

endmodule