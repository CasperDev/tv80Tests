
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

	localparam string TESTNAME = "-- FD 01 12 34 (ld bc,$3412) (undoc)";

initial begin

	tb.i_reset_btn = 1; #30; tb.i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	$display(TESTNAME);
	// -----------------------------------------------------
	//       - AF    BC   DE   HL   AF'  BC'  DE'  HL'  IX   IY   SP   PC
	tb.SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	tb.mem[0] = 8'hfd;  tb.mem[1] = 8'h01;  tb.mem[2] = 8'h12;  tb.mem[3] = 8'h34;
	#(`CLKPERIOD * 14+`FIN);
	tb.ASSERT(192'h6a00_3412_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0004, 8'h00, 8'h02, 2'b00);
	$finish;
end	
endmodule
