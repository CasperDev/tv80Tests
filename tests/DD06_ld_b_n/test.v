
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

	localparam string TESTNAME = "-- DD 06 CB (ld b,$CB) (undoc)";

initial begin

	tb.i_reset_btn = 1; #30; tb.i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	$display(TESTNAME);
	// -----------------------------------------------------
	//       - AF    BC   DE   HL   AF'  BC'  DE'  HL'  IX   IY   SP   PC
	tb.SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	tb.mem[0] = 8'hdd;  tb.mem[1] = 8'h06;  tb.mem[2] = 8'hCB; tb.mem[3] = 8'h00; // ld b,$BC
	#(`CLKPERIOD * (11+2));
	tb.ASSERT(192'h0000_cb00_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h02, 2'b00);
	$finish;
end	
endmodule
