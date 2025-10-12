
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

	localparam string TESTNAME = "-- 01 12 34 (ld bc,$3412)";

initial begin

	tb.i_reset_btn = 1; #30; tb.i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	$display(TESTNAME);
	// -----------------------------------------------------
	//       - AF    BC   DE   HL   AF'  BC'  DE'  HL'  IX   IY   SP   PC
	tb.SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	tb.mem[0] = 8'h01;  tb.mem[1] = 8'h12;  tb.mem[2] = 8'h34;
	#(`CLKPERIOD * 10+`FIN);
	tb.ASSERT(192'h0000_3412_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h01, 2'b00);
	$finish;
end	
endmodule
