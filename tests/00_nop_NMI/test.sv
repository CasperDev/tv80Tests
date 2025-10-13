
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

	localparam string TESTNAME = "-- 00 (NOP) NMI";

initial begin

	tb.i_reset_btn = 1; #30; tb.i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	$display(TESTNAME);
	// -----------------------------------------------------
	//       - AF    BC   DE   HL   AF'  BC'  DE'  HL'  IX   IY   SP   PC
	tb.SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h55, 2'b11);
	tb.mem[0] = 8'h00; tb.mem[1] = 8'h00; tb.mem[2] = 8'h00; tb.mem['h38] = 8'hff; // NOP
	tb.cpu.core.mcode.IMode = 'b01; // tryb 1
	#(`CLKPERIOD * 3-6);
	// -----------------------------------------------------
	tb.cpu_nmi_n = 0;
	#6; // full clock alignment
	#(`CLKPERIOD * 6); // NMI ack cycle (fake fetch) -> RST 0x66
	#(`CLKPERIOD * (4+4)); // push PC on stack
	#(`CLKPERIOD * (4)); // fetch - execute from 0x66
	tb.ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_fffe_0066, 8'h00, 8'h57, 2'b10);
	$finish;
end	
endmodule
