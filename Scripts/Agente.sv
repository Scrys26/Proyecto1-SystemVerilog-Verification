class Agente #(                                          // Clase generadora de transacciones
    parameter int PCKG_SZ = 16,                         // Tamaño del paquete
    parameter int DRVRS   = 4,                          // Número de terminales
    parameter bit [7:0] BROADCAST = 8'hFF               // Dirección de broadcast
);
    int unsigned terminal_id;                           // ID del terminal origen

    bus_config cfg;                                      // Configuración compartida

    mailbox #(                                           // Mailbox hacia el Driver
        bus_txn #(PCKG_SZ, DRVRS, BROADCAST)             // Tipo de transacción
    ) agnt2drv;                                          // Canal Agente-Driver

    mailbox #(                                           // Mailbox hacia el Scoreboard
        bus_txn #(PCKG_SZ, DRVRS, BROADCAST)             // Tipo de transacción
    ) agnt2sb;                                           // Canal Agente-Scoreboard

    bus_txn #(                                           // Transacción base
        PCKG_SZ,                                         // Tamaño del paquete
        DRVRS,                                           // Número de terminales
        BROADCAST                                        // Dirección de broadcast
    ) blueprint;                                         // Plantilla a randomizar

    int unsigned n_generated;                            // Contador de generadas

    function new(                                        // Constructor del Agente
        int unsigned terminal_id,                        // ID del terminal

        mailbox #(                                       // Mailbox del Driver
            bus_txn #(PCKG_SZ, DRVRS, BROADCAST)         // Tipo de transacción
        ) agnt2drv,                                      // Canal hacia Driver

        mailbox #(                                       // Mailbox del Scoreboard
            bus_txn #(PCKG_SZ, DRVRS, BROADCAST)         // Tipo de transacción
        ) agnt2sb                                        // Canal hacia Scoreboard
    );
        this.terminal_id = terminal_id;                  // Guarda el ID del terminal
        this.agnt2drv    = agnt2drv;                     // Guarda mailbox del Driver
        this.agnt2sb     = agnt2sb;                      // Guarda mailbox del Scoreboard
        
        cfg = bus_config::get();                         // Obtiene configuración global
        blueprint = new(terminal_id);                    // Crea plantilla del terminal
        n_generated = 0;                                 // Inicializa contador
    endfunction                                          // Fin del constructor

    task run();                                          // Ejecuta generación de tráfico

        bus_txn #(                                       // Transacción para Driver
            PCKG_SZ,                                     // Tamaño del paquete
            DRVRS,                                       // Número de terminales
            BROADCAST                                    // Dirección de broadcast
        ) tr_drv;                                        // Copia enviada al Driver

        bus_txn #(                                       // Transacción para Scoreboard
            PCKG_SZ,                                     // Tamaño del paquete
            DRVRS,                                       // Número de terminales
            BROADCAST                                    // Dirección de broadcast
        ) tr_sb;                                         // Copia enviada al Scoreboard
        $display("[%0t] [AGNT%0d] iniciado",$time,terminal_id); // Muestra inicio del Agente
        repeat (cfg.n_txn_per_terminal) begin            // Genera cantidad configurada

            if (!blueprint.randomize()) begin            // Randomiza la plantilla
             $fatal(1,"[%0t] [AGNT%0d] fallo randomize()",$time, terminal_id ); // Detiene si falla
            end                                          // Fin de validación

            tr_drv = blueprint.copy();                   // Copia para el Driver
            tr_sb  = blueprint.copy();                   // Copia para el Scoreboard
            n_generated++;                               // Incrementa contador

            if (cfg.verbose) begin                       // Verifica modo detallado
                tr_drv.print($sformatf("AGNT%0d",terminal_id)); // Imprime transacción
            end                                          // Fin del modo verbose
             agnt2sb.put(tr_sb);                         // Envía esperado al Scoreboard
             agnt2drv.put(tr_drv);                       // Envía estímulo al Driver
        end                                              // Fin de generación
        $display( "[%0t] [AGNT%0d] termino. Generadas=%0d",  $time, terminal_id,n_generated );
    endtask                                          
endclass                                                 