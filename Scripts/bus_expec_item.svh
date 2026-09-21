class bus_expected_item #(
    parameter int PCKG_SZ = 16
);

    int unsigned src;
    int unsigned dst;

    bit [PCKG_SZ-1:0] packet;

    time t_send;
    time t_pop;
    time t_recv;
    time latency;

    bit is_broadcast;

    function new();
        src = 0;
        dst = 0;
        packet = '0;
        t_send = 0;
        t_pop = 0;
        t_recv = 0;
        latency = 0;
        is_broadcast = 0;
    endfunction

    function void print(string tag = "EXPECTED");
        $display(
            "[%0t] %s src=%0d dst=%0d packet=0x%0h t_send=%0t t_pop=%0t t_recv=%0t latency=%0t broadcast=%0b",
            $time, tag, src, dst, packet, t_send, t_pop, t_recv, latency, is_broadcast
        );
    endfunction

endclass
