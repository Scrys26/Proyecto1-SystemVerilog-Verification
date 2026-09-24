typedef enum bit [1:0] {
    DST_VALID,
    DST_BROADCAST,
    DST_INVALID
} dst_type_e;

class bus_txn #(
    parameter int PCKG_SZ = 16,
    parameter int DRVRS   = 4,
    parameter bit [7:0] BROADCAST = 8'hFF
);
    // ID únicamente para seguimiento/debug
    static int unsigned created_count;
    int unsigned id;

    // El origen NO se randomiza.
    // Lo define el Agent al que pertenece la transacción.
    int unsigned src;
    // Tipo de destino
    rand dst_type_e dst_type;
    // Dirección real que irá en el paquete
    rand bit [7:0] dst;
    // Payload
    rand bit [PCKG_SZ-9:0] payload;
    // Tiempo antes de presentar la transacción
    rand int unsigned delay;
    // Paquete final
    bit [PCKG_SZ-1:0] packet;
    // Configuración compartida
    bus_config cfg;

    // ---------------------------------------------------------
    // Selección del tipo de destino
    // ---------------------------------------------------------
    constraint c_dst_type {
        dst_type dist {
            DST_VALID     := cfg.wt_valid,
            DST_BROADCAST := cfg.wt_broadcast,
            DST_INVALID   := cfg.wt_invalid
        };
    }
    // Construcción de la dirección
    constraint c_destination {

        if (dst_type == DST_VALID) {
            dst < DRVRS;
            if (!cfg.allow_self_send)
                dst != src;
        }
        if (dst_type == DST_BROADCAST) {
            dst == BROADCAST;
        }
        if (dst_type == DST_INVALID) {
            dst >= DRVRS;
            dst != BROADCAST;
        }
    }
    // Retardo
    constraint c_delay {

        delay inside {
            [cfg.min_delay : cfg.max_delay]
        };
    }
    // Constructor
    function new(int unsigned src_id = 0);
        src = src_id;
        cfg = bus_config::get();
        packet = '0;
    endfunction
    // Despés de randomizar
    function void post_randomize();
        created_count++;
        id = created_count;
        // Los 8 MSB son destino.
        packet = {
            dst,
            payload
        };

    endfunction
    // Copia independiente
    function bus_txn #(PCKG_SZ, DRVRS, BROADCAST) copy();
        bus_txn #(
            PCKG_SZ,
            DRVRS,
            BROADCAST
        ) c;
        c = new(src);
        c.id       = id;
        c.src      = src;
        c.dst      = dst;
        c.dst_type = dst_type;
        c.payload  = payload;
        c.delay    = delay;
        c.packet   = packet;

        return c;
    endfunction
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