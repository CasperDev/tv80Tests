
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

	localparam string TESTNAME = "-- 00 (NOP) INT 2";

initial begin

	tb.i_reset_btn = 1; #30; tb.i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	$display(TESTNAME);
	// -----------------------------------------------------
	//       - AF    BC   DE   HL   AF'  BC'  DE'  HL'  IX   IY   SP   PC
	tb.SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h02, 8'h55, 2'b11);
	tb.mem[0] = 8'h00; tb.mem[1] = 8'h00; tb.mem[2] = 8'h00; 
	tb.mem['h02e7] = 8'h44; tb.mem['h02e8] = 8'h55; // vector from table
	tb.mem['h5544] = 8'h00; // NOP (int routine)
	tb.cpu.core.mcode.IMode = 'b10; // tryb 2
	#(`CLKPERIOD * 3-6);
	// -----------------------------------------------------
	tb.cpu_int_n = 0;
	#6; // full clock alignment
	#(`CLKPERIOD); // align to end of current instruction (NOP)
	#(`CLKPERIOD * 6); // INT ack cycle, read low byte of vector
	#(`CLKPERIOD * 1); // 1 internal cycle
	#(`CLKPERIOD * (4+4)); // push PC on stack (4+4 ???)
	#(`CLKPERIOD * (3+3)); // read target address
	#(`CLKPERIOD * 2); // execute (fetch) final int routine
	tb.ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_fffe_5544, 8'h02, 8'h57, 2'b00);
	$finish;
end	
endmodule
