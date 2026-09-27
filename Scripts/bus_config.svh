class bus_config;                                         // Configuración global del ambiente

    static bus_config instance;                          // Instancia única de configuración

    // Cantidd de transacciones generadas por cada terminal
    int unsigned n_txn_per_terminal;                     // Número de transacciones por terminal

    // Retardo entre transacciones
    int unsigned min_delay;                              // Retardo mínimo
    int unsigned max_delay;                              // Retardo máximo

    // Pesos para seleccionar el tipo de destino
    int unsigned wt_valid;                               // Peso para destino válido
    int unsigned wt_broadcast;                           // Peso para broadcast
    int unsigned wt_invalid;                             // Peso para destino inválido

    // Opciones
    bit allow_self_send;                                 // Permite enviar al mismo origen
    bit verbose;                                         // Habilita mensajes detallados

    protected function new();                            // Constructor protegido
        n_txn_per_terminal = 20;                         // Define cantidad por defecto

        min_delay = 0;                                   // Define retardo mínimo
        max_delay = 5;                                   // Define retardo máximo

        wt_valid     = 100;                              // Prioriza destinos válidos
        wt_broadcast = 0;                                // Desactiva broadcast por defecto
        wt_invalid   = 0;                                // Desactiva inválidos por defecto

        allow_self_send = 0;                             // Desactiva self-send
        verbose         = 1;                             // Activa mensajes detallados

    endfunction                                          // Fin del constructor

    static function bus_config get();                    // Obtiene instancia única

        if (instance == null) begin                      // Verifica si ya existe
            instance = new();                            // Crea la instancia
        end

        return instance;                                 // Retorna configuración global
    endfunction                                          // Fin de get

    function void read_plusargs();                       // Lee parámetros desde simulación

        void'($value$plusargs("n_txn=%d", n_txn_per_terminal )); // Lee cantidad de transacciones

        void'($value$plusargs("min_delay=%d",min_delay));        // Lee retardo mínimo

        void'($value$plusargs("max_delay=%d",max_delay ));       // Lee retardo máximo

        void'($value$plusargs("wt_valid=%d",wt_valid ));         // Lee peso válido

        void'($value$plusargs("wt_broadcast=%d",wt_broadcast )); // Lee peso broadcast

        void'($value$plusargs("wt_invalid=%d",wt_invalid ));     // Lee peso inválido

        void'($value$plusargs("allow_self_send=%d",allow_self_send )); // Lee opción self-send

        void'($value$plusargs("verbose=%d",verbose ));           // Lee opción verbose
    endfunction                                          // Fin de read_plusargs

    function void validate();                            // Valida la configuración

        if (min_delay > max_delay) begin                 // Verifica rango de retardo
            $fatal( 1,"CONFIG ERROR: min_delay (%0d) > max_delay (%0d)", min_delay, max_delay); // Reporta error
        end

        if ((wt_valid + wt_broadcast + wt_invalid) == 0) begin // Verifica pesos válidos
            $fatal(1, "CONFIG ERROR: todos los pesos de destino son 0"); // Reporta error
        end

    endfunction                                         

    function void print();                               

        $display("");                                   
        $display("          BUS TEST CONFIG");          
        $display("Transacciones/terminal : %0d",n_txn_per_terminal); 
        $display("Delay    : [%0d:%0d]", min_delay, max_delay );     
        $display("Peso destino valido    : %0d", wt_valid);         
        $display("Peso broadcast    : %0d", wt_broadcast);           
        $display("Peso destino invalido  : %0d", wt_invalid);        
        $display("Self-send permitido    : %0d", allow_self_send);   
        $display("Verbose          : %0d", verbose);                 
        $display("");                                    

    endfunction                                          

endclass                                                