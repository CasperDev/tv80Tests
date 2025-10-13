
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

	localparam string TESTNAME = "-- 00 (NOP) INT 0";

initial begin

	tb.i_reset_btn = 1; #30; tb.i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	$display(TESTNAME);
	// -----------------------------------------------------
	//       - AF    BC   DE   HL   AF'  BC'  DE'  HL'  IX   IY   SP   PC
	tb.SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h55, 2'b11);
	tb.mem[0] = 8'h00; tb.mem[1] = 8'h00; tb.mem[2] = 8'h00; tb.mem['h20] = 8'hff; // NOP
	tb.cpu.core.mcode.IMode = 'b00; // tryb 0
	#(`CLKPERIOD * 3-6);
	// -----------------------------------------------------
	tb.cpu_int_n = 0;
	#6;
	#(`CLKPERIOD * (6+3+3+4));
	tb.ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_fffe_0020, 8'h00, 8'h57, 2'b00);
	$finish;
end	
endmodule
