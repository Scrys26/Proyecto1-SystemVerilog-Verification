typedef enum bit [1:0] {                                 // Tipos posibles de destino
    DST_VALID,                                           // Destino válido
    DST_BROADCAST,                                       // Destino broadcast
    DST_INVALID                                          // Destino inválido
} dst_type_e;                                            // Tipo enumerado de destino

class bus_txn #(                                         // Clase de transacción del bus
    parameter int PCKG_SZ = 16,                          // Tamaño del paquete
    parameter int DRVRS   = 4,                           // Número de terminales
    parameter bit [7:0] BROADCAST = 8'hFF                // Dirección de broadcast
);

    // ID únicamente para seguimiento/debug
    static int unsigned created_count;                   // Cuenta transacciones creadas
    int unsigned id;                                     // ID de la transacción

    // Lo define el Agent al que pertenece la transacción.
    int unsigned src;                                    // Terminal origen

    // Tipo de destino
    rand dst_type_e dst_type;                            // Tipo de destino aleatorio

    // Dirección real que irá en el paquete
    rand bit [7:0] dst;                                  // Dirección destino aleatoria

    // Payload
    rand bit [PCKG_SZ-9:0] payload;                      // Datos útiles del paquete

    // Tiempo antes de presentar la transacción
    rand int unsigned delay;                             // Retardo aleatorio

    // Paquete final
    bit [PCKG_SZ-1:0] packet;                            // Paquete completo

    // Configuración compartida
    bus_config cfg;                                      // Configuración global

    // ---------------------------------------------------------
    // Selección del tipo de destino
    // ---------------------------------------------------------
    constraint c_dst_type {                              // Restringe tipo de destino
        dst_type dist {                                  // Distribuye según pesos
            DST_VALID     := cfg.wt_valid,                // Peso de destino válido
            DST_BROADCAST := cfg.wt_broadcast,            // Peso de broadcast
            DST_INVALID   := cfg.wt_invalid               // Peso de destino inválido
        };
    }

    // Construcción de la dirección
    constraint c_destination {                           // Restringe dirección destino

        if (dst_type == DST_VALID) {                     // Caso destino válido
            dst < DRVRS;                                 // Limita al rango de terminales

            if (!cfg.allow_self_send)                    // Verifica self-send
                dst != src;                              // Evita enviarse a sí mismo
        }
        if (dst_type == DST_BROADCAST) {                 // Caso broadcast
            dst == BROADCAST;                            // Fuerza dirección broadcast
        }

        if (dst_type == DST_INVALID) {                   // Caso destino inválido
            dst >= DRVRS;                                // Lo deja fuera del rango válido
            dst != BROADCAST;                            // Evita confundir con broadcast
        }
    }
    // Retardo
    constraint c_delay {                                 // Restringe el retardo

        delay inside {                                   // Limita rango permitido
            [cfg.min_delay : cfg.max_delay]              // Usa límites configurados
        };
    }
    // Constructor
    function new(int unsigned src_id = 0);               // Constructor de la transacción
        src = src_id;                                    // Asigna terminal origen
        cfg = bus_config::get();                         // Obtiene configuración global
        packet = '0;                                     // Inicializa paquete
    endfunction                                          // Fin del constructor

    // Despés de randomizar
    function void post_randomize();                      // Se ejecuta tras randomize
        created_count++;                                 // Incrementa contador global
        id = created_count;                              // Asigna ID único

        // Los 8 MSB son destino.
        packet = {                                       // Construye paquete completo
            dst,                                         // Coloca destino en MSB
            payload                                      // Coloca payload en LSB
        };

    endfunction                                          // Fin de post_randomize
    // Copia independiente
    function bus_txn #(PCKG_SZ, DRVRS, BROADCAST) copy();// Crea copia independiente

        bus_txn #(                                       // Objeto de copia
            PCKG_SZ,                                     // Tamaño del paquete
            DRVRS,                                       // Número de terminales
            BROADCAST                                    // Dirección de broadcast
        ) c;                                             // Nueva transacción
        c = new(src);                                    // Crea objeto con mismo origen
        c.id       = id;                                 // Copia ID
        c.src      = src;                                // Copia origen
        c.dst      = dst;                                // Copia destino
        c.dst_type = dst_type;                           // Copia tipo de destino
        c.payload  = payload;                            // Copia payload
        c.delay    = delay;                              // Copia retardo
        c.packet   = packet;                             // Copia paquete
        return c;                                        // Retorna la copia
    endfunction                                          // Fin de copy

    // Print
    function void print(string tag = "BUS_TXN");         
        $display(                                        
            "[%0t] %s id=%0d src=%0d dst=%0h type=%s payload=0x%0h packet=0x%0h delay=%0d",
            $time,                                       
            tag,                                        
            id,                                        
            src,                                        
            dst,                                        
            dst_type.name(),                             
            payload,                                    
            packet,                                      
            delay                                        
        );

    endfunction                                         

endclass                                                 