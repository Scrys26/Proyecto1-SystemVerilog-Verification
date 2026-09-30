class Checker #(
    parameter int PCKG_SZ = 16,
    parameter int DRVRS = 4,
    parameter bit [7:0] BROADCAST = 8'hFF,
    parameter bit BROADCAST_TO_SELF = 1'b0
);
    mailbox #(bus_mon_txn #(PCKG_SZ,DRVRS)) mon2chk;

    Scoreboard #(
        PCKG_SZ,
        DRVRS,
        BROADCAST,
        BROADCAST_TO_SELF
    ) sb;

    int unsigned n_samples = 0;
    int unsigned n_pops = 0;
    int unsigned n_pushes = 0;
    int unsigned n_completed = 0;
    int unsigned n_errors = 0;
    int unsigned n_pop_empty = 0;
    int unsigned n_pop_mismatch = 0;
    int unsigned n_push_unexp = 0;

    integer csv_fd;
    string csv_nombre;
    bit csv_habilitado = 0;

    localparam time CLK_PERIOD = 10ns;


    function new(
        mailbox #(bus_mon_txn #(PCKG_SZ,DRVRS)) mon2chk,
        Scoreboard #(PCKG_SZ,DRVRS,BROADCAST,BROADCAST_TO_SELF) sb
    );

        this.mon2chk = mon2chk;
        this.sb = sb;

    endfunction


    task run();

        bus_mon_txn #(PCKG_SZ,DRVRS) m;

        $display("[%0t] [CHK] iniciado",$time);

        forever begin

            mon2chk.get(m);
            n_samples++;

            if (m.reset)
                continue;

            check_pushes(m);
            check_pops(m);

        end

    endtask

    task automatic check_pushes(
        bus_mon_txn #(PCKG_SZ,DRVRS) m
    );

        int idx;
        bus_expected_item #(PCKG_SZ) item;
        time latencia;
        int unsigned latencia_ciclos;

        for (int dst = 0; dst < DRVRS; dst++) begin

            if (m.push[dst]) begin

                n_pushes++;

                idx = sb.buscar_entrega(dst,m.D_push[dst]);

                if (idx < 0) begin

                    n_push_unexp++;
                    n_errors++;

                    $display("[%0t] [CHK][ERROR] PUSH inesperado: dst=%0d packet=0x%0h",m.t,dst,m.D_push[dst]);

                end
                else begin

                    item = sb.ver_entrega(idx);

                    latencia = m.t - item.t_pop;
                    latencia_ciclos = latencia / CLK_PERIOD;

                    if (csv_habilitado) begin
                        $fdisplay(csv_fd,"%0d,%0d,%0d,0x%0h,%0t,%0t,%0t,%0d,%0b",item.txn_id,item.src,item.dst,item.packet,item.t_pop,m.t,latencia,latencia_ciclos,item.is_broadcast);
                    end

                    void'(sb.retirar_entrega(idx));
                    n_completed++;

                    $display("[%0t] [CHK] OK push: src=%0d dst=%0d packet=0x%0h latency_desde_pop=%0t ciclos=%0d",m.t,item.src,item.dst,item.packet,latencia,latencia_ciclos);

                end

            end

        end

    endtask
    task automatic check_pops(
        bus_mon_txn #(PCKG_SZ,DRVRS) m
    );

        bus_txn #(PCKG_SZ,DRVRS,BROADCAST) tr;

        for (int src = 0; src < DRVRS; src++) begin

            if (m.pop[src]) begin

                n_pops++;

                if (!m.pndng[src]) begin
                    n_pop_empty++;
                    n_errors++;
                    $display("[%0t] [CHK][ERROR] POP sin PNDNG: src=%0d",$time,src);
                end

                tr = sb.ver_frente(src);

                if (tr == null) begin

                    n_pop_empty++;
                    n_errors++;

                    $display("[%0t] [CHK][ERROR] POP sin dato esperado: src=%0d",$time,src);

                end
                else begin

                    if (m.D_pop[src] !== tr.packet) begin

                        n_pop_mismatch++;
                        n_errors++;

                        $display("[%0t] [CHK][ERROR] D_pop incorrecto: src=%0d esperado=0x%0h recibido=0x%0h",$time,src,tr.packet,m.D_pop[src]);

                    end

                    tr = sb.consumir_frente(src);

                    if (tr != null)
                        sb.esperar_entrega(tr,m.t);

                end

            end

        end

    endtask

    function void abrir_csv(string nombre = "latencias.csv");

        if (csv_habilitado)
            cerrar_csv();

        csv_nombre = nombre;
        csv_fd = $fopen(csv_nombre,"w");

        if (csv_fd == 0) begin
            $error("[CHK] No se pudo crear el archivo CSV: %s",csv_nombre);
            csv_habilitado = 0;
            return;
        end

        csv_habilitado = 1;

        $fdisplay(csv_fd,"txn_id,src,dst,packet,tiempo_envio,tiempo_recibido,retraso,retraso_ciclos,is_broadcast");

        $display("[%0t] [CHK] CSV abierto: %s",$time,csv_nombre);

    endfunction

    function void cerrar_csv();

        if (csv_habilitado) begin

            $fclose(csv_fd);
            csv_habilitado = 0;

            $display("[%0t] [CHK] CSV cerrado: %s",$time,csv_nombre);

        end

    endfunction
    function void final_check();

        int unsigned restantes = 0;

        for (int src = 0; src < DRVRS; src++)
            restantes += sb.fifo_esperada[src].size();

        restantes += sb.entregas_pendientes.size();

        if (restantes != 0) begin
            n_errors += restantes;
            $display("[CHK][ERROR] Quedaron %0d elementos pendientes al finalizar",restantes);
        end

    endfunction
    function void reporte();

        $display("");
        $display("======================================");
        $display("            CHECKER REPORT");
        $display("======================================");
        $display("Muestras recibidas       : %0d",n_samples);
        $display("POP observados           : %0d",n_pops);
        $display("PUSH observados          : %0d",n_pushes);
        $display("Entregas correctas       : %0d",n_completed);
        $display("POP sin dato esperado    : %0d",n_pop_empty);
        $display("D_pop incorrectos        : %0d",n_pop_mismatch);
        $display("PUSH inesperados         : %0d",n_push_unexp);
        $display("ERRORES                  : %0d",n_errors);

        if (csv_habilitado)
            $display("CSV                       : %s",csv_nombre);

        $display("");

    endfunction

endclass