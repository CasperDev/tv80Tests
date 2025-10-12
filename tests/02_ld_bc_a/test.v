
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

	localparam string TESTNAME = "-- 02 (ld [bc],a)";

initial begin

	tb.i_reset_btn = 1; #30; tb.i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	$display(TESTNAME);
	// -----------------------------------------------------
	//       - AF    BC   DE   HL   AF'  BC'  DE'  HL'  IX   IY   SP   PC
	tb.SETUP(192'h5600_0001_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	tb.mem[0] = 8'h02;  tb.mem[1] = 8'h00;
	#(`CLKPERIOD * 7);
	tb.ASSERT(192'h5600_0001_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
	if (tb.mem[1] != 8'h56) $display("* FAIL *: [MEMWR] expected=56, actual=%2h",tb.mem[1]);
	$finish;
end	
endmodule
