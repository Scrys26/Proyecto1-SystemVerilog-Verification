class bus_expected_item #(                               // Entrega esperada por el Scoreboard
    parameter int PCKG_SZ = 16                          // Tamaño del paquete
);

    int unsigned txn_id;                                 // ID de la transacción
    int unsigned src;                                    // Terminal origen
    int unsigned dst;                                    // Terminal destino

    bit [PCKG_SZ-1:0] packet;                            // Paquete esperado

    time t_pop;                                          // Tiempo en que ocurrió el POP

    bit is_broadcast;                                    // Indica si es broadcast

    function new();                                      // Constructor del objeto
        txn_id       = 0;                                // Inicializa ID
        src          = 0;                                // Inicializa origen
        dst          = 0;                                // Inicializa destino
        packet       = '0;                               // Inicializa paquete
        t_pop        = 0;                                // Inicializa tiempo de POP
        is_broadcast = 0;                                // Inicializa tipo de entrega
    endfunction                                          // Fin del constructor

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