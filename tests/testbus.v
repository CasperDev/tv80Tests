`timescale 1ns/1ns

module tb_bus;


  // Signals
  reg clk = 0;
  reg reset = 1;

  // Instantiate

  topz80 dut (
	.clk(clk),
	.reset(reset),
	.di(8'h00),
	.wait_n(1'b1),
	.int_n(1'b1),
	.nmi_n(1'b1),
	.busrq_n(1'b1)
  );

  always #5 clk = ~clk;

  initial begin
	$dumpfile("tb_bus.vcd");
	$dumpvars(0, tb_bus);

	// Reset
	#20;
	reset = 0;
	dut.tv80s.i_tv80_core.R = 8'hFF;  // Set R to a known value
	// Run for a while
	#1000;

	$finish;
  end

endmodule
