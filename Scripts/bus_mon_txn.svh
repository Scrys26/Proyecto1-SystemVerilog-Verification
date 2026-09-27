class bus_mon_txn #(                                    // Muestra capturada por el Monitor
    parameter int PCKG_SZ = 16,                         // Tamaño del paquete
    parameter int DRVRS   = 4                           // Número de terminales
);
    time t;                                              // Tiempo de la muestra
    logic reset;                                         // Estado de reset

    logic pndng [DRVRS];                                 // Datos pendientes por terminal
    logic pop   [DRVRS];                                 // Señales POP observadas
    logic push  [DRVRS];                                 // Señales PUSH observadas

    logic [PCKG_SZ-1:0] D_pop  [DRVRS];                  // Datos presentados al DUT
    logic [PCKG_SZ-1:0] D_push [DRVRS];                  // Datos entregados por el DUT

    function new();                                      // Constructor de la muestra
        t = 0;                                           // Inicializa tiempo
        reset = 0;                                       // Inicializa reset

        foreach (pndng[i]) begin                         // Recorre todos los terminales
            pndng[i] = 0;                                // Inicializa pndng
            pop[i] = 0;                                  // Inicializa pop
            push[i] = 0;                                 // Inicializa push
            D_pop[i] = '0;                               // Inicializa D_pop
            D_push[i] = '0;                              // Inicializa D_push
        end
    endfunction                                          // Fin del constructor

    function void print(string tag = "BUS_MON_TXN");     // Muestra la muestra capturada
        $display("[%0t] %s reset=%0b", t, tag, reset);   // Imprime tiempo y reset

        for (int i = 0; i < DRVRS; i++) begin            
            $display(                                   
                "  T%0d: pndng=%0b pop=%0b push=%0b D_pop=0x%0h D_push=0x%0h",
                i,                                      
                pndng[i],                              
                pop[i],                                  
                push[i],                                
                D_pop[i],                                
                D_push[i]                                
            );
        end
    endfunction                                         

endclass                                                