class Checker #(
    parameter int PCKG_SZ = 16,
    parameter int DRVRS   = 4,
    parameter bit [7:0] BROADCAST = 8'hFF,
    parameter bit BROADCAST_TO_SELF = 1'b0
);
    // Monitor -> Checker
    mailbox #(
        bus_mon_txn #(PCKG_SZ, DRVRS)
    ) mon2chk;

    Scoreboard #(
        PCKG_SZ,
        DRVRS,
        BROADCAST,
        BROADCAST_TO_SELF
    ) sb;

    // Estadisticas
    int unsigned n_samples       = 0;
    int unsigned n_pops          = 0;
    int unsigned n_pushes        = 0;
    int unsigned n_completed     = 0;
    int unsigned n_errors        = 0;

    int unsigned n_pop_empty     = 0;
    int unsigned n_pop_mismatch  = 0;
    int unsigned n_push_unexp    = 0;

    function new(
        mailbox #(
            bus_mon_txn #(PCKG_SZ, DRVRS)
        ) mon2chk,

        Scoreboard #(
            PCKG_SZ,
            DRVRS,
            BROADCAST,
            BROADCAST_TO_SELF
        ) sb
    );

        this.mon2chk = mon2chk;
        this.sb      = sb;

    endfunction

    task run();
        bus_mon_txn #(
            PCKG_SZ,
            DRVRS
        ) m;
        $display(
            "[%0t] [CHK] iniciado",
            $time
        );
        forever begin

            mon2chk.get(m);
            n_samples++;

            if (m.reset) begin
                continue;
            end
            check_pushes(m);
            check_pops(m);

        end
    endtask

    function void check_pushes(
        bus_mon_txn #(PCKG_SZ, DRVRS) m
    );
        int idx;
        bus_expected_item #(
            PCKG_SZ
        ) item;
        for (int dst = 0; dst < DRVRS; dst++) begin

            if (!m.push[dst]) begin
                continue;
            end
            n_pushes++;

            idx = sb.buscar_entrega(
                dst,
                m.D_push[dst]
            );

            if (idx < 0) begin
                n_errors++;
                n_push_unexp++;

                $error(
                    "[%0t] [CHK] PUSH inesperado: dst=%0d packet=0x%0h",
                    m.t,
                    dst,
                    m.D_push[dst]
                );
                continue;

            end
            item = sb.ver_entrega(idx);

            if (item == null) begin
                n_errors++;
                $error("[%0t] [CHK] error interno: entrega encontrada pero no disponible",m.t);
                continue;
            end
            // La busqueda ya comprobo destino + paquete.
            // Se retira solamente despues de confirmar la salida.
            void'(sb.retirar_entrega(idx));
            n_completed++;
            $display(
                "[%0t] [CHK] OK push: src=%0d dst=%0d packet=0x%0h latency_desde_pop=%0t",
                m.t,
                item.src,
                item.dst,
                item.packet,
                m.t - item.t_pop
            );

        end
    endfunction
    function void check_pops(
        bus_mon_txn #(PCKG_SZ, DRVRS) m
    );

        bus_txn #(
            PCKG_SZ,
            DRVRS,
            BROADCAST
        ) exp;

        for (int src = 0; src < DRVRS; src++) begin
            if (!m.pop[src]) begin
                continue;
            end
            n_pops++;
            if (!m.pndng[src]) begin
                n_errors++;
                n_pop_empty++;
                $error("[%0t] [CHK] POP sin PNDNG: src=%0d",m.t,src);
                continue;

            end
            exp = sb.ver_frente(src);
            // El Agent/Scoreboard no esperaba ningun paquete
            // para esta terminal.
            if (exp == null) begin
                n_errors++;
                n_pop_empty++;
                $error(
                    "[%0t] [CHK] POP inesperado: FIFO esperada[%0d] vacia, D_pop=0x%0h",
                    m.t,
                    src,
                    m.D_pop[src]
                );
                continue;
            end
            // Se usa !== para que
            // X/Z tambien sean considerados como un mismatch.
            if (m.D_pop[src] !== exp.packet) begin
                n_errors++;
                n_pop_mismatch++;
                $error(
                    "[%0t] [CHK] D_pop mismatch: src=%0d exp=0x%0h got=0x%0h",
                    m.t,
                    src,
                    exp.packet,
                    m.D_pop[src]
                );
            end
            exp = sb.consumir_frente(src);
            sb.esperar_entrega(exp,m.t);
        end
    endfunction
    // Comprobacion al final de la prueba

    function void final_check();
        int unsigned restantes = 0;
        foreach (sb.fifo_esperada[i]) begin
            restantes += sb.fifo_esperada[i].size();
        end
        restantes += sb.entregas_pendientes.size();
        
        if (restantes != 0) begin
            n_errors++;
            $error("[CHK] La simulacion termino con %0d elementos esperados pendientes", restantes);
        end
    endfunction

    // Reporte final
    function void reporte();

        $display("");
        $display("======================================");
        $display("            CHECKER REPORT");
        $display("======================================");
        $display("Muestras recibidas       : %0d", n_samples);
        $display("POP observados           : %0d", n_pops);
        $display("PUSH observados          : %0d", n_pushes);
        $display("Entregas correctas       : %0d", n_completed);
        $display("POP sin dato esperado    : %0d", n_pop_empty);
        $display("D_pop incorrectos        : %0d", n_pop_mismatch);
        $display("PUSH inesperados         : %0d", n_push_unexp);
        $display("ERRORES                  : %0d", n_errors);
        $display("======================================");
        $display("");

    endfunction

endclass
