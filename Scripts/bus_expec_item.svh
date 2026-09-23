class bus_expected_item #(
    parameter int PCKG_SZ = 16
);

    int unsigned txn_id;
    int unsigned src;
    int unsigned dst;

    bit [PCKG_SZ-1:0] packet;

    time t_pop;

    bit is_broadcast;

    function new();
        txn_id       = 0;
        src          = 0;
        dst          = 0;
        packet       = '0;
        t_pop        = 0;
        is_broadcast = 0;
    endfunction

    function void print(string tag = "EXPECTED");
        $display(
            "[%0t] [%s] id=%0d src=%0d dst=%0d packet=0x%0h t_pop=%0t broadcast=%0b",
            $time,
            tag,
            txn_id,
            src,
            dst,
            packet,
            t_pop,
            is_broadcast
        );
    endfunction

endclass
