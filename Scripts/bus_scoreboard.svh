class bus_scoreboard #(
    parameter int PCKG_SZ = 16,
    parameter int DRVRS   = 4,
    parameter bit [7:0] BROADCAST = 8'hFF,
    parameter bit BROADCAST_TO_SELF = 1'b0
);

    mailbox #(bus_mon_txn #(PCKG_SZ, DRVRS)) mon2sb;

    // Paquetes aceptados por el DUT mediante pop,
    // pero aun pendientes de aparecer en un push.
    bus_expected_item #(PCKG_SZ) pending_delivery[$];

    // FIFO receptora emulada por terminal.
    bit [PCKG_SZ-1:0] rx_fifo [DRVRS][$];

    // Seguimiento del frente de cada FIFO de origen.
    bit source_valid [DRVRS];
    bit [PCKG_SZ-1:0] source_packet [DRVRS];
    time source_visible_time [DRVRS];

    int unsigned n_pops;
    int unsigned n_pushes;
    int unsigned n_completed;
    int unsigned n_errors;
    int unsigned n_invalid;
    int unsigned n_broadcast;

    function new(
        mailbox #(bus_mon_txn #(PCKG_SZ, DRVRS)) mon2sb
    );
        this.mon2sb = mon2sb;

        n_pops = 0;
        n_pushes = 0;
        n_completed = 0;
        n_errors = 0;
        n_invalid = 0;
        n_broadcast = 0;

        foreach (source_valid[i]) begin
            source_valid[i] = 0;
            source_packet[i] = '0;
            source_visible_time[i] = 0;
        end
    endfunction


    function void reset_model();
        pending_delivery.delete();

        foreach (rx_fifo[i])
            rx_fifo[i].delete();

        foreach (source_valid[i]) begin
            source_valid[i] = 0;
            source_packet[i] = '0;
            source_visible_time[i] = 0;
        end
    endfunction


    task track_sources(
        bus_mon_txn #(PCKG_SZ, DRVRS) m
    );
        for (int src = 0; src < DRVRS; src++) begin
            if (m.pndng[src] && !source_valid[src]) begin
                source_valid[src] = 1;
                source_packet[src] = m.D_pop[src];
                source_visible_time[src] = m.t;
            end
        end
    endtask


    function int find_expected(
        int unsigned dst,
        bit [PCKG_SZ-1:0] packet
    );
        foreach (pending_delivery[i]) begin
            if (
                pending_delivery[i].dst == dst &&
                pending_delivery[i].packet === packet
            )
                return i;
        end

        return -1;
    endfunction


    function void add_expected(
        int unsigned src,
        int unsigned dst,
        bit [PCKG_SZ-1:0] packet,
        time t_send,
        time t_pop,
        bit is_broadcast
    );
        bus_expected_item #(PCKG_SZ) item;

        item = new();
        item.src = src;
        item.dst = dst;
        item.packet = packet;
        item.t_send = t_send;
        item.t_pop = t_pop;
        item.is_broadcast = is_broadcast;

        pending_delivery.push_back(item);
    endfunction


    task process_pop(
        bus_mon_txn #(PCKG_SZ, DRVRS) m,
        int unsigned src
    );
        bit [PCKG_SZ-1:0] packet;
        bit [7:0] dst;

        packet = m.D_pop[src];
        dst = packet[PCKG_SZ-1 -: 8];

        n_pops++;

        if (!m.pndng[src]) begin
            $error(
                "[%0t] SB: pop sin pndng en terminal %0d",
                m.t, src
            );
            n_errors++;
        end

        if (source_valid[src]) begin
            if (packet !== source_packet[src]) begin
                $error(
                    "[%0t] SB: D_pop cambio antes de pop. src=%0d esperado=0x%0h observado=0x%0h",
                    m.t, src, source_packet[src], packet
                );
                n_errors++;
            end
        end

        if (dst == BROADCAST) begin
            n_broadcast++;

            for (int d = 0; d < DRVRS; d++) begin
                if (BROADCAST_TO_SELF || (d != src)) begin
                    add_expected(
                        src,
                        d,
                        packet,
                        source_valid[src] ? source_visible_time[src] : m.t,
                        m.t,
                        1'b1
                    );
                end
            end
        end
        else if (dst < DRVRS) begin
            add_expected(
                src,
                dst,
                packet,
                source_valid[src] ? source_visible_time[src] : m.t,
                m.t,
                1'b0
            );
        end
        else begin
            n_invalid++;

            $display(
                "[%0t] SB: destino invalido src=%0d dst=0x%0h packet=0x%0h",
                m.t, src, dst, packet
            );
        end

        source_valid[src] = 0;
        source_packet[src] = '0;
        source_visible_time[src] = 0;
    endtask


    task process_push(
        bus_mon_txn #(PCKG_SZ, DRVRS) m,
        int unsigned dst
    );
        bit [PCKG_SZ-1:0] packet;
        int idx;
        bus_expected_item #(PCKG_SZ) item;

        packet = m.D_push[dst];
        n_pushes++;

        idx = find_expected(dst, packet);

        if (idx < 0) begin
            $error(
                "[%0t] SB: PUSH inesperado dst=%0d packet=0x%0h",
                m.t, dst, packet
            );
            n_errors++;
            return;
        end

        item = pending_delivery[idx];

        item.t_recv = m.t;
        item.latency = item.t_recv - item.t_send;

        // Emulacion de la FIFO de recepcion.
        rx_fifo[dst].push_back(packet);

        pending_delivery.delete(idx);
        n_completed++;

        $display(
            "[%0t] SB PASS: src=%0d dst=%0d packet=0x%0h latency=%0t",
            m.t, item.src, item.dst, item.packet, item.latency
        );
    endtask


    task run();
        bus_mon_txn #(PCKG_SZ, DRVRS) m;

        $display("[%0t] Scoreboard iniciado", $time);

        forever begin
            mon2sb.get(m);

            if (m.reset) begin
                reset_model();
                continue;
            end

            track_sources(m);

            for (int src = 0; src < DRVRS; src++) begin
                if (m.pop[src])
                    process_pop(m, src);
            end

            for (int dst = 0; dst < DRVRS; dst++) begin
                if (m.push[dst])
                    process_push(m, dst);
            end
        end
    endtask


    function void final_check();
        if (pending_delivery.size() != 0) begin
            $error(
                "SB: quedaron %0d entregas pendientes al finalizar",
                pending_delivery.size()
            );

            n_errors += pending_delivery.size();
        end
    endfunction


    function void report();
        $display("");
        $display("======================================");
        $display("          SCOREBOARD REPORT");
        $display("======================================");
        $display("POP observados       : %0d", n_pops);
        $display("PUSH observados      : %0d", n_pushes);
        $display("Completados          : %0d", n_completed);
        $display("Broadcast             : %0d", n_broadcast);
        $display("Destinos invalidos   : %0d", n_invalid);
        $display("Pendientes           : %0d", pending_delivery.size());
        $display("Errores              : %0d", n_errors);
        $display("======================================");
        $display("");
    endfunction

endclass
