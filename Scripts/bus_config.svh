class bus_config;

    static bus_config instance;
    // Cantidd de transacciones generadas por cada terminal
    int unsigned n_txn_per_terminal;
    // Retardo entre transacciones
    int unsigned min_delay;
    int unsigned max_delay;
    // Pesos para seleccionar el tipo de destino
    int unsigned wt_valid;
    int unsigned wt_broadcast;
    int unsigned wt_invalid;
    // Opciones
    bit allow_self_send;
    bit verbose;

    protected function new();
        n_txn_per_terminal = 20;

        min_delay = 0;
        max_delay = 5;

        wt_valid     = 100;
        wt_broadcast = 0;
        wt_invalid   = 0;

        allow_self_send = 0;
        verbose         = 1;

    endfunction

    static function bus_config get();

        if (instance == null) begin
            instance = new();
        end
        return instance;
    endfunction

    function void read_plusargs();
        void'($value$plusargs("n_txn=%d", n_txn_per_terminal ));

        void'($value$plusargs("min_delay=%d",min_delay));

        void'($value$plusargs( "max_delay=%d",max_delay ));

        void'($value$plusargs("wt_valid=%d",wt_valid ));

        void'($value$plusargs("wt_broadcast=%d",wt_broadcast ));

        void'($value$plusargs("wt_invalid=%d",wt_invalid ));

        void'($value$plusargs("allow_self_send=%d",allow_self_send ));

        void'($value$plusargs("verbose=%d",verbose ));
    endfunction

    function void validate();

        if (min_delay > max_delay) begin
            $fatal( 1,"CONFIG ERROR: min_delay (%0d) > max_delay (%0d)", min_delay, max_delay);
        end

        if ((wt_valid + wt_broadcast + wt_invalid) == 0) begin
            $fatal(1, "CONFIG ERROR: todos los pesos de destino son 0");
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