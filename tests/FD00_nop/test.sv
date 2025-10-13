
`include "tb.vh"


module test();

	
	string vcd_path;

	initial begin
		if (!$value$plusargs("vcd=%s", vcd_path))
			vcd_path = "default.vcd"; // domyślna nazwa, gdyby nie podano parametru
		$dumpfile(vcd_path);
		$dumpvars(0,test);
	end

	tb tb ();

	localparam string TESTNAME = "-- FD 00 (NOP undoc)";

initial begin

	tb.i_reset_btn = 1; #30; tb.i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	$display(TESTNAME);
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	tb.SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	tb.mem[0] = 8'hfd;  tb.mem[1] = 8'h00;
	#(`CLKPERIOD * 8+`FIN)
	tb.ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
	$finish;
end	

endmodule
