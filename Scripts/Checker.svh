class Checker #(                                         // Clase que valida el comportamiento
    parameter int PCKG_SZ = 16,                         // Tamaño del paquete
    parameter int DRVRS   = 4,                          // Número de terminales
    parameter bit [7:0] BROADCAST = 8'hFF,              // Dirección de broadcast
    parameter bit BROADCAST_TO_SELF = 1'b0              // Permite broadcast al origen
);
    // Monitor -> Checker
    mailbox #(                                           // Mailbox desde el Monitor
        bus_mon_txn #(PCKG_SZ, DRVRS)                    // Tipo de muestra observada
    ) mon2chk;                                           // Canal Monitor-Checker

    Scoreboard #(                                        // Modelo de referencia
        PCKG_SZ,                                         // Tamaño del paquete
        DRVRS,                                           // Número de terminales
        BROADCAST,                                       // Dirección de broadcast
        BROADCAST_TO_SELF                                // Política de broadcast
    ) sb;                                                // Referencia al Scoreboard

    // Estadisticas
    int unsigned n_samples       = 0;                    // Muestras recibidas
    int unsigned n_pops          = 0;                    // POP observados
    int unsigned n_pushes        = 0;                    // PUSH observados
    int unsigned n_completed     = 0;                    // Entregas correctas
    int unsigned n_errors        = 0;                    // Errores detectados

    int unsigned n_pop_empty     = 0;                    // POP sin dato esperado
    int unsigned n_pop_mismatch  = 0;                    // Errores en D_pop
    int unsigned n_push_unexp    = 0;                    // PUSH inesperados

    function new(                                        // Constructor del Checker
        mailbox #(                                       // Mailbox del Monitor
            bus_mon_txn #(PCKG_SZ, DRVRS)                // Tipo de muestra
        ) mon2chk,                                       // Canal desde Monitor

        Scoreboard #(                                    // Scoreboard asociado
            PCKG_SZ,                                     // Tamaño del paquete
            DRVRS,                                       // Número de terminales
            BROADCAST,                                   // Dirección de broadcast
            BROADCAST_TO_SELF                            // Política de broadcast
        ) sb                                             // Referencia al Scoreboard
    );

        this.mon2chk = mon2chk;                          // Guarda mailbox del Monitor
        this.sb      = sb;                               // Guarda referencia al Scoreboard

    endfunction                                          // Fin del constructor
    task run();                                          // Ejecuta revisión continua
        bus_mon_txn #(                                   // Muestra del Monitor
            PCKG_SZ,                                     // Tamaño del paquete
            DRVRS                                        // Número de terminales
        ) m;                                             // Transacción observada

        $display( "[%0t] [CHK] iniciado", $time );

        forever begin                                    // Revisa muestras continuamente
            mon2chk.get(m);                              // Recibe muestra del Monitor
            n_samples++;                                 // Incrementa muestras recibidas

            if (m.reset) begin                           // Ignora muestras durante reset
                continue;                                // Pasa a la siguiente muestra
            end
            check_pushes(m);                             // Revisa entregas del DUT
            check_pops(m);                               // Revisa consumos del DUT

        end
    endtask                                              // Fin de run
    function void check_pushes(                          // Verifica señales PUSH
        bus_mon_txn #(PCKG_SZ, DRVRS) m                  // Muestra observada
    );
        int idx;                                         // Índice de entrega esperada
        bus_expected_item #(                             // Entrega esperada
            PCKG_SZ                                      // Tamaño del paquete
        ) item;                                          // Elemento esperado
        for (int dst = 0; dst < DRVRS; dst++) begin      // Recorre destinos
            if (!m.push[dst]) begin                      // Verifica si hubo PUSH
                continue;                                // Ignora destino sin PUSH
            end
            n_pushes++;                                  // Incrementa PUSH observados
            idx = sb.buscar_entrega(                     // Busca entrega esperada
                dst,                                     // Destino observado
                m.D_push[dst]                            // Paquete observado
            );
            if (idx < 0) begin                           // No existe entrega esperada
                n_errors++;                              // Incrementa errores
                n_push_unexp++;                          // Incrementa PUSH inesperados

                $error(                                  // Reporta PUSH inesperado
                    "[%0t] [CHK] PUSH inesperado: dst=%0d packet=0x%0h",
                    m.t,                                 // Tiempo de la muestra
                    dst,                                 // Destino observado
                    m.D_push[dst]                        // Paquete recibido
                );
                continue;                                // Continúa con otro destino

            end
            item = sb.ver_entrega(idx);                  // Obtiene entrega encontrada

            if (item == null) begin                      // Verifica entrega válida
                n_errors++;                              // Incrementa errores
                $error("[%0t] [CHK] error interno: entrega encontrada pero no disponible",m.t); // Reporta error
                continue;                                // Continúa con otro destino
            end
            // La busqueda ya comprobo destino + paquete.
            // Se retira solamente despues de confirmar la salida.
            void'(sb.retirar_entrega(idx));              // Elimina entrega confirmada
            n_completed++;                               // Incrementa entregas correctas
            $display(                                    // Muestra entrega correcta
                "[%0t] [CHK] OK push: src=%0d dst=%0d packet=0x%0h latency_desde_pop=%0t",
                m.t,                                     // Tiempo de recepción
                item.src,                                // Terminal origen
                item.dst,                                // Terminal destino
                item.packet,                             // Paquete entregado
                m.t - item.t_pop                         // Latencia desde POP
            );

        end
    endfunction                                          // Fin de check_pushes

    function void check_pops(                            // Verifica señales POP
        bus_mon_txn #(PCKG_SZ, DRVRS) m                  // Muestra observada
    );

        bus_txn #(                                       // Transacción esperada
            PCKG_SZ,                                     // Tamaño del paquete
            DRVRS,                                       // Número de terminales
            BROADCAST                                    // Dirección de broadcast
        ) exp;                                           // Paquete esperado

        for (int src = 0; src < DRVRS; src++) begin      // Recorre terminales origen
            if (!m.pop[src]) begin                       // Verifica si hubo POP
                continue;                                // Ignora terminal sin POP
            end
            n_pops++;                                    // Incrementa POP observados

            if (!m.pndng[src]) begin                     // POP sin dato disponible
                n_errors++;                              // Incrementa errores
                n_pop_empty++;                           // Incrementa POP vacíos
                $error("[%0t] [CHK] POP sin PNDNG: src=%0d",m.t,src); // Reporta error
                continue;                                // Continúa con otro origen
            end
            exp = sb.ver_frente(src);                    // Consulta paquete esperado
            // El Agent/Scoreboard no esperaba ningun paquete
            // para esta terminal.
            if (exp == null) begin                       // No existe paquete esperado
                n_errors++;                              // Incrementa errores
                n_pop_empty++;                           // Incrementa POP inesperados

                $error(                                  // Reporta FIFO esperada vacía
                    "[%0t] [CHK] POP inesperado: FIFO esperada[%0d] vacia, D_pop=0x%0h",
                    m.t,                                 // Tiempo de la muestra
                    src,                                 // Terminal origen
                    m.D_pop[src]                         // Paquete observado
                );
                continue;                                // Continúa con otro origen
            end

            // Se usa !== para que
            // X/Z tambien sean considerados como un mismatch.
            if (m.D_pop[src] !== exp.packet) begin       // Compara paquete observado
                n_errors++;                              // Incrementa errores
                n_pop_mismatch++;                        // Incrementa mismatches
                $error("[%0t] [CHK] D_pop mismatch: src=%0d exp=0x%0h got=0x%0h",m.t,src,exp.packet,m.D_pop[src]);
            end

            exp = sb.consumir_frente(src);               // Consume paquete esperado
            sb.esperar_entrega(exp,m.t);                 // Registra entrega futura
        end
    endfunction                                          // Fin de check_pops

    // Comprobacion al final de la prueba

    function void final_check();                         // Verifica elementos pendientes
        int unsigned restantes = 0;                      // Contador de pendientes

        foreach (sb.fifo_esperada[i]) begin              // Recorre FIFOs esperadas
            restantes += sb.fifo_esperada[i].size();     // Suma paquetes pendientes
        end

        restantes += sb.entregas_pendientes.size();      // Suma entregas pendientes
        
        if (restantes != 0) begin                        // Verifica si quedaron elementos
            n_errors++;                                  // Incrementa errores
            $error("[CHK] La simulacion termino con %0d elementos esperados pendientes", restantes); // Reporta pendientes
        end
    endfunction                                          // Fin de final_check

    // Reporte final
    function void reporte();                             // Muestra estadísticas finales

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

        $display("");                              

    endfunction                                        

endclass                                                