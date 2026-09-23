class Scoreboard #(
    parameter int PCKG_SZ = 16,
    parameter int DRVRS   = 4,
    parameter bit [7:0] BROADCAST = 8'hFF,
    parameter bit BROADCAST_TO_SELF = 1'b0
);

    // Agent -> Scoreboard
    mailbox #(
        bus_txn #(PCKG_SZ, DRVRS, BROADCAST)
    ) agnt2sb;

    bus_txn #(
        PCKG_SZ,
        DRVRS,
        BROADCAST
    ) fifo_esperada [DRVRS][$];

    bus_expected_item #(PCKG_SZ) entregas_pendientes[$];

    // Estadisticas del modelo
    int unsigned n_recibidas;
    int unsigned n_consumidas;
    int unsigned n_entregas_creadas;
    int unsigned n_entregas_retiradas;
    int unsigned n_broadcast;
    int unsigned n_invalidas;
    int unsigned n_src_fuera_rango;

    function new(
        mailbox #(
            bus_txn #(PCKG_SZ, DRVRS, BROADCAST)
        ) agnt2sb
    );
        this.agnt2sb = agnt2sb;

        n_recibidas          = 0;
        n_consumidas         = 0;
        n_entregas_creadas   = 0;
        n_entregas_retiradas = 0;
        n_broadcast          = 0;
        n_invalidas          = 0;
        n_src_fuera_rango    = 0;

    endfunction
    task run();

        bus_txn #(
            PCKG_SZ,
            DRVRS,
            BROADCAST
        ) tr;

        $display(
            "[%0t] [SB] iniciado",
            $time
        );

        forever begin
            agnt2sb.get(tr);

            if (tr.src >= DRVRS) begin

                n_src_fuera_rango++;

                $display("[%0t] [SB] transaccion ignorada: src=%0d fuera de rango",$time,tr.src);
            end
            else begin
                fifo_esperada[tr.src].push_back(tr);
                n_recibidas++;
            end

        end

    endtask

    function bus_txn #(
        PCKG_SZ,
        DRVRS,
        BROADCAST
    ) ver_frente(int unsigned src);

        if (src >= DRVRS) begin
            return null;
        end
        if (fifo_esperada[src].size() == 0) begin
            return null;
        end
        return fifo_esperada[src][0];

    endfunction

    function bus_txn #(
        PCKG_SZ,
        DRVRS,
        BROADCAST
    ) consumir_frente(int unsigned src);

        bus_txn #(
            PCKG_SZ,
            DRVRS,
            BROADCAST
        ) tr;

        if (src >= DRVRS) begin
            return null;
        end
        if (fifo_esperada[src].size() == 0) begin  
            return null;
        end

        tr = fifo_esperada[src].pop_front();
        n_consumidas++;

        return tr;

    endfunction

    function void agregar_entrega(
        bus_txn #(
            PCKG_SZ,
            DRVRS,
            BROADCAST
        ) tr,

        int unsigned dst,
        time t_pop,
        bit is_broadcast
    );

        bus_expected_item #(PCKG_SZ) item;

        item = new();
        item.txn_id       = tr.id;
        item.src          = tr.src;
        item.dst          = dst;
        item.packet       = tr.packet;
        item.t_pop        = t_pop;
        item.is_broadcast = is_broadcast;

        entregas_pendientes.push_back(item);

        n_entregas_creadas++;

    endfunction
    function void esperar_entrega(
        bus_txn #(
            PCKG_SZ,
            DRVRS,
            BROADCAST
        ) tr,

        time t_pop
    );

        bit [7:0] dst;

        if (tr == null) begin   
            return;
        end
        dst = tr.packet[PCKG_SZ-1 -: 8];
        // Broadcast
        if (dst == BROADCAST) begin
            n_broadcast++;
            for (int d = 0; d < DRVRS; d++) begin

                if (BROADCAST_TO_SELF || (d != tr.src)) begin
                    agregar_entrega(
                        tr,
                        d,
                        t_pop,
                        1'b1
                    );
                end
            end
        end
        // Transferencia punto a punto valida
        else if (dst < DRVRS) begin

            agregar_entrega(
                tr,
                dst,
                t_pop,
                1'b0
            );

        end
        // Destino invalido: no se espera ningun push
        else begin
            n_invalidas++;
        end

    endfunction

    function int buscar_entrega(
        int unsigned dst,
        logic [PCKG_SZ-1:0] packet
    );

        foreach (entregas_pendientes[i]) begin

            if (entregas_pendientes[i].dst == dst && entregas_pendientes[i].packet === packet) begin
                return i;
            end
        end

        return -1;

    endfunction

    function bus_expected_item #(PCKG_SZ) ver_entrega(
        int index
    );
        if (index < 0 ||index >= entregas_pendientes.size())begin 
            return null;
        end
        return entregas_pendientes[index];

    endfunction

    function bus_expected_item #(PCKG_SZ) retirar_entrega(
        int index
    );
        bus_expected_item #(PCKG_SZ) item;
        if (index < 0 ||index >= entregas_pendientes.size())begin
            return null;
        end
        item = entregas_pendientes[index];
        entregas_pendientes.delete(index);
        n_entregas_retiradas++;
        return item;

    endfunction

    function void limpiar();

        foreach (fifo_esperada[i]) begin
            fifo_esperada[i].delete();
        end 
        entregas_pendientes.delete();

    endfunction

    function bit vacio();

        if (agnt2sb.num() != 0)begin
            return 0;
        end 
        foreach (fifo_esperada[i]) begin

            if (fifo_esperada[i].size() != 0) begin  
                return 0;
            end
        end
        if (entregas_pendientes.size() != 0) begin
            return 0;
        end
        return 1;
    endfunction

    function void reporte();

        $display("");
        $display("======================================");
        $display("          SCOREBOARD REPORT");
        $display("======================================");
        $display("Recibidas del Agent      : %0d", n_recibidas);
        $display("Consumidas por pop       : %0d", n_consumidas);
        $display("Entregas creadas         : %0d", n_entregas_creadas);
        $display("Entregas retiradas       : %0d", n_entregas_retiradas);
        $display("Broadcast                : %0d", n_broadcast);
        $display("Destinos invalidos       : %0d", n_invalidas);
        $display("Src fuera de rango       : %0d", n_src_fuera_rango);
        $display(
            "Entregas pendientes     : %0d",
            entregas_pendientes.size()
        );

        foreach (fifo_esperada[i]) begin

            $display(
                "FIFO esperada[%0d]      : %0d",
                i,
                fifo_esperada[i].size()
            );

        end

        $display("======================================");
        $display("");

    endfunction

endclass
