
module wave_dump;

  string fsdb_name = "Reportes/ondas.fsdb";

  initial begin
    if ($test$plusargs("fsdb")) begin
      void'($value$plusargs("fsdb_file=%s", fsdb_name));
      $fsdbDumpfile(fsdb_name);
      $fsdbDumpvars(0, "+all");
      $display("[WAVE] volcando ondas en %s", fsdb_name);
    end
  end

endmodule
