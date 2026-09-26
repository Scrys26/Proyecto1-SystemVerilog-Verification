`timescale 1ns/1ps

`include "bus_config.svh"
`include "bus_txn.svh"
`include "bus_expec_item.svh"
`include "Scoreboard.svh"

module tb_scoreboard;

    localparam int PCKG_SZ = 16;
    localparam int DRVRS   = 4;
    localparam bit [7:0] BROADCAST = 8'hFF;

    mailbox #(
        bus_txn #(PCKG_SZ, DRVRS, BROADCAST)
    ) agnt2sb;

    Scoreboard #(
        PCKG_SZ,
        DRVRS,
        BROADCAST,
        1'b0
    ) sb;

    bus_txn #(
        PCKG_SZ,
        DRVRS,
        BROADCAST
    ) tr;

    bus_txn #(
        PCKG_SZ,
        DRVRS,
        BROADCAST
    ) frente;

    bus_expected_item #(
        PCKG_SZ
    ) item;

    int idx;
    int errores = 0;

    initial begin
        $display("       TEST DE Scoreboard");
        // Crear mailbox y Scoreboard
        agnt2sb = new();
        sb = new(agnt2sb);
        // Arrancar run() del Scoreboard
        fork
            sb.run();
        join_none

        tr = new(0);
        tr.id       = 1;
        tr.src      = 0;
        tr.dst      = 8'h02;
        tr.dst_type = DST_VALID;
        tr.payload  = 8'hA5;
        tr.delay    = 0;
        tr.packet   = 16'h02A5;


        // Enviar al Scoreboard
        agnt2sb.put(tr);
        #1;


        if (sb.fifo_esperada[0].size() != 1) begin
            $error("FIFO esperada[0] size=%0d, esperado=1",sb.fifo_esperada[0].size() );
            errores++;
        end

        if (sb.n_recibidas != 1) begin
            $error("n_recibidas=%0d, esperado=1",sb.n_recibidas );
            errores++;
        end

        frente = sb.ver_frente(0);

        if (frente == null) begin

            $error("ver_frente(0) devolvio null");
            errores++;
        end
        else begin

            if (frente.packet != 16'h02A5) begin

                $error( "Frente incorrecto: esperado=02A5 obtenido=%0h", frente.packet );
                errores++;
            end

        end

        if (sb.fifo_esperada[0].size() != 1) begin

            $error("ver_frente() modifico la FIFO");
            errores++;
        end

        frente = sb.consumir_frente(0);
        if (frente == null) begin

            $error("consumir_frente(0) devolvio null");
            errores++;
        end

        if (sb.fifo_esperada[0].size() != 0) begin
            $error( "FIFO esperada[0] no quedo vacia" );
            errores++;
        end

        if (sb.n_consumidas != 1) begin

            $error("n_consumidas=%0d, esperado=1",sb.n_consumidas );
            errores++;
        end
        sb.esperar_entrega(frente,100);

        if (sb.entregas_pendientes.size() != 1) begin

            $error( "Entregas pendientes=%0d, esperado=1",sb.entregas_pendientes.size() );
            errores++;
        end

        idx = sb.buscar_entrega( 2, 16'h02A5 );

        if (idx < 0) begin
            $error("No se encontro entrega dst=2 packet=02A5" );
            errores++;
        end
        else begin
            item = sb.ver_entrega(idx);

            if (item == null) begin
                $error("ver_entrega() devolvio null"  );
                errores++;
            end
            else begin

                $display("");
                $display("Entrega encontrada:");
                item.print("TEST_SB");
            end
        end

        item = sb.retirar_entrega(idx);


        if (sb.entregas_pendientes.size() != 0) begin

            $error("La entrega no fue eliminada");
            errores++;
        end

        if (!sb.vacio()) begin
            $error( "Scoreboard deberia estar vacio" );
            errores++;
        end
        sb.reporte();
        $display("====================================");

        if (errores == 0) begin
            $display("      TEST Scoreboard: PASS");
        end
        else begin
            $display(" TEST Scoreboard: FAIL (%0d errores)",errores);
        end

        $finish;

    end

endmodule