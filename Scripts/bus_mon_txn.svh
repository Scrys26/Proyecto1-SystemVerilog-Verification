class bus_mon_txn #(
    parameter int PCKG_SZ = 16,
    parameter int DRVRS   = 4
);

    time t;
    logic reset;

    logic pndng [DRVRS];
    logic pop   [DRVRS];
    logic push  [DRVRS];

    logic [PCKG_SZ-1:0] D_pop  [DRVRS];
    logic [PCKG_SZ-1:0] D_push [DRVRS];

    function new();
        t = 0;
        reset = 0;

        foreach (pndng[i]) begin
            pndng[i] = 0;
            pop[i] = 0;
            push[i] = 0;
            D_pop[i] = '0;
            D_push[i] = '0;
        end
    endfunction

    function void print(string tag = "BUS_MON_TXN");
        $display("[%0t] %s reset=%0b", t, tag, reset);

        for (int i = 0; i < DRVRS; i++) begin
            $display(
                "  T%0d: pndng=%0b pop=%0b push=%0b D_pop=0x%0h D_push=0x%0h",
                i, pndng[i], pop[i], push[i], D_pop[i], D_push[i]
            );
        end
    endfunction

endclass
