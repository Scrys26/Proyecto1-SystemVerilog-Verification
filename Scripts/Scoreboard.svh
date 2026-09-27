class Scoreboard #(                                       
    parameter int PCKG_SZ = 16,                          // Tamaño del paquete
    parameter int DRVRS   = 4,                           // Número de terminales
    parameter bit [7:0] BROADCAST = 8'hFF,               // Dirección de broadcast
    parameter bit BROADCAST_TO_SELF = 1'b0               // Permite broadcast al origen
);

    // Agent -> Scoreboard
    mailbox #(                                            // Mailbox desde el Agente
        bus_txn #(PCKG_SZ, DRVRS, BROADCAST)              // Tipo de transacción
    ) agnt2sb;                                            // Canal Agente-Scoreboard

    bus_txn #(                                            // Transacciones esperadas
        PCKG_SZ,                                          // Tamaño del paquete
        DRVRS,                                            // Número de terminales
        BROADCAST                                         // Dirección de broadcast
    ) fifo_esperada [DRVRS][$];                           // Colas esperadas por origen

    bus_expected_item #(PCKG_SZ) entregas_pendientes[$];  // Entregas aún no observadas

    // Estadisticas del modelo
    int unsigned n_recibidas;                             // Transacciones recibidas
    int unsigned n_consumidas;                            // Transacciones consumidas
    int unsigned n_entregas_creadas;                      // Entregas esperadas creadas
    int unsigned n_entregas_retiradas;                    // Entregas confirmadas
    int unsigned n_broadcast;                             // Broadcast procesados
    int unsigned n_invalidas;                             // Destinos inválidos
    int unsigned n_src_fuera_rango;                       // Orígenes fuera de rango

    function new(                                         // Constructor del Scoreboard
        mailbox #(                                        // Mailbox del Agente
            bus_txn #(PCKG_SZ, DRVRS, BROADCAST)          // Tipo de transacción
        ) agnt2sb                                         // Canal desde Agente
    );
        this.agnt2sb = agnt2sb;                           // Guarda mailbox recibido

        n_recibidas          = 0;                         // Inicializa recibidas
        n_consumidas         = 0;                         // Inicializa consumidas
        n_entregas_creadas   = 0;                         // Inicializa entregas creadas
        n_entregas_retiradas = 0;                         // Inicializa retiradas
        n_broadcast          = 0;                         // Inicializa broadcast
        n_invalidas          = 0;                         // Inicializa inválidas
        n_src_fuera_rango    = 0;                         // Inicializa orígenes inválidos

    endfunction                                           // Fin del constructor

    task run();                                           // Ejecuta recepción continua

        bus_txn #(                                        // Transacción recibida
            PCKG_SZ,                                      // Tamaño del paquete
            DRVRS,                                        // Número de terminales
            BROADCAST                                     // Dirección de broadcast
        ) tr;                                             // Transacción del Agente

        $display(  "[%0t] [SB] iniciado", $time);

        forever begin                                     // Recibe transacciones siempre
            agnt2sb.get(tr);                              // Obtiene transacción del Agente

            if (tr.src >= DRVRS) begin                    // Valida origen

                n_src_fuera_rango++;                      // Cuenta origen inválido

                $display("[%0t] [SB] transaccion ignorada: src=%0d fuera de rango",$time,tr.src); // Reporta origen inválido
            end
            else begin
                fifo_esperada[tr.src].push_back(tr);      // Guarda en cola esperada
                n_recibidas++;                            // Incrementa recibidas
            end
        end
    endtask                                               // Fin de run

    function bus_txn #(                                   // Consulta frente esperado
        PCKG_SZ,                                          // Tamaño del paquete
        DRVRS,                                            // Número de terminales
        BROADCAST                                         // Dirección de broadcast
    ) ver_frente(int unsigned src);                       // Origen a consultar

        if (src >= DRVRS) begin                           // Valida origen
            return null;                                  // Retorna nulo si es inválido
        end
        if (fifo_esperada[src].size() == 0) begin         // Verifica cola vacía
            return null;                                  // Retorna nulo si está vacía
        end
        return fifo_esperada[src][0];                     // Retorna primer elemento

    endfunction                                           // Fin de ver_frente

    function bus_txn #(                                   // Consume frente esperado
        PCKG_SZ,                                          // Tamaño del paquete
        DRVRS,                                            // Número de terminales
        BROADCAST                                         // Dirección de broadcast
    ) consumir_frente(int unsigned src);                  // Origen a consumir

        bus_txn #(                                        // Transacción consumida
            PCKG_SZ,                                      // Tamaño del paquete
            DRVRS,                                        // Número de terminales
            BROADCAST                                     // Dirección de broadcast
        ) tr;                                             // Elemento extraído

        if (src >= DRVRS) begin                           // Valida origen
            return null;                                  // Retorna nulo si es inválido
        end
        if (fifo_esperada[src].size() == 0) begin         // Verifica cola vacía
            return null;                                  // Retorna nulo si no hay datos
        end

        tr = fifo_esperada[src].pop_front();              // Extrae primer elemento
        n_consumidas++;                                   // Incrementa consumidas

        return tr;                                        // Retorna transacción consumida

    endfunction                                           // Fin de consumir_frente

    function void agregar_entrega(                        // Agrega entrega esperada
        bus_txn #(                                        // Transacción original
            PCKG_SZ,                                      // Tamaño del paquete
            DRVRS,                                        // Número de terminales
            BROADCAST                                     // Dirección de broadcast
        ) tr,

        int unsigned dst,                                 // Destino esperado
        time t_pop,                                       // Tiempo del POP
        bit is_broadcast                                  // Indica si es broadcast
    );
        bus_expected_item #(PCKG_SZ) item;                // Entrega esperada

        item = new();                                     // Crea nueva entrega
        item.txn_id       = tr.id;                        // Guarda ID de transacción
        item.src          = tr.src;                       // Guarda origen
        item.dst          = dst;                          // Guarda destino
        item.packet       = tr.packet;                    // Guarda paquete
        item.t_pop        = t_pop;                        // Guarda tiempo de POP
        item.is_broadcast = is_broadcast;                 // Guarda tipo de entrega

        entregas_pendientes.push_back(item);              // Añade entrega pendiente

        n_entregas_creadas++;                             // Incrementa creadas

    endfunction                                           // Fin de agregar_entrega

    function void esperar_entrega(                        // Genera entregas esperadas
        bus_txn #(                                        // Transacción consumida
            PCKG_SZ,                                      // Tamaño del paquete
            DRVRS,                                        // Número de terminales
            BROADCAST                                     // Dirección de broadcast
        ) tr,

        time t_pop                                        // Tiempo del POP
    );

        bit [7:0] dst;                                    // Destino extraído

        if (tr == null) begin                             // Verifica transacción válida
            return;                                       // Sale si es nula
        end
        dst = tr.packet[PCKG_SZ-1 -: 8];                  // Extrae destino del paquete
        // Broadcast
        if (dst == BROADCAST) begin                       // Detecta broadcast
            n_broadcast++;                                // Incrementa broadcast

            for (int d = 0; d < DRVRS; d++) begin        // Recorre destinos

                if (BROADCAST_TO_SELF || (d != tr.src)) begin // Decide envío al origen
                    agregar_entrega(  tr,d, t_pop,1'b1);
                end
            end
        end
        // Transferencia punto a punto valida
        else if (dst < DRVRS) begin                     
            agregar_entrega( tr, dst, t_pop,  1'b0 );
        end
        // Destino invalido: no se espera ningun push
        else begin
            n_invalidas++;                                // Cuenta destino inválido
        end

    endfunction                                           // Fin de esperar_entrega
    function int buscar_entrega(                          // Busca entrega pendiente
        int unsigned dst,                                 // Destino observado
        logic [PCKG_SZ-1:0] packet                        // Paquete observado
    );

        foreach (entregas_pendientes[i]) begin            // Recorre entregas pendientes

            if (entregas_pendientes[i].dst == dst && entregas_pendientes[i].packet === packet) begin // Compara destino y paquete
                return i;                                 // Retorna índice encontrado
            end
        end

        return -1;                                        // Indica que no existe

    endfunction                                           // Fin de buscar_entrega

    function bus_expected_item #(PCKG_SZ) ver_entrega(    // Consulta una entrega
        int index                                         // Índice solicitado
    );
        if (index < 0 ||index >= entregas_pendientes.size())begin // Valida índice
            return null;                                  // Retorna nulo si es inválido
        end
        return entregas_pendientes[index];                // Retorna entrega encontrada

    endfunction                                           // Fin de ver_entrega

    function bus_expected_item #(PCKG_SZ) retirar_entrega( // Retira entrega pendiente
        int index                                         // Índice a retirar
    );
        bus_expected_item #(PCKG_SZ) item;                // Entrega retirada

        if (index < 0 ||index >= entregas_pendientes.size())begin // Valida índice
            return null;                                  // Retorna nulo si es inválido
        end
        item = entregas_pendientes[index];                // Guarda entrega seleccionada
        entregas_pendientes.delete(index);                // Elimina entrega pendiente
        n_entregas_retiradas++;                           // Incrementa retiradas
        return item;                                      // Retorna entrega eliminada

    endfunction                                           // Fin de retirar_entrega

    function void limpiar();                              // Limpia el modelo interno

        foreach (fifo_esperada[i]) begin                  // Recorre colas esperadas
            fifo_esperada[i].delete();                    // Vacía cada cola
        end 
        entregas_pendientes.delete();                     // Vacía entregas pendientes

    endfunction                                           // Fin de limpiar

    function bit vacio();                                 // Verifica estado vacío

        if (agnt2sb.num() != 0)begin                      // Revisa mailbox del Agente
            return 0;                                     // Aún hay transacciones
        end 
        foreach (fifo_esperada[i]) begin                  // Recorre colas esperadas

            if (fifo_esperada[i].size() != 0) begin       // Verifica elementos pendientes
                return 0;                                 // Scoreboard no está vacío
            end
        end
        if (entregas_pendientes.size() != 0) begin        // Revisa entregas pendientes
            return 0;                                     // Aún quedan entregas
        end

        return 1;                                         // Scoreboard está vacío
    endfunction                                        

    function void reporte();                              // Muestra estadísticas finales

        $display("");                                     // Línea en blanco
        $display("======================================"); // Separador
        $display("          SCOREBOARD REPORT");         // Título del reporte
        $display("======================================"); // Separador
        $display("Recibidas del Agent      : %0d", n_recibidas);          
        $display("Consumidas por pop       : %0d", n_consumidas);         
        $display("Entregas creadas         : %0d", n_entregas_creadas);   
        $display("Entregas retiradas       : %0d", n_entregas_retiradas);
        $display("Broadcast                : %0d", n_broadcast);         
        $display("Destinos invalidos       : %0d", n_invalidas);          
        $display("Src fuera de rango       : %0d", n_src_fuera_rango);    

        $display("Entregas pendientes: %0d",entregas_pendientes.size());

        foreach (fifo_esperada[i]) begin                  // Recorre colas esperadas
            $display("FIFO esperada[%0d]: %0d",i,fifo_esperada[i].size());
        end
        $display("");                                    
    endfunction                                         
endclass                                                