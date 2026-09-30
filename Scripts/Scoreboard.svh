class Scoreboard #(
    parameter int PCKG_SZ = 16,
    parameter int DRVRS = 4,
    parameter bit [7:0] BROADCAST = 8'hFF,
    parameter bit BROADCAST_TO_SELF = 1'b0
);

    // ============================================================
    // MAILBOXES
    // ============================================================

    // Agent -> Scoreboard
    mailbox #(
        bus_txn #(PCKG_SZ,DRVRS,BROADCAST)
    ) agnt2sb;

    // Driver -> Scoreboard
    // Se utiliza para recibir el instante real de envio.
    mailbox #(
        bus_txn #(PCKG_SZ,DRVRS,BROADCAST)
    ) drv2sb;


    // ============================================================
    // MODELO ESPERADO
    // ============================================================

    // FIFO esperada por cada terminal de origen.
    bus_txn #(
        PCKG_SZ,
        DRVRS,
        BROADCAST
    ) fifo_esperada [DRVRS][$];

    // Entregas que esperamos observar como PUSH.
    bus_expected_item #(
        PCKG_SZ
    ) entregas_pendientes[$];


    // ============================================================
    // TIEMPOS DE ENVIO
    // ============================================================

    // Guarda:
    //
    // txn_id -> tiempo en que el Driver introdujo el paquete
    //           en la FIFO de entrada.
    //
    time t_envio_por_id[int unsigned];


    // ============================================================
    // ESTADISTICAS
    // ============================================================

    int unsigned n_recibidas = 0;
    int unsigned n_consumidas = 0;

    int unsigned n_entregas_creadas = 0;
    int unsigned n_entregas_retiradas = 0;

    int unsigned n_broadcast = 0;
    int unsigned n_invalidas = 0;

    int unsigned n_src_fuera_rango = 0;

    int unsigned n_envios_registrados = 0;


    // ============================================================
    // CONSTRUCTOR
    // ============================================================

    function new(
        mailbox #(
            bus_txn #(PCKG_SZ,DRVRS,BROADCAST)
        ) agnt2sb,

        mailbox #(
            bus_txn #(PCKG_SZ,DRVRS,BROADCAST)
        ) drv2sb = null
    );

        this.agnt2sb = agnt2sb;
        this.drv2sb  = drv2sb;

    endfunction


    // ============================================================
    // RUN
    // ============================================================

    task run();

        $display(
            "[%0t] [SB] iniciado",
            $time
        );

        fork

            recibir_agente();

            begin
                if (drv2sb != null)
                    recibir_envios();
            end

        join

    endtask


    // ============================================================
    // AGENT -> SCOREBOARD
    // ============================================================

    task recibir_agente();

        bus_txn #(
            PCKG_SZ,
            DRVRS,
            BROADCAST
        ) tr;

        forever begin

            agnt2sb.get(tr);

            if (tr.src >= DRVRS) begin

                n_src_fuera_rango++;

                $display(
                    "[%0t] [SB][ERROR] src=%0d fuera de rango",
                    $time,
                    tr.src
                );

            end
            else begin

                fifo_esperada[tr.src].push_back(tr);

                n_recibidas++;

            end

        end

    endtask


    // ============================================================
    // DRIVER -> SCOREBOARD
    // ============================================================

    task recibir_envios();

        bus_txn #(
            PCKG_SZ,
            DRVRS,
            BROADCAST
        ) tr;

        forever begin

            drv2sb.get(tr);

            t_envio_por_id[tr.id] = tr.t_envio;

            n_envios_registrados++;

        end

    endtask


    // ============================================================
    // OBTENER TIEMPO DE ENVIO
    // ============================================================

    function bit obtener_t_envio(
        input int unsigned txn_id,
        output time t_envio
    );

        if (t_envio_por_id.exists(txn_id)) begin

            t_envio = t_envio_por_id[txn_id];

            return 1'b1;

        end

        t_envio = 0;

        return 1'b0;

    endfunction


    // ============================================================
    // VER FRENTE DE FIFO ESPERADA
    // ============================================================

    function bus_txn #(
        PCKG_SZ,
        DRVRS,
        BROADCAST
    ) ver_frente(
        input int src
    );

        if (src < 0 || src >= DRVRS)
            return null;

        if (fifo_esperada[src].size() == 0)
            return null;

        return fifo_esperada[src][0];

    endfunction


    // ============================================================
    // CONSUMIR FRENTE DE FIFO
    // ============================================================

    function bus_txn #(
        PCKG_SZ,
        DRVRS,
        BROADCAST
    ) consumir_frente(
        input int src
    );

        bus_txn #(
            PCKG_SZ,
            DRVRS,
            BROADCAST
        ) tr;

        if (src < 0 || src >= DRVRS)
            return null;

        if (fifo_esperada[src].size() == 0)
            return null;

        tr = fifo_esperada[src].pop_front();

        n_consumidas++;

        return tr;

    endfunction


    // ============================================================
    // CREAR ENTREGAS ESPERADAS DESPUES DEL POP
    // ============================================================

    function void esperar_entrega(
        bus_txn #(
            PCKG_SZ,
            DRVRS,
            BROADCAST
        ) tr,

        time t_pop
    );

        bit [7:0] dst;

        dst = tr.packet[PCKG_SZ-1 -: 8];


        // --------------------------------------------------------
        // BROADCAST
        // --------------------------------------------------------

        if (dst == BROADCAST) begin

            n_broadcast++;

            for (int d = 0; d < DRVRS; d++) begin

                if (BROADCAST_TO_SELF || d != tr.src) begin

                    agregar_entrega(
                        tr,
                        d,
                        t_pop,
                        1'b1
                    );

                end

            end

        end


        // --------------------------------------------------------
        // DESTINO VALIDO
        // --------------------------------------------------------

        else if (dst < DRVRS) begin

            agregar_entrega(
                tr,
                dst,
                t_pop,
                1'b0
            );

        end


        // --------------------------------------------------------
        // DESTINO INVALIDO
        // --------------------------------------------------------

        else begin

            n_invalidas++;

        end

    endfunction


    // ============================================================
    // AGREGAR ENTREGA PENDIENTE
    // ============================================================

    function void agregar_entrega(
        bus_txn #(
            PCKG_SZ,
            DRVRS,
            BROADCAST
        ) tr,

        int dst,

        time t_pop,

        bit is_broadcast
    );

        bus_expected_item #(
            PCKG_SZ
        ) item;

        item = new();

        item.txn_id = tr.id;
        item.src = tr.src;
        item.dst = dst;

        item.packet = tr.packet;

        item.t_pop = t_pop;

        item.is_broadcast = is_broadcast;

        entregas_pendientes.push_back(item);

        n_entregas_creadas++;

    endfunction


    // ============================================================
    // BUSCAR ENTREGA ESPERADA
    // ============================================================

    function int buscar_entrega(
        input int dst,
        input bit [PCKG_SZ-1:0] packet
    );

        for (int i = 0; i < entregas_pendientes.size(); i++) begin

            if (
                entregas_pendientes[i].dst == dst &&
                entregas_pendientes[i].packet == packet
            )
                return i;

        end

        return -1;

    endfunction


    // ============================================================
    // VER ENTREGA
    // ============================================================

    function bus_expected_item #(
        PCKG_SZ
    ) ver_entrega(
        input int index
    );

        if (
            index < 0 ||
            index >= entregas_pendientes.size()
        )
            return null;

        return entregas_pendientes[index];

    endfunction


    // ============================================================
    // RETIRAR ENTREGA
    // ============================================================

    function bus_expected_item #(
        PCKG_SZ
    ) retirar_entrega(
        input int index
    );

        bus_expected_item #(
            PCKG_SZ
        ) item;

        if (
            index < 0 ||
            index >= entregas_pendientes.size()
        )
            return null;

        item = entregas_pendientes[index];

        entregas_pendientes.delete(index);

        n_entregas_retiradas++;

        return item;

    endfunction


    // ============================================================
    // LIMPIAR SCOREBOARD
    // ============================================================

    function void limpiar();

        for (int src = 0; src < DRVRS; src++)
            fifo_esperada[src].delete();

        entregas_pendientes.delete();

        t_envio_por_id.delete();

    endfunction


    // ============================================================
    // SCOREBOARD VACIO
    // ============================================================

    function bit vacio();

        for (int src = 0; src < DRVRS; src++) begin

            if (fifo_esperada[src].size() != 0)
                return 1'b0;

        end

        if (entregas_pendientes.size() != 0)
            return 1'b0;

        if (agnt2sb.num() != 0)
            return 1'b0;

        if (drv2sb != null) begin

            if (drv2sb.num() != 0)
                return 1'b0;

        end

        return 1'b1;

    endfunction


    // ============================================================
    // REPORTE
    // ============================================================

    function void reporte();

        $display("");
        $display("======================================");
        $display("          SCOREBOARD REPORT");
        $display("======================================");

        $display(
            "Recibidas del Agent      : %0d",
            n_recibidas
        );

        $display(
            "Tiempos envio registrados: %0d",
            n_envios_registrados
        );

        $display(
            "Consumidas por pop       : %0d",
            n_consumidas
        );

        $display(
            "Entregas creadas         : %0d",
            n_entregas_creadas
        );

        $display(
            "Entregas retiradas       : %0d",
            n_entregas_retiradas
        );

        $display(
            "Broadcast                : %0d",
            n_broadcast
        );

        $display(
            "Destinos invalidos       : %0d",
            n_invalidas
        );

        $display(
            "Src fuera de rango       : %0d",
            n_src_fuera_rango
        );

        $display(
            "Entregas pendientes      : %0d",
            entregas_pendientes.size()
        );


        for (int src = 0; src < DRVRS; src++) begin

            $display(
                "FIFO esperada[%0d]       : %0d",
                src,
                fifo_esperada[src].size()
            );

        end

        $display("");

    endfunction

endclass
