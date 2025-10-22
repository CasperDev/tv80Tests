
`timescale 1ns/1ns
`default_nettype none
`define CLKPERIOD 5

module tb();

    reg i_clk = 0;          // Signals driven from within a process (an initial or always block) must be type reg
    reg i_reset_btn =1;

    initial begin
        $dumpfile("fuse_tb.vcd");    // where to write the dump
        $dumpvars(0,tb);                  // dump EVERYTHING
		//$monitor("%5t: clk=%b, MREQ=%b, RD=%b, M1=%b", $time, i_clk, cpu_mreq_n, cpu_rd_n, cpu_m1_n);
    end
	

// reset debounce
wire cpu_reset = i_reset_btn;

// Bus Req test - 300 clocks after reset for 100 cycles
wire cpu_busak_n;
 
//------------- CPU ----------------------
wire [7:0] cpu_di;
wire [7:0] cpu_do;
wire [15:0] cpu_a;

wire cpu_clk = i_clk;
wire cpu_m1_n, cpu_rfsh_n,cpu_mreq_n,cpu_iorq_n,cpu_rd_n, cpu_wr_n, cpu_halt_n;

tv80s cpu (
    .reset(cpu_reset), .clk(cpu_clk), .cen(1'b1),
    .m1_n(cpu_m1_n), .mreq_n(cpu_mreq_n), .iorq_n(cpu_iorq_n), .rd_n(cpu_rd_n), .wr_n(cpu_wr_n), 
    .rfsh_n(cpu_rfsh_n), .halt_n(cpu_halt_n), .busak_n(cpu_busak_n), 
    .A(cpu_a), .di(cpu_di), .dout(cpu_do),
    .wait_n(1'b1), .int_n(1'b1), .nmi_n(1'b1), .busrq_n(1'b1)    // all inactive for now
);

//------------- MEMORY ----------------------
 
reg [7:0] mem[0:65535];
reg [7:0] mem_o;
always@(negedge cpu_clk) begin
	mem_o <= mem[cpu_a];
	if (cpu_wr_n == 1'b0 && cpu_mreq_n == 1'b0) 
		mem[cpu_a] = cpu_do;
end
reg [7:0] io[0:255];
reg [7:0] io_o;
always@(negedge cpu_clk) begin
	io_o <= io[cpu_a[7:0]];
	if (cpu_wr_n == 1'b0 && cpu_iorq_n == 1'b0) 
		io[cpu_a[7:0]] = cpu_do;
end
assign cpu_di = cpu_iorq_n == 1'b0 ? io_o : mem_o;

reg FAIL = 1'b0;

task TESTCASE(input string testcase);
	$write("Test %s ... ", testcase);
	FAIL = 1'b0;
endtask

task RESULT();
	if (!FAIL) $display("PASS"); 
endtask

task SETFAIL();
	if (!FAIL) $display("FAIL");
	FAIL = 1'b1;
endtask

task ASSERTMEM(input [15:0] addr, input [7:0] expected);
	if (mem[addr] != expected) begin 
		SETFAIL(); 
		$display("- FAIL: [MEMWR] expected=%2h, actual=%2h",expected, mem[addr]); 
	end
endtask

task ASSERT;
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	input [191:0] REGS;
	input [7:0] I;
	input [7:0] R;
	input [1:0] IFF;
	reg alt;
	begin
		
	alt = cpu.core.Alternate;
	//if (cpu.state != cpu.ST_FETCH_M1_T1) $display("* FAIL *: [CPU state] other than ST_FETCH_M1_T1, %b", cpu.state);
	if (cpu.core.PC != REGS[15:0]) begin SETFAIL(); $display("- FAIL: [PC] expected=%4h, actual=%4h",REGS[15:0],cpu.core.PC); end;
	if (cpu.core.SP != REGS[31:16]) begin SETFAIL(); $display("- FAIL: [SP] expected=%4h, actual=%4h",REGS[31:16],cpu.core.SP); end;
	if (cpu.core.ACC != REGS[191:184]) begin SETFAIL(); $display("- FAIL: [A] expected=%2h, actual=%2h",REGS[191:184],cpu.core.ACC); end;
	if (cpu.core.F != REGS[183:176]) begin SETFAIL(); $display("- FAIL: [F] expected=%2h, actual=%2h",REGS[183:176],cpu.core.F); end;
	if (cpu.core.Ap != REGS[127:120]) begin SETFAIL(); $display("- FAIL: [A'] expected=%2h, actual=%2h",REGS[127:120],cpu.core.Ap); end;
	if (cpu.core.Fp != REGS[119:112]) begin SETFAIL(); $display("- FAIL: [F'] expected=%2h, actual=%2h",REGS[119:112],cpu.core.Fp); end;
	if (cpu.core.regs.RegsH[{alt,2'b00}] != REGS[175:168]) begin SETFAIL(); $display("- FAIL: [B] expected=%2h, actual=%2h",REGS[175:168],cpu.core.regs.RegsH[{alt,2'b00}]); end;
	if (cpu.core.regs.RegsL[{alt,2'b00}] != REGS[167:160]) begin SETFAIL(); $display("- FAIL: [C] expected=%2h, actual=%2h",REGS[167:160],cpu.core.regs.RegsL[{alt,2'b00}]); end;
	if (cpu.core.regs.RegsH[{alt,2'b01}] != REGS[159:152]) begin SETFAIL(); $display("- FAIL: [D] expected=%2h, actual=%2h",REGS[159:152],cpu.core.regs.RegsH[{alt,2'b01}]); end;
	if (cpu.core.regs.RegsL[{alt,2'b01}] != REGS[151:144]) begin SETFAIL(); $display("- FAIL: [E] expected=%2h, actual=%2h",REGS[151:144],cpu.core.regs.RegsL[{alt,2'b01}]); end;
	if (cpu.core.regs.RegsH[{alt,2'b10}] != REGS[143:136]) begin SETFAIL(); $display("- FAIL: [H] expected=%2h, actual=%2h",REGS[143:136],cpu.core.regs.RegsH[{alt,2'b10}]); end;
	if (cpu.core.regs.RegsL[{alt,2'b10}] != REGS[135:128]) begin SETFAIL(); $display("- FAIL: [L] expected=%2h, actual=%2h",REGS[135:128],cpu.core.regs.RegsL[{alt,2'b10}]); end;
	if (cpu.core.regs.RegsH[{!alt,2'b00}] != REGS[111:104]) begin SETFAIL(); $display("- FAIL: [B'] expected=%2h, actual=%2h",REGS[111:104],cpu.core.regs.RegsH[{!alt,2'b00}]); end;
	if (cpu.core.regs.RegsL[{!alt,2'b00}] != REGS[103:96]) begin SETFAIL(); $display("- FAIL: [C'] expected=%2h, actual=%2h",REGS[103:96],cpu.core.regs.RegsL[{!alt,2'b00}]); end;
	if (cpu.core.regs.RegsH[{!alt,2'b01}] != REGS[95:88]) begin SETFAIL(); $display("- FAIL: [D'] expected=%2h, actual=%2h",REGS[95:88],cpu.core.regs.RegsH[{!alt,2'b01}]); end;
	if (cpu.core.regs.RegsL[{!alt,2'b01}] != REGS[87:80]) begin SETFAIL(); $display("- FAIL: [E'] expected=%2h, actual=%2h",REGS[87:80],cpu.core.regs.RegsL[{!alt,2'b01}]); end;
	if (cpu.core.regs.RegsH[{!alt,2'b10}] != REGS[79:72]) begin SETFAIL(); $display("- FAIL: [H'] expected=%2h, actual=%2h",REGS[79:72],cpu.core.regs.RegsH[{!alt,2'b10}]); end;
	if (cpu.core.regs.RegsL[{!alt,2'b10}] != REGS[71:64]) begin SETFAIL(); $display("- FAIL: [L'] expected=%2h, actual=%2h",REGS[71:64],cpu.core.regs.RegsL[{!alt,2'b10}]); end;
	if (cpu.core.regs.RegsH[3] != REGS[63:56]) begin SETFAIL(); $display("- FAIL: [IXH] expected=%2h, actual=%2h",REGS[63:56],cpu.core.regs.RegsH[3]); end;
	if (cpu.core.regs.RegsL[3] != REGS[55:48]) begin SETFAIL(); $display("- FAIL: [IXL] expected=%2h, actual=%2h",REGS[55:48],cpu.core.regs.RegsL[3]); end;
	if (cpu.core.regs.RegsH[7] != REGS[47:40]) begin SETFAIL(); $display("- FAIL: [IYH] expected=%2h, actual=%2h",REGS[47:40],cpu.core.regs.RegsH[7]); end;
	if (cpu.core.regs.RegsL[7] != REGS[39:32]) begin SETFAIL(); $display("- FAIL: [IYL] expected=%2h, actual=%2h",REGS[39:32],cpu.core.regs.RegsL[7]); end;
	if (cpu.core.I != I) begin SETFAIL(); $display("- FAIL: [I] expected=%2h, actual=%2h",I,cpu.core.I); end;
	if (cpu.core.R != R) begin SETFAIL(); $display("- FAIL: [R] expected=%2h, actual=%2h",R,cpu.core.R); end;
	if (cpu.core.IntE_FF1 != IFF[0]) begin SETFAIL(); $display("- FAIL: [IFF1] expected=1'b1 actual=%1b",cpu.core.IntE_FF1); end;
	if (cpu.core.IntE_FF2 != IFF[1]) begin SETFAIL(); $display("- FAIL: [IFF2] expected=1'b1, actual=%1b",cpu.core.IntE_FF2); end;
	RESULT();
	end
endtask

task SETMEM(input [15:0] addr, input [7:0] value);
	mem[addr] = value;
endtask

task SETUP;
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	input [191:0] REGS;
	input [7:0] I;
	input [7:0] R;
	input [1:0] IFF;
	reg alt;
	begin
		alt = cpu.core.Alternate;
		cpu.core.ACC = REGS[191:184];
		cpu.core.F = REGS[183:176];
		cpu.core.Ap = REGS[127:120];
		cpu.core.Fp = REGS[119:112];
		cpu.core.regs.RegsH[{alt,2'b00}] = REGS[175:168];
		cpu.core.regs.RegsL[{alt,2'b00}] = REGS[167:160];
		cpu.core.regs.RegsH[{alt,2'b01}] = REGS[159:152];
		cpu.core.regs.RegsL[{alt,2'b01}] = REGS[151:144];
		cpu.core.regs.RegsH[{alt,2'b10}] = REGS[143:136];
		cpu.core.regs.RegsL[{alt,2'b10}] = REGS[135:128];
		cpu.core.regs.RegsH[{!alt,2'b00}] = REGS[111:104];
		cpu.core.regs.RegsL[{!alt,2'b00}] = REGS[103:96];
		cpu.core.regs.RegsH[{!alt,2'b01}] = REGS[95:88];
		cpu.core.regs.RegsL[{!alt,2'b01}] = REGS[87:80];
		cpu.core.regs.RegsH[{!alt,2'b10}] = REGS[79:72];
		cpu.core.regs.RegsL[{!alt,2'b10}] = REGS[71:64];
		cpu.core.regs.RegsH[3] = REGS[63:56];
		cpu.core.regs.RegsL[3] = REGS[55:48];
		cpu.core.regs.RegsH[7] = REGS[47:40];
		cpu.core.regs.RegsL[7] = REGS[39:32];
		cpu.core.SP = REGS[31:16];
		cpu.core.PC = REGS[15:0];
		cpu.core.A = REGS[15:0];
		cpu.core.I = I; cpu.core.R = R; 
		cpu.core.IntE_FF1 = IFF[0]; cpu.core.IntE_FF2 = IFF[1];
	end
endtask


`define FIN 15
initial begin
`ifdef TEST_ALL
	$display("Starting all tests...");
`endif

`ifdef TEST_ALL
`define TEST_00
`endif 
`ifdef TEST_00
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	TESTCASE(" -- 00 -- nop");
	// -----------------------------------------------------
	//       - AF    BC   DE   HL   AF'  BC'  DE'  HL'  IX   IY   SP   PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	SETMEM(0, 8'h00);
	#(2* `CLKPERIOD * 4+`FIN);
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_00

`ifdef TEST_ALL
`define TEST_DD00
`endif 
`ifdef TEST_DD00
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	TESTCASE(" -- dd 00 -- nop (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd);  SETMEM(1, 8'h00);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD00

`ifdef TEST_ALL
`define TEST_FD00
`endif
`ifdef TEST_FD00

	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	TESTCASE(" -- fd 00 -- nop (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd);  SETMEM(1, 8'h00);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD00

`ifdef TEST_ALL
`define TEST_01
`endif
`ifdef TEST_01

	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	TESTCASE(" -- 01 12 34 -- ld bc,$3412");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h01); SETMEM(1, 8'h12); SETMEM(2, 8'h34);
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0000_3412_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h01, 2'b00);
`endif // TEST_01

`ifdef TEST_ALL
`define TEST_DD01
`endif
`ifdef TEST_DD01
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	TESTCASE(" -- dd 01 12 34 -- ld bc,$3412 (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd);  SETMEM(1, 8'h01); SETMEM(2, 8'h12); SETMEM(3, 8'h34);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h6a00_3412_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD01

`ifdef TEST_ALL
`define TEST_FD01
`endif
`ifdef TEST_FD01
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	TESTCASE(" -- fd 01 12 34 -- ld bc,$3412 (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd);  SETMEM(1, 8'h01); SETMEM(2, 8'h12); SETMEM(3, 8'h34);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h6a00_3412_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD01

`ifdef TEST_ALL
`define TEST_02
`endif
`ifdef TEST_02
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	TESTCASE(" -- 02 -- ld (bc),a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h5600_0001_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h02); SETMEM(1, 8'h00);
	#(2* `CLKPERIOD * 7)
	ASSERTMEM(16'h0001, 8'h56);
	ASSERT(192'h5600_0001_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_02

`ifdef TEST_ALL
`define TEST_DD02
`endif
`ifdef TEST_DD02
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	TESTCASE(" -- dd 02 -- ld (bc),a (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h5600_0134_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h02);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERTMEM(16'h0134,8'h56);
	ASSERT(192'h5600_0134_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD02

`ifdef TEST_ALL
`define TEST_FD02
`endif
`ifdef TEST_FD02
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	TESTCASE(" -- fd 02 -- ld (bc),a (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h5600_0134_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h02);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERTMEM(16'h0134, 8'h56);
	ASSERT(192'h5600_0134_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD02

`ifdef TEST_ALL
`define TEST_03
`endif
`ifdef TEST_03
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	TESTCASE(" -- 03 -- inc bc");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_789a_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h03);
	#(2* `CLKPERIOD * 6+`FIN)
	ASSERT(192'h0000_789b_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_03

`ifdef TEST_ALL
`define TEST_DD03
`endif
`ifdef TEST_DD03
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 03 (INC BC)
	TESTCASE(" -- dd 03 -- inc bc (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_789a_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h03);
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0000_789b_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD03

`ifdef TEST_ALL
`define TEST_FD03
`endif
`ifdef TEST_FD03
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 03 (INC BC)
	TESTCASE(" -- fd 03 -- inc bc (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_789a_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h03);
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0000_789b_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD03

`ifdef TEST_ALL
`define TEST_04
`endif
`ifdef TEST_04
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 04 (INC B)
	TESTCASE(" -- 04 -- inc b (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_ff00_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h04);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0050_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_04

`ifdef TEST_ALL
`define TEST_DD04
`endif
`ifdef TEST_DD04
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 04 (INC B)
	TESTCASE(" -- dd 04 -- inc b (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_ff00_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h04);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0050_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD04

`ifdef TEST_ALL
`define TEST_FD04
`endif
`ifdef TEST_FD04
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 04 (INC B)
	TESTCASE(" -- fd 04 -- inc b (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_ff00_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h04);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0050_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD04

`ifdef TEST_ALL
`define TEST_05
`endif
`ifdef TEST_05
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 05 (DEC B)
	TESTCASE(" -- 05 -- dec b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h05);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h00ba_ff00_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_05

`ifdef TEST_ALL
`define TEST_DD05
`endif
`ifdef TEST_DD05
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 05 (DEC B)
	TESTCASE(" -- dd 05 -- dec b (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h05);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h00ba_ff00_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD05

`ifdef TEST_ALL
`define TEST_FD05
`endif
`ifdef TEST_FD05
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 05 (DEC B)
	TESTCASE(" -- fd 05 -- dec b (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h05);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h00ba_ff00_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD05

`ifdef TEST_ALL
`define TEST_06
`endif
`ifdef TEST_06
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 06 (LD B,n)
	TESTCASE(" -- 06 -- ld b,$BC");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h06); SETMEM(1, 8'hbc);
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h0000_bc00_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h01, 2'b00);
`endif // TEST_06

`ifdef TEST_ALL
`define TEST_DD06
`endif
`ifdef TEST_DD06
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 06 (LD B,n)
	TESTCASE(" -- dd 06 -- ld b,$CB (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h06); SETMEM(2, 8'hcb);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h0000_cb00_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD06

`ifdef TEST_ALL
`define TEST_FD06
`endif
`ifdef TEST_FD06
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 06 (LD B,n)
	TESTCASE(" -- fd 06 -- ld b,$CB (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h06); SETMEM(2, 8'hcb);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h0000_cb00_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD06

`ifdef TEST_ALL
`define TEST_07
`endif
`ifdef TEST_07
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 07 (RLCA)
	TESTCASE(" -- 07 -- rlca");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h8800_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h07);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h1101_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_07

`ifdef TEST_ALL
`define TEST_DD07
`endif
`ifdef TEST_DD07
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 07 (RLCA)
	TESTCASE(" -- dd 07 -- rlca (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h8800_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h07);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h1101_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD07

`ifdef TEST_ALL
`define TEST_FD07
`endif
`ifdef TEST_FD07
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 07 (RLCA)
	TESTCASE(" -- fd 07 -- rlca (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h8800_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h07);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h1101_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD07

`ifdef TEST_ALL
`define TEST_08
`endif
`ifdef TEST_08
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 08 (EX AF,AF')
	TESTCASE(" -- 08 -- ex af,af'");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hdef0_0000_0000_0000_1234_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h08);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h1234_0000_0000_0000_def0_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_08

`ifdef TEST_ALL
`define TEST_DD08
`endif
`ifdef TEST_DD08
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 08 (EX AF,AF')
	TESTCASE(" -- dd 08 -- ex af,af' (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hdef0_0000_0000_0000_1234_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h08);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h1234_0000_0000_0000_def0_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD08

`ifdef TEST_ALL
`define TEST_FD08
`endif
`ifdef TEST_FD08
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 08 (EX AF,AF')
	TESTCASE(" -- fd 08 -- ex af,af' (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hdef0_0000_0000_0000_1234_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h08);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h1234_0000_0000_0000_def0_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD08

`ifdef TEST_ALL
`define TEST_09
`endif
`ifdef TEST_09
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 09 (ADD HL,BC)
	TESTCASE(" -- 09 -- add hl,bc");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_5678_0000_9abc_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h09);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h0030_5678_0000_f134_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_09

`ifdef TEST_ALL
`define TEST_DD09
`endif
`ifdef TEST_DD09
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 09 (ADD IX,BC)
	TESTCASE(" -- dd 09 -- add ix,bc");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_5678_0000_1abc_0000_0000_0000_0000_9abc_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h09);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h0030_5678_0000_1abc_0000_0000_0000_0000_f134_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD09

`ifdef TEST_ALL
`define TEST_FD09
`endif
`ifdef TEST_FD09
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 09 (ADD IY,BC)
	TESTCASE(" -- fd 09 -- add iy,bc");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_5678_0000_1abc_0000_0000_0000_0000_0000_9abc_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h09);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h0030_5678_0000_1abc_0000_0000_0000_0000_0000_f134_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD09

`ifdef TEST_ALL
`define TEST_0A
`endif
`ifdef TEST_0A
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 0A (LD A,(BC))
	TESTCASE(" -- 0A -- ld a,(bc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0122_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h0a);  SETMEM(16'h0122, 8'hde);
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'hde00_0122_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_0A

`ifdef TEST_ALL
`define TEST_DD0A
`endif
`ifdef TEST_DD0A
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 0A (LD A,(BC))
	TESTCASE(" -- dd 0A -- ld a,(bc) (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0122_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h0a);  SETMEM(16'h0122, 8'hde);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'hde00_0122_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD0A

`ifdef TEST_ALL
`define TEST_FD0A
`endif
`ifdef TEST_FD0A
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 0A (LD A,(BC))
	TESTCASE(" -- fd 0A -- ld a,(bc) (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0122_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h0a); SETMEM(16'h0122, 8'hde);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'hde00_0122_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD0A

`ifdef TEST_ALL
`define TEST_0B
`endif
`ifdef TEST_0B
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 0B (DEC BC)
	TESTCASE(" -- 0B -- dec bc");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h0b);
	#(2* `CLKPERIOD * 6+`FIN)
	ASSERT(192'h0000_ffff_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_0B

`ifdef TEST_ALL
`define TEST_DD0B
`endif
`ifdef TEST_DD0B
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 0B (DEC BC)
	TESTCASE(" -- dd 0B -- dec bc (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h0b);
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0000_ffff_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD0B

`ifdef TEST_ALL
`define TEST_FD0B
`endif
`ifdef TEST_FD0B
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 0B (DEC BC)
	TESTCASE(" -- fd 0B -- dec bc (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h0b);
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0000_ffff_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD0B

`ifdef TEST_ALL
`define TEST_0C
`endif
`ifdef TEST_0C
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 0C (INC C)
	TESTCASE(" -- 0C -- inc c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_007f_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h0c);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0094_0080_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_0C

`ifdef TEST_ALL
`define TEST_DD0C
`endif
`ifdef TEST_DD0C
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 0C (INC C)
	TESTCASE(" -- dd 0C -- inc c (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_007f_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h0c);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0094_0080_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD0C

`ifdef TEST_ALL
`define TEST_FD0C
`endif
`ifdef TEST_FD0C
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 0C (INC C)
	TESTCASE(" -- fd 0C -- inc c (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_007f_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h0c);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0094_0080_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD0C

`ifdef TEST_ALL
`define TEST_0D
`endif
`ifdef TEST_0D
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 0D (DEC C)
	TESTCASE(" -- 0D -- dec c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0080_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h0d);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h003e_007f_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_0D

`ifdef TEST_ALL
`define TEST_DD0D
`endif
`ifdef TEST_DD0D
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 0D (DEC C)
	TESTCASE(" -- dd 0D -- dec c (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0080_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h0d);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h003e_007f_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD0D

`ifdef TEST_ALL
`define TEST_FD0D
`endif
`ifdef TEST_FD0D
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 0D (DEC C)
	TESTCASE(" -- fd 0D -- dec c (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0080_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h0d);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h003e_007f_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD0D

`ifdef TEST_ALL
`define TEST_0E
`endif
`ifdef TEST_0E
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 0E (LD C,n)
	TESTCASE(" -- 0E -- ld c,$f0");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h0e); SETMEM(1, 8'hf0);
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h0000_00f0_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h01, 2'b00);
`endif // TEST_0E

`ifdef TEST_ALL
`define TEST_DD0E
`endif
`ifdef TEST_DD0E
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 0E (LD C,n)
	TESTCASE(" -- dd 0E -- ld c,$f0 (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h0e); SETMEM(2, 8'hf0);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h0000_00f0_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD0E

`ifdef TEST_ALL
`define TEST_FD0E
`endif
`ifdef TEST_FD0E
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 0E (LD C,n)
	TESTCASE(" -- fd 0E -- ld c,$f0 (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h0e); SETMEM(2, 8'hf0);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h0000_00f0_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD0E

`ifdef TEST_ALL
`define TEST_0F
`endif
`ifdef TEST_0F
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 0F (RRCA)
	TESTCASE(" -- 0F -- rrca");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h4100_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h0f);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'ha021_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_0F

`ifdef TEST_ALL
`define TEST_DD0F
`endif
`ifdef TEST_DD0F
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 0F (RRCA)
	TESTCASE(" -- dd 0F -- rrca (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h4100_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h0f);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha021_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD0F

`ifdef TEST_ALL
`define TEST_FD0F
`endif
`ifdef TEST_FD0F
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 0F (RRCA)
	TESTCASE(" -- fd 0F -- rrca (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h4100_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h0f);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha021_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD0F

`ifdef TEST_ALL
`define TEST_10
`endif
`ifdef TEST_10
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 10 (DJNZ d)
	TESTCASE(" -- 00 10 fd 03 -- nop : djnz -3 : inc c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0800_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h00); SETMEM(1, 8'h10); SETMEM(2, 8'hfd); SETMEM(3, 8'h0c);
	#(2* `CLKPERIOD * 135+`FIN)
	ASSERT(192'h0000_0001_0000_0000_0000_0000_0000_0000_0000_0000_0000_0004, 8'h00, 8'h11, 2'b00);
`endif // TEST_10

`ifdef TEST_ALL
`define TEST_DD10
`endif
`ifdef TEST_DD10
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 10 (DJNZ d)
	TESTCASE(" -- dd 10 fd 03 -- DD : djnz -3 : inc c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0800_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h10); SETMEM(2, 8'hfd); SETMEM(3, 8'h0c);
	#(2* `CLKPERIOD * 135+`FIN)
	ASSERT(192'h0000_0001_0000_0000_0000_0000_0000_0000_0000_0000_0000_0004, 8'h00, 8'h11, 2'b00);
`endif // TEST_DD10

`ifdef TEST_ALL
`define TEST_FD10
`endif
`ifdef TEST_FD10
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 10 (DJNZ d)
	TESTCASE(" -- fd 10 fd 03 -- FD : djnz -3 : inc c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0800_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h10); SETMEM(2, 8'hfd); SETMEM(3, 8'h0c);
	#(2* `CLKPERIOD * 135+`FIN)
	ASSERT(192'h0000_0001_0000_0000_0000_0000_0000_0000_0000_0000_0000_0004, 8'h00, 8'h11, 2'b00);
`endif // TEST_FD10

`ifdef TEST_ALL
`define TEST_11
`endif
`ifdef TEST_11
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 11 (LD DE,nn)
	TESTCASE(" -- 11 9a bc -- ld de, $bc9a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_8123_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h11); SETMEM(1, 8'hab); SETMEM(2, 8'hcd);
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0000_0000_cdab_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h01, 2'b00);
`endif // TEST_11

`ifdef TEST_ALL
`define TEST_DD11
`endif
`ifdef TEST_DD11
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 11 (LD DE,nn)
	TESTCASE(" -- dd 11 9a bc -- ld de, $bc9a (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_8123_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h11); SETMEM(2, 8'hab); SETMEM(3, 8'hcd);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0000_0000_cdab_0000_0000_0000_0000_0000_0000_0000_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD11

`ifdef TEST_ALL
`define TEST_FD11
`endif
`ifdef TEST_FD11
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 11 (LD DE,nn)
	TESTCASE(" -- fd 11 9a bc -- ld de, $bc9a (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_8123_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h11); SETMEM(2, 8'hab); SETMEM(3, 8'hcd);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0000_0000_cdab_0000_0000_0000_0000_0000_0000_0000_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD11

`ifdef TEST_ALL
`define TEST_12
`endif
`ifdef TEST_12
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 12 (LD (DE),a)
	TESTCASE(" -- 12  -- ld (de),a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h5600_0000_0080_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h12);
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERTMEM(16'h0080, 8'h56);
	ASSERT(192'h5600_0000_0080_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_12

`ifdef TEST_ALL
`define TEST_DD12
`endif
`ifdef TEST_DD12
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 12 (LD (DE),a)
	TESTCASE(" -- dd 12 -- ld (de),a (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h5600_0000_00dd_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h12);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERTMEM(16'h00dd, 8'h56);
	ASSERT(192'h5600_0000_00dd_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD12

`ifdef TEST_ALL
`define TEST_FD12
`endif
`ifdef TEST_FD12
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 12 (LD (DE),a)
	TESTCASE(" -- fd 12 -- ld (de),a (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h5600_0000_00fd_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h12);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERTMEM(16'h00fd, 8'h56);
	ASSERT(192'h5600_0000_00fd_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD12

`ifdef TEST_ALL
`define TEST_13
`endif
`ifdef TEST_13
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 13 (INC DE)
	TESTCASE(" -- 13 -- inc de");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_def0_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h13);
	#(2* `CLKPERIOD * 6+`FIN)
	ASSERT(192'h0000_0000_def1_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_13

`ifdef TEST_ALL
`define TEST_DD13
`endif
`ifdef TEST_DD13
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 13 (INC DE)
	TESTCASE(" -- dd 13 -- inc de (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_def0_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h13);
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0000_0000_def1_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD13

`ifdef TEST_ALL
`define TEST_FD13
`endif
`ifdef TEST_FD13
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 13 (INC DE)
	TESTCASE(" -- fd 13 -- FD inc de (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_def0_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h13);
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0000_0000_def1_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD13

`ifdef TEST_ALL
`define TEST_14
`endif
`ifdef TEST_14
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 14 (INC D)
	TESTCASE(" -- 14 -- inc d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_2700_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h14);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0028_0000_2800_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_14

`ifdef TEST_ALL
`define TEST_DD14
`endif
`ifdef TEST_DD14
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 14 (INC D)
	TESTCASE(" -- dd 14 -- inc d (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_2700_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h14);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0028_0000_2800_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD14

`ifdef TEST_ALL
`define TEST_FD14
`endif
`ifdef TEST_FD14
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 14 (INC D)
	TESTCASE(" -- fd 14 -- inc d (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_2700_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h14);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0028_0000_2800_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD14

`ifdef TEST_ALL
`define TEST_15
`endif
`ifdef TEST_15
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 15 (DEC D)
	TESTCASE(" -- 15 -- dec d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_1000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h15);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h001a_0000_0f00_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_15

`ifdef TEST_ALL
`define TEST_DD15
`endif
`ifdef TEST_DD15
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 15 (DEC D)
	TESTCASE(" -- dd 15 -- dec d (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_1000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h15);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h001a_0000_0f00_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD15

`ifdef TEST_ALL
`define TEST_FD15
`endif
`ifdef TEST_FD15
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 15 (DEC D)
	TESTCASE(" -- fd 15 -- dec d (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_1000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h15);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h001a_0000_0f00_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD15

`ifdef TEST_ALL
`define TEST_16
`endif
`ifdef TEST_16
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 16 (LD D,n)
	TESTCASE(" -- 16 -- ld d,$12");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h16); SETMEM(1, 8'h12);
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h0000_0000_1200_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h01, 2'b00);
`endif // TEST_16

`ifdef TEST_ALL
`define TEST_DD16
`endif
`ifdef TEST_DD16
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 16 (LD D,n)
	TESTCASE(" -- dd 16 -- ld d,$dd (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h16); SETMEM(2, 8'hdd);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h0000_0000_dd00_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD16

`ifdef TEST_ALL
`define TEST_FD16
`endif
`ifdef TEST_FD16
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 16 (LD D,n)
	TESTCASE(" -- fd 16 - ld d,$fd (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h16); SETMEM(2, 8'hfd);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h0000_0000_fd00_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD16

`ifdef TEST_ALL
`define TEST_17
`endif
`ifdef TEST_17
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 17 (RLA)
	TESTCASE(" -- 17 -- rla");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0801_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h17);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h1100_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_17

`ifdef TEST_ALL
`define TEST_DD17
`endif
`ifdef TEST_DD17
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 17 (RLA)
	TESTCASE(" -- dd 17 -- rla (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0801_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h17);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h1100_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD17

`ifdef TEST_ALL
`define TEST_FD17
`endif
`ifdef TEST_FD17
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 17 (RLA)
	TESTCASE(" -- fd 17 -- rla (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0801_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h17);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h1100_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD17

`ifdef TEST_ALL
`define TEST_18
`endif
`ifdef TEST_18
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 18 (JR d')
	TESTCASE(" -- 18 -- jr $40");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h18); SETMEM(1, 8'h40);
	#(2* `CLKPERIOD * 12+`FIN)
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0042, 8'h00, 8'h01, 2'b00);
`endif // TEST_18

`ifdef TEST_ALL
`define TEST_DD18
`endif
`ifdef TEST_DD18
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 18 (JR d')
	TESTCASE(" -- dd 18 -- jr $fe (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h18); SETMEM(2, 8'hfe);
	#(2* `CLKPERIOD * 16+`FIN)
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD18

`ifdef TEST_ALL
`define TEST_FD18
`endif
`ifdef TEST_FD18
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 18 (JR d')
	TESTCASE(" -- fd 18 -- jr $fd (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h18); SETMEM(2, 8'hfd);
	#(2* `CLKPERIOD * 16+`FIN)
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD18

`ifdef TEST_ALL
`define TEST_19
`endif
`ifdef TEST_19
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 19 (ADD HL,DE)
	TESTCASE(" -- 19 -- add hl,de");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_3456_789a_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h19);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h0028_0000_3456_acf0_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_19

`ifdef TEST_ALL
`define TEST_DD19
`endif
`ifdef TEST_DD19
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 19 (ADD IX,DE)
	TESTCASE(" -- dd 19 == add ix,de");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_3456_bcde_0000_0000_0000_0000_789a_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h19);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h0028_0000_3456_bcde_0000_0000_0000_0000_acf0_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD19

`ifdef TEST_ALL
`define TEST_FD19
`endif
`ifdef TEST_FD19
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 19 (ADD IY,DE)
	TESTCASE(" -- fd 19 -- add iy,de");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_3456_bcde_0000_0000_0000_0000_0000_789a_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h19);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h0028_0000_3456_bcde_0000_0000_0000_0000_0000_acf0_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD19

`ifdef TEST_ALL
`define TEST_1A
`endif
`ifdef TEST_1A
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 1A (LD A,(DE))
	TESTCASE(" -- 1A -- ld a,(de)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0081_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h1a); SETMEM(16'h0081, 8'h13);
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h1300_0000_0081_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_1A

`ifdef TEST_ALL
`define TEST_DD1A
`endif
`ifdef TEST_DD1A
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 1A (LD A,(DE))
	TESTCASE(" -- dd 1A -- ld a,(de) (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_00dd_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h1a); SETMEM(16'h00dd, 8'h13);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h1300_0000_00dd_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD1A

`ifdef TEST_ALL
`define TEST_FD1A
`endif
`ifdef TEST_FD1A
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 1A (LD A,(DE))
	TESTCASE(" -- fd 1A -- ld a,(de) (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_00dd_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h1a); SETMEM(16'h00dd, 8'h13);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h1300_0000_00dd_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD1A

`ifdef TEST_ALL
`define TEST_1B
`endif
`ifdef TEST_1B
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 1B (DEC DE)
	TESTCASE(" -- 1B -- dec de");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_e5d4_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h1b);
	#(2* `CLKPERIOD * 6+`FIN)
	ASSERT(192'h0000_0000_e5d3_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_1B

`ifdef TEST_ALL
`define TEST_DD1B
`endif
`ifdef TEST_DD1B
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 1B (DEC DE)
	TESTCASE(" -- dd 1B -- dec de (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_e5d4_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h1b);
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0000_0000_e5d3_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD1B

`ifdef TEST_ALL
`define TEST_FD1B
`endif
`ifdef TEST_FD1B
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 1B (DEC DE)
	TESTCASE(" -- fd 1B -- dec de (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_e5d4_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h1b);
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0000_0000_e5d3_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD1B

`ifdef TEST_ALL
`define TEST_1C
`endif
`ifdef TEST_1C
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 1C (INC E)
	TESTCASE(" -- 1c -- inc e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_00aa_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h1c);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h00a8_0000_00ab_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_1C

`ifdef TEST_ALL
`define TEST_DD1C
`endif
`ifdef TEST_DD1C
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 1C (INC E)
	TESTCASE(" -- dd 1c -- inc e (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_00aa_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h1c);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h00a8_0000_00ab_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD1C

`ifdef TEST_ALL
`define TEST_FD1C
`endif
`ifdef TEST_FD1C
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 1C (INC E)
	TESTCASE(" -- fd 1c -- inc e (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_00aa_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h1c);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h00a8_0000_00ab_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD1C

`ifdef TEST_ALL
`define TEST_1D
`endif
`ifdef TEST_1D
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 1D (DEC E)
	TESTCASE(" -- 1d -- dec e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_00aa_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h1d);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h00aa_0000_00a9_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_1D

`ifdef TEST_ALL
`define TEST_DD1D
`endif
`ifdef TEST_DD1D
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 1D (DEC E)
	TESTCASE(" -- dd 1d -- dec e (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_00aa_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h1d);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h00aa_0000_00a9_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD1D

`ifdef TEST_ALL
`define TEST_FD1D
`endif
`ifdef TEST_FD1D
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 1D (DEC E)
	TESTCASE(" -- fd 1d -- dec e (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_00aa_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h1d);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h00aa_0000_00a9_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD1D

`ifdef TEST_ALL
`define TEST_1E
`endif
`ifdef TEST_1E
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 1E (LD E,n)
	TESTCASE(" -- 1E -- ld e,$ef");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h1e); SETMEM(1, 8'hef);
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h0000_0000_00ef_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h01, 2'b00);
`endif // TEST_1E

`ifdef TEST_ALL
`define TEST_DD1E
`endif
`ifdef TEST_DD1E
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 1E (LD E,n)
	TESTCASE(" -- dd 1e -- ld e,$dd (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h1e); SETMEM(2, 8'hdd);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h0000_0000_00dd_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD1E

`ifdef TEST_ALL
`define TEST_FD1E
`endif
`ifdef TEST_FD1E
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 1E (LD E,n)
	TESTCASE(" -- fd 1e -- ld e,$fd (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h1e); SETMEM(2, 8'hfd);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h0000_0000_00fd_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD1E

`ifdef TEST_ALL
`define TEST_1F
`endif
`ifdef TEST_1F
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 1F (RRA)
	TESTCASE(" -- 1F -- rra");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h01c4_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h1f);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h00c5_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_1F

`ifdef TEST_ALL
`define TEST_DD1F
`endif
`ifdef TEST_DD1F
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 1F (RRA)
	TESTCASE(" -- dd 1f -- rra (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h01c4_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h1f);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h00c5_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD1F

`ifdef TEST_ALL
`define TEST_FD1F
`endif
`ifdef TEST_FD1F
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 1F (RRA)
	TESTCASE(" -- fd 1f -- rra (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h01c4_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h1f);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h00c5_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD1F

`ifdef TEST_ALL
`define TEST_20_1
`endif
`ifdef TEST_20_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 20_1 (JR NZ,d)
	TESTCASE(" -- 20 40 -- jr nz,40 ;jump");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h20); SETMEM(1, 8'h40);
	#(2* `CLKPERIOD * 12+`FIN)
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0042, 8'h00, 8'h01, 2'b00);
`endif // TEST_20_1

`ifdef TEST_ALL
`define TEST_DD20_1
`endif
`ifdef TEST_DD20_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 20_1 (JR NZ,d)
	TESTCASE(" -- dd 20 40 -- jr nz,$40 ;jump (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h20); SETMEM(2, 8'h40);
	#(2* `CLKPERIOD * 16+`FIN)
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0043, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD20_1

`ifdef TEST_ALL
`define TEST_FD20_1
`endif
`ifdef TEST_FD20_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 20_1 (JR NZ,d)
	TESTCASE(" -- fd 20 40    FD jr nz,$40 ;jump");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h20); SETMEM(2, 8'h40);
	#(2* `CLKPERIOD * 16+`FIN)
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0043, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD20_1

`ifdef TEST_ALL
`define TEST_20_2
`endif
`ifdef TEST_20_2
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 20_1 (JR NZ,d)
	TESTCASE(" -- 20 40       jr nz,40 ;no jump");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0040_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h20); SETMEM(1, 8'h40);
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h0040_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h01, 2'b00);
`endif // TEST_20_2

`ifdef TEST_ALL
`define TEST_DD20_2
`endif
`ifdef TEST_DD20_2
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 20_1 (JR NZ,d)
	TESTCASE(" -- dd 20 40    DD jr nz,40 ;no jump");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0040_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h20); SETMEM(2, 8'h40);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h0040_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD20_2

`ifdef TEST_ALL
`define TEST_FD20_2
`endif
`ifdef TEST_FD20_2
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 20_1 (JR NZ,d)
	TESTCASE(" -- fd 20 40    FD jr nz,40 ;no jump");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0040_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h20); SETMEM(2, 8'h40);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h0040_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD20_2

`ifdef TEST_ALL
`define TEST_21
`endif
`ifdef TEST_21
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 21 (LD HL,nn)
	TESTCASE(" -- 21 28 ed    ld hl, $ed28");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h21); SETMEM(1, 8'h28); SETMEM(2, 8'hed);
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0000_0000_0000_ed28_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h01, 2'b00);
`endif // TEST_21

`ifdef TEST_ALL
`define TEST_DD21
`endif
`ifdef TEST_DD21
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 21 (LD IX,nn)
	TESTCASE(" -- dd 21 28 ed ld ix,$ed28");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h21); SETMEM(2, 8'h28); SETMEM(3, 8'hed);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_ed28_0000_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD21

`ifdef TEST_ALL
`define TEST_FD21
`endif
`ifdef TEST_FD21
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 21 (LD IY,nn)
	TESTCASE(" -- fd 21 28 ed ld iy,$ed28");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h21); SETMEM(2, 8'h28); SETMEM(3, 8'hed);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_ed28_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD21

`ifdef TEST_ALL
`define TEST_22
`endif
`ifdef TEST_22
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 22 (LD (nn),hl)
	TESTCASE(" -- 22 c3 01    ld ($01c3),hl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0080_c64c_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h22); SETMEM(1, 8'hc3); SETMEM(2, 8'h01);
	#(2* `CLKPERIOD * 16+`FIN)
	ASSERTMEM(16'h01c3, 8'h4c);
	ASSERTMEM(16'h01c4, 8'hc6);
	ASSERT(192'h0000_0000_0080_c64c_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h01, 2'b00);
`endif // TEST_22

`ifdef TEST_ALL
`define TEST_DD22
`endif
`ifdef TEST_DD22
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 22 (LD (nn),ix)
	TESTCASE(" -- dd 22 c3 01 ld ($01c3),ix");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0080_c64c_0000_0000_0000_0000_dd22_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h22); SETMEM(2, 8'hc3); SETMEM(3, 8'h01);
	#(2* `CLKPERIOD * 20+`FIN)
	ASSERTMEM(16'h01c3, 8'h22);
	ASSERTMEM(16'h01c4, 8'hdd);
	ASSERT(192'h0000_0000_0080_c64c_0000_0000_0000_0000_dd22_0000_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD22

`ifdef TEST_ALL
`define TEST_FD22
`endif
`ifdef TEST_FD22
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 22 (LD (nn),ix)
	TESTCASE(" -- fd 22 c3 01 ld ($01c3),iy");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0080_c64c_0000_0000_0000_0000_0000_fd33_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h22); SETMEM(2, 8'hc3); SETMEM(3, 8'h01);
	#(2* `CLKPERIOD * 20+`FIN)
	ASSERTMEM(16'h01c3, 8'h33);
	ASSERTMEM(16'h01c4, 8'hfd);
	ASSERT(192'h0000_0000_0080_c64c_0000_0000_0000_0000_0000_fd33_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD22

`ifdef TEST_ALL
`define TEST_23
`endif
`ifdef TEST_23
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 23 (INC HL)
	TESTCASE(" -- 23          inc hl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_9c4e_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h23);
	#(2* `CLKPERIOD * 6+`FIN)
	ASSERT(192'h0000_0000_0000_9c4f_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_23

`ifdef TEST_ALL
`define TEST_DD23
`endif
`ifdef TEST_DD23
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 23 (INC IX)
	TESTCASE(" -- dd 23       inc ix");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_9c4e_0000_0000_0000_0000_abcd_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h23);
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0000_0000_0000_9c4e_0000_0000_0000_0000_abce_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD23

`ifdef TEST_ALL
`define TEST_FD23
`endif
`ifdef TEST_FD23
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 23 (INC IY)
	TESTCASE(" -- fd 23       inc iy");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_9c4e_0000_0000_0000_0000_abcd_1234_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h23);
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0000_0000_0000_9c4e_0000_0000_0000_0000_abcd_1235_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD23

`ifdef TEST_ALL
`define TEST_24
`endif
`ifdef TEST_24
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 24 (INC D)
	TESTCASE(" -- 24          inc h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_7200_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h24);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0020_0000_0000_7300_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_24

`ifdef TEST_ALL
`define TEST_DD24
`endif
`ifdef TEST_DD24
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 24 (INC IXH)
	TESTCASE(" -- dd 24       inc ixh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_7200_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h24);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0000_0000_0000_7200_0000_0000_0000_0000_0100_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD24

`ifdef TEST_ALL
`define TEST_FD24
`endif
`ifdef TEST_FD24
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 24 (INC IYH)
	TESTCASE(" -- fd 24       inc iyh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_7200_0000_0000_0000_0000_0000_7200_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h24);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0020_0000_0000_7200_0000_0000_0000_0000_0000_7300_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD24

`ifdef TEST_ALL
`define TEST_25
`endif
`ifdef TEST_25
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 25 (DEC H)
	TESTCASE(" -- 25          dec h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_a500_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h25);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h00a2_0000_0000_a400_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_25

`ifdef TEST_ALL
`define TEST_DD25
`endif
`ifdef TEST_DD25
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 25 (DEC IXH)
	TESTCASE(" -- dd 25       dec ixh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_a500_0000_0000_0000_0000_a500_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h25);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h00a2_0000_0000_a500_0000_0000_0000_0000_a400_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD25

`ifdef TEST_ALL
`define TEST_FD25
`endif
`ifdef TEST_FD25
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 25 (DEC IYH)
	TESTCASE(" -- fd 25       dec iyh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_a500_0000_0000_0000_0000_0000_a500_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h25);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h00a2_0000_0000_a500_0000_0000_0000_0000_0000_a400_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD25

`ifdef TEST_ALL
`define TEST_26
`endif
`ifdef TEST_26
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 26 (LD H,n)
	TESTCASE(" -- 26 3a       ld h,$3a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h26); SETMEM(1, 8'h3a);
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h0000_0000_0000_3a00_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h01, 2'b00);
`endif // TEST_26

`ifdef TEST_ALL
`define TEST_DD26
`endif
`ifdef TEST_DD26
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 26 (LD IXH,n)
	TESTCASE(" -- dd 26 3a    ld ixh,$3a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h26); SETMEM(2, 8'h3a);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_3a00_0000_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD26

`ifdef TEST_ALL
`define TEST_FD26
`endif
`ifdef TEST_FD26
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 26 (LD IYH,n)
	TESTCASE(" -- fd 26 3a    ld iyh,$3a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h26); SETMEM(2, 8'h3a);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_3a00_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD26

`ifdef TEST_ALL
`define TEST_27
`endif
`ifdef TEST_27
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 27 (DAA)
	TESTCASE(" -- 27          daa -- 1");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9a02_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h27);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h3423_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_27

`ifdef TEST_ALL
`define TEST_DD27
`endif
`ifdef TEST_DD27
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 27 (DAA)
	TESTCASE(" -- dd 27       DD daa -- 1");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9a02_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h27);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h3423_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD27

`ifdef TEST_ALL
`define TEST_FD27
`endif
`ifdef TEST_FD27
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 27 (DAA)
	TESTCASE(" -- fd 27       FD daa -- 1");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9a02_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h27);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h3423_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD27

`ifdef TEST_ALL
`define TEST_27_2
`endif
`ifdef TEST_27_2
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 27 (DAA)
	TESTCASE(" -- 27          daa -- 2");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h1f00_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h27);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h2530_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_27_2

`ifdef TEST_ALL
`define TEST_DD27_2
`endif
`ifdef TEST_DD27_2
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 27 (DAA)
	TESTCASE(" -- dd 27       daa -- 2");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h1f00_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h27);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h2530_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD27_2

`ifdef TEST_ALL
`define TEST_FD27_2
`endif
`ifdef TEST_FD27_2
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 27 (DAA)
	TESTCASE(" -- fd 27       daa -- 2");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h1f00_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h27);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h2530_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD27_2

`ifdef TEST_ALL
`define TEST_28
`endif
`ifdef TEST_28
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 28 (JR Z,d')
	TESTCASE(" -- 28          jr Z,-114 ;no jump");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h28); SETMEM(1, 8'h8e);
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h01, 2'b00);
`endif // TEST_28

`ifdef TEST_ALL
`define TEST_DD28
`endif
`ifdef TEST_DD28
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 28 (JR Z,d')
	TESTCASE(" -- dd 28       jr Z,-114 ;no jump");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h28); SETMEM(2, 8'h8e);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD28

`ifdef TEST_ALL
`define TEST_FD28
`endif
`ifdef TEST_FD28
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 28 (JR Z,d')
	TESTCASE(" -- fd 28       jr Z,-114 ;no jump");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h28); SETMEM(2, 8'h8e);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD28

`ifdef TEST_ALL
`define TEST_28_2
`endif
`ifdef TEST_28_2
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 28 (JR Z,d')
	TESTCASE(" -- 28          jr Z,-114 ;jump");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0040_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h28); SETMEM(1, 8'h8e);
	#(2* `CLKPERIOD * 12+`FIN)
	ASSERT(192'h0040_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_ff90, 8'h00, 8'h01, 2'b00);
`endif // TEST_28_2

`ifdef TEST_ALL
`define TEST_DD28_2
`endif
`ifdef TEST_DD28_2
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 28 (JR Z,d')
	TESTCASE(" -- dd 28       jr Z,-114 ;jump");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0040_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h28); SETMEM(2, 8'h8e);
	#(2* `CLKPERIOD * 16+`FIN)
	ASSERT(192'h0040_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_ff91, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD28_2

`ifdef TEST_ALL
`define TEST_FD28_2
`endif
`ifdef TEST_FD28_2
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 28 (JR Z,d')
	TESTCASE(" -- fd 28       jr Z,-114 ;jump");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0040_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h28); SETMEM(2, 8'h8e);
	#(2* `CLKPERIOD * 16+`FIN)
	ASSERT(192'h0040_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_ff91, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD28_2

`ifdef TEST_ALL
`define TEST_29
`endif
`ifdef TEST_29
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 29 (ADD HL,HL)
	TESTCASE(" -- 29          add hl,hl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_cdfa_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h29);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h0019_0000_0000_9bf4_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_29

`ifdef TEST_ALL
`define TEST_DD29
`endif
`ifdef TEST_DD29
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 29 (ADD IX,IX)
	TESTCASE(" -- DD 29       add ix,ix");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_1234_0000_0000_0000_0000_cdfa_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h29);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h0019_0000_0000_1234_0000_0000_0000_0000_9bf4_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD29

`ifdef TEST_ALL
`define TEST_FD29
`endif
`ifdef TEST_FD29
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 29 (ADD IY,IY)
	TESTCASE(" -- FD 29       add iy,iy");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_1234_0000_0000_0000_0000_0000_cdfa_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h29);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h0019_0000_0000_1234_0000_0000_0000_0000_0000_9bf4_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD29

`ifdef TEST_ALL
`define TEST_2A
`endif
`ifdef TEST_2A
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 2A (LD HL,(nn))
	TESTCASE(" -- 2A          ld hl,(nn)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h2a); SETMEM(1, 8'h3a); SETMEM(2, 8'h01); SETMEM(16'h013a, 8'hc4); SETMEM(16'h013b, 8'hde);
	#(2* `CLKPERIOD * 16+`FIN)
	ASSERT(192'h0000_0000_0000_dec4_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h01, 2'b00);
`endif // TEST_2A

`ifdef TEST_ALL
`define TEST_DD2A
`endif
`ifdef TEST_DD2A
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 2A (LD IX,(nn))
	TESTCASE(" -- dd 2A       ld ix,(nn)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_8899_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h2a); SETMEM(2, 8'hdd); SETMEM(3, 8'h01); 
	SETMEM(16'h01dd, 8'hc4); SETMEM(16'h01de, 8'hde);
	#(2* `CLKPERIOD * 20+`FIN)
	ASSERT(192'h0000_0000_0000_8899_0000_0000_0000_0000_dec4_0000_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD2A

`ifdef TEST_ALL
`define TEST_FD2A
`endif
`ifdef TEST_FD2A
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 2A (LD IX,(nn))
	TESTCASE(" -- fd 2A       ld iy,(nn)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_8899_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h2a); SETMEM(2, 8'hdd); SETMEM(3, 8'h01); 
	SETMEM(16'h01dd, 8'hc4); SETMEM(16'h01de, 8'hde);
	#(2* `CLKPERIOD * 20+`FIN)
	ASSERT(192'h0000_0000_0000_8899_0000_0000_0000_0000_0000_dec4_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD2A

`ifdef TEST_ALL
`define TEST_2B
`endif
`ifdef TEST_2B
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 2B (DEC HL)
	TESTCASE(" -- 2B          dec hl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_9e66_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h2b);
	#(2* `CLKPERIOD * 6+`FIN)
	ASSERT(192'h0000_0000_0000_9e65_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_2B

`ifdef TEST_ALL
`define TEST_DD2B
`endif
`ifdef TEST_DD2B
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 2B (DEC IX)
	TESTCASE(" -- dd 2b       dec ix");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_9e66_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h2b);
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0000_0000_0000_9e66_0000_0000_0000_0000_ffff_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD2B

`ifdef TEST_ALL
`define TEST_FD2B
`endif
`ifdef TEST_FD2B
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 2B (DEC IY)
	TESTCASE(" -- fd 2b       dec iy");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_9e66_0000_0000_0000_0000_0000_0001_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h2b);
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0000_0000_0000_9e66_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD2B

`ifdef TEST_ALL
`define TEST_2C
`endif
`ifdef TEST_2C
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 2C (INC L)
	TESTCASE(" -- 2C          inc l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0026_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h2c);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0020_0000_0000_0027_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_2C

`ifdef TEST_ALL
`define TEST_DD2C
`endif
`ifdef TEST_DD2C
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 2C (INC IXL)
	TESTCASE(" -- dd 2c       inc ixl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0026_0000_0000_0000_0000_0026_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h2c);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0020_0000_0000_0026_0000_0000_0000_0000_0027_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD2C

`ifdef TEST_ALL
`define TEST_FD2C
`endif
`ifdef TEST_FD2C
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 2C (INC IYL)
	TESTCASE(" -- fd 2c       inc iyl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0026_0000_0000_0000_0000_0026_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h2c);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0000_0000_0000_0026_0000_0000_0000_0000_0026_0001_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD2C

`ifdef TEST_ALL
`define TEST_2D
`endif
`ifdef TEST_2D
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 2D (DEC L)
	TESTCASE(" -- 2D          dec l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0032_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h2d);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0022_0000_0000_0031_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_2D

`ifdef TEST_ALL
`define TEST_DD2D
`endif
`ifdef TEST_DD2D
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 2D (DEC IXL)
	TESTCASE(" -- dd 2d       dec ixl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0032_0000_0000_0000_0000_0032_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h2d);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0022_0000_0000_0032_0000_0000_0000_0000_0031_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD2D

`ifdef TEST_ALL
`define TEST_FD2D
`endif
`ifdef TEST_FD2D
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 2D (DEC IYL)
	TESTCASE(" -- fd 2d       dec iyl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0032_0000_0000_0000_0000_0032_0032_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h2d);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0022_0000_0000_0032_0000_0000_0000_0000_0032_0031_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD2D

`ifdef TEST_ALL
`define TEST_2E
`endif
`ifdef TEST_2E
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 2E (LD L,n)
	TESTCASE(" -- 2E          ld l,$18");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h2e); SETMEM(1, 8'h18);
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h0000_0000_0000_0018_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h01, 2'b00);
`endif // TEST_2E

`ifdef TEST_ALL
`define TEST_DD2E
`endif
`ifdef TEST_DD2E
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 2E (LD IXL,n)
	TESTCASE(" -- dd 2e       ld ixl,$18");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h2e); SETMEM(2, 8'h18);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_0018_0000_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD2E

`ifdef TEST_ALL
`define TEST_FD2E
`endif
`ifdef TEST_FD2E
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 2E (LD IYL,n)
	TESTCASE(" -- fd 2e       ld iyl,$18");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h2e); SETMEM(2, 8'h18);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0018_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD2E

`ifdef TEST_ALL
`define TEST_2F
`endif
`ifdef TEST_2F
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 2F (CPL)
	TESTCASE(" -- 2F          cpl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h8900_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h2f);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h7632_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_2F

`ifdef TEST_ALL
`define TEST_DD2F
`endif
`ifdef TEST_DD2F
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 2F (CPL)
	TESTCASE(" -- dd 2f       DD cpl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h8900_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h2f);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h7632_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD2F

`ifdef TEST_ALL
`define TEST_FD2F
`endif
`ifdef TEST_FD2F
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 2F (CPL)
	TESTCASE(" -- fd 2f       FD cpl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h8900_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h2f);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h7632_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD2F

`ifdef TEST_ALL
`define TEST_30_1
`endif
`ifdef TEST_30_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 30_1 (JR NC,d)
	TESTCASE(" -- 30 50       jr nc,$50 ;jump");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0036_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h30); SETMEM(1, 8'h50);
	#(2* `CLKPERIOD * 12+`FIN)
	ASSERT(192'h0036_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0052, 8'h00, 8'h01, 2'b00);
`endif // TEST_30_1

`ifdef TEST_ALL
`define TEST_DD30_1
`endif
`ifdef TEST_DD30_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 30_1 (JR NC,d)
	TESTCASE(" -- dd 30 50    jr nc,$50 ;jump");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0036_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h30); SETMEM(2, 8'h50);
	#(2* `CLKPERIOD * 16+`FIN)
	ASSERT(192'h0036_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0053, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD30_1

`ifdef TEST_ALL
`define TEST_FD30_1
`endif
`ifdef TEST_FD30_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 30_1 (JR NC,d)
	TESTCASE(" -- fd 30 50    jr nc,$50 ;jump");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0036_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h30); SETMEM(2, 8'h50);
	#(2* `CLKPERIOD * 16+`FIN)
	ASSERT(192'h0036_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0053, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD30_1

`ifdef TEST_ALL
`define TEST_30_2
`endif
`ifdef TEST_30_2
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 30_2 (JR NC,d)
	TESTCASE(" -- 30 50       jr nc,$50 ;no jump");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0037_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h30); SETMEM(1, 8'h50);
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h0037_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h01, 2'b00);
`endif // TEST_30_2

`ifdef TEST_ALL
`define TEST_DD30_2
`endif
`ifdef TEST_DD30_2
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 30_2 (JR NC,d)
	TESTCASE(" -- dd 30 50    jr nc,$50 ;no jump");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0037_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h30); SETMEM(2, 8'h50);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h0037_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD30_2

`ifdef TEST_ALL
`define TEST_FD30_2
`endif
`ifdef TEST_FD30_2
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 30_2 (JR NC,d)
	TESTCASE(" -- fd 30 50    jr nc,$50 ;no jump");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0037_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h30); SETMEM(2, 8'h50);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h0037_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD30_2

`ifdef TEST_ALL
`define TEST_31
`endif
`ifdef TEST_31
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 31 (LD SP,nn)
	TESTCASE(" -- 31 d4 61    ld sp, $61d4");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h31); SETMEM(1, 8'hd4); SETMEM(2, 8'h61);
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_61d4_0003, 8'h00, 8'h01, 2'b00);
`endif // TEST_31

`ifdef TEST_ALL
`define TEST_DD31
`endif
`ifdef TEST_DD31
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 31 (LD SP,nn)
	TESTCASE(" -- dd 31 d4 dd ld sp, $ddd4");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h31); SETMEM(2, 8'hd4); SETMEM(3, 8'hdd);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_ddd4_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD31

`ifdef TEST_ALL
`define TEST_FD31
`endif
`ifdef TEST_FD31
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 31 (LD SP,nn)
	TESTCASE(" -- fd 31 d4 fd ld sp, $fdd4");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h31); SETMEM(2, 8'hd4); SETMEM(3, 8'hfd);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_fdd4_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD31

`ifdef TEST_ALL
`define TEST_32
`endif
`ifdef TEST_32
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 32 (LD (nn),a)
	TESTCASE(" -- 32 ad 01    ld ($01ad),a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0e00_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h32); SETMEM(1, 8'had); SETMEM(2, 8'h01);
	#(2* `CLKPERIOD * 13+`FIN)
	ASSERTMEM(16'h01ad, 8'h0e);
	ASSERT(192'h0e00_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h01, 2'b00);
`endif // TEST_32

`ifdef TEST_ALL
`define TEST_DD32
`endif
`ifdef TEST_DD32
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 32 (LD (nn),a)
	TESTCASE(" -- dd 32 ad 01 ld ($01ad),a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0e00_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h32); SETMEM(2, 8'had); SETMEM(3, 8'h01);
	#(2* `CLKPERIOD * 17+`FIN)
	ASSERTMEM(16'h01ad, 8'h0e);
	ASSERT(192'h0e00_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD32

`ifdef TEST_ALL
`define TEST_FD32
`endif
`ifdef TEST_FD32
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 32 (LD (nn),a)
	TESTCASE(" -- fd 32 ad 01 ld ($01ad),a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0e00_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h32); SETMEM(2, 8'had); SETMEM(3, 8'h01);
	#(2* `CLKPERIOD * 17+`FIN)
	ASSERTMEM(16'h01ad, 8'h0e);
	ASSERT(192'h0e00_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD32

`ifdef TEST_ALL
`define TEST_33
`endif
`ifdef TEST_33
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 33 (INC SP)
	TESTCASE(" -- 33          inc sp");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_a55a_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h33);
	#(2* `CLKPERIOD * 6+`FIN)
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_a55b_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_33

`ifdef TEST_ALL
`define TEST_DD33
`endif
`ifdef TEST_DD33
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 33 (INC SP)
	TESTCASE(" -- dd 33       inc sp");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_a55a_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h33);
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_a55b_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD33

`ifdef TEST_ALL
`define TEST_FD33
`endif
`ifdef TEST_FD33
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 33 (INC SP)
	TESTCASE(" -- fd 33       inc sp");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_a55a_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h33);
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_a55b_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD33

`ifdef TEST_ALL
`define TEST_34
`endif
`ifdef TEST_34
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 34 (INC (HL))
	TESTCASE(" -- 34          inc (hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_011d_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h34); SETMEM(16'h011d, 8'hfd); 
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERTMEM(16'h011d, 8'hfe);
	ASSERT(192'h00a8_0000_0000_011d_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_34

`ifdef TEST_ALL
`define TEST_DD34
`endif
`ifdef TEST_DD34
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 34 (INC (IX+d))
	TESTCASE(" -- dd 34 34    inc (ix+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_011d_0000_0000_0000_0000_0101_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h34); SETMEM(2, 8'h34); 
	SETMEM(16'h0135, 8'hdd); 
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERTMEM(16'h0135, 8'hde);
	ASSERT(192'h0088_0000_0000_011d_0000_0000_0000_0000_0101_0000_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD34

`ifdef TEST_ALL
`define TEST_FD34
`endif
`ifdef TEST_FD34
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 34 (INC (IY+d))
	TESTCASE(" -- fd 34 fe    inc (iy+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_011d_0000_0000_0000_0000_0000_0101_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h34); SETMEM(2, 8'hfe); SETMEM(16'h00ff, 8'hfd); 
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERTMEM(16'h00ff, 8'hfe);
	ASSERT(192'h00a8_0000_0000_011d_0000_0000_0000_0000_0000_0101_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD34

`ifdef TEST_ALL
`define TEST_35
`endif
`ifdef TEST_35
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 35 (DEC (HL))
	TESTCASE(" -- 35          dec (hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_01a5_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h35); SETMEM(16'h01a5, 8'h82);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERTMEM(16'h01a5, 8'h81);
	ASSERT(192'h0082_0000_0000_01a5_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_35

`ifdef TEST_ALL
`define TEST_DD35
`endif
`ifdef TEST_DD35
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 35 (DEC (IX+d))
	TESTCASE(" -- dd 35 34    dec (ix+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_011d_0000_0000_0000_0000_0101_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h35); SETMEM(2, 8'h34); SETMEM(16'h0135, 8'hdd); 
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERTMEM(16'h0135, 8'hdc);
	ASSERT(192'h008a_0000_0000_011d_0000_0000_0000_0000_0101_0000_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD35

`ifdef TEST_ALL
`define TEST_FD35
`endif
`ifdef TEST_FD35
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 35 (DEC (IY+d))
	TESTCASE(" -- fd 35 fe    dec (iy+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_011d_0000_0000_0000_0000_0000_0101_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h35); SETMEM(2, 8'hfe); SETMEM(16'h00ff, 8'hfd); 
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERTMEM(16'h00ff, 8'hfc);
	ASSERT(192'h00aa_0000_0000_011d_0000_0000_0000_0000_0000_0101_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD35

`ifdef TEST_ALL
`define TEST_36
`endif
`ifdef TEST_36
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 36 (LD (HL),n)
	TESTCASE(" -- 36 7c       ld (hl),$7c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0129_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h36); SETMEM(1, 8'h7c);
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERTMEM(16'h0129, 8'h7c);
	ASSERT(192'h0000_0000_0000_0129_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h01, 2'b00);
`endif // TEST_36

`ifdef TEST_ALL
`define TEST_DD36
`endif
`ifdef TEST_DD36
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 36 (LD (IX+d),$77)
	TESTCASE(" -- dd 36 34 77 ld (ix+d),$77");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_011d_0000_0000_0000_0000_0101_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h36); SETMEM(2, 8'h34); SETMEM(3, 8'h77); SETMEM(16'h0135, 8'hdd); 
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERTMEM(16'h0135, 8'h77);
	ASSERT(192'h0000_0000_0000_011d_0000_0000_0000_0000_0101_0000_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD36

`ifdef TEST_ALL
`define TEST_FD36
`endif
`ifdef TEST_FD36
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 36 (LD (IY+d),n)
	TESTCASE(" -- fd 36 fe 66 ld (iy+d),$66");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_011d_0000_0000_0000_0000_0000_0101_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h36); SETMEM(2, 8'hfe); SETMEM(3, 8'h66); SETMEM(16'h00ff, 8'hfd); 
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERTMEM(16'h00ff, 8'h66);
	ASSERT(192'h0000_0000_0000_011d_0000_0000_0000_0000_0000_0101_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD36

`ifdef TEST_ALL
`define TEST_37
`endif
`ifdef TEST_37
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 37 (SCF)
	TESTCASE(" -- 37          scf ;1");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h00ff_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h37);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h00c5_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_37

`ifdef TEST_ALL
`define TEST_DD37
`endif
`ifdef TEST_DD37
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 37 (SCF)
	TESTCASE(" -- dd 37       DD scf ;1");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h00ff_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h37);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h00c5_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD37

`ifdef TEST_ALL
`define TEST_FD37
`endif
`ifdef TEST_FD37
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 37 (SCF)
	TESTCASE(" -- fd 37       FD scf ;1");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h00ff_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h37);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h00c5_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD37

`ifdef TEST_ALL
`define TEST_37
`endif
`ifdef TEST_37
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 37 (SCF)
	TESTCASE(" -- 37          scf ;2");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hff00_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h37);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hff29_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_37

`ifdef TEST_ALL
`define TEST_37
`endif
`ifdef TEST_37
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 37 (SCF)
	TESTCASE(" -- 37          scf ;3");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hffff_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h37);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hffed_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_37

`ifdef TEST_ALL
`define TEST_37
`endif
`ifdef TEST_37
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 37 (SCF)
	TESTCASE(" -- 37          scf ;4");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h37);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0001_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_37

`ifdef TEST_ALL
`define TEST_38
`endif
`ifdef TEST_38
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 38 (JR C,d')
	TESTCASE(" -- 38 66       jr C,$66 ;no jump");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h00b2_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h38); SETMEM(1, 8'h66);
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h00b2_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h01, 2'b00);
`endif // TEST_38

`ifdef TEST_ALL
`define TEST_DD38
`endif
`ifdef TEST_DD38
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 38 (JR C,d')
	TESTCASE(" -- dd 38 66    jr C,$66 ;no jump");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h00b2_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h38); SETMEM(2, 8'h66);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h00b2_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD38

`ifdef TEST_ALL
`define TEST_FD38
`endif
`ifdef TEST_FD38
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 38 (JR C,d')
	TESTCASE(" -- fd 38 66    jr C,$66 ;no jump");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h00b2_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h38); SETMEM(2, 8'h66);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h00b2_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD38

`ifdef TEST_ALL
`define TEST_38
`endif
`ifdef TEST_38
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 38 (JR C,d')
	TESTCASE(" -- 38 66       jr C,$66 ;jump");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h00b3_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h38); SETMEM(1, 8'h66);
	#(2* `CLKPERIOD * 12+`FIN)
	ASSERT(192'h00b3_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0068, 8'h00, 8'h01, 2'b00);
`endif // TEST_38

`ifdef TEST_ALL
`define TEST_DD38
`endif
`ifdef TEST_DD38
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 38 (JR C,d')
	TESTCASE(" -- dd 38 66    jr C,$66 ;jump");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h00b3_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h38); SETMEM(2, 8'h66);
	#(2* `CLKPERIOD * 16+`FIN)
	ASSERT(192'h00b3_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0069, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD38

`ifdef TEST_ALL
`define TEST_FD38
`endif
`ifdef TEST_FD38
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 38 (JR C,d')
	TESTCASE(" -- fd 38 66    jr C,$66 ;jump");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h00b3_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h38); SETMEM(2, 8'h66);
	#(2* `CLKPERIOD * 16+`FIN)
	ASSERT(192'h00b3_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0069, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD38

`ifdef TEST_ALL
`define TEST_39
`endif
`ifdef TEST_39
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 39 (ADD HL,SP)
	TESTCASE(" -- 39          add hl,sp");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_1aef_0000_0000_0000_0000_0000_0000_c534_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h39);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h0030_0000_0000_e023_0000_0000_0000_0000_0000_0000_c534_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_39

`ifdef TEST_ALL
`define TEST_DD39
`endif
`ifdef TEST_DD39
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 39 (ADD IX,SP)
	TESTCASE(" -- dd 39       add ix,sp");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_abcd_0000_0000_0000_0000_1aef_0000_c534_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h39);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h0030_0000_0000_abcd_0000_0000_0000_0000_e023_0000_c534_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD39

`ifdef TEST_ALL
`define TEST_FD39
`endif
`ifdef TEST_FD39
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 39 (ADD IY,SP)
	TESTCASE(" -- fd 39       add iy,sp");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_abcd_0000_0000_0000_0000_0000_1aef_c534_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h39);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h0030_0000_0000_abcd_0000_0000_0000_0000_0000_e023_c534_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD39

`ifdef TEST_ALL
`define TEST_3A
`endif
`ifdef TEST_3A
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 3A (LD A,(nn))
	TESTCASE(" -- 3A          ld a,(nn)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h3a); SETMEM(1, 8'h99); SETMEM(2, 8'h02); SETMEM(16'h0299, 8'h28);
	#(2* `CLKPERIOD * 13+`FIN)
	ASSERT(192'h2800_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h01, 2'b00);
`endif // TEST_3A

`ifdef TEST_ALL
`define TEST_DD3A
`endif
`ifdef TEST_DD3A
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 3A (LD A,(nn))
	TESTCASE(" -- dd 3A       ld a,(nn)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h3a); SETMEM(2, 8'h99); SETMEM(3, 8'h02); SETMEM(16'h0299, 8'h28);
	#(2* `CLKPERIOD * 17+`FIN)
	ASSERT(192'h2800_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD3A

`ifdef TEST_ALL
`define TEST_FD3A
`endif
`ifdef TEST_FD3A
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 3A (LD A,(nn))
	TESTCASE(" -- fd 3A       ld a,(nn)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h3a); SETMEM(2, 8'h99); SETMEM(3, 8'h02); SETMEM(16'h0299, 8'h28);
	#(2* `CLKPERIOD * 17+`FIN)
	ASSERT(192'h2800_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD3A

`ifdef TEST_ALL
`define TEST_3B
`endif
`ifdef TEST_3B
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 3B (DEC SP)
	TESTCASE(" -- 3B          dec sp");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_9d36_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h3b);
	#(2* `CLKPERIOD * 6+`FIN)
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_9d35_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_3B

`ifdef TEST_ALL
`define TEST_DD3B
`endif
`ifdef TEST_DD3B
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 3B (DEC SP)
	TESTCASE(" -- dd 3B       dec sp");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_9d36_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h3b);
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_9d35_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD3B

`ifdef TEST_ALL
`define TEST_FD3B
`endif
`ifdef TEST_FD3B
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 3B (DEC SP)
	TESTCASE(" -- fd 3B       dec sp");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_9d36_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h3b);
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_9d35_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD3B

`ifdef TEST_ALL
`define TEST_3C
`endif
`ifdef TEST_3C
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 3C (INC A)
	TESTCASE(" -- 3C          inc a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hcf00_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h3c);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hd090_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_3C

`ifdef TEST_ALL
`define TEST_DD3C
`endif
`ifdef TEST_DD3C
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 3C (INC A)
	TESTCASE(" -- dd 3C       inc a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hcf00_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h3c);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hd090_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD3C

`ifdef TEST_ALL
`define TEST_FD3C
`endif
`ifdef TEST_FD3C
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 3C (INC A)
	TESTCASE(" -- fd 3C       inc a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hcf00_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h3c);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hd090_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD3C

`ifdef TEST_ALL
`define TEST_3D
`endif
`ifdef TEST_3D
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 3D (DEC A)
	TESTCASE(" -- 3D          dec a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hea00_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h3d);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'he9aa_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_3D

`ifdef TEST_ALL
`define TEST_DD3D
`endif
`ifdef TEST_DD3D
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 3D (DEC A)
	TESTCASE(" -- dd 3D       dec a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hea00_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h3d);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'he9aa_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD3D

`ifdef TEST_ALL
`define TEST_FD3D
`endif
`ifdef TEST_FD3D
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 3D (DEC A)
	TESTCASE(" -- fd 3D       dec a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hea00_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h3d);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'he9aa_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD3D

`ifdef TEST_ALL
`define TEST_3E
`endif
`ifdef TEST_3E
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 3E (LD A,n)
	TESTCASE(" -- 3E          ld a,$d6");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h3e); SETMEM(1, 8'hd6);
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'hd600_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h01, 2'b00);
`endif // TEST_3E

`ifdef TEST_ALL
`define TEST_DD3E
`endif
`ifdef TEST_DD3E
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 3E (LD A,n)
	TESTCASE(" -- dd 3E       ld a,$d6");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h3e); SETMEM(2, 8'hd6);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'hd600_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD3E

`ifdef TEST_ALL
`define TEST_FD3E
`endif
`ifdef TEST_FD3E
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 3E (LD A,n)
	TESTCASE(" -- fd 3E       ld a,$d6");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h3e); SETMEM(2, 8'hd6);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'hd600_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD3E

`ifdef TEST_ALL
`define TEST_3F
`endif
`ifdef TEST_3F
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 3F (CCF)
	TESTCASE(" -- 3F          ccf");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h005b_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h3f);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0050_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_3F

`ifdef TEST_ALL
`define TEST_DD3F
`endif
`ifdef TEST_DD3F
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 3F (CCF)
	TESTCASE(" -- dd 3F       ccf");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h005b_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h3f);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0050_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD3F

`ifdef TEST_ALL
`define TEST_FD3F
`endif
`ifdef TEST_FD3F
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 3F (CCF)
	TESTCASE(" -- fd 3F       ccf");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h005b_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h3f);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0050_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD3F

`ifdef TEST_ALL
`define TEST_40
`endif
`ifdef TEST_40
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 40 (LD B,B)
	TESTCASE(" -- 40          ld b,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h40);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_40

`ifdef TEST_ALL
`define TEST_DD40
`endif
`ifdef TEST_DD40
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 40 (LD B,B)
	TESTCASE(" -- dd 40       ld b,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h40);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD40

`ifdef TEST_ALL
`define TEST_FD40
`endif
`ifdef TEST_FD40
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 40 (LD B,B)
	TESTCASE(" -- fd 40       ld b,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h40);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD40

`ifdef TEST_ALL
`define TEST_41
`endif
`ifdef TEST_41
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 41 (LD B,C)
	TESTCASE(" -- 41          ld b,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h41);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_9898_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_41

`ifdef TEST_ALL
`define TEST_DD41
`endif
`ifdef TEST_DD41
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 41 (LD B,C)
	TESTCASE(" -- dd 41       ld b,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h41);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_9898_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD41

`ifdef TEST_ALL
`define TEST_FD41
`endif
`ifdef TEST_FD41
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 41 (LD B,C)
	TESTCASE(" -- fd 41       ld b,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h41);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_9898_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD41

`ifdef TEST_ALL
`define TEST_42
`endif
`ifdef TEST_42
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 42 (LD B,D)
	TESTCASE(" -- 42          ld b,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h42);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_9098_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_42

`ifdef TEST_ALL
`define TEST_DD42
`endif
`ifdef TEST_DD42
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 42 (LD B,D)
	TESTCASE(" -- dd 42       ld b,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h42);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_9098_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD42

`ifdef TEST_ALL
`define TEST_FD42
`endif
`ifdef TEST_FD42
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 42 (LD B,D)
	TESTCASE(" -- fd 42       ld b,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h42);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_9098_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD42

`ifdef TEST_ALL
`define TEST_43
`endif
`ifdef TEST_43
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 43 (LD B,E)
	TESTCASE(" -- 43          ld b,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h43);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_d898_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_43

`ifdef TEST_ALL
`define TEST_DD43
`endif
`ifdef TEST_DD43
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 43 (LD B,E)
	TESTCASE(" -- dd 43       ld b,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h43);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_d898_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD43

`ifdef TEST_ALL
`define TEST_FD43
`endif
`ifdef TEST_FD43
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 43 (LD B,E)
	TESTCASE(" -- fd 43       ld b,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h43);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_d898_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD43

`ifdef TEST_ALL
`define TEST_44
`endif
`ifdef TEST_44
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 44 (LD B,H)
	TESTCASE(" -- 44          ld b,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h44);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_a198_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_44

`ifdef TEST_ALL
`define TEST_DD44
`endif
`ifdef TEST_DD44
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 44 (LD B,H)
	TESTCASE(" -- dd 44       ld b,ixh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_dd00_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h44);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_dd98_90d8_a169_0000_0000_0000_0000_dd00_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD44

`ifdef TEST_ALL
`define TEST_FD44
`endif
`ifdef TEST_FD44
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 44 (LD B,H)
	TESTCASE(" -- fd 44       ld b,iyh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_fd00_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h44);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_fd98_90d8_a169_0000_0000_0000_0000_0000_fd00_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD44

`ifdef TEST_ALL
`define TEST_45
`endif
`ifdef TEST_45
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 45 (LD B,L)
	TESTCASE(" -- 45          ld b,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h45); 
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_6998_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_45

`ifdef TEST_ALL
`define TEST_DD45
`endif
`ifdef TEST_DD45
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 45 (LD B,L)
	TESTCASE(" -- dd 45       ld b,ixl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_00dd_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h45); SETMEM(2, 8'h00); 
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_dd98_90d8_a169_0000_0000_0000_0000_00dd_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD45

`ifdef TEST_ALL
`define TEST_FD45
`endif
`ifdef TEST_FD45
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 45 (LD B,L)
	TESTCASE(" -- fd 45       ld b,iyl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_00dd_00fd_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h45); 
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_fd98_90d8_a169_0000_0000_0000_0000_00dd_00fd_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD45

`ifdef TEST_ALL
`define TEST_46
`endif
`ifdef TEST_46
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 46 (LD B,(HL))
	TESTCASE(" -- 46          ld b,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h46); SETMEM(16'h0169, 8'h50);
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h0200_5098_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_46

`ifdef TEST_ALL
`define TEST_DD46
`endif
`ifdef TEST_DD46
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 46 (LD B,(IX+d))
	TESTCASE(" -- dd 46       ld b,(ix+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_01dd_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h46); SETMEM(2, 8'h00); SETMEM(16'h01dd, 8'h50);
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'h0200_5098_90d8_0169_0000_0000_0000_0000_01dd_0000_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD46

`ifdef TEST_ALL
`define TEST_FD46
`endif
`ifdef TEST_FD46
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 46 (LD B,(IY+d))
	TESTCASE(" -- fd 46       ld b,(iy+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_01fd_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h46); SETMEM(2, 8'h02); SETMEM(16'h01ff, 8'h50);
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'h0200_5098_90d8_0169_0000_0000_0000_0000_0000_01fd_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD46

`ifdef TEST_ALL
`define TEST_47
`endif
`ifdef TEST_47
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 47 (LD B,A)
	TESTCASE(" -- 47          ld b,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h47);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_0298_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_47

`ifdef TEST_ALL
`define TEST_DD47
`endif
`ifdef TEST_DD47
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 47 (LD B,A)
	TESTCASE(" -- dd 47       ld b,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h47);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_0298_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD47

`ifdef TEST_ALL
`define TEST_FD47
`endif
`ifdef TEST_FD47
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 47 (LD B,A)
	TESTCASE(" -- fd 47       ld b,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h47);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_0298_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD47

`ifdef TEST_ALL
`define TEST_48
`endif
`ifdef TEST_48
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 48 (LD C,B)
	TESTCASE(" -- 48          ld c,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h48);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cfcf_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_48

`ifdef TEST_ALL
`define TEST_DD48
`endif
`ifdef TEST_DD48
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 48 (LD C,B)
	TESTCASE(" -- dd 48       ld c,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h48);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cfcf_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD48

`ifdef TEST_ALL
`define TEST_FD48
`endif
`ifdef TEST_FD48
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 48 (LD C,B)
	TESTCASE(" -- fd 48       ld c,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h48);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cfcf_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD48

`ifdef TEST_ALL
`define TEST_49
`endif
`ifdef TEST_49
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 49 (LD C,C)
	TESTCASE(" -- 49          ld c,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h49);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_49

`ifdef TEST_ALL
`define TEST_DD49
`endif
`ifdef TEST_DD49
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 49 (LD C,C)
	TESTCASE(" -- dd 49       ld c,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h49);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD49

`ifdef TEST_ALL
`define TEST_FD49
`endif
`ifdef TEST_FD49
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 49 (LD C,C)
	TESTCASE(" -- fd 49       ld c,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h49);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD49

`ifdef TEST_ALL
`define TEST_4A
`endif
`ifdef TEST_4A
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 4A (LD C,D)
	TESTCASE(" -- 4a          ld c,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h4a);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf90_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_4A

`ifdef TEST_ALL
`define TEST_DD4A
`endif
`ifdef TEST_DD4A
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 4A (LD C,D)
	TESTCASE(" -- dd 4a       ld c,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h4a);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf90_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD4A

`ifdef TEST_ALL
`define TEST_FD4A
`endif
`ifdef TEST_FD4A
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 4A (LD C,D)
	TESTCASE(" -- fd 4a       ld c,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h4a);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf90_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD4A

`ifdef TEST_ALL
`define TEST_4B
`endif
`ifdef TEST_4B
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 4B (LD C,E)
	TESTCASE(" -- 4b          ld c,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h4b);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cfd8_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_4B

`ifdef TEST_ALL
`define TEST_DD4B
`endif
`ifdef TEST_DD4B
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 4B (LD C,E)
	TESTCASE(" -- dd 4b       ld c,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h4b);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cfd8_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD4B

`ifdef TEST_ALL
`define TEST_FD4B
`endif
`ifdef TEST_FD4B
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 4B (LD C,E)
	TESTCASE(" -- fd 4b       ld c,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h4b);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cfd8_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD4B

`ifdef TEST_ALL
`define TEST_4C
`endif
`ifdef TEST_4C
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 4C (LD C,H)
	TESTCASE(" -- 4c          ld c,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h4c);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cfa1_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_4C

`ifdef TEST_ALL
`define TEST_DD4C
`endif
`ifdef TEST_DD4C
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 4C (LD C,IXH)
	TESTCASE(" -- dd 4c       ld c,ixh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_1100_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h4c);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf11_90d8_a169_0000_0000_0000_0000_1100_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD4C

`ifdef TEST_ALL
`define TEST_FD4C
`endif
`ifdef TEST_FD4C
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 4C (LD C,H)
	TESTCASE(" -- fd 4c       ld c,iyh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_2200_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h4c);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf22_90d8_a169_0000_0000_0000_0000_0000_2200_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD4C

`ifdef TEST_ALL
`define TEST_4D
`endif
`ifdef TEST_4D
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 4D (LD C,L)
	TESTCASE(" -- 4D          ld c,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h4d);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf69_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_4D

`ifdef TEST_ALL
`define TEST_DD4D
`endif
`ifdef TEST_DD4D
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 4D (LD C,IXL)
	TESTCASE(" -- dd 4D       ld c,ixl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0011_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h4d);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf11_90d8_a169_0000_0000_0000_0000_0011_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD4D

`ifdef TEST_ALL
`define TEST_FD4D
`endif
`ifdef TEST_FD4D
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 4D (LD C,IYL)
	TESTCASE(" -- fd 4D       ld c,iyl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0011_0022_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h4d);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf22_90d8_a169_0000_0000_0000_0000_0011_0022_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD4D

`ifdef TEST_ALL
`define TEST_4E
`endif
`ifdef TEST_4E
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 4E (LD C,(HL))
	TESTCASE(" -- 4e          ld c,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h4e); SETMEM(16'h0169, 8'h77);
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h0200_cf77_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_4E

`ifdef TEST_ALL
`define TEST_DD4E
`endif
`ifdef TEST_DD4E
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 4E (LD C,(IX+d))
	TESTCASE(" -- dd 4e       ld c,(ix+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0167_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h4e); SETMEM(2, 8'h02); SETMEM(16'h0169, 8'h77);
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'h0200_cf77_90d8_0169_0000_0000_0000_0000_0167_0000_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD4E

`ifdef TEST_ALL
`define TEST_FD4E
`endif
`ifdef TEST_FD4E
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 4E (LD C,(IY+d))
	TESTCASE(" -- fd 4e       ld c,(iy+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_01aa_0167_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h4e); SETMEM(2, 8'h03); SETMEM(16'h016a, 8'h77);
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'h0200_cf77_90d8_0169_0000_0000_0000_0000_01aa_0167_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD4E

`ifdef TEST_ALL
`define TEST_4F
`endif
`ifdef TEST_4F
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 4F (LD C,A)
	TESTCASE(" -- 4f          ld c,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h4f);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf02_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_4F

`ifdef TEST_ALL
`define TEST_DD4F
`endif
`ifdef TEST_DD4F
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 4F (LD C,A)
	TESTCASE(" -- dd 4f       ld c,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h4f);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf02_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD4F

`ifdef TEST_ALL
`define TEST_FD4F
`endif
`ifdef TEST_FD4F
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 4F (LD C,A)
	TESTCASE(" -- fd 4f       ld c,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h4f);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf02_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD4F

`ifdef TEST_ALL
`define TEST_50
`endif
`ifdef TEST_50
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 50 (LD D,B)
	TESTCASE(" -- 50          ld d,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h50);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_cfd8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_50

`ifdef TEST_ALL
`define TEST_DD50
`endif
`ifdef TEST_DD50
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 50 (LD D,B)
	TESTCASE(" -- dd 50       ld d,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h50);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_cfd8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD50

`ifdef TEST_ALL
`define TEST_FD50
`endif
`ifdef TEST_FD50
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 50 (LD D,B)
	TESTCASE(" -- fd 50       ld d,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h50);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_cfd8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD50

`ifdef TEST_ALL
`define TEST_51
`endif
`ifdef TEST_51
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 51 (LD D,C)
	TESTCASE(" -- 51          ld d,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h51);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_98d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_51

`ifdef TEST_ALL
`define TEST_DD51
`endif
`ifdef TEST_DD51
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 51 (LD D,C)
	TESTCASE(" -- dd 51       ld d,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h51);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_98d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD51

`ifdef TEST_ALL
`define TEST_FD51
`endif
`ifdef TEST_FD51
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 51 (LD D,C)
	TESTCASE(" -- fd 51       ld d,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h51);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_98d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD51

`ifdef TEST_ALL
`define TEST_52
`endif
`ifdef TEST_52
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 52 (LD D,D)
	TESTCASE(" -- 52          ld d,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h52);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_52

`ifdef TEST_ALL
`define TEST_DD52
`endif
`ifdef TEST_DD52
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 52 (LD D,D)
	TESTCASE(" -- dd 52       ld d,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h52);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD52

`ifdef TEST_ALL
`define TEST_FD52
`endif
`ifdef TEST_FD52
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 52 (LD D,D)
	TESTCASE(" -- fd 52       ld d,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h52);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD52

`ifdef TEST_ALL
`define TEST_53
`endif
`ifdef TEST_53
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 53 (LD D,E)
	TESTCASE(" -- 53          ld d,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h53);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_d8d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_53

`ifdef TEST_ALL
`define TEST_DD53
`endif
`ifdef TEST_DD53
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 53 (LD D,E)
	TESTCASE(" -- dd 53       ld d,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h53);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_d8d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD53

`ifdef TEST_ALL
`define TEST_FD53
`endif
`ifdef TEST_FD53
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 53 (LD D,E)
	TESTCASE(" -- fd 53       ld d,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h53);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_d8d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD53

`ifdef TEST_ALL
`define TEST_54
`endif
`ifdef TEST_54
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 54 (LD B,H)
	TESTCASE(" -- 54          ld d,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h54);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_a1d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_54

`ifdef TEST_ALL
`define TEST_DD54
`endif
`ifdef TEST_DD54
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 54 (LD B,IXH)
	TESTCASE(" -- dd 54       ld d,ixh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_1100_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h54);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_11d8_a169_0000_0000_0000_0000_1100_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD54

`ifdef TEST_ALL
`define TEST_FD54
`endif
`ifdef TEST_FD54
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 54 (LD B,IYH)
	TESTCASE(" -- fd 54       ld d,iyh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_1100_2200_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h54);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_22d8_a169_0000_0000_0000_0000_1100_2200_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD54

`ifdef TEST_ALL
`define TEST_55
`endif
`ifdef TEST_55
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 55 (LD D,L)
	TESTCASE(" -- 55          ld d,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h55); 
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_69d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_55

`ifdef TEST_ALL
`define TEST_DD55
`endif
`ifdef TEST_DD55
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 55 (LD D,IXL)
	TESTCASE(" -- dd 55       ld d,ixl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_00dd_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h55); 
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_ddd8_a169_0000_0000_0000_0000_00dd_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD55

`ifdef TEST_ALL
`define TEST_FD55
`endif
`ifdef TEST_FD55
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 55 (LD D,IYL)
	TESTCASE(" -- fd 55       ld d,iyl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_00dd_00fd_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h55); 
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_fdd8_a169_0000_0000_0000_0000_00dd_00fd_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD55

`ifdef TEST_ALL
`define TEST_56
`endif
`ifdef TEST_56
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 56 (LD D,(HL))
	TESTCASE(" -- 56          ld d,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h56); SETMEM(16'h0169, 8'haa);
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h0200_cf98_aad8_0169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_56

`ifdef TEST_ALL
`define TEST_DD56
`endif
`ifdef TEST_DD56
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 56 (LD D,(IX+d))
	TESTCASE(" -- dd 56       ld d,(ix+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_00dd_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h56); SETMEM(2, 8'h02); SETMEM(16'h00df, 8'haa);
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'h0200_cf98_aad8_0169_0000_0000_0000_0000_00dd_0000_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD56

`ifdef TEST_ALL
`define TEST_FD56
`endif
`ifdef TEST_FD56
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 56 (LD D,(IX+d))
	TESTCASE(" -- fd 56       ld d,(iy+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_00dd_00fd_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h56); SETMEM(2, 8'hff); SETMEM(16'h00fc, 8'haa);
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'h0200_cf98_aad8_0169_0000_0000_0000_0000_00dd_00fd_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD56

`ifdef TEST_ALL
`define TEST_57
`endif
`ifdef TEST_57
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 57 (LD D,A)
	TESTCASE(" -- 57          ld d,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h57);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_02d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_57

`ifdef TEST_ALL
`define TEST_DD57
`endif
`ifdef TEST_DD57
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 57 (LD D,A)
	TESTCASE(" -- dd 57       ld d,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h57);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_02d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD57

`ifdef TEST_ALL
`define TEST_FD57
`endif
`ifdef TEST_FD57
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 57 (LD D,A)
	TESTCASE(" -- fd 57       ld d,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h57);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_02d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD57

`ifdef TEST_ALL
`define TEST_58
`endif
`ifdef TEST_58
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 58 (LD E,B)
	TESTCASE(" -- 58          ld e,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h58);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_90cf_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_58

`ifdef TEST_ALL
`define TEST_DD58
`endif
`ifdef TEST_DD58
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 58 (LD E,B)
	TESTCASE(" -- dd 58       ld e,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h58);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90cf_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD58

`ifdef TEST_ALL
`define TEST_FD58
`endif
`ifdef TEST_FD58
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 58 (LD E,B)
	TESTCASE(" -- fd 58       ld e,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h58);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90cf_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD58

`ifdef TEST_ALL
`define TEST_59
`endif
`ifdef TEST_59
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 59 (LD E,C)
	TESTCASE(" -- 59          ld e,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h59);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_9098_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_59

`ifdef TEST_ALL
`define TEST_DD59
`endif
`ifdef TEST_DD59
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 59 (LD E,C)
	TESTCASE(" -- dd 59       ld e,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h59);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_9098_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD59

`ifdef TEST_ALL
`define TEST_FD59
`endif
`ifdef TEST_FD59
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 59 (LD E,C)
	TESTCASE(" -- fd 59       ld e,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h59);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_9098_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD59

`ifdef TEST_ALL
`define TEST_5A
`endif
`ifdef TEST_5A
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 5A (LD E,D)
	TESTCASE(" -- 5a          ld e,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h5a);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_9090_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_5A

`ifdef TEST_ALL
`define TEST_DD5A
`endif
`ifdef TEST_DD5A
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 5A (LD E,D)
	TESTCASE(" -- dd 5a       ld e,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h5a);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_9090_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD5A

`ifdef TEST_ALL
`define TEST_FD5A
`endif
`ifdef TEST_FD5A
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 5A (LD E,D)
	TESTCASE(" -- fd 5a       ld e,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h5a);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_9090_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD5A

`ifdef TEST_ALL
`define TEST_5B
`endif
`ifdef TEST_5B
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 5B (LD E,E)
	TESTCASE(" -- 5b          ld e,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h5b);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_5B

`ifdef TEST_ALL
`define TEST_DD5B
`endif
`ifdef TEST_DD5B
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 5B (LD E,E)
	TESTCASE(" -- dd 5b       ld e,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h5b);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD5B

`ifdef TEST_ALL
`define TEST_FD5B
`endif
`ifdef TEST_FD5B
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 5B (LD E,E)
	TESTCASE(" -- fd 5b       ld e,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h5b);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD5B

`ifdef TEST_ALL
`define TEST_5C
`endif
`ifdef TEST_5C
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 5C (LD E,H)
	TESTCASE(" -- 5c          ld e,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h5c);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_90a1_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_5C

`ifdef TEST_ALL
`define TEST_DD5C
`endif
`ifdef TEST_DD5C
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 5C (LD E,IXH)
	TESTCASE(" -- dd 5c       ld e,ixh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_1100_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h5c);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_9011_a169_0000_0000_0000_0000_1100_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD5C

`ifdef TEST_ALL
`define TEST_FD5C
`endif
`ifdef TEST_FD5C
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 5C (LD E,IXH)
	TESTCASE(" -- fd 5c       ld e,iyh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_1100_2200_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h5c);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_9022_a169_0000_0000_0000_0000_1100_2200_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD5C

`ifdef TEST_ALL
`define TEST_5D
`endif
`ifdef TEST_5D
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 5D (LD E,L)
	TESTCASE(" -- 5D          ld e,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h5d);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_9069_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_5D

`ifdef TEST_ALL
`define TEST_DD5D
`endif
`ifdef TEST_DD5D
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 5D (LD E,IXL)
	TESTCASE(" -- dd 5D       ld e,ixl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_00dd_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h5d);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90dd_a169_0000_0000_0000_0000_00dd_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD5D

`ifdef TEST_ALL
`define TEST_FD5D
`endif
`ifdef TEST_FD5D
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 5D (LD E,IYL)
	TESTCASE(" -- fd 5D       ld e,iyl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_00dd_00fd_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h5d);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90fd_a169_0000_0000_0000_0000_00dd_00fd_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD5D

`ifdef TEST_ALL
`define TEST_5E
`endif
`ifdef TEST_5E
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 5E (LD E,(HL))
	TESTCASE(" -- 5e          ld e,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h5e); SETMEM(16'h0169, 8'h55);
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h0200_cf98_9055_0169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_5E	

`ifdef TEST_ALL
`define TEST_DD5E
`endif
`ifdef TEST_DD5E
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 5E (LD E,(IX+d))
	TESTCASE(" -- dd 5e       ld e,(ix+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0169_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h5e); SETMEM(2, 8'h00); SETMEM(16'h0169, 8'h55);
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'h0200_cf98_9055_0169_0000_0000_0000_0000_0169_0000_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD5E	

`ifdef TEST_ALL
`define TEST_FD5E
`endif
`ifdef TEST_FD5E
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 5E (LD E,(IY+d))
	TESTCASE(" -- fd 5e       ld e,(iy+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0169_0068_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h5e); SETMEM(2, 8'h00); SETMEM(16'h0068, 8'h55);
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'h0200_cf98_9055_0169_0000_0000_0000_0000_0169_0068_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD5E	

`ifdef TEST_ALL
`define TEST_5F
`endif
`ifdef TEST_5F
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 5F (LD E,A)
	TESTCASE(" -- 5f          ld e,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h5f);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_9002_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_5F	

`ifdef TEST_ALL
`define TEST_DD5F
`endif
`ifdef TEST_DD5F
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 5F (LD E,A)
	TESTCASE(" -- dd 5f       ld e,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h5f);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_9002_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD5F	

`ifdef TEST_ALL
`define TEST_FD5F
`endif
`ifdef TEST_FD5F
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 5F (LD E,A)
	TESTCASE(" -- fd 5f       ld e,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h5f);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_9002_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD5F	

`ifdef TEST_ALL
`define TEST_60
`endif
`ifdef TEST_60
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 60 (LD H,B)
	TESTCASE(" -- 60          ld h,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h60);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_90d8_cf69_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_60

`ifdef TEST_ALL
`define TEST_DD60
`endif
`ifdef TEST_DD60
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 60 (LD IXH,B)
	TESTCASE(" -- dd 60       ld ixh,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h60);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_cf00_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD60

`ifdef TEST_ALL
`define TEST_FD60
`endif
`ifdef TEST_FD60
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 60 (LD IYH,B)
	TESTCASE(" -- fd 60       ld iyh,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h60);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_cf00_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD60

`ifdef TEST_ALL
`define TEST_61
`endif
`ifdef TEST_61
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 61 (LD H,C)
	TESTCASE(" -- 61          ld h,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h61);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_90d8_9869_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_61

`ifdef TEST_ALL
`define TEST_DD61
`endif
`ifdef TEST_DD61
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 61 (LD IXH,C)
	TESTCASE(" -- dd 61       ld ixh,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h61);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_9800_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD61

`ifdef TEST_ALL
`define TEST_FD61
`endif
`ifdef TEST_FD61
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 61 (LD IYH,C)
	TESTCASE(" -- fd 61       ld iyh,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h61);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_9800_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD61

`ifdef TEST_ALL
`define TEST_62
`endif
`ifdef TEST_62
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 62 (LD H,D)
	TESTCASE(" -- 62          ld h,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h62);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_90d8_9069_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_62

`ifdef TEST_ALL
`define TEST_DD62
`endif
`ifdef TEST_DD62
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 62 (LD IXH,D)
	TESTCASE(" -- dd 62       ld ixh,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h62);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_9000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD62

`ifdef TEST_ALL
`define TEST_FD62
`endif
`ifdef TEST_FD62
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 62 (LD IYH,D)
	TESTCASE(" -- fd 62       ld iyh,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h62);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_9000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD62

`ifdef TEST_ALL
`define TEST_63
`endif
`ifdef TEST_63
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 63 (LD H,E)
	TESTCASE(" -- 63          ld h,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h63);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_90d8_d869_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_63

`ifdef TEST_ALL
`define TEST_DD63
`endif
`ifdef TEST_DD63
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 63 (LD IXH,E)
	TESTCASE(" -- dd 63       ld ixh,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h63);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_d800_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD63

`ifdef TEST_ALL
`define TEST_FD63
`endif
`ifdef TEST_FD63
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 63 (LD IYH,E)
	TESTCASE(" -- fd 63       ld iyh,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h63);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_d800_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD63

`ifdef TEST_ALL
`define TEST_64
`endif
`ifdef TEST_64
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 64 (LD H,H)
	TESTCASE(" -- 64          ld h,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h64);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_64

`ifdef TEST_ALL
`define TEST_DD64
`endif
`ifdef TEST_DD64
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 64 (LD IXH,IXH)
	TESTCASE(" -- dd 64       ld ixh,ixh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_1234_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h64);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_1234_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD64

`ifdef TEST_ALL
`define TEST_FD64
`endif
`ifdef TEST_FD64
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 64 (LD IYH,IYH)
	TESTCASE(" -- fd 64       ld iyh,iyh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_5678_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h64);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_5678_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD64

`ifdef TEST_ALL
`define TEST_65
`endif
`ifdef TEST_65
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 65 (LD H,L)
	TESTCASE(" -- 65          ld h,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h65); 
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_90d8_6969_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_65

`ifdef TEST_ALL
`define TEST_DD65
`endif
`ifdef TEST_DD65
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 65 (LD IXH,IXL)
	TESTCASE(" -- dd 65       ld ixh,ixl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_1234_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h65);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_3434_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD65

`ifdef TEST_ALL
`define TEST_FD65
`endif
`ifdef TEST_FD65
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 65 (LD IYH,IYL)
	TESTCASE(" -- fd 65       ld iyh,iyl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_5678_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h65);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_7878_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD65

`ifdef TEST_ALL
`define TEST_66
`endif
`ifdef TEST_66
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 66 (LD H,(HL))
	TESTCASE(" -- 66          ld h,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h66); SETMEM(16'h0169, 8'h11);
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h0200_cf98_90d8_1169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_66

`ifdef TEST_ALL
`define TEST_DD66
`endif
`ifdef TEST_DD66
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 66 (LD H,(IX+d))
	TESTCASE(" -- dd 66       ld h,(ix+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_1234_0000_0000_0000_0000_0169_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h66); SETMEM(2, 8'h00); SETMEM(16'h0169, 8'h55);
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'h0200_cf98_90d8_5534_0000_0000_0000_0000_0169_0000_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD66

`ifdef TEST_ALL
`define TEST_FD66
`endif
`ifdef TEST_FD66
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 66 (LD H,(IY+d))
	TESTCASE(" -- fd 66       ld h,(iy+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_1234_0000_0000_0000_0000_0000_0168_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h66); SETMEM(2, 8'h01); SETMEM(16'h0169, 8'haa);
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'h0200_cf98_90d8_aa34_0000_0000_0000_0000_0000_0168_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD66

`ifdef TEST_ALL
`define TEST_67
`endif
`ifdef TEST_67
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 67 (LD D,A)
	TESTCASE(" -- 67          ld h,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h67);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h2200_cf98_90d8_2269_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_67

`ifdef TEST_ALL
`define TEST_DD67
`endif
`ifdef TEST_DD67
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 67 (LD IXH,A)
	TESTCASE(" -- DD 67       ld ixh,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h67);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h2200_cf98_90d8_a169_0000_0000_0000_0000_2200_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD67

`ifdef TEST_ALL
`define TEST_FD67
`endif
`ifdef TEST_FD67
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 67 (LD IYH,A)
	TESTCASE(" -- fd 67       ld iyh,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h67);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h2200_cf98_90d8_a169_0000_0000_0000_0000_0000_2200_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD67

`ifdef TEST_ALL
`define TEST_68
`endif
`ifdef TEST_68
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 68 (LD L,B)
	TESTCASE(" -- 68          ld l,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h68);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_90d8_a1cf_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_68

`ifdef TEST_ALL
`define TEST_DD68
`endif
`ifdef TEST_DD68
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 68 (LD IXL,B)
	TESTCASE(" -- dd 68       ld ixl,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h68);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_00cf_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD68

`ifdef TEST_ALL
`define TEST_FD68
`endif
`ifdef TEST_FD68
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 68 (LD IYL,B)
	TESTCASE(" -- fd 68       ld iyl,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h68);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_00cf_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD68

`ifdef TEST_ALL
`define TEST_69
`endif
`ifdef TEST_69
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 69 (LD L,C)
	TESTCASE(" -- 69          ld l,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h69);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_90d8_a198_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_69

`ifdef TEST_ALL
`define TEST_DD69
`endif
`ifdef TEST_DD69
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 69 (LD IXL,C)
	TESTCASE(" -- dd 69       ld ixl,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h69);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0098_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD69

`ifdef TEST_ALL
`define TEST_FD69
`endif
`ifdef TEST_FD69
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 69 (LD IYL,C)
	TESTCASE(" -- fd 69       ld iyl,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h69);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0098_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD69

`ifdef TEST_ALL
`define TEST_6A
`endif
`ifdef TEST_6A
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 6A (LD L,D)
	TESTCASE(" -- 6a          ld l,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h6a);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_90d8_a190_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_6A

`ifdef TEST_ALL
`define TEST_DD6A
`endif
`ifdef TEST_DD6A
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 6A (LD IXL,D)
	TESTCASE(" -- dd 6a       ld ixl,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h6a);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0090_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD6A

`ifdef TEST_ALL
`define TEST_FD6A
`endif
`ifdef TEST_FD6A
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 6A (LD IYL,D)
	TESTCASE(" -- fd 6a       ld iyl,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h6a);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0090_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD6A

`ifdef TEST_ALL
`define TEST_6B
`endif
`ifdef TEST_6B
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 6B (LD L,E)
	TESTCASE(" -- 6b          ld l,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h6b);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_90d8_a1d8_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_6B

`ifdef TEST_ALL
`define TEST_DD6B
`endif
`ifdef TEST_DD6B
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 6B (LD IXL,E)
	TESTCASE(" -- dd 6b       ld ixl,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h6b);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_00d8_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD6B

`ifdef TEST_ALL
`define TEST_FD6B
`endif
`ifdef TEST_FD6B
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 6B (LD IYL,E)
	TESTCASE(" -- fd 6b       ld iyl,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h6b);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_00d8_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD6B

`ifdef TEST_ALL
`define TEST_6C
`endif
`ifdef TEST_6C
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 6C (LD L,H)
	TESTCASE(" -- 6c          ld l,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h6c);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_90d8_a1a1_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_6C

`ifdef TEST_ALL
`define TEST_DD6C
`endif
`ifdef TEST_DD6C
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 6C (LD IXL,IXH)
	TESTCASE(" -- dd 6c       ld ixl,ixh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_1234_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h6c);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_1212_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD6C

`ifdef TEST_ALL
`define TEST_FD6C
`endif
`ifdef TEST_FD6C
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 6C (LD IYL,IYH)
	TESTCASE(" -- fd 6c       ld iyl,iyh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_5678_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h6c);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_5656_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD6C

`ifdef TEST_ALL
`define TEST_6D
`endif
`ifdef TEST_6D
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 6D (LD L,L)
	TESTCASE(" -- 6D          ld l,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h6d);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_6D

`ifdef TEST_ALL
`define TEST_DD6D
`endif
`ifdef TEST_DD6D
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 6D (LD IXL,IXL)
	TESTCASE(" -- dd 6d       ld ixl,ixl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_1234_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h6d);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_1234_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD6D

`ifdef TEST_ALL
`define TEST_FD6D
`endif
`ifdef TEST_FD6D
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 6D (LD IYL,IYL)
	TESTCASE(" -- fd 6d       ld iyl,iyl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_5678_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h6d);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_5678_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD6D

`ifdef TEST_ALL
`define TEST_6E
`endif
`ifdef TEST_6E
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 6E (LD L,(HL))
	TESTCASE(" -- 6e          ld l,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h6e); SETMEM(16'h0169, 8'h33);
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h0200_cf98_90d8_0133_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_6E

`ifdef TEST_ALL
`define TEST_DD6E
`endif
`ifdef TEST_DD6E
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 6E (LD L,(IX+d))
	TESTCASE(" -- dd 6e       ld l,(ix+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_01dd_0000_0000_0000_0000_0160_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h6e); SETMEM(2, 8'h09); SETMEM(16'h0169, 8'h33);
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'h0200_cf98_90d8_0133_0000_0000_0000_0000_0160_0000_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD6E

`ifdef TEST_ALL
`define TEST_FD6E
`endif
`ifdef TEST_FD6E
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 6E (LD L,(IY+d))
	TESTCASE(" -- fd 6e       ld l,(iy+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_01dd_0000_0000_0000_0000_0000_0160_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h6e); SETMEM(2, 8'h09); SETMEM(16'h0169, 8'h33);
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'h0200_cf98_90d8_0133_0000_0000_0000_0000_0000_0160_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD6E

`ifdef TEST_ALL
`define TEST_6F
`endif
`ifdef TEST_6F
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 6F (LD L,A)
	TESTCASE(" -- 6f          ld l,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h6f);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_90d8_a102_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_6F

`ifdef TEST_ALL
`define TEST_DD6F
`endif
`ifdef TEST_DD6F
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 6F (LD IXL,A)
	TESTCASE(" -- dd 6f       ld ixl,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h6f);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0002_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD6F

`ifdef TEST_ALL
`define TEST_FD6F
`endif
`ifdef TEST_FD6F
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 6F (LD IYL,A)
	TESTCASE(" -- fd 6f       ld iyl,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h6f);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0002_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD6F

`ifdef TEST_ALL
`define TEST_70
`endif
`ifdef TEST_70
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 70 (LD (HL),B)
	TESTCASE(" -- 70          ld (hl),b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h70); SETMEM(16'h0169, 8'ha5);
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERTMEM(16'h0169, 8'hcf);
	ASSERT(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_70

`ifdef TEST_ALL
`define TEST_DD70
`endif
`ifdef TEST_DD70
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 70 (LD (IX+d),B)
	TESTCASE(" -- dd 70       ld (ix+d),b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0168_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h70); SETMEM(2, 8'h01); SETMEM(16'h0169, 8'ha5);
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERTMEM(16'h0169, 8'hcf);
	ASSERT(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0168_0000_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD70

`ifdef TEST_ALL
`define TEST_FD70
`endif
`ifdef TEST_FD70
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 70 (LD (IY+d),B)
	TESTCASE(" -- fd 70       ld (iy+d),b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_00fd_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h70); SETMEM(2, 8'h03); SETMEM(16'h0100, 8'ha5);
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERTMEM(16'h0100, 8'hcf);
	ASSERT(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_00fd_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD70

`ifdef TEST_ALL
`define TEST_71
`endif
`ifdef TEST_71
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 71 (LD (HL),C)
	TESTCASE(" -- 71          ld (hl),c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h71); SETMEM(16'h0169, 8'ha5);
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERTMEM(16'h0169, 8'h98);
	ASSERT(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_71

`ifdef TEST_ALL
`define TEST_DD71
`endif
`ifdef TEST_DD71
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 71 (LD (IX+d),C)
	TESTCASE(" -- dd 71       ld (ix+d),c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0168_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h71); SETMEM(2, 8'h01); SETMEM(16'h0169, 8'ha5);
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERTMEM(16'h0169, 8'h98);
	ASSERT(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0168_0000_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD71

`ifdef TEST_ALL
`define TEST_FD71
`endif
`ifdef TEST_FD71
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 71 (LD (IY+d),C)
	TESTCASE(" -- fd 71       ld (iy+d),c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_00fd_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h71); SETMEM(2, 8'h03); SETMEM(16'h0100, 8'ha5);
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERTMEM(16'h0100, 8'h98);
	ASSERT(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_00fd_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD71

`ifdef TEST_ALL
`define TEST_72
`endif
`ifdef TEST_72
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 72 (LD (HL),D)
	TESTCASE(" -- 72          ld (hl),d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h72); SETMEM(16'h0169, 8'ha5);
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERTMEM(16'h0169, 8'h90);
	ASSERT(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_72

`ifdef TEST_ALL
`define TEST_DD72
`endif
`ifdef TEST_DD72
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 72 (LD (IX+d),D)
	TESTCASE(" -- dd 72       ld (ix+d),d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0168_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h72); SETMEM(2, 8'h01); SETMEM(16'h0169, 8'ha5);
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERTMEM(16'h0169, 8'h90);
	ASSERT(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0168_0000_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD72

`ifdef TEST_ALL
`define TEST_FD72
`endif
`ifdef TEST_FD72
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 72 (LD (IY+d),D)
	TESTCASE(" -- fd 72       ld (iy+d),d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_00fd_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h72); SETMEM(2, 8'h03); SETMEM(16'h0100, 8'ha5);
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERTMEM(16'h0100, 8'h90);
	ASSERT(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_00fd_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD72

`ifdef TEST_ALL
`define TEST_73
`endif
`ifdef TEST_73
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 73 (LD (HL),E)
	TESTCASE(" -- 73          ld (hl),e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h73); SETMEM(16'h0169, 8'ha5);
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERTMEM(16'h0169, 8'hd8);
	ASSERT(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_73

`ifdef TEST_ALL
`define TEST_DD73
`endif
`ifdef TEST_DD73
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 73 (LD (IX+d),eB)
	TESTCASE(" -- dd 73       ld (ix+d),e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0168_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h73); SETMEM(2, 8'h01); SETMEM(16'h0169, 8'ha5);
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERTMEM(16'h0169, 8'hd8);
	ASSERT(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0168_0000_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD73

`ifdef TEST_ALL
`define TEST_FD73
`endif
`ifdef TEST_FD73
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 73 (LD (IY+d),E)
	TESTCASE(" -- fd 73       ld (iy+d),e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_00fd_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h73); SETMEM(2, 8'h03); SETMEM(16'h0100, 8'ha5);
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERTMEM(16'h0100, 8'hd8);
	ASSERT(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_00fd_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD73

`ifdef TEST_ALL
`define TEST_74
`endif
`ifdef TEST_74
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 74 (LD (HL),H)
	TESTCASE(" -- 74          ld (hl),h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h74); SETMEM(16'h0169, 8'ha5);
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERTMEM(16'h0169, 8'h01);
	ASSERT(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_74

`ifdef TEST_ALL
`define TEST_DD74
`endif
`ifdef TEST_DD74
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 74 (LD (IX+d),H)
	TESTCASE(" -- dd 74       ld (ix+d),h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0168_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h74); SETMEM(2, 8'h01); SETMEM(16'h0169, 8'ha5);
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERTMEM(16'h0169, 8'h01);
	ASSERT(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0168_0000_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD74

`ifdef TEST_ALL
`define TEST_FD74
`endif
`ifdef TEST_FD74
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 74 (LD (IY+d),H)
	TESTCASE(" -- fd 74       ld (iy+d),h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_00fd_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h74); SETMEM(2, 8'h03); SETMEM(16'h0100, 8'ha5);
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERTMEM(16'h0100, 8'h01);
	ASSERT(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_00fd_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD74

`ifdef TEST_ALL
`define TEST_75
`endif
`ifdef TEST_75
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 75 (LD (HL),L)
	TESTCASE(" -- 75          ld (hl),l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h75); SETMEM(16'h0169, 8'ha5);
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERTMEM(16'h0169, 8'h69);
	ASSERT(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_75

`ifdef TEST_ALL
`define TEST_DD75
`endif
`ifdef TEST_DD75
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 75 (LD (IX+d),L)
	TESTCASE(" -- dd 75       ld (ix+d),l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0168_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h75); SETMEM(2, 8'h01); SETMEM(16'h0169, 8'ha5);
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERTMEM(16'h0169, 8'h69);
	ASSERT(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0168_0000_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD75

`ifdef TEST_ALL
`define TEST_FD75
`endif
`ifdef TEST_FD75
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 75 (LD (IY+d),L)
	TESTCASE(" -- fd 75       ld (iy+d),l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_00fd_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h75); SETMEM(2, 8'h03); SETMEM(16'h0100, 8'ha5);
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERTMEM(16'h0100, 8'h69);
	ASSERT(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_00fd_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD75

`ifdef TEST_ALL
`define TEST_76
`endif
`ifdef TEST_76
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 76 (HALT)
	TESTCASE(" -- 76          halt");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h76); SETMEM(16'h0169, 8'h11);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
	if (cpu.core.Halt_FF != 1'b1) $display("* FAIL *: [HALT] expected=1, actual=0");
`endif // TEST_76

`ifdef TEST_ALL
`define TEST_DD76
`endif
`ifdef TEST_DD76
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 76 (HALT)
	TESTCASE(" -- dd 76       halt");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h76); SETMEM(16'h0169, 8'h11);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
	if (cpu.core.Halt_FF != 1'b1) $display("* FAIL *: [HALT] expected=1, actual=0");
`endif // TEST_DD76

`ifdef TEST_ALL
`define TEST_FD76
`endif
`ifdef TEST_FD76
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 76 (HALT)
	TESTCASE(" -- fd 76       halt");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h76); SETMEM(16'h0169, 8'h11);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
	if (cpu.core.Halt_FF != 1'b1) $display("* FAIL *: [HALT] expected=1, actual=0");
`endif // TEST_FD76

`ifdef TEST_ALL
`define TEST_77
`endif
`ifdef TEST_77
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 77 (LD (HL),A)
	TESTCASE(" -- 77          ld (hl),a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h77); SETMEM(16'h0169, 8'ha5);
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERTMEM(16'h0169, 8'h02);
	ASSERT(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_77

`ifdef TEST_ALL
`define TEST_DD77
`endif
`ifdef TEST_DD77
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 77 (LD (IX+d),A)
	TESTCASE(" -- dd 77       ld (ix+d),a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0168_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h77); SETMEM(2, 8'h01); SETMEM(16'h0169, 8'ha5);
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERTMEM(16'h0169, 8'h02);
	ASSERT(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0168_0000_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD77

`ifdef TEST_ALL
`define TEST_FD77
`endif
`ifdef TEST_FD77
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 77 (LD (IY+d),A)
	TESTCASE(" -- fd 77       ld (iy+d),a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_00fd_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h77); SETMEM(2, 8'h03); SETMEM(16'h0100, 8'ha5);
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERTMEM(16'h0100, 8'h02);
	ASSERT(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_00fd_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD77

`ifdef TEST_ALL
`define TEST_78
`endif
`ifdef TEST_78
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 78 (LD A,B)
	TESTCASE(" -- 78          ld a,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h78);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hcf00_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_78

`ifdef TEST_ALL
`define TEST_DD78
`endif
`ifdef TEST_DD78
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 78 (LD A,B)
	TESTCASE(" -- dd 78       ld a,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h78);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hcf00_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD78

`ifdef TEST_ALL
`define TEST_FD78
`endif
`ifdef TEST_FD78
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 78 (LD A,B)
	TESTCASE(" -- fd 78       ld a,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h78);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hcf00_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD78

`ifdef TEST_ALL
`define TEST_79
`endif
`ifdef TEST_79
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 79 (LD A,C)
	TESTCASE(" -- 79          ld a,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h79);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h9800_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_79

`ifdef TEST_ALL
`define TEST_DD79
`endif
`ifdef TEST_DD79
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 79 (LD A,C)
	TESTCASE(" -- dd 79       ld a,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h79);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9800_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD79

`ifdef TEST_ALL
`define TEST_FD79
`endif
`ifdef TEST_FD79
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 79 (LD A,C)
	TESTCASE(" -- fd 79       ld a,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h79);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9800_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD79

`ifdef TEST_ALL
`define TEST_7A
`endif
`ifdef TEST_7A
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 7A (LD A,D)
	TESTCASE(" -- 7a          ld a,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h7a);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h9000_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_7A

`ifdef TEST_ALL
`define TEST_DD7A
`endif
`ifdef TEST_DD7A
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 7A (LD A,D)
	TESTCASE(" -- dd 7a       ld a,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h7a);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9000_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD7A

`ifdef TEST_ALL
`define TEST_FD7A
`endif
`ifdef TEST_FD7A
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 7A (LD A,D)
	TESTCASE(" -- fd 7a       ld a,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h7a);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9000_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD7A

`ifdef TEST_ALL
`define TEST_7B
`endif
`ifdef TEST_7B
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 7B (LD A,E)
	TESTCASE(" -- 7b          ld a,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h7b);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hd800_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_7B

`ifdef TEST_ALL
`define TEST_DD7B
`endif
`ifdef TEST_DD7B
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 7B (LD A,E)
	TESTCASE(" -- dd 7b       ld a,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h7b);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hd800_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD7B

`ifdef TEST_ALL
`define TEST_FD7B
`endif
`ifdef TEST_FD7B
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 7B (LD A,E)
	TESTCASE(" -- fd 7b       ld a,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h7b);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hd800_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD7B

`ifdef TEST_ALL
`define TEST_7C
`endif
`ifdef TEST_7C
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 7C (LD A,H)
	TESTCASE(" -- 7c          ld a,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h7c);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'ha100_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_7C

`ifdef TEST_ALL
`define TEST_DD7C
`endif
`ifdef TEST_DD7C
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 7C (LD A,IXH)
	TESTCASE(" -- dd 7c       ld a,ixh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_1234_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h7c);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h1200_cf98_90d8_a169_0000_0000_0000_0000_1234_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD7C

`ifdef TEST_ALL
`define TEST_FD7C
`endif
`ifdef TEST_FD7C
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 7C (LD A,IYH)
	TESTCASE(" -- fd 7c       ld a,iyh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_1234_5678_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h7c);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h5600_cf98_90d8_a169_0000_0000_0000_0000_1234_5678_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD7C

`ifdef TEST_ALL
`define TEST_7D
`endif
`ifdef TEST_7D
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 7D (LD A,L)
	TESTCASE(" -- 7D          ld a,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h7d);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h6900_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_7D

`ifdef TEST_ALL
`define TEST_DD7D
`endif
`ifdef TEST_DD7D
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 7D (LD A,IXL)
	TESTCASE(" -- dd 7d       ld a,ixl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_1234_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h7d);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h3400_cf98_90d8_a169_0000_0000_0000_0000_1234_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD7D

`ifdef TEST_ALL
`define TEST_FD7D
`endif
`ifdef TEST_FD7D
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 7D (LD A,IYL)
	TESTCASE(" -- fd 7d       ld a,iyl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_1234_5678_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h7d);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h7800_cf98_90d8_a169_0000_0000_0000_0000_1234_5678_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD7D

`ifdef TEST_ALL
`define TEST_7E
`endif
`ifdef TEST_7E
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 7E (LD A,(HL))
	TESTCASE(" -- 7e          ld a,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h7e); SETMEM(16'h0169, 8'h33);
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h3300_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_7E

`ifdef TEST_ALL
`define TEST_DD7E
`endif
`ifdef TEST_DD7E
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 7E (LD A,(IX+d))
	TESTCASE(" -- dd 7e       ld a,(ix+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0123_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h7e); SETMEM(2, 8'h40); SETMEM(16'h0163, 8'h33);
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'h3300_cf98_90d8_0169_0000_0000_0000_0000_0123_0000_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD7E

`ifdef TEST_ALL
`define TEST_FD7E
`endif
`ifdef TEST_FD7E
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 7E (LD A,(IY+d))
	TESTCASE(" -- fd 7e       ld a,(iy+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0123_0100_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h7e); SETMEM(2, 8'h63); SETMEM(16'h0163, 8'h44);
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'h4400_cf98_90d8_0169_0000_0000_0000_0000_0123_0100_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD7E

`ifdef TEST_ALL
`define TEST_7F
`endif
`ifdef TEST_7F
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 7F (LD A,A)
	TESTCASE(" -- 7f          ld a,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h7f);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_7F

`ifdef TEST_ALL
`define TEST_DD7F
`endif
`ifdef TEST_DD7F
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 7F (LD A,A)
	TESTCASE(" -- dd 7f       ld a,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h7f);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD7F

`ifdef TEST_ALL
`define TEST_FD7F
`endif
`ifdef TEST_FD7F
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 7F (LD A,A)
	TESTCASE(" -- fd 7f       ld a,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h7f);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD7F

`ifdef TEST_ALL
`define TEST_80
`endif
`ifdef TEST_80
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 80 (ADD A,B)
	TESTCASE(" -- 80          add a,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h80);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0411_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_80

`ifdef TEST_ALL
`define TEST_DD80
`endif
`ifdef TEST_DD80
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 80 (ADD A,B)
	TESTCASE(" -- dd 80       add a,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h80);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0411_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD80

`ifdef TEST_ALL
`define TEST_FD80
`endif
`ifdef TEST_FD80
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 80 (ADD A,B)
	TESTCASE(" -- fd 80       add a,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h80);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0411_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD80

`ifdef TEST_ALL
`define TEST_81
`endif
`ifdef TEST_81
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 81 (ADD A,C)
	TESTCASE(" -- 81          add a,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h81);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h3031_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_81

`ifdef TEST_ALL
`define TEST_DD81
`endif
`ifdef TEST_DD81
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 81 (ADD A,C)
	TESTCASE(" -- dd 81       add a,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h81);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h3031_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD81

`ifdef TEST_ALL
`define TEST_FD81
`endif
`ifdef TEST_FD81
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 81 (ADD A,C)
	TESTCASE(" -- fd 81       add a,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h81);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h3031_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD81

`ifdef TEST_ALL
`define TEST_82
`endif
`ifdef TEST_82
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 82 (ADD A,D)
	TESTCASE(" -- 82          add a,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h82);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h1501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_82

`ifdef TEST_ALL
`define TEST_DD82
`endif
`ifdef TEST_DD82
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 82 (ADD A,D)
	TESTCASE(" -- dd 82       add a,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h82);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h1501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD82

`ifdef TEST_ALL
`define TEST_FD82
`endif
`ifdef TEST_FD82
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 82 (ADD A,D)
	TESTCASE(" -- fd 82       add a,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h82);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h1501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD82

`ifdef TEST_ALL
`define TEST_83
`endif
`ifdef TEST_83
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 83 (ADD A,E)
	TESTCASE(" -- 83          add a,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h83);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0211_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_83

`ifdef TEST_ALL
`define TEST_DD83
`endif
`ifdef TEST_DD83
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 83 (ADD A,E)
	TESTCASE(" -- dd 83       add a,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h83);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0211_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD83

`ifdef TEST_ALL
`define TEST_FD83
`endif
`ifdef TEST_FD83
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 83 (ADD A,E)
	TESTCASE(" -- fd 83       add a,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h83);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0211_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD83

`ifdef TEST_ALL
`define TEST_84
`endif
`ifdef TEST_84
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 84 (ADD A,H)
	TESTCASE(" -- 84          add a,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h84);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hd191_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_84

`ifdef TEST_ALL
`define TEST_DD84
`endif
`ifdef TEST_DD84
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 84 (ADD A,IXH)
	TESTCASE(" -- dd 84       add a,ixh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_1234_0000_0000_0000_0000_dca6_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h84);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hd191_0f3b_200d_1234_0000_0000_0000_0000_dca6_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD84

`ifdef TEST_ALL
`define TEST_FD84
`endif
`ifdef TEST_FD84
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 84 (ADD A,IYH)
	TESTCASE(" -- fd 84       add a,iyh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_1234_0000_0000_0000_0000_0000_dca6_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h84);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hd191_0f3b_200d_1234_0000_0000_0000_0000_0000_dca6_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD84

`ifdef TEST_ALL
`define TEST_85
`endif
`ifdef TEST_85
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 85 (ADD A,L)
	TESTCASE(" -- 85          add a,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h85);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h9b89_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_85

`ifdef TEST_ALL
`define TEST_DD85
`endif
`ifdef TEST_DD85
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 85 (ADD A,IXL)
	TESTCASE(" -- dd 85       add a,ixl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_1234_0000_0000_0000_0000_dca6_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h85);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9b89_0f3b_200d_1234_0000_0000_0000_0000_dca6_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD85

`ifdef TEST_ALL
`define TEST_FD85
`endif
`ifdef TEST_FD85
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 85 (ADD A,IXL)
	TESTCASE(" -- fd 85       add a,iyl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_1234_0000_0000_0000_0000_0000_dca6_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h85);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9b89_0f3b_200d_1234_0000_0000_0000_0000_0000_dca6_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD85

`ifdef TEST_ALL
`define TEST_86
`endif
`ifdef TEST_86
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 86 (ADD A,(HL))
	TESTCASE(" -- 86          add a,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h86); SETMEM(16'h0169, 8'h49);
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h3e29_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_86

`ifdef TEST_ALL
`define TEST_DD86
`endif
`ifdef TEST_DD86
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 86 (ADD A,(IX+d))
	TESTCASE(" -- dd 86       add a,(ix+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_cf98_90d8_0169_0000_0000_0000_0000_0160_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h86); SETMEM(2, 8'h09); SETMEM(16'h0169, 8'h49);
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'h3e29_cf98_90d8_0169_0000_0000_0000_0000_0160_0000_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD86

`ifdef TEST_ALL
`define TEST_FD86
`endif
`ifdef TEST_FD86
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 86 (ADD A,(IX+d))
	TESTCASE(" -- fd 86       add a,(iy+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_cf98_90d8_0169_0000_0000_0000_0000_0000_0160_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h86); SETMEM(2, 8'h09); SETMEM(16'h0169, 8'h49);
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'h3e29_cf98_90d8_0169_0000_0000_0000_0000_0000_0160_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD86

`ifdef TEST_ALL
`define TEST_87
`endif
`ifdef TEST_87
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 87 (ADD A,A)
	TESTCASE(" -- 87          add a,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h87);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'heaa9_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_87

`ifdef TEST_ALL
`define TEST_DD87
`endif
`ifdef TEST_DD87
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 87 (ADD A,A)
	TESTCASE(" -- dd 87       add a,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h87);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'heaa9_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD87

`ifdef TEST_ALL
`define TEST_FD87
`endif
`ifdef TEST_FD87
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 87 (ADD A,A)
	TESTCASE(" -- fd 87       add a,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h87);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'heaa9_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD87

`ifdef TEST_ALL
`define TEST_88
`endif
`ifdef TEST_88
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 88 (ADC A,B)
	TESTCASE(" -- 88          adc a,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h88);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0411_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_88

`ifdef TEST_ALL
`define TEST_DD88
`endif
`ifdef TEST_DD88
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 88 (ADC A,B)
	TESTCASE(" -- dd 88       adc a,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h88);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0411_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD88

`ifdef TEST_ALL
`define TEST_FD88
`endif
`ifdef TEST_FD88
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 88 (ADC A,B)
	TESTCASE(" -- fd 88       adc a,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h88);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0411_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD88

`ifdef TEST_ALL
`define TEST_89
`endif
`ifdef TEST_89
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 89 (ADC A,C)
	TESTCASE(" -- 89          adc a,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h89);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h3031_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_89

`ifdef TEST_ALL
`define TEST_DD89
`endif
`ifdef TEST_DD89
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 89 (ADC A,C)
	TESTCASE(" -- dd 89       adc a,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h89);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h3031_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD89

`ifdef TEST_ALL
`define TEST_FD89
`endif
`ifdef TEST_FD89
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 89 (ADC A,C)
	TESTCASE(" -- fd 89       adc a,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h89);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h3031_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD89

`ifdef TEST_ALL
`define TEST_8A
`endif
`ifdef TEST_8A
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 8A (ADC A,D)
	TESTCASE(" -- 8a          adc a,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h8a);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h1501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_8A

`ifdef TEST_ALL
`define TEST_DD8A
`endif
`ifdef TEST_DD8A
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 8A (ADC A,D)
	TESTCASE(" -- dd 8a       adc a,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h8a);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h1501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD8A

`ifdef TEST_ALL
`define TEST_FD8A
`endif
`ifdef TEST_FD8A
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 8A (ADC A,D)
	TESTCASE(" -- fd 8a       adc a,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h8a);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h1501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD8A

`ifdef TEST_ALL
`define TEST_8B
`endif
`ifdef TEST_8B
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 8B (ADC A,E)
	TESTCASE(" -- 8b          adc a,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h8b);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0211_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_8B

`ifdef TEST_ALL
`define TEST_DD8B
`endif
`ifdef TEST_DD8B
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 8B (ADC A,E)
	TESTCASE(" -- dd 8b       adc a,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h8b);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0211_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD8B

`ifdef TEST_ALL
`define TEST_FD8B
`endif
`ifdef TEST_FD8B
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 8B (ADC A,E)
	TESTCASE(" -- fd 8b       adc a,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h8b);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0211_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD8B

`ifdef TEST_ALL
`define TEST_8C
`endif
`ifdef TEST_8C
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 8C (ADC A,H)
	TESTCASE(" -- 8c          adc a,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h8c);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hd191_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_8C

`ifdef TEST_ALL
`define TEST_DD8C
`endif
`ifdef TEST_DD8C
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 8C (ADC A,IXH)
	TESTCASE(" -- dd 8c       adc a,ixh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_1234_0000_0000_0000_0000_dca6_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h8c);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hd191_0f3b_200d_1234_0000_0000_0000_0000_dca6_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD8C

`ifdef TEST_ALL
`define TEST_FD8C
`endif
`ifdef TEST_FD8C
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 8C (ADC A,IYH)
	TESTCASE(" -- fd 8c       adc a,iyh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_1234_0000_0000_0000_0000_0000_dca6_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h8c);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hd191_0f3b_200d_1234_0000_0000_0000_0000_0000_dca6_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD8C

`ifdef TEST_ALL
`define TEST_8D
`endif
`ifdef TEST_8D
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 8D (ADC A,L)
	TESTCASE(" -- 8d          adc a,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h8d);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h9b89_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_8D

`ifdef TEST_ALL
`define TEST_DD8D
`endif
`ifdef TEST_DD8D
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 8D (ADC A,L)
	TESTCASE(" -- dd 8d       adc a,ixl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_1234_0000_0000_0000_0000_dca6_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h8d);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9b89_0f3b_200d_1234_0000_0000_0000_0000_dca6_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD8D

`ifdef TEST_ALL
`define TEST_FD8D
`endif
`ifdef TEST_FD8D
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 8D (ADC A,L)
	TESTCASE(" -- fd 8d       adc a,iyl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_1234_0000_0000_0000_0000_0000_dca6_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h8d);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9b89_0f3b_200d_1234_0000_0000_0000_0000_0000_dca6_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD8D

`ifdef TEST_ALL
`define TEST_8E
`endif
`ifdef TEST_8E
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 8e (ADC A,(HL))
	TESTCASE(" -- 8e          adc a,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h8e); SETMEM(16'h0169, 8'h49);
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h3e29_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_8E

`ifdef TEST_ALL
`define TEST_DD8E
`endif
`ifdef TEST_DD8E
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 8e (ADC A,(IX+d))
	TESTCASE(" -- dd 8e       adc a,(ix+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_cf98_90d8_0169_0000_0000_0000_0000_0160_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h8e); SETMEM(2, 8'h09); SETMEM(16'h0169, 8'h49);
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'h3e29_cf98_90d8_0169_0000_0000_0000_0000_0160_0000_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD8E

`ifdef TEST_ALL
`define TEST_FD8E
`endif
`ifdef TEST_FD8E
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 8e (ADC A,(IY+d))
	TESTCASE(" -- fd 8e       adc a,(iy+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_cf98_90d8_0169_0000_0000_0000_0000_0000_0160_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h8e); SETMEM(2, 8'h09); SETMEM(16'h0169, 8'h49);
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'h3e29_cf98_90d8_0169_0000_0000_0000_0000_0000_0160_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD8E

`ifdef TEST_ALL
`define TEST_8F
`endif
`ifdef TEST_8F
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 8F (ADC A,A)
	TESTCASE(" -- 8f          adc a,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h8f);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'heaa9_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_8F

`ifdef TEST_ALL
`define TEST_DD8F
`endif
`ifdef TEST_DD8F
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 8F (ADC A,A)
	TESTCASE(" -- dd 8f       adc a,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h8f);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'heaa9_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD8F

`ifdef TEST_ALL
`define TEST_FD8F
`endif
`ifdef TEST_FD8F
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 8F (ADC A,A)
	TESTCASE(" -- fd 8f       adc a,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h8f);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'heaa9_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD8F

`ifdef TEST_ALL
`define TEST_90
`endif
`ifdef TEST_90
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 90 (SUB A,B)
	TESTCASE(" -- 90          sub a,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h90);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'he6b2_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_90

`ifdef TEST_ALL
`define TEST_DD90
`endif
`ifdef TEST_DD90
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 90 (SUB A,B)
	TESTCASE(" -- dd 90       sub a,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h90);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'he6b2_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD90

`ifdef TEST_ALL
`define TEST_FD90
`endif
`ifdef TEST_FD90
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 90 (SUB A,B)
	TESTCASE(" -- fd 90       sub a,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h90);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'he6b2_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD90

`ifdef TEST_ALL
`define TEST_91
`endif
`ifdef TEST_91
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 91 (SUB A,C)
	TESTCASE(" -- 91          sub a,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h91);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hbaba_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_91

`ifdef TEST_ALL
`define TEST_DD91
`endif
`ifdef TEST_DD91
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 91 (SUB A,C)
	TESTCASE(" -- dd 91       sub a,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h91);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hbaba_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD91

`ifdef TEST_ALL
`define TEST_FD91
`endif
`ifdef TEST_FD91
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 91 (SUB A,C)
	TESTCASE(" -- fd 91       sub a,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h91);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hbaba_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD91

`ifdef TEST_ALL
`define TEST_92
`endif
`ifdef TEST_92
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 92 (SUB A,D)
	TESTCASE(" -- 92          sub a,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h92);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hd582_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_92

`ifdef TEST_ALL
`define TEST_DD92
`endif
`ifdef TEST_DD92
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 92 (SUB A,D)
	TESTCASE(" -- dd 92       sub a,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h92);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hd582_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD92

`ifdef TEST_ALL
`define TEST_FD92
`endif
`ifdef TEST_FD92
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 92 (SUB A,D)
	TESTCASE(" -- fd 92       sub a,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h92);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hd582_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD92

`ifdef TEST_ALL
`define TEST_93
`endif
`ifdef TEST_93
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 93 (SUB A,E)
	TESTCASE(" -- 93          sub a,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h93);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'he8ba_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_93

`ifdef TEST_ALL
`define TEST_DD93
`endif
`ifdef TEST_DD93
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 93 (SUB A,E)
	TESTCASE(" -- dd 93       sub a,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h93);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'he8ba_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD93

`ifdef TEST_ALL
`define TEST_FD93
`endif
`ifdef TEST_FD93
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 93 (SUB A,E)
	TESTCASE(" -- fd 93       sub a,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h93);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'he8ba_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD93

`ifdef TEST_ALL
`define TEST_94
`endif
`ifdef TEST_94
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 94 (SUB A,H)
	TESTCASE(" -- 94          sub a,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h94);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h191a_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_94

`ifdef TEST_ALL
`define TEST_DD94
`endif
`ifdef TEST_DD94
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 94 (SUB A,IXH)
	TESTCASE(" -- dd 94       sub a,ixh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf501_0f3b_200d_dca6_0000_0000_0000_0000_dca6_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h94);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h191a_0f3b_200d_dca6_0000_0000_0000_0000_dca6_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD94

`ifdef TEST_ALL
`define TEST_FD94
`endif
`ifdef TEST_FD94
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 94 (SUB A,IYH)
	TESTCASE(" -- fd 94       sub a,iyh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf501_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h94);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h191a_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD94

`ifdef TEST_ALL
`define TEST_95
`endif
`ifdef TEST_95
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 95 (SUB A,L)
	TESTCASE(" -- 95          sub a,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h95);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h4f1a_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_95

`ifdef TEST_ALL
`define TEST_DD95
`endif
`ifdef TEST_DD95
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 95 (SUB A,IXL)
	TESTCASE(" -- dd 95       sub a,ixl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf501_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h95);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h4f1a_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD95

`ifdef TEST_ALL
`define TEST_FD95
`endif
`ifdef TEST_FD95
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 95 (SUB A,IYL)
	TESTCASE(" -- fd 95       sub a,iyl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf501_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h95);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h4f1a_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD95

`ifdef TEST_ALL
`define TEST_96
`endif
`ifdef TEST_96
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 96 (SUB A,(HL))
	TESTCASE(" -- 96          sub a,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h96); SETMEM(16'h0169, 8'h49);
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'hacba_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_96

`ifdef TEST_ALL
`define TEST_DD96
`endif
`ifdef TEST_DD96
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 96 (SUB A,(IX+d))
	TESTCASE(" -- dd 96       sub a,(ix+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_cf98_90d8_0169_0000_0000_0000_0000_0160_0020_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h96); SETMEM(2, 8'h06); SETMEM(16'h0166, 8'h49);
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'hacba_cf98_90d8_0169_0000_0000_0000_0000_0160_0020_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD96

`ifdef TEST_ALL
`define TEST_FD96
`endif
`ifdef TEST_FD96
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 96 (SUB A,(IY+d))
	TESTCASE(" -- fd 96       sub a,(iy+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_cf98_90d8_0169_0000_0000_0000_0000_0160_0020_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h96); SETMEM(2, 8'h46); SETMEM(16'h0066, 8'h49);
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'hacba_cf98_90d8_0169_0000_0000_0000_0000_0160_0020_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD96

`ifdef TEST_ALL
`define TEST_97
`endif
`ifdef TEST_97
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 97 (SUB A,A)
	TESTCASE(" -- 97          sub a,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h97);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0042_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_97

`ifdef TEST_ALL
`define TEST_DD97
`endif
`ifdef TEST_DD97
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 97 (SUB A,A)
	TESTCASE(" -- dd 97       sub a,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h97);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0042_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD97

`ifdef TEST_ALL
`define TEST_FD97
`endif
`ifdef TEST_FD97
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 97 (SUB A,A)
	TESTCASE(" -- fd 97       sub a,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h97);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0042_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD97

`ifdef TEST_ALL
`define TEST_98
`endif
`ifdef TEST_98
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 98 (SBC A,B)
	TESTCASE(" -- 98          sbc a,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h98);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'he6b2_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_98

`ifdef TEST_ALL
`define TEST_DD98
`endif
`ifdef TEST_DD98
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 98 (SBC A,B)
	TESTCASE(" -- dd 98       sbc a,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h98);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'he6b2_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD98

`ifdef TEST_ALL
`define TEST_FD98
`endif
`ifdef TEST_FD98
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 98 (SBC A,B)
	TESTCASE(" -- fd 98       sbc a,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h98);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'he6b2_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD98

`ifdef TEST_ALL
`define TEST_99
`endif
`ifdef TEST_99
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 99 (SBC A,C)
	TESTCASE(" -- 99          sbc a,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h99);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hbaba_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_99

`ifdef TEST_ALL
`define TEST_DD99
`endif
`ifdef TEST_DD99
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 99 (SBC A,C)
	TESTCASE(" -- dd 99       sbc a,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h99);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hbaba_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD99

`ifdef TEST_ALL
`define TEST_FD99
`endif
`ifdef TEST_FD99
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 99 (SBC A,C)
	TESTCASE(" -- fd 99       sbc a,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h99);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hbaba_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD99

`ifdef TEST_ALL
`define TEST_9A
`endif
`ifdef TEST_9A
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 9A (SBC A,D)
	TESTCASE(" -- 9a          sbc a,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h9a);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hd582_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_9A

`ifdef TEST_ALL
`define TEST_DD9A
`endif
`ifdef TEST_DD9A
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 9A (SBC A,D)
	TESTCASE(" -- dd 9a       sbc a,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h9a);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hd582_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD9A

`ifdef TEST_ALL
`define TEST_FD9A
`endif
`ifdef TEST_FD9A
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 9A (SBC A,D)
	TESTCASE(" -- fd 9a       sbc a,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h9a);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hd582_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD9A

`ifdef TEST_ALL
`define TEST_9B
`endif
`ifdef TEST_9B
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 9B (SBC A,E)
	TESTCASE(" -- 9b          sbc a,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h9b);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'he8ba_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_9B

`ifdef TEST_ALL
`define TEST_DD9B
`endif
`ifdef TEST_DD9B
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 9B (SBC A,E)
	TESTCASE(" -- dd 9b       sbc a,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h9b);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'he8ba_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD9B

`ifdef TEST_ALL
`define TEST_FD9B
`endif
`ifdef TEST_FD9B
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 9B (SBC A,E)
	TESTCASE(" -- fd 9b       sbc a,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h9b);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'he8ba_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD9B

`ifdef TEST_ALL
`define TEST_9C
`endif
`ifdef TEST_9C
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 9C (SBC A,H)
	TESTCASE(" -- 9c          sbc a,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h9c);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h191a_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_9C

`ifdef TEST_ALL
`define TEST_DD9C
`endif
`ifdef TEST_DD9C
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 9C (SBC A,IXH)
	TESTCASE(" -- dd 9c       sbc a,ixh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h9c);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h191a_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD9C

`ifdef TEST_ALL
`define TEST_FD9C
`endif
`ifdef TEST_FD9C
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 9C (SBC A,IYH)
	TESTCASE(" -- fd 9c       sbc a,iyh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h9c);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h191a_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD9C

`ifdef TEST_ALL
`define TEST_9D
`endif
`ifdef TEST_9D
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 9D (SBC A,L)
	TESTCASE(" -- 9d          sbc a,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h9d);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h4f1a_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_9D

`ifdef TEST_ALL
`define TEST_DD9D
`endif
`ifdef TEST_DD9D
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 9D (SBC A,IXL)
	TESTCASE(" -- dd 9d       sbc a,ixl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h9d);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h4f1a_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD9D

`ifdef TEST_ALL
`define TEST_FD9D
`endif
`ifdef TEST_FD9D
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 9D (SBC A,IYL)
	TESTCASE(" -- fd 9d       sbc a,iyl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h9d);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h4f1a_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD9D

`ifdef TEST_ALL
`define TEST_9E
`endif
`ifdef TEST_9E
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 9E (SBC A,(HL))
	TESTCASE(" -- 9E          sbc a,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h9e); SETMEM(16'h0169, 8'h49);
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'hacba_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_9E

`ifdef TEST_ALL
`define TEST_DD9E
`endif
`ifdef TEST_DD9E
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 9E (SBC A,(IX+d))
	TESTCASE(" -- dd 9E       sbc a,(ix+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_cf98_90d8_0169_0000_0000_0000_0000_0160_0160_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h9e); SETMEM(2, 8'h09); SETMEM(16'h0169, 8'h49);
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'hacba_cf98_90d8_0169_0000_0000_0000_0000_0160_0160_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD9E

`ifdef TEST_ALL
`define TEST_FD9E
`endif
`ifdef TEST_FD9E
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 9E (SBC A,(IX+d))
	TESTCASE(" -- fd 9E       sbc a,(ix+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_cf98_90d8_0169_0000_0000_0000_0000_0160_0160_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h9e); SETMEM(2, 8'h09); SETMEM(16'h0169, 8'h49);
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'hacba_cf98_90d8_0169_0000_0000_0000_0000_0160_0160_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD9E

`ifdef TEST_ALL
`define TEST_9F
`endif
`ifdef TEST_9F
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 9F (SBC A,A)
	TESTCASE(" -- 9f          sbc a,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h9f);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0042_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_9F

`ifdef TEST_ALL
`define TEST_DD9F
`endif
`ifdef TEST_DD9F
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 9F (SBC A,A)
	TESTCASE(" -- dd 9f       sbc a,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h9f);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0042_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD9F

`ifdef TEST_ALL
`define TEST_FD9F
`endif
`ifdef TEST_FD9F
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 9F (SBC A,A)
	TESTCASE(" -- fd 9f       sbc a,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h9f);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0042_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_9F

`ifdef TEST_ALL
`define TEST_9F_1
`endif
`ifdef TEST_9F_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 9F (SBC A,A) w/Carry
	TESTCASE(" -- 9f          sbc a,a ; w/ Carry");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'h9f);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hffbb_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_9F_1

`ifdef TEST_ALL
`define TEST_DD9F_1
`endif
`ifdef TEST_DD9F_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 9F (SBC A,A) w/Carry
	TESTCASE(" -- dd 9f       sbc a,a ; w/ Carry");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'h9f);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hffbb_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DD9F_1

`ifdef TEST_ALL
`define TEST_FD9F_1
`endif
`ifdef TEST_FD9F_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 9F (SBC A,A) w/Carry
	TESTCASE(" -- fd 9f       sbc a,a ; w/ Carry");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'h9f);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hffbb_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FD9F_1

`ifdef TEST_ALL
`define TEST_A0
`endif
`ifdef TEST_A0
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE A0 (AND A,B)
	TESTCASE(" -- a0          and a,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'ha0);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0514_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_A0

`ifdef TEST_ALL
`define TEST_DDA0
`endif
`ifdef TEST_DDA0
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD A0 (AND A,B)
	TESTCASE(" -- dd a0       and a,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'ha0);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0514_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDA0

`ifdef TEST_ALL
`define TEST_FDA0
`endif
`ifdef TEST_FDA0
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD A0 (AND A,B)
	TESTCASE(" -- fd a0       and a,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'ha0);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0514_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDA0

`ifdef TEST_ALL
`define TEST_A1
`endif
`ifdef TEST_A1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE A1 (AND A,C)
	TESTCASE(" -- a1          and a,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'ha1);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h3130_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_A1

`ifdef TEST_ALL
`define TEST_DDA1
`endif
`ifdef TEST_DDA1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD A1 (AND A,C)
	TESTCASE(" -- dd a1       and a,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'ha1);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h3130_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDA1

`ifdef TEST_ALL
`define TEST_FDA1
`endif
`ifdef TEST_FDA1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD A1 (AND A,C)
	TESTCASE(" -- fd a1       and a,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'ha1);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h3130_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDA1

`ifdef TEST_ALL
`define TEST_A2
`endif
`ifdef TEST_A2
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE A2 (AND A,D)
	TESTCASE(" -- a2          and a,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'ha2);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h2030_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_A2

`ifdef TEST_ALL
`define TEST_DDA2
`endif
`ifdef TEST_DDA2
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD A2 (AND A,D)
	TESTCASE(" -- dd a2       and a,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'ha2);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h2030_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDA2

`ifdef TEST_ALL
`define TEST_FDA2
`endif
`ifdef TEST_FDA2
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD A2 (AND A,D)
	TESTCASE(" -- fd a2       and a,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'ha2);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h2030_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDA2

`ifdef TEST_ALL
`define TEST_A3
`endif
`ifdef TEST_A3
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE A3 (AND A,E)
	TESTCASE(" -- a3          and a,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'ha3);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0514_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_A3

`ifdef TEST_ALL
`define TEST_DDA3
`endif
`ifdef TEST_DDA3
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD A3 (AND A,E)
	TESTCASE(" -- dd a3       and a,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'ha3);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0514_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDA3

`ifdef TEST_ALL
`define TEST_FDA3
`endif
`ifdef TEST_FDA3
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD A3 (AND A,E)
	TESTCASE(" -- fd a3       and a,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'ha3);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0514_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDA3

`ifdef TEST_ALL
`define TEST_A4
`endif
`ifdef TEST_A4
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE A4 (AND A,H)
	TESTCASE(" -- a4          and a,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'ha4);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hd494_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_A4

`ifdef TEST_ALL
`define TEST_DDA4
`endif
`ifdef TEST_DDA4
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD A4 (AND A,IXH)
	TESTCASE(" -- dd a4       and a,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'ha4);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hd494_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDA4

`ifdef TEST_ALL
`define TEST_FDA4
`endif
`ifdef TEST_FDA4
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD A4 (AND A,IXH)
	TESTCASE(" -- fd a4       and a,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'ha4);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hd494_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDA4

`ifdef TEST_ALL
`define TEST_A5
`endif
`ifdef TEST_A5
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE A5 (AND A,L)
	TESTCASE(" -- a5          and a,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'ha5);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'ha4b0_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_A5

`ifdef TEST_ALL
`define TEST_DDA5
`endif
`ifdef TEST_DDA5
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD A5 (AND A,IXL)
	TESTCASE(" -- dd a5       and a,ixl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'ha5);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha4b0_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDA5

`ifdef TEST_ALL
`define TEST_FDA5
`endif
`ifdef TEST_FDA5
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD A5 (AND A,IXL)
	TESTCASE(" -- fd a5       and a,iyl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'ha5);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha4b0_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDA5

`ifdef TEST_ALL
`define TEST_A6
`endif
`ifdef TEST_A6
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE A6 (AND A,(HL))
	TESTCASE(" -- a6          and a,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_0169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'ha6); SETMEM(16'h0169, 8'h49);
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h4114_0f3b_200d_0169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_A6

`ifdef TEST_ALL
`define TEST_DDA6
`endif
`ifdef TEST_DDA6
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD A6 (AND A,(HL))
	TESTCASE(" -- dd a6       and a,(ix+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_0169_0000_0000_0000_0000_0160_0100_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'ha6); SETMEM(2, 8'h01); SETMEM(16'h0161, 8'h49);
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'h4114_0f3b_200d_0169_0000_0000_0000_0000_0160_0100_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDA6

`ifdef TEST_ALL
`define TEST_FDA6
`endif
`ifdef TEST_FDA6
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD A6 (AND A,(HL))
	TESTCASE(" -- fd a6       and a,(iy+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_0169_0000_0000_0000_0000_0160_0100_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'ha6); SETMEM(2, 8'h62); SETMEM(16'h0162, 8'h49);
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'h4114_0f3b_200d_0169_0000_0000_0000_0000_0160_0100_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDA6

`ifdef TEST_ALL
`define TEST_A7
`endif
`ifdef TEST_A7
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE A7 (AND A,A)
	TESTCASE(" -- a7          and a,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'ha7);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hf5b4_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_A7

`ifdef TEST_ALL
`define TEST_DDA7
`endif
`ifdef TEST_DDA7
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD A7 (AND A,A)
	TESTCASE(" -- dd a7       and a,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'ha7);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hf5b4_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDA7

`ifdef TEST_ALL
`define TEST_FDA7
`endif
`ifdef TEST_FDA7
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD A7 (AND A,A)
	TESTCASE(" -- fd a7       and a,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'ha7);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hf5b4_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDA7

`ifdef TEST_ALL
`define TEST_A8
`endif
`ifdef TEST_A8
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE A8 (XOR A,B)
	TESTCASE(" -- a8          xor a,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'ha8);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hfaac_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_A8

`ifdef TEST_ALL
`define TEST_DDA8
`endif
`ifdef TEST_DDA8
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD A8 (XOR A,B)
	TESTCASE(" -- dd a8       xor a,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'ha8);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hfaac_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDA8

`ifdef TEST_ALL
`define TEST_FDA8
`endif
`ifdef TEST_FDA8
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD A8 (XOR A,B)
	TESTCASE(" -- fd a8       xor a,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'ha8);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hfaac_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDA8

`ifdef TEST_ALL
`define TEST_A9
`endif
`ifdef TEST_A9
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE A9 (XOR A,C)
	TESTCASE(" -- a9          xor a,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'ha9);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hce88_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_A9

`ifdef TEST_ALL
`define TEST_DDA9
`endif
`ifdef TEST_DDA9
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD A9 (XOR A,C)
	TESTCASE(" -- dd a9       xor a,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'ha9);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hce88_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDA9

`ifdef TEST_ALL
`define TEST_FDA9
`endif
`ifdef TEST_FDA9
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD A9 (XOR A,C)
	TESTCASE(" -- fd a9       xor a,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'ha9);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hce88_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDA9

`ifdef TEST_ALL
`define TEST_AA
`endif
`ifdef TEST_AA
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE AA (XOR A,D)
	TESTCASE(" -- aa          xor a,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'haa);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hd580_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_AA

`ifdef TEST_ALL
`define TEST_DDAA
`endif
`ifdef TEST_DDAA
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD AA (XOR A,D)
	TESTCASE(" -- dd aa       xor a,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'haa);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hd580_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDAA

`ifdef TEST_ALL
`define TEST_FDAA
`endif
`ifdef TEST_FDAA
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD AA (XOR A,D)
	TESTCASE(" -- fd aa       xor a,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'haa);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hd580_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDAA

`ifdef TEST_ALL
`define TEST_AB
`endif
`ifdef TEST_AB
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE AB (XOR A,E)
	TESTCASE(" -- ab          xor a,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hab);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hf8a8_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_AB

`ifdef TEST_ALL
`define TEST_DDAB
`endif
`ifdef TEST_DDAB
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD AB (XOR A,E)
	TESTCASE(" -- dd ab       xor a,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hab);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hf8a8_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDAB

`ifdef TEST_ALL
`define TEST_FDAB
`endif
`ifdef TEST_FDAB
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD AB (XOR A,E)
	TESTCASE(" -- fd ab       xor a,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hab);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hf8a8_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDAB

`ifdef TEST_ALL
`define TEST_AC
`endif
`ifdef TEST_AC
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE AC (XOR A,H)
	TESTCASE(" -- ac          xor a,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hac);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h2928_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_AC

`ifdef TEST_ALL
`define TEST_DDAC
`endif
`ifdef TEST_DDAC
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD AC (XOR A,IXH)
	TESTCASE(" -- dd ac       xor a,ixh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hac);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h2928_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDAC

`ifdef TEST_ALL
`define TEST_FDAC
`endif
`ifdef TEST_FDAC
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD AC (XOR A,IYH)
	TESTCASE(" -- fd ac       xor a,iyh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hac);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h2928_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDAC

`ifdef TEST_ALL
`define TEST_AD
`endif
`ifdef TEST_AD
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE AD (XOR A,L)
	TESTCASE(" -- ad          xor a,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'had);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h5304_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_AD

`ifdef TEST_ALL
`define TEST_DDAD
`endif
`ifdef TEST_DDAD
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD AD (XOR A,IXL)
	TESTCASE(" -- dd ad       xor a,ixl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'had);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h5304_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDAD

`ifdef TEST_ALL
`define TEST_FDAD
`endif
`ifdef TEST_FDAD
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD AD (XOR A,IYL)
	TESTCASE(" -- fd ad       xor a,iyl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'had);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h5304_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDAD

`ifdef TEST_ALL
`define TEST_AE
`endif
`ifdef TEST_AE
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE AE (XOR A,(HL))
	TESTCASE(" -- ae          xor a,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_0169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hae); SETMEM(16'h0169, 8'h49);
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'hbca8_0f3b_200d_0169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_AE

`ifdef TEST_ALL
`define TEST_DDAE
`endif
`ifdef TEST_DDAE
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD AE (XOR A,(IX+d))
	TESTCASE(" -- dd ae       xor a,(ix+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_0169_0000_0000_0000_0000_0160_00ff_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hae); SETMEM(2, 8'h09); SETMEM(16'h0169, 8'h49);
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'hbca8_0f3b_200d_0169_0000_0000_0000_0000_0160_00ff_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDAE

`ifdef TEST_ALL
`define TEST_FDAE
`endif
`ifdef TEST_FDAE
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD AE (XOR A,(IX+d))
	TESTCASE(" -- fd ae       xor a,(iy+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_0169_0000_0000_0000_0000_0160_00ff_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hae); SETMEM(2, 8'h01); SETMEM(16'h0100, 8'h49);
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'hbca8_0f3b_200d_0169_0000_0000_0000_0000_0160_00ff_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDAE

`ifdef TEST_ALL
`define TEST_AF
`endif
`ifdef TEST_AF
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE AF (XOR A,A)
	TESTCASE(" -- af          xor a,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'haf);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0044_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_AF

`ifdef TEST_ALL
`define TEST_DDAF
`endif
`ifdef TEST_DDAF
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD AF (XOR A,A)
	TESTCASE(" -- dd af       xor a,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'haf);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0044_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDAF

`ifdef TEST_ALL
`define TEST_FDAF
`endif
`ifdef TEST_FDAF
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD AF (XOR A,A)
	TESTCASE(" -- fd af       xor a,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'haf);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0044_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDAF

`ifdef TEST_ALL
`define TEST_B0
`endif
`ifdef TEST_B0
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE B0 (OR A,B)
	TESTCASE(" -- b0          or a,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hb0);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hffac_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_B0

`ifdef TEST_ALL
`define TEST_DDB0
`endif
`ifdef TEST_DDB0
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD B0 (OR A,B)
	TESTCASE(" -- dd b0       or a,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hb0);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hffac_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDB0

`ifdef TEST_ALL
`define TEST_FDB0
`endif
`ifdef TEST_FDB0
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD B0 (OR A,B)
	TESTCASE(" -- fd b0       or a,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hb0);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hffac_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDB0

`ifdef TEST_ALL
`define TEST_B1
`endif
`ifdef TEST_B1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE B1 (OR A,C)
	TESTCASE(" -- b1          or a,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hb1);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hffac_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_B1

`ifdef TEST_ALL
`define TEST_DDB1
`endif
`ifdef TEST_DDB1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD B1 (OR A,C)
	TESTCASE(" -- dd b1       or a,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hb1);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hffac_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDB1

`ifdef TEST_ALL
`define TEST_FDB1
`endif
`ifdef TEST_FDB1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD B1 (OR A,C)
	TESTCASE(" -- fd b1       or a,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hb1);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hffac_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDB1

`ifdef TEST_ALL
`define TEST_B2
`endif
`ifdef TEST_B2
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE B2 (OR A,D)
	TESTCASE(" -- b2          or a,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hb2);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hf5a4_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_B2

`ifdef TEST_ALL
`define TEST_DDB2
`endif
`ifdef TEST_DDB2
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD B2 (OR A,D)
	TESTCASE(" -- dd b2       or a,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hb2);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hf5a4_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDB2

`ifdef TEST_ALL
`define TEST_FDB2
`endif
`ifdef TEST_FDB2
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD B2 (OR A,D)
	TESTCASE(" -- fd b2       or a,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hb2);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hf5a4_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDB2

`ifdef TEST_ALL
`define TEST_B3
`endif
`ifdef TEST_B3
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE B3 (OR A,C)
	TESTCASE(" -- b3          or a,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hb3);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hfda8_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_B3

`ifdef TEST_ALL
`define TEST_DDB3
`endif
`ifdef TEST_DDB3
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD B3 (OR A,E)
	TESTCASE(" -- dd b3       or a,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hb3);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hfda8_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDB3

`ifdef TEST_ALL
`define TEST_FDB3
`endif
`ifdef TEST_FDB3
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD B3 (OR A,E)
	TESTCASE(" -- fd b3       or a,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hb3);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hfda8_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDB3

`ifdef TEST_ALL
`define TEST_B4
`endif
`ifdef TEST_B4
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE B4 (OR A,H)
	TESTCASE(" -- b4          or a,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hb4);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hfda8_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_B4

`ifdef TEST_ALL
`define TEST_DDB4
`endif
`ifdef TEST_DDB4
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD B4 (OR A,IXH)
	TESTCASE(" -- dd b4       or a,ixh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hb4);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hfda8_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDB4

`ifdef TEST_ALL
`define TEST_FDB4
`endif
`ifdef TEST_FDB4
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD B4 (OR A,IXH)
	TESTCASE(" -- fd b4       or a,iyh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hb4);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hfda8_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDB4

`ifdef TEST_ALL
`define TEST_B5
`endif
`ifdef TEST_B5
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE B5 (OR A,L)
	TESTCASE(" -- b5          or a,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hb5);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hf7a0_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_B5

`ifdef TEST_ALL
`define TEST_DDB5
`endif
`ifdef TEST_DDB5
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD B5 (OR A,IXL)
	TESTCASE(" -- dd b5       or a,ixl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hb5);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hf7a0_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDB5

`ifdef TEST_ALL
`define TEST_FDB5
`endif
`ifdef TEST_FDB5
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD B5 (OR A,IYL)
	TESTCASE(" -- fd b5       or a,iyl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hb5);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hf7a0_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDB5

`ifdef TEST_ALL
`define TEST_B6
`endif
`ifdef TEST_B6
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE B6 (OR A,(HL))
	TESTCASE(" -- b6          or a,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_0169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hb6); SETMEM(16'h0169, 8'h49);
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'hfda8_0f3b_200d_0169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_B6

`ifdef TEST_ALL
`define TEST_DDB6
`endif
`ifdef TEST_DDB6
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD B6 (OR A,(IX+d))
	TESTCASE(" -- dd b6       or a,(ix+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_0169_0000_0000_0000_0000_0160_0160_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hb6); SETMEM(2, 8'h09); SETMEM(16'h0169, 8'h49);
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'hfda8_0f3b_200d_0169_0000_0000_0000_0000_0160_0160_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDB6

`ifdef TEST_ALL
`define TEST_FDB6
`endif
`ifdef TEST_FDB6
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD B6 (OR A,(IY+d))
	TESTCASE(" -- fd b6       or a,(iy+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_0169_0000_0000_0000_0000_0160_0160_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hb6); SETMEM(2, 8'h09); SETMEM(16'h0169, 8'h49);
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'hfda8_0f3b_200d_0169_0000_0000_0000_0000_0160_0160_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDB6

`ifdef TEST_ALL
`define TEST_B7
`endif
`ifdef TEST_B7
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE B7 (OR A,A)
	TESTCASE(" -- b7          or a,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hb7);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hf5a4_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_B7

`ifdef TEST_ALL
`define TEST_DDB7
`endif
`ifdef TEST_DDB7
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD B7 (OR A,A)
	TESTCASE(" -- dd b7       or a,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hb7);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hf5a4_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDB7

`ifdef TEST_ALL
`define TEST_FDB7
`endif
`ifdef TEST_FDB7
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD B7 (OR A,A)
	TESTCASE(" -- fd b7       or a,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hb7);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hf5a4_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDB7

`ifdef TEST_ALL
`define TEST_B8
`endif
`ifdef TEST_B8
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE B8 (CP B)
	TESTCASE(" -- b8          cp b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hb8);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hf59a_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_B8

`ifdef TEST_ALL
`define TEST_DDB8
`endif
`ifdef TEST_DDB8
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD B8 (CP B)
	TESTCASE(" -- dd b8       cp b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hb8);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hf59a_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDB8

`ifdef TEST_ALL
`define TEST_FDB8
`endif
`ifdef TEST_FDB8
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD B8 (CP B)
	TESTCASE(" -- fd b8       cp b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hb8);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hf59a_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDB8

`ifdef TEST_ALL
`define TEST_B9
`endif
`ifdef TEST_B9
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE B9 (CP C)
	TESTCASE(" -- b9          cp c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hb9);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hf5ba_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_B9

`ifdef TEST_ALL
`define TEST_DDB9
`endif
`ifdef TEST_DDB9
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD B9 (CP C)
	TESTCASE(" -- dd b9       cp c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hb9);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hf5ba_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDB9

`ifdef TEST_ALL
`define TEST_FDB9
`endif
`ifdef TEST_FDB9
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD B9 (CP C)
	TESTCASE(" -- fd b9       cp c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hb9);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hf5ba_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDB9

`ifdef TEST_ALL
`define TEST_BA
`endif
`ifdef TEST_BA
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE BA (CP D)
	TESTCASE(" -- ba          cp d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hba);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hf5a2_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_BA

`ifdef TEST_ALL
`define TEST_DDBA
`endif
`ifdef TEST_DDBA
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD BA (CP D)
	TESTCASE(" -- dd ba       cp d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hba);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hf5a2_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDBA

`ifdef TEST_ALL
`define TEST_FDBA
`endif
`ifdef TEST_FDBA
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD BA (CP D)
	TESTCASE(" -- fd ba       cp d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hba);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hf5a2_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDBA

`ifdef TEST_ALL
`define TEST_BB
`endif
`ifdef TEST_BB
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE BB (CP E)
	TESTCASE(" -- bb          cp e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hbb);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hf59a_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_BB

`ifdef TEST_ALL
`define TEST_DDBB
`endif
`ifdef TEST_DDBB
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD BB (CP E)
	TESTCASE(" -- dd bb       cp e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hbb);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hf59a_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDBB

`ifdef TEST_ALL
`define TEST_FDBB
`endif
`ifdef TEST_FDBB
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD BB (CP E)
	TESTCASE(" -- fd bb       cp e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hbb);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hf59a_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDBB

`ifdef TEST_ALL
`define TEST_BC
`endif
`ifdef TEST_BC
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE BC (CP H)
	TESTCASE(" -- bc          cp h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hbc);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hf51a_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_BC

`ifdef TEST_ALL
`define TEST_DDBC
`endif
`ifdef TEST_DDBC
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD BC (CP IXH)
	TESTCASE(" -- dd bc       cp ixh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hbc);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hf51a_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDBC

`ifdef TEST_ALL
`define TEST_FDBC
`endif
`ifdef TEST_FDBC
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD BC (CP IYH)
	TESTCASE(" -- fd bc       cp iyh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hbc);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hf51a_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDBC

`ifdef TEST_ALL
`define TEST_BD
`endif
`ifdef TEST_BD
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE BD (CP L)
	TESTCASE(" -- bd          cp l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hbd);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hf532_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_BD

`ifdef TEST_ALL
`define TEST_DDBD
`endif
`ifdef TEST_DDBD
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD BD (CP IXL)
	TESTCASE(" -- dd bd       cp ixl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hbd);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hf532_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDBD

`ifdef TEST_ALL
`define TEST_FDBD
`endif
`ifdef TEST_FDBD
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD BD (CP IYL)
	TESTCASE(" -- fd bd       cp iyl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hbd);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hf532_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDBD

`ifdef TEST_ALL
`define TEST_BE
`endif
`ifdef TEST_BE
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE BE (CP (HL))
	TESTCASE(" -- be          cp (hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_01c6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hbe); SETMEM('h01c6, 8'h49);
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'hf59a_0f3b_200d_01c6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_BE

`ifdef TEST_ALL
`define TEST_DDBE
`endif
`ifdef TEST_DDBE
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD BE (CP (IX+d))
	TESTCASE(" -- dd be       cp (ix+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_01c6_0000_0000_0000_0000_01d0_01e0_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hbe); SETMEM(2, 8'h0d); SETMEM('h01dd, 8'h49);
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'hf59a_0f3b_200d_01c6_0000_0000_0000_0000_01d0_01e0_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDBE

`ifdef TEST_ALL
`define TEST_FDBE
`endif
`ifdef TEST_FDBE
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD BE (CP (IY+d))
	TESTCASE(" -- fd be       cp (iy+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_01c6_0000_0000_0000_0000_01d0_01e0_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hbe); SETMEM(2, 8'h0d); SETMEM('h01ed, 8'h49);
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'hf59a_0f3b_200d_01c6_0000_0000_0000_0000_01d0_01e0_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDBE

`ifdef TEST_ALL
`define TEST_BF
`endif
`ifdef TEST_BF
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE BF (CP A)
	TESTCASE(" -- bf          cp a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hbf);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hf562_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_BF

`ifdef TEST_ALL
`define TEST_DDBF
`endif
`ifdef TEST_DDBF
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD BF (CP A)
	TESTCASE(" -- dd bf       cp a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hbf);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hf562_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDBF

`ifdef TEST_ALL
`define TEST_FDBF
`endif
`ifdef TEST_FDBF
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD BF (CP A)
	TESTCASE(" -- fd bf       cp a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hbf);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hf562_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDBF

`ifdef TEST_ALL
`define TEST_C0_1
`endif
`ifdef TEST_C0_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE C0_1 (RET NZ ; taken)
	TESTCASE(" -- c0          ret nz ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hc0); SETMEM(16'h01f7, 8'he9); SETMEM(16'h01f8, 8'haf);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f9_afe9, 8'h00, 8'h01, 2'b00);
`endif // TEST_C0_1

`ifdef TEST_ALL
`define TEST_DDC0_1
`endif
`ifdef TEST_DDC0_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD C0_1 (RET NZ ; taken)
	TESTCASE(" -- DD c0       ret nz ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hc0); SETMEM(16'h01f7, 8'he9); SETMEM(16'h01f8, 8'haf);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f9_afe9, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDC0_1

`ifdef TEST_ALL
`define TEST_FDC0_1
`endif
`ifdef TEST_FDC0_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD C0_1 (RET NZ ; taken)
	TESTCASE(" -- FD c0       ret nz ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hc0); SETMEM(16'h01f7, 8'he9); SETMEM(16'h01f8, 8'haf);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f9_afe9, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDC0_1

`ifdef TEST_ALL
`define TEST_C0_2
`endif
`ifdef TEST_C0_2
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE C0_1 (RET NZ ; not taken)
	TESTCASE(" -- c0          ret nz ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h00d8_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hc0); SETMEM(16'h01f7, 8'he9); SETMEM(16'h01f8, 8'haf);
	#(2* `CLKPERIOD * 5+`FIN)
	ASSERT(192'h00d8_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_C0_2

`ifdef TEST_ALL
`define TEST_C1
`endif
`ifdef TEST_C1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE C1 (POP BC)
	TESTCASE(" -- c1          pop bc");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0143_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hc1); SETMEM(16'h0143, 8'hce); SETMEM(16'h0144, 8'he8);
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0000_e8ce_0000_0000_0000_0000_0000_0000_0000_0000_0145_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_C1

`ifdef TEST_ALL
`define TEST_DDC1
`endif
`ifdef TEST_DDC1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD C1 (POP BC)
	TESTCASE(" -- dd c1       pop bc");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0143_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hc1); SETMEM(16'h0143, 8'hce); SETMEM(16'h0144, 8'he8);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0000_e8ce_0000_0000_0000_0000_0000_0000_0000_0000_0145_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDC1

`ifdef TEST_ALL
`define TEST_FDC1
`endif
`ifdef TEST_FDC1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD C1 (POP BC)
	TESTCASE(" -- fd c1       pop bc");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0143_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hc1); SETMEM(16'h0143, 8'hce); SETMEM(16'h0144, 8'he8);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0000_e8ce_0000_0000_0000_0000_0000_0000_0000_0000_0145_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDC1

`ifdef TEST_ALL
`define TEST_C2
`endif
`ifdef TEST_C2
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE C2_1 (JP NZ,nn ; taken)
	TESTCASE(" -- c2          jp nz,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hc2); SETMEM(1, 8'h1b); SETMEM(2, 8'he1);
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_e11b, 8'h00, 8'h01, 2'b00);
`endif // TEST_C2

`ifdef TEST_ALL
`define TEST_DDC2
`endif
`ifdef TEST_DDC2
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD C2_1 (JP NZ,nn ; taken)
	TESTCASE(" -- dd c2       jp nz,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hc2); SETMEM(2, 8'h1b); SETMEM(3, 8'he1);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_e11b, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDC2

`ifdef TEST_ALL
`define TEST_FDC2
`endif
`ifdef TEST_FDC2
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD C2_1 (JP NZ,nn ; taken)
	TESTCASE(" -- fd c2       jp nz,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hc2); SETMEM(2, 8'h1b); SETMEM(3, 8'he1);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_e11b, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDC2

`ifdef TEST_ALL
`define TEST_C2_1
`endif
`ifdef TEST_C2_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE C2_1 (JP NZ,nn ; not taken)
	TESTCASE(" -- c2          jp nz,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h00c7_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hc2); SETMEM(1, 8'h1b); SETMEM(2, 8'he1);
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h00c7_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h01, 2'b00);
`endif // TEST_C2_1

`ifdef TEST_ALL
`define TEST_DDC2_1
`endif
`ifdef TEST_DDC2_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD C2_1 (JP NZ,nn ; not taken)
	TESTCASE(" -- dd c2       jp nz,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h00c7_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hc2); SETMEM(2, 8'h1b); SETMEM(3, 8'he1);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h00c7_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDC2_1

`ifdef TEST_ALL
`define TEST_FDC2_1
`endif
`ifdef TEST_FDC2_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD C2_1 (JP NZ,nn ; not taken)
	TESTCASE(" -- fd c2       jp nz,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h00c7_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hc2); SETMEM(2, 8'h1b); SETMEM(3, 8'he1);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h00c7_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDC2_1

`ifdef TEST_ALL
`define TEST_C3
`endif
`ifdef TEST_C3
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE C3 (JP nn)
	TESTCASE(" -- c3          jp $7ced");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hc3); SETMEM(1, 8'hed); SETMEM(2, 8'h7c);
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_7ced, 8'h00, 8'h01, 2'b00);
`endif // TEST_C3

`ifdef TEST_ALL
`define TEST_DDC3
`endif
`ifdef TEST_DDC3
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD C3 (JP nn)
	TESTCASE(" -- dd c3       jp $7ced");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hc3); SETMEM(2, 8'hed); SETMEM(3, 8'h7c);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_7ced, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDC3

`ifdef TEST_ALL
`define TEST_FDC3
`endif
`ifdef TEST_FDC3
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD C3 (JP nn)
	TESTCASE(" -- fd c3       jp $7ced");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hc3); SETMEM(2, 8'hed); SETMEM(3, 8'h7c);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_7ced, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDC3

`ifdef TEST_ALL
`define TEST_C4
`endif
`ifdef TEST_C4
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE C4_1 (CALL NZ,nn ; taken)
	TESTCASE(" -- c4          call nz,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hc4); SETMEM(1, 8'h1b); SETMEM(2, 8'he1); SETMEM('h0197, 8'hff);
	#(2* `CLKPERIOD * 17+`FIN)
	ASSERTMEM(16'h0198, 8'h03);
	ASSERTMEM(16'h0197, 8'h00);
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_e11b, 8'h00, 8'h01, 2'b00);
`endif // TEST_C4

`ifdef TEST_ALL
`define TEST_DDC4
`endif
`ifdef TEST_DDC4
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD C4_1 (CALL NZ,nn ; taken)
	TESTCASE(" -- dd c4       call nz,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hc4); SETMEM(2, 8'h1b); SETMEM(3, 8'he1); SETMEM('h0197, 8'hff);
	#(2* `CLKPERIOD * 21+`FIN)
	ASSERTMEM(16'h0198, 8'h04);
	ASSERTMEM(16'h0197, 8'h00);
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_e11b, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDC4

`ifdef TEST_ALL
`define TEST_FDC4
`endif
`ifdef TEST_FDC4
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD C4_1 (CALL NZ,nn ; taken)
	TESTCASE(" -- fd c4       call nz,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hc4); SETMEM(2, 8'h1b); SETMEM(3, 8'he1); SETMEM('h0197, 8'hff);
	#(2* `CLKPERIOD * 21+`FIN)
	ASSERTMEM(16'h0198, 8'h04);
	ASSERTMEM(16'h0197, 8'h00);
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_e11b, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDC4

`ifdef TEST_ALL
`define TEST_C4_1
`endif
`ifdef TEST_C4_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE C4_1 (CALL NZ,nn ; taken)
	TESTCASE(" -- c4          call nz,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h004e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hc4); SETMEM(1, 8'h1b); SETMEM(2, 8'he1);
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h004e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0003, 8'h00, 8'h01, 2'b00);
`endif // TEST_C4_1

`ifdef TEST_ALL
`define TEST_DDC4_1
`endif
`ifdef TEST_DDC4_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD C4_1 (CALL NZ,nn ; taken)
	TESTCASE(" -- dd c4       call nz,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h004e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hc4); SETMEM(2, 8'h1b); SETMEM(3, 8'he1);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h004e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDC4_1

`ifdef TEST_ALL
`define TEST_FDC4_1
`endif
`ifdef TEST_FDC4_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD C4_1 (CALL NZ,nn ; taken)
	TESTCASE(" -- fd c4       call nz,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h004e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hc4); SETMEM(2, 8'h1b); SETMEM(3, 8'he1);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h004e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDC4_1

`ifdef TEST_ALL
`define TEST_C5
`endif
`ifdef TEST_C5
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE C5 (PUSH BC)
	TESTCASE(" -- c5          push bc");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h53e3_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hc5); SETMEM('h0197, 8'hff);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERTMEM(16'h0198, 8'h59);
	ASSERTMEM(16'h0197, 8'h14);
	ASSERT(192'h53e3_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0196_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_C5

`ifdef TEST_ALL
`define TEST_DDC5
`endif
`ifdef TEST_DDC5
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD C5 (PUSH BC)
	TESTCASE(" -- dd c5       push bc");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h53e3_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hc5); SETMEM('h0197, 8'hff);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERTMEM(16'h0198, 8'h59);
	ASSERTMEM(16'h0197, 8'h14);
	ASSERT(192'h53e3_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0196_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDC5

`ifdef TEST_ALL
`define TEST_FDC5
`endif
`ifdef TEST_FDC5
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD C5 (PUSH BC)
	TESTCASE(" -- fd c5       push bc");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h53e3_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hc5); SETMEM('h0197, 8'hff);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERTMEM(16'h0198, 8'h59);
	ASSERTMEM(16'h0197, 8'h14);
	ASSERT(192'h53e3_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0196_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDC5

`ifdef TEST_ALL
`define TEST_C6
`endif
`ifdef TEST_C6
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE C6 (ADD a,n)
	TESTCASE(" -- c6          add a,n");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hca00_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0100, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(16'h0100, 8'hc6); SETMEM(16'h0101, 8'h6f);
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h3939_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0102, 8'h00, 8'h01, 2'b00);
`endif // TEST_C6

`ifdef TEST_ALL
`define TEST_DDC6
`endif
`ifdef TEST_DDC6
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD C6 (ADD a,n)
	TESTCASE(" -- dd c6       add a,n");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hca00_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0100, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(16'h0100, 8'hdd); SETMEM(16'h0101, 8'hc6); SETMEM(16'h0102, 8'h6f);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h3939_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0103, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDC6

`ifdef TEST_ALL
`define TEST_FDC6
`endif
`ifdef TEST_FDC6
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD C6 (ADD a,n)
	TESTCASE(" -- fd c6       add a,n");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hca00_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0100, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(16'h0100, 8'hfd); SETMEM(16'h0101, 8'hc6); SETMEM(16'h0102, 8'h6f);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h3939_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0103, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDC6

`ifdef TEST_ALL
`define TEST_C7
`endif
`ifdef TEST_C7
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE C7 (RST 00h)
	TESTCASE(" -- c7          rst 00h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0234, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(16'h0234, 8'hc7);  SETMEM(16'h0197, 8'hff);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERTMEM(16'h0198, 8'h35);
	ASSERTMEM(16'h0197, 8'h02);
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_0000, 8'h00, 8'h01, 2'b00);
`endif // TEST_C7

`ifdef TEST_ALL
`define TEST_DDC7
`endif
`ifdef TEST_DDC7
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD C7 (RST 00h)
	TESTCASE(" -- dd c7       rst 00h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0234, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(16'h0234, 8'hdd); SETMEM(16'h0235, 8'hc7); SETMEM(16'h0197, 8'hff);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERTMEM(16'h0198, 8'h35);
	ASSERTMEM(16'h0197, 8'h02);
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_0000, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDC7

`ifdef TEST_ALL
`define TEST_FDC7
`endif
`ifdef TEST_FDC7
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD C7 (RST 00h)
	TESTCASE(" -- fd c7       rst 00h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0234, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(16'h0234, 8'hdd); SETMEM(16'h0235, 8'hc7); SETMEM(16'h0197, 8'hff);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERTMEM(16'h0198, 8'h35);
	ASSERTMEM(16'h0197, 8'h02);
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_0000, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDC7

`ifdef TEST_ALL
`define TEST_C8
`endif
`ifdef TEST_C8
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE C8_1 (RET Z ; taken)
	TESTCASE(" -- c8          ret z ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h00d8_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hc8); SETMEM(16'h01f7, 8'he9); SETMEM(16'h01f8, 8'haf);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h00d8_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f9_afe9, 8'h00, 8'h01, 2'b00);
`endif // TEST_C8

`ifdef TEST_ALL
`define TEST_DDC8
`endif
`ifdef TEST_DDC8
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD C8_1 (RET Z ; taken)
	TESTCASE(" -- dd c8       ret z ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h00d8_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hc8); SETMEM(16'h01f7, 8'he9); SETMEM(16'h01f8, 8'haf);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h00d8_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f9_afe9, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDC8

`ifdef TEST_ALL
`define TEST_FDC8
`endif
`ifdef TEST_FDC8
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD C8_1 (RET Z ; taken)
	TESTCASE(" -- fd c8       ret z ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h00d8_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hc8); SETMEM(16'h01f7, 8'he9); SETMEM(16'h01f8, 8'haf);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h00d8_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f9_afe9, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDC8

`ifdef TEST_ALL
`define TEST_C8_1
`endif
`ifdef TEST_C8_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE C8_1 (RET Z ; not taken)
	TESTCASE(" -- c8          ret z ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hc8); SETMEM(16'h01f7, 8'he9); SETMEM(16'h01f8, 8'haf);
	#(2* `CLKPERIOD * 5+`FIN)
	ASSERT(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_C8_1

`ifdef TEST_ALL
`define TEST_DDC8_1
`endif
`ifdef TEST_DDC8_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD C8_1 (RET Z ; not taken)
	TESTCASE(" -- dd c8       ret z ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hc8); SETMEM(16'h01f7, 8'he9); SETMEM(16'h01f8, 8'haf);
	#(2* `CLKPERIOD * 9+`FIN)
	ASSERT(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDC8_1

`ifdef TEST_ALL
`define TEST_FDC8_1
`endif
`ifdef TEST_FDC8_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD C8_1 (RET Z ; not taken)
	TESTCASE(" -- fd c8       ret z ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hc8); SETMEM(16'h01f7, 8'he9); SETMEM(16'h01f8, 8'haf);
	#(2* `CLKPERIOD * 9+`FIN)
	ASSERT(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDC8_1

`ifdef TEST_ALL
`define TEST_C9
`endif
`ifdef TEST_C9
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE C9 (RET)
	TESTCASE(" -- c9          ret");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h00d8_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hc9); SETMEM(16'h01f7, 8'he9); SETMEM(16'h01f8, 8'haf);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h00d8_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f9_afe9, 8'h00, 8'h01, 2'b00);
`endif // TEST_C9

`ifdef TEST_ALL
`define TEST_DDC9
`endif
`ifdef TEST_DDC9
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD C9 (RET)
	TESTCASE(" -- dd c9       ret");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h00d8_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hc9); SETMEM(16'h01f7, 8'he9); SETMEM(16'h01f8, 8'haf);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h00d8_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f9_afe9, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDC9

`ifdef TEST_ALL
`define TEST_FDC9
`endif
`ifdef TEST_FDC9
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD C9 (RET)
	TESTCASE(" -- fd c9       ret");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h00d8_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hc9); SETMEM(16'h01f7, 8'he9); SETMEM(16'h01f8, 8'haf);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h00d8_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f9_afe9, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDC9

`ifdef TEST_ALL
`define TEST_CA
`endif
`ifdef TEST_CA
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CA_1 (JP Z,nn ; taken)
	TESTCASE(" -- ca          jp z,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h00c7_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hca); SETMEM(1, 8'h1b); SETMEM(2, 8'he1);
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h00c7_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_e11b, 8'h00, 8'h01, 2'b00);
`endif // TEST_CA

`ifdef TEST_ALL
`define TEST_DDCA
`endif
`ifdef TEST_DDCA
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CA_1 (JP Z,nn ; taken)
	TESTCASE(" -- dd ca       jp z,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h00c7_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hca); SETMEM(2, 8'h1b); SETMEM(3, 8'he1);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h00c7_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_e11b, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDCA

`ifdef TEST_ALL
`define TEST_FDCA
`endif
`ifdef TEST_FDCA
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD CA_1 (JP Z,nn ; taken)
	TESTCASE(" -- fd ca       jp z,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h00c7_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hca); SETMEM(2, 8'h1b); SETMEM(3, 8'he1);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h00c7_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_e11b, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDCA

`ifdef TEST_ALL
`define TEST_CA_1
`endif
`ifdef TEST_CA_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CA_2 (JP Z,nn ; not taken)
	TESTCASE(" -- ca          jp z,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hca); SETMEM(1, 8'h1b); SETMEM(2, 8'he1);
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h01, 2'b00);
`endif // TEST_CA_1

`ifdef TEST_ALL
`define TEST_DDCA_1
`endif
`ifdef TEST_DDCA_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CA_2 (JP Z,nn ; not taken)
	TESTCASE(" -- dd ca       jp z,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hca); SETMEM(2, 8'h1b); SETMEM(3, 8'he1);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDCA_1

`ifdef TEST_ALL
`define TEST_FDCA_1
`endif
`ifdef TEST_FDCA_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD CA_2 (JP Z,nn ; not taken)
	TESTCASE(" -- fd ca       jp z,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hca); SETMEM(2, 8'h1b); SETMEM(3, 8'he1);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDCA_1

`ifdef TEST_ALL
`define TEST_CC
`endif
`ifdef TEST_CC
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CC_1 (CALL Z,nn ; taken)
	TESTCASE(" -- cc          call z,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h004e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcc); SETMEM(1, 8'h1b); SETMEM(2, 8'he1); SETMEM('h0197, 8'hff);
	#(2* `CLKPERIOD * 17+`FIN)
	ASSERTMEM(16'h0198, 8'h03);
	ASSERTMEM(16'h0197, 8'h00);
	ASSERT(192'h004e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_e11b, 8'h00, 8'h01, 2'b00);
`endif // TEST_CC

`ifdef TEST_ALL
`define TEST_DDCC
`endif
`ifdef TEST_DDCC
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CC_1 (CALL Z,nn ; taken)
	TESTCASE(" -- dd cc       call z,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h004e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hcc); SETMEM(2, 8'h1b); SETMEM(3, 8'he1); SETMEM('h0197, 8'hff);
	#(2* `CLKPERIOD * 21+`FIN)
	ASSERTMEM(16'h0198, 8'h03);
	ASSERTMEM(16'h0197, 8'h00);
	ASSERT(192'h004e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_e11b, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDCC

`ifdef TEST_ALL
`define TEST_FDCC
`endif
`ifdef TEST_FDCC
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD CC_1 (CALL Z,nn ; taken)
	TESTCASE(" -- fd cc       call z,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h004e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hcc); SETMEM(2, 8'h1b); SETMEM(3, 8'he1); SETMEM('h0197, 8'hff);
	#(2* `CLKPERIOD * 21+`FIN)
	ASSERTMEM(16'h0198, 8'h03);
	ASSERTMEM(16'h0197, 8'h00);
	ASSERT(192'h004e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_e11b, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDCC

`ifdef TEST_ALL
`define TEST_CC_1
`endif
`ifdef TEST_CC_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CC_1 (CALL Z,nn ; taken)
	TESTCASE(" -- cc          call z,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcc); SETMEM(1, 8'h1b); SETMEM(2, 8'he1);
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0003, 8'h00, 8'h01, 2'b00);
`endif // TEST_CC_1

`ifdef TEST_ALL
`define TEST_DDCC_1
`endif
`ifdef TEST_DDCC_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CC_1 (CALL Z,nn ; taken)
	TESTCASE(" -- dd cc       call z,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hcc); SETMEM(2, 8'h1b); SETMEM(3, 8'he1);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDCC_1

`ifdef TEST_ALL
`define TEST_FDCC_1
`endif
`ifdef TEST_FDCC_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD CC_1 (CALL Z,nn ; taken)
	TESTCASE(" -- fd cc       call z,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hcc); SETMEM(2, 8'h1b); SETMEM(3, 8'he1);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDCC_1

`ifdef TEST_ALL
`define TEST_CD
`endif
`ifdef TEST_CD
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CD (CALL nn)
	TESTCASE(" -- cd          call $e11b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h004e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcd); SETMEM(1, 8'h1b); SETMEM(2, 8'he1); SETMEM('h0197, 8'hff);
	#(2* `CLKPERIOD * 17+`FIN)
	ASSERTMEM(16'h0198, 8'h03);
	ASSERTMEM(16'h0197, 8'h00);
	ASSERT(192'h004e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_e11b, 8'h00, 8'h01, 2'b00);
`endif // TEST_CD

`ifdef TEST_ALL
`define TEST_DDCD
`endif
`ifdef TEST_DDCD
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CD (CALL nn)
	TESTCASE(" -- dd cd       call $e11b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h004e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hcd); SETMEM(2, 8'h1b); SETMEM(3, 8'he1); SETMEM('h0197, 8'hff);
	#(2* `CLKPERIOD * 21+`FIN)
	ASSERTMEM(16'h0198, 8'h03);
	ASSERTMEM(16'h0197, 8'h00);
	ASSERT(192'h004e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_e11b, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDCD

`ifdef TEST_ALL
`define TEST_FDCD
`endif
`ifdef TEST_FDCD
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD CD (CALL nn)
	TESTCASE(" -- fd cd       call $e11b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h004e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hcd); SETMEM(2, 8'h1b); SETMEM(3, 8'he1); SETMEM('h0197, 8'hff);
	#(2* `CLKPERIOD * 21+`FIN)
	ASSERTMEM(16'h0198, 8'h03);
	ASSERTMEM(16'h0197, 8'h00);
	ASSERT(192'h004e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_e11b, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDCD

`ifdef TEST_ALL
`define TEST_CE
`endif
`ifdef TEST_CE
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CE (ADC a,n)
	TESTCASE(" -- ce          adc a,n");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hca01_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hce); SETMEM(1, 8'h6f);
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h3a39_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0002, 8'h00, 8'h01, 2'b00);
`endif // TEST_CE

`ifdef TEST_ALL
`define TEST_DDCE
`endif
`ifdef TEST_DDCE
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CE (ADC a,n)
	TESTCASE(" -- dd ce       adc a,n");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hca01_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hce); SETMEM(2, 8'h6f);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h3a39_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDCE

`ifdef TEST_ALL
`define TEST_FDCE
`endif
`ifdef TEST_FDCE
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD CE (ADC a,n)
	TESTCASE(" -- fd ce       adc a,n");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hca01_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hce); SETMEM(2, 8'h6f);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h3a39_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDCE

`ifdef TEST_ALL
`define TEST_CF
`endif
`ifdef TEST_CF
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CF (RST 08h)
	TESTCASE(" -- cf          rst 08h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0234, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(16'h0234, 8'hcf); SETMEM(16'h0197, 8'hff);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERTMEM(16'h0198, 8'h35);
	ASSERTMEM(16'h0197, 8'h02);
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_0008, 8'h00, 8'h01, 2'b00);
`endif // TEST_CF

`ifdef TEST_ALL
`define TEST_DDCF
`endif
`ifdef TEST_DDCF
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CF (RST 08h)
	TESTCASE(" -- dd cf       rst 08h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0234, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(16'h0234, 8'hdd); SETMEM(16'h0235, 8'hcf); SETMEM(16'h0197, 8'hff);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERTMEM(16'h0198, 8'h35);
	ASSERTMEM(16'h0197, 8'h02);
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_0008, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDCF

`ifdef TEST_ALL
`define TEST_FDCF
`endif
`ifdef TEST_FDCF
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD CF (RST 08h)
	TESTCASE(" -- fd cf       rst 08h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0234, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(16'h0234, 8'hfd); SETMEM(16'h0235, 8'hcf); SETMEM(16'h0197, 8'hff);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERTMEM(16'h0198, 8'h35);
	ASSERTMEM(16'h0197, 8'h02);
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_0008, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDCF

`ifdef TEST_ALL
`define TEST_D0
`endif
`ifdef TEST_D0
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE D0_1 (RET NC ; taken)
	TESTCASE(" -- d0          ret nc ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hd0); SETMEM(16'h01f7, 8'he9); SETMEM(16'h01f8, 8'haf);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f9_afe9, 8'h00, 8'h01, 2'b00);
`endif // TEST_D0

`ifdef TEST_ALL
`define TEST_DDD0
`endif
`ifdef TEST_DDD0
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD D0_1 (RET NC ; taken)
	TESTCASE(" -- dd d0       ret nc ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hd0); SETMEM(16'h01f7, 8'he9); SETMEM(16'h01f8, 8'haf);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f9_afe9, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDD0

`ifdef TEST_ALL
`define TEST_FDD0
`endif
`ifdef TEST_FDD0
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD D0_1 (RET NC ; taken)
	TESTCASE(" -- fd d0       ret nc ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hd0); SETMEM(16'h01f7, 8'he9); SETMEM(16'h01f8, 8'haf);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f9_afe9, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDD0

`ifdef TEST_ALL
`define TEST_D0_1
`endif
`ifdef TEST_D0_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE D0_1 (RET NC ; not taken)
	TESTCASE(" -- d0          ret nc ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0099_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hd0); SETMEM(16'h01f7, 8'he9); SETMEM(16'h01f8, 8'haf);
	#(2* `CLKPERIOD * 5+`FIN)
	ASSERT(192'h0099_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_D0_1

`ifdef TEST_ALL
`define TEST_DDD0_1
`endif
`ifdef TEST_DDD0_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD D0_1 (RET NC ; not taken)
	TESTCASE(" -- dd d0       ret nc ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0099_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hd0); SETMEM(16'h01f7, 8'he9); SETMEM(16'h01f8, 8'haf);
	#(2* `CLKPERIOD * 9+`FIN)
	ASSERT(192'h0099_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDD0_1

`ifdef TEST_ALL
`define TEST_FDD0_1
`endif
`ifdef TEST_FDD0_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD D0_1 (RET NC ; not taken)
	TESTCASE(" -- fd d0       ret nc ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0099_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hd0); SETMEM(16'h01f7, 8'he9); SETMEM(16'h01f8, 8'haf);
	#(2* `CLKPERIOD * 9+`FIN)
	ASSERT(192'h0099_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDD0_1

`ifdef TEST_ALL
`define TEST_D1
`endif
`ifdef TEST_D1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE C1 (POP DE)
	TESTCASE(" -- d1          pop de");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0143_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hd1); SETMEM(16'h0143, 8'hce); SETMEM(16'h0144, 8'he8);
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0000_0000_e8ce_0000_0000_0000_0000_0000_0000_0000_0145_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_D1

`ifdef TEST_ALL
`define TEST_DDD1
`endif
`ifdef TEST_DDD1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD C1 (POP DE)
	TESTCASE(" -- dd d1       pop de");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0143_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hd1); SETMEM(16'h0143, 8'hce); SETMEM(16'h0144, 8'he8);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0000_0000_e8ce_0000_0000_0000_0000_0000_0000_0000_0145_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDD1

`ifdef TEST_ALL
`define TEST_FDD1
`endif
`ifdef TEST_FDD1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD C1 (POP DE)
	TESTCASE(" -- fd d1       pop de");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0143_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hd1); SETMEM(16'h0143, 8'hce); SETMEM(16'h0144, 8'he8);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0000_0000_e8ce_0000_0000_0000_0000_0000_0000_0000_0145_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDD1

`ifdef TEST_ALL
`define TEST_D2
`endif
`ifdef TEST_D2
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE D2_1 (JP NC,nn ; taken)
	TESTCASE(" -- d2          jp nc,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0086_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hd2); SETMEM(1, 8'h1b); SETMEM(2, 8'he1);
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0086_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_e11b, 8'h00, 8'h01, 2'b00);
`endif // TEST_D2

`ifdef TEST_ALL
`define TEST_DDD2
`endif
`ifdef TEST_DDD2
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD D2_1 (JP NC,nn ; taken)
	TESTCASE(" -- dd d2       jp nc,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0086_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hd2); SETMEM(2, 8'h1b); SETMEM(3, 8'he1);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0086_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_e11b, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDD2

`ifdef TEST_ALL
`define TEST_FDD2
`endif
`ifdef TEST_FDD2
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD D2_1 (JP NC,nn ; taken)
	TESTCASE(" -- fd d2       jp nc,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0086_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hd2); SETMEM(2, 8'h1b); SETMEM(3, 8'he1);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0086_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_e11b, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDD2

`ifdef TEST_ALL
`define TEST_D2_1
`endif
`ifdef TEST_D2_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE D2_2 (JP NC,nn ; not taken)
	TESTCASE(" -- d2          jp nc,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hd2); SETMEM(1, 8'h1b); SETMEM(2, 8'he1);
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h01, 2'b00);
`endif // TEST_D2_1

`ifdef TEST_ALL
`define TEST_DDD2_1
`endif
`ifdef TEST_DDD2_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD D2_2 (JP NC,nn ; not taken)
	TESTCASE(" -- dd d2       jp nc,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hd2); SETMEM(2, 8'h1b); SETMEM(3, 8'he1);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDD2_1

`ifdef TEST_ALL
`define TEST_FDD2_1
`endif
`ifdef TEST_FDD2_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD D2_2 (JP NC,nn ; not taken)
	TESTCASE(" -- fd d2       jp nc,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hd2); SETMEM(2, 8'h1b); SETMEM(3, 8'he1);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDD2_1

`ifdef TEST_ALL
`define TEST_D3
`endif
`ifdef TEST_D3
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE D3 (OUT (n),a)
	TESTCASE(" -- d3          out ($18),a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha200_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hd3); SETMEM(1, 8'h18);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'ha200_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h01, 2'b00);
	if (io[8'h18] != 8'ha2) $display("* FAIL *: [IOWR] expected=a2, actual=%2h",io[8'h18]);
`endif // TEST_D3

`ifdef TEST_ALL
`define TEST_DDD3
`endif
`ifdef TEST_DDD3
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD D3 (OUT (n),a)
	TESTCASE(" -- dd d3       out ($18),a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha200_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hd3); SETMEM(2, 8'h18);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'ha200_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h02, 2'b00);
	if (io[8'h18] != 8'ha2) $display("* FAIL *: [IOWR] expected=a2, actual=%2h",io[8'h18]);
`endif // TEST_DDD3

`ifdef TEST_ALL
`define TEST_FDD3
`endif
`ifdef TEST_FDD3
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD D3 (OUT (n),a)
	TESTCASE(" -- fd d3       out ($18),a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha200_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hd3); SETMEM(2, 8'h18);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'ha200_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h02, 2'b00);
	if (io[8'h18] != 8'ha2) $display("* FAIL *: [IOWR] expected=a2, actual=%2h",io[8'h18]);
`endif // TEST_FDD3

`ifdef TEST_ALL
`define TEST_D4
`endif
`ifdef TEST_D4
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE D4_1 (CALL NC,nn ; taken)
	TESTCASE(" -- d4          call nc,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hd4); SETMEM(1, 8'h1b); SETMEM(2, 8'he1); SETMEM('h0197, 8'hff);
	#(2* `CLKPERIOD * 17+`FIN)
	ASSERTMEM(16'h0198, 8'h03);
	ASSERTMEM(16'h0197, 8'h00);
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_e11b, 8'h00, 8'h01, 2'b00);
`endif // TEST_D4

`ifdef TEST_ALL
`define TEST_DDD4
`endif
`ifdef TEST_DDD4
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD D4_1 (CALL NC,nn ; taken)
	TESTCASE(" -- dd d4       call nc,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hd4); SETMEM(2, 8'h1b); SETMEM(3, 8'he1); SETMEM('h0197, 8'hff);
	#(2* `CLKPERIOD * 21+`FIN)
	ASSERTMEM(16'h0198, 8'h03);
	ASSERTMEM(16'h0197, 8'h00);
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_e11b, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDD4

`ifdef TEST_ALL
`define TEST_FDD4
`endif
`ifdef TEST_FDD4
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD D4_1 (CALL NC,nn ; taken)
	TESTCASE(" -- fd d4       call nc,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hd4); SETMEM(2, 8'h1b); SETMEM(3, 8'he1); SETMEM('h0197, 8'hff);
	#(2* `CLKPERIOD * 21+`FIN)
	ASSERTMEM(16'h0198, 8'h03);
	ASSERTMEM(16'h0197, 8'h00);
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_e11b, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDD4

`ifdef TEST_ALL
`define TEST_D4_1
`endif
`ifdef TEST_D4_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE D4_1 (CALL NC,nn ; taken)
	TESTCASE(" -- d4          call nc,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h004f_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hd4); SETMEM(1, 8'h1b); SETMEM(2, 8'he1);
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h004f_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0003, 8'h00, 8'h01, 2'b00);
`endif // TEST_D4_1

`ifdef TEST_ALL
`define TEST_DDD4_1
`endif
`ifdef TEST_DDD4_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD D4_1 (CALL NC,nn ; taken)
	TESTCASE(" -- dd d4       call nc,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h004f_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hd4); SETMEM(2, 8'h1b); SETMEM(3, 8'he1);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h004f_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDD4_1

`ifdef TEST_ALL
`define TEST_FDD4_1
`endif
`ifdef TEST_FDD4_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD D4_1 (CALL NC,nn ; taken)
	TESTCASE(" -- fd d4       call nc,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h004f_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hd4); SETMEM(2, 8'h1b); SETMEM(3, 8'he1);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h004f_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDD4_1

`ifdef TEST_ALL
`define TEST_D5
`endif
`ifdef TEST_D5
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE D5 (PUSH DE)
	TESTCASE(" -- d5          push de");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h53e3_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hd5); SETMEM('h0197, 8'hff);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERTMEM(16'h0198, 8'h5f);
	ASSERTMEM(16'h0197, 8'h77);
	ASSERT(192'h53e3_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0196_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_D5

`ifdef TEST_ALL
`define TEST_DDD5
`endif
`ifdef TEST_DDD5
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD D5 (PUSH DE)
	TESTCASE(" -- dd d5       push de");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h53e3_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hd5); SETMEM('h0197, 8'hff);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERTMEM(16'h0198, 8'h5f);
	ASSERTMEM(16'h0197, 8'h77);
	ASSERT(192'h53e3_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0196_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDD5

`ifdef TEST_ALL
`define TEST_FDD5
`endif
`ifdef TEST_FDD5
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD D5 (PUSH DE)
	TESTCASE(" -- fd d5       push de");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h53e3_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hd5); SETMEM('h0197, 8'hff);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERTMEM(16'h0198, 8'h5f);
	ASSERTMEM(16'h0197, 8'h77);
	ASSERT(192'h53e3_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0196_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDD5

`ifdef TEST_ALL
`define TEST_D6
`endif
`ifdef TEST_D6
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE D6 (SUB n)
	TESTCASE(" -- d6          sub n");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h3901_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hd6); SETMEM(1, 8'hdf);
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h5a1b_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0002, 8'h00, 8'h01, 2'b00);
`endif // TEST_D6

`ifdef TEST_ALL
`define TEST_DDD6
`endif
`ifdef TEST_DDD6
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD D6 (SUB n)
	TESTCASE(" -- dd d6       sub n");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h3901_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hd6); SETMEM(2, 8'hdf);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h5a1b_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDD6

`ifdef TEST_ALL
`define TEST_FDD6
`endif
`ifdef TEST_FDD6
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD D6 (SUB n)
	TESTCASE(" -- fd d6       sub n");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h3901_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hd6); SETMEM(2, 8'hdf);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h5a1b_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDD6

`ifdef TEST_ALL
`define TEST_D7
`endif
`ifdef TEST_D7
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE D7 (RST 10h)
	TESTCASE(" -- d7          rst 10h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0234, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(16'h0234, 8'hd7); SETMEM(16'h0196, 8'hff); SETMEM(16'h0197, 8'hff);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERTMEM(16'h0196, 8'h35);
	ASSERTMEM(16'h0197, 8'h02);
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_0010, 8'h00, 8'h01, 2'b00);
`endif // TEST_D7

`ifdef TEST_ALL
`define TEST_DDD7
`endif
`ifdef TEST_DDD7
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD D7 (RST 10h)
	TESTCASE(" -- dd d7       rst 10h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0234, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(16'h0234, 8'hdd); SETMEM(16'h0235, 8'hd7); SETMEM(16'h0196, 8'hff); SETMEM(16'h0197, 8'hff);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERTMEM(16'h0196, 8'h36);
	ASSERTMEM(16'h0197, 8'h02);
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_0010, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDD7

`ifdef TEST_ALL
`define TEST_FDD7
`endif
`ifdef TEST_FDD7
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD D7 (RST 10h)
	TESTCASE(" -- fd d7       rst 10h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0234, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(16'h0234, 8'hfd); SETMEM(16'h0235, 8'hd7); SETMEM(16'h0196, 8'hff); SETMEM(16'h0197, 8'hff);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERTMEM(16'h0196, 8'h36);
	ASSERTMEM(16'h0197, 8'h02);
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_0010, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDD7

`ifdef TEST_ALL
`define TEST_D8
`endif
`ifdef TEST_D8
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE D8_1 (RET C ; taken)
	TESTCASE(" -- d8          ret c ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0099_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hd8); SETMEM(16'h01f7, 8'he9); SETMEM(16'h01f8, 8'haf);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h0099_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f9_afe9, 8'h00, 8'h01, 2'b00);
`endif // TEST_D8

`ifdef TEST_ALL
`define TEST_DDD8
`endif
`ifdef TEST_DDD8
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD D8_1 (RET C ; taken)
	TESTCASE(" -- dd d8       ret c ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0099_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hd8); SETMEM(16'h01f7, 8'he9); SETMEM(16'h01f8, 8'haf);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h0099_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f9_afe9, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDD8

`ifdef TEST_ALL
`define TEST_FDD8
`endif
`ifdef TEST_FDD8
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD D8_1 (RET C ; taken)
	TESTCASE(" -- fd d8       ret c ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0099_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hd8); SETMEM(16'h01f7, 8'he9); SETMEM(16'h01f8, 8'haf);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h0099_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f9_afe9, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDD8

`ifdef TEST_ALL
`define TEST_D8_1
`endif
`ifdef TEST_D8_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE D8_1 (RET C ; not taken)
	TESTCASE(" -- d8          ret c ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hd8); SETMEM(16'h01f7, 8'he9); SETMEM(16'h01f8, 8'haf);
	#(2* `CLKPERIOD * 5+`FIN)
	ASSERT(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_D8_1

`ifdef TEST_ALL
`define TEST_DDD8_1
`endif
`ifdef TEST_DDD8_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD D8_1 (RET C ; not taken)
	TESTCASE(" -- dd d8       ret c ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hd8); SETMEM(16'h01f7, 8'he9); SETMEM(16'h01f8, 8'haf);
	#(2* `CLKPERIOD * 9+`FIN)
	ASSERT(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDD8_1

`ifdef TEST_ALL
`define TEST_FDD8_1
`endif
`ifdef TEST_FDD8_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD D8_1 (RET C ; not taken)
	TESTCASE(" -- fd d8       ret c ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hd8); SETMEM(16'h01f7, 8'he9); SETMEM(16'h01f8, 8'haf);
	#(2* `CLKPERIOD * 9+`FIN)
	ASSERT(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDD8_1

`ifdef TEST_ALL
`define TEST_D9
`endif
`ifdef TEST_D9
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE D9 (EXX)
	TESTCASE(" -- d9          exx");
	// -----------------------------------------------------
	// -       AF    BC   DE   HL   AF'  BC'  DE'  HL'  IX   IY   SP   PC
	SETUP(192'h4d94_e07a_e35b_9d64_1a64_c930_3d01_7d02_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hd9);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h4d94_c930_3d01_7d02_1a64_e07a_e35b_9d64_0000_0000_01f7_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_D9

`ifdef TEST_ALL
`define TEST_DDD9
`endif
`ifdef TEST_DDD9
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD D9 (EXX)
	TESTCASE(" -- dd d9       exx");
	// -----------------------------------------------------
	// -       AF    BC   DE   HL   AF'  BC'  DE'  HL'  IX   IY   SP   PC
	SETUP(192'h4d94_e07a_e35b_9d64_1a64_c930_3d01_7d02_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hd9);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h4d94_c930_3d01_7d02_1a64_e07a_e35b_9d64_0000_0000_01f7_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDD9

`ifdef TEST_ALL
`define TEST_FDD9
`endif
`ifdef TEST_FDD9
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FF DD D9 (EXX)
	TESTCASE(" -- fd d9       exx");
	// -----------------------------------------------------
	// -       AF    BC   DE   HL   AF'  BC'  DE'  HL'  IX   IY   SP   PC
	SETUP(192'h4d94_e07a_e35b_9d64_1a64_c930_3d01_7d02_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hd9);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h4d94_c930_3d01_7d02_1a64_e07a_e35b_9d64_0000_0000_01f7_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDD9

`ifdef TEST_ALL
`define TEST_DA
`endif
`ifdef TEST_DA
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DA_1 (JP C,nn ; taken)
	TESTCASE(" -- da          jp c,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hda); SETMEM(1, 8'h1b); SETMEM(2, 8'he1);
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_e11b, 8'h00, 8'h01, 2'b00);
`endif // TEST_DA

`ifdef TEST_ALL
`define TEST_DDDA
`endif
`ifdef TEST_DDDA
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD DA_1 (JP C,nn ; taken)
	TESTCASE(" -- dd da       jp c,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hda); SETMEM(2, 8'h1b); SETMEM(3, 8'he1);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_e11b, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDDA

`ifdef TEST_ALL
`define TEST_FDDA
`endif
`ifdef TEST_FDDA
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD DA_1 (JP C,nn ; taken)
	TESTCASE(" -- fd da       jp c,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hda); SETMEM(2, 8'h1b); SETMEM(3, 8'he1);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_e11b, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDDA

`ifdef TEST_ALL
`define TEST_DA_1
`endif
`ifdef TEST_DA_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DA_2 (JP C,nn ; not taken)
	TESTCASE(" -- da          jp c,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0086_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hda); SETMEM(1, 8'h1b); SETMEM(2, 8'he1);
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0086_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h01, 2'b00);
`endif // TEST_DA_1

`ifdef TEST_ALL
`define TEST_DDDA_1
`endif
`ifdef TEST_DDDA_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD DA_2 (JP C,nn ; not taken)
	TESTCASE(" -- dd da       jp c,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0086_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hda); SETMEM(2, 8'h1b); SETMEM(3, 8'he1);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0086_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDDA_1

`ifdef TEST_ALL
`define TEST_FDDA_1
`endif
`ifdef TEST_FDDA_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD DA_2 (JP C,nn ; not taken)
	TESTCASE(" -- fd da       jp c,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0086_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hda); SETMEM(2, 8'h1b); SETMEM(3, 8'he1);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0086_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDDA_1

`ifdef TEST_ALL
`define TEST_DB
`endif
`ifdef TEST_DB
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DB (IN A,(n))
	TESTCASE(" -- db          in a,(n)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0086_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdb); SETMEM(1, 8'h1b); io[8'h1b] = 8'he1;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'he186_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h01, 2'b00);
`endif // TEST_DB

`ifdef TEST_ALL
`define TEST_DDDB
`endif
`ifdef TEST_DDDB
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD DB (IN A,(n))
	TESTCASE(" -- dd db       in a,(n)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0086_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hdb); SETMEM(2, 8'h1b); io[8'h1b] = 8'he1;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'he186_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDDB

`ifdef TEST_ALL
`define TEST_FDDB
`endif
`ifdef TEST_FDDB
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD DB (IN A,(n))
	TESTCASE(" -- fd db       in a,(n)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0086_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hdb); SETMEM(2, 8'h1b); io[8'h1b] = 8'he1;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'he186_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDDB

`ifdef TEST_ALL
`define TEST_DC
`endif
`ifdef TEST_DC
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DC_1 (CALL C,nn ; taken)
	TESTCASE(" -- dc          call c,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000f_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdc); SETMEM(1, 8'h1b); SETMEM(2, 8'he1); SETMEM(16'h0196, 8'hff); SETMEM(16'h0197, 8'hff);
	#(2* `CLKPERIOD * 17+`FIN)
	ASSERTMEM(16'h0196, 8'h03);
	ASSERTMEM(16'h0197, 8'h00);
	ASSERT(192'h000f_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_e11b, 8'h00, 8'h01, 2'b00);
`endif // TEST_DC

`ifdef TEST_ALL
`define TEST_DDDC
`endif
`ifdef TEST_DDDC
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD DC_1 (CALL C,nn ; taken)
	TESTCASE(" -- dd dc       call c,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000f_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hdc); SETMEM(2, 8'h1b); SETMEM(3, 8'he1); SETMEM(16'h0196, 8'hff); SETMEM(16'h0197, 8'hff);
	#(2* `CLKPERIOD * 21+`FIN)
	ASSERTMEM(16'h0196, 8'h04);
	ASSERTMEM(16'h0197, 8'h00);
	ASSERT(192'h000f_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_e11b, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDDC

`ifdef TEST_ALL
`define TEST_FDDC
`endif
`ifdef TEST_FDDC
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD DC_1 (CALL C,nn ; taken)
	TESTCASE(" -- fd dc       call c,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000f_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hdc); SETMEM(2, 8'h1b); SETMEM(3, 8'he1); SETMEM(16'h0196, 8'hff); SETMEM(16'h0197, 8'hff);
	#(2* `CLKPERIOD * 21+`FIN)
	ASSERTMEM(16'h0196, 8'h04);
	ASSERTMEM(16'h0197, 8'h00);
	ASSERT(192'h000f_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_e11b, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDDC

`ifdef TEST_ALL
`define TEST_DC_1
`endif
`ifdef TEST_DC_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DC_1 (CALL C,nn ; taken)
	TESTCASE(" -- dc          call c,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h004e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdc); SETMEM(1, 8'h1b); SETMEM(2, 8'he1);
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h004e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0003, 8'h00, 8'h01, 2'b00);
`endif // TEST_DC_1

`ifdef TEST_ALL
`define TEST_DDDC_1
`endif
`ifdef TEST_DDDC_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD DC_1 (CALL C,nn ; taken)
	TESTCASE(" -- dd dc       call c,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h004e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hdc); SETMEM(2, 8'h1b); SETMEM(3, 8'he1);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h004e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDDC_1

`ifdef TEST_ALL
`define TEST_FDDC_1
`endif
`ifdef TEST_FDDC_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD DC_1 (CALL C,nn ; taken)
	TESTCASE(" -- fd dc       call c,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h004e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hdc); SETMEM(2, 8'h1b); SETMEM(3, 8'he1);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h004e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDDC_1

`ifdef TEST_ALL
`define TEST_DE
`endif
`ifdef TEST_DE
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DE (SBC a,n)
	TESTCASE(" -- de          sbc a,n");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'he78d_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hde); SETMEM(1, 8'ha1);
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h4502_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0002, 8'h00, 8'h01, 2'b00);
`endif // TEST_DE

`ifdef TEST_ALL
`define TEST_DDDE
`endif
`ifdef TEST_DDDE
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD DE (SBC a,n)
	TESTCASE(" -- dd de       sbc a,n");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'he78d_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hde); SETMEM(2, 8'ha1);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h4502_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDDE

`ifdef TEST_ALL
`define TEST_FDDE
`endif
`ifdef TEST_FDDE
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD DE (SBC a,n)
	TESTCASE(" -- fd de       sbc a,n");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'he78d_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hde); SETMEM(2, 8'ha1);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h4502_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDDE

`ifdef TEST_ALL
`define TEST_DF
`endif
`ifdef TEST_DF
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DF (RST 18h)
	TESTCASE(" -- df          rst 18h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0234, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(16'h0234, 8'hdf);  SETMEM(16'h0196, 8'hff); SETMEM(16'h0197, 8'hff);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERTMEM(16'h0196, 8'h35);
	ASSERTMEM(16'h0197, 8'h02);
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_0018, 8'h00, 8'h01, 2'b00);
`endif // TEST_DF

`ifdef TEST_ALL
`define TEST_DDDF
`endif
`ifdef TEST_DDDF
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD DF (RST 18h)
	TESTCASE(" -- dd df       rst 18h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0233, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(16'h0233, 8'hdd); SETMEM(16'h0234, 8'hdf); SETMEM(16'h0196, 8'hff); SETMEM(16'h0197, 8'hff);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERTMEM(16'h0196, 8'h35);
	ASSERTMEM(16'h0197, 8'h02);
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_0018, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDDF

`ifdef TEST_ALL
`define TEST_FDDF
`endif
`ifdef TEST_FDDF
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD DF (RST 18h)
	TESTCASE(" -- fd df       rst 18h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0233, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(16'h0233, 8'hfd); SETMEM(16'h0234, 8'hdf); SETMEM(16'h0196, 8'hff); SETMEM(16'h0197, 8'hff);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERTMEM(16'h0196, 8'h35);
	ASSERTMEM(16'h0197, 8'h02);
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_0018, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDDF

`ifdef TEST_ALL
`define TEST_E0
`endif
`ifdef TEST_E0
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE E0_1 (RET PO ; taken)
	TESTCASE(" -- e0          ret po ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'he0); SETMEM(16'h01f7, 8'he9); SETMEM(16'h01f8, 8'haf);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f9_afe9, 8'h00, 8'h01, 2'b00);
`endif // TEST_E0

`ifdef TEST_ALL
`define TEST_DDE0
`endif
`ifdef TEST_DDE0
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD E0_1 (RET PO ; taken)
	TESTCASE(" -- dd e0       ret po ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'he0); SETMEM(16'h01f7, 8'he9); SETMEM(16'h01f8, 8'haf);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f9_afe9, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDE0

`ifdef TEST_ALL
`define TEST_FDE0
`endif
`ifdef TEST_FDE0
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD E0_1 (RET PO ; taken)
	TESTCASE(" -- fd e0       ret po ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'he0); SETMEM(16'h01f7, 8'he9); SETMEM(16'h01f8, 8'haf);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f9_afe9, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDE0

`ifdef TEST_ALL
`define TEST_E0_1
`endif
`ifdef TEST_E0_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE E0_1 (RET PO ; not taken)
	TESTCASE(" -- e0          ret po ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h009c_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'he0); SETMEM(16'h01f7, 8'he9); SETMEM(16'h01f8, 8'haf);
	#(2* `CLKPERIOD * 5+`FIN)
	ASSERT(192'h009c_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_E0_1

`ifdef TEST_ALL
`define TEST_DDE0_1
`endif
`ifdef TEST_DDE0_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD E0_1 (RET PO ; not taken)
	TESTCASE(" -- dd e0       ret po ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h009c_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'he0); SETMEM(16'h01f7, 8'he9); SETMEM(16'h01f8, 8'haf);
	#(2* `CLKPERIOD * 9+`FIN)
	ASSERT(192'h009c_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDE0_1

`ifdef TEST_ALL
`define TEST_FDE0_1
`endif
`ifdef TEST_FDE0_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD E0_1 (RET PO ; not taken)
	TESTCASE(" -- fd e0       ret po ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h009c_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'he0); SETMEM(16'h01f7, 8'he9); SETMEM(16'h01f8, 8'haf);
	#(2* `CLKPERIOD * 9+`FIN)
	ASSERT(192'h009c_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDE0_1

`ifdef TEST_ALL
`define TEST_E1
`endif
`ifdef TEST_E1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE E1 (POP HL)
	TESTCASE(" -- e1          pop hl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0143_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'he1); SETMEM(16'h0143, 8'hce); SETMEM(16'h0144, 8'he8);
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0000_0000_0000_e8ce_0000_0000_0000_0000_0000_0000_0145_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_E1

`ifdef TEST_ALL
`define TEST_DDE1
`endif
`ifdef TEST_DDE1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD E1 (POP IX)
	TESTCASE(" -- dd e1       pop ix");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0143_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'he1); SETMEM(16'h0143, 8'hce); SETMEM(16'h0144, 8'he8);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_e8ce_0000_0145_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDE1

`ifdef TEST_ALL
`define TEST_FDE1
`endif
`ifdef TEST_FDE1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD E1 (POP IY)
	TESTCASE(" -- fd e1       pop iy");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0143_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'he1); SETMEM(16'h0143, 8'hce); SETMEM(16'h0144, 8'he8);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_e8ce_0145_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDE1

`ifdef TEST_ALL
`define TEST_E2
`endif
`ifdef TEST_E2
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE E2_1 (JP PO,nn ; taken)
	TESTCASE(" -- e2          jp po,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0083_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'he2); SETMEM(1, 8'h1b); SETMEM(2, 8'he1);
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0083_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_e11b, 8'h00, 8'h01, 2'b00);
`endif // TEST_E2

`ifdef TEST_ALL
`define TEST_DDE2
`endif
`ifdef TEST_DDE2
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD E2_1 (JP PO,nn ; taken)
	TESTCASE(" -- dd e2       jp po,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0083_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'he2); SETMEM(2, 8'h1b); SETMEM(3, 8'he1);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0083_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_e11b, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDE2

`ifdef TEST_ALL
`define TEST_FDE2
`endif
`ifdef TEST_FDE2
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD E2_1 (JP PO,nn ; taken)
	TESTCASE(" -- fd e2       jp po,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0083_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'he2); SETMEM(2, 8'h1b); SETMEM(3, 8'he1);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0083_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_e11b, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDE2

`ifdef TEST_ALL
`define TEST_E2_1
`endif
`ifdef TEST_E2_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE E2_2 (JP PE,nn ; not taken)
	TESTCASE(" -- e2          jp po,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'he2); SETMEM(1, 8'h1b); SETMEM(2, 8'he1);
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h01, 2'b00);
`endif // TEST_E2_1

`ifdef TEST_ALL
`define TEST_DDE2_1
`endif
`ifdef TEST_DDE2_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD E2_2 (JP PE,nn ; not taken)
	TESTCASE(" -- dd e2       jp po,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'he2); SETMEM(2, 8'h1b); SETMEM(3, 8'he1);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDE2_1

`ifdef TEST_ALL
`define TEST_FDE2_1
`endif
`ifdef TEST_FDE2_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD E2_2 (JP PE,nn ; not taken)
	TESTCASE(" -- fd e2       jp po,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'he2); SETMEM(2, 8'h1b); SETMEM(3, 8'he1);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDE2_1

`ifdef TEST_ALL
`define TEST_E3
`endif
`ifdef TEST_E3
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE E3 (EX (SP),HL)
	TESTCASE(" -- e3          ex (sp),hl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000a_0000_0000_5432_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'he3); SETMEM('h0198, 8'h8e); SETMEM('h0199, 8'he1);
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERTMEM(16'h0198, 8'h32);
	ASSERTMEM(16'h0199, 8'h54);
	ASSERT(192'h000a_0000_0000_e18e_0000_0000_0000_0000_0000_0000_0198_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_E3

`ifdef TEST_ALL
`define TEST_DDE3
`endif
`ifdef TEST_DDE3
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD E3 (EX (SP),IX)
	TESTCASE(" -- dd e3       ex (sp),ix");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000a_0000_0000_5432_0000_0000_0000_0000_1234_5678_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'he3); SETMEM(16'h0198, 8'h8e); SETMEM(16'h0199, 8'he1);
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERTMEM(16'h0198, 8'h34);
	ASSERTMEM(16'h0199, 8'h12);
	ASSERT(192'h000a_0000_0000_5432_0000_0000_0000_0000_e18e_5678_0198_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDE3

`ifdef TEST_ALL
`define TEST_FDE3
`endif
`ifdef TEST_FDE3
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD E3 (EX (SP),IY)
	TESTCASE(" -- fd e3       ex (sp),iy");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000a_0000_0000_5432_0000_0000_0000_0000_1234_5678_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'he3); SETMEM(16'h0198, 8'h8e); SETMEM(16'h0199, 8'he1);
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERTMEM(16'h0198, 8'h78);
	ASSERTMEM(16'h0199, 8'h56);
	ASSERT(192'h000a_0000_0000_5432_0000_0000_0000_0000_1234_e18e_0198_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDE3

`ifdef TEST_ALL
`define TEST_E4
`endif
`ifdef TEST_E4
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE E4_1 (CALL PO,nn ; taken)
	TESTCASE(" -- e4          call po,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000a_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'he4); SETMEM(1, 8'h1b); SETMEM(2, 8'he1); SETMEM(16'h0196, 8'hff); SETMEM(16'h0197, 8'hff);
	#(2* `CLKPERIOD * 17+`FIN)
	ASSERTMEM(16'h0196, 8'h03);
	ASSERTMEM(16'h0197, 8'h00);
	ASSERT(192'h000a_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_e11b, 8'h00, 8'h01, 2'b00);
`endif // TEST_E4

`ifdef TEST_ALL
`define TEST_DDE4
`endif
`ifdef TEST_DDE4
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD E4_1 (CALL PO,nn ; taken)
	TESTCASE(" -- dd e4       call po,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000a_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'he4); SETMEM(2, 8'h1b); SETMEM(3, 8'he1); SETMEM(16'h0196, 8'hff); SETMEM(16'h0197, 8'hff);
	#(2* `CLKPERIOD * 21+`FIN)
	ASSERTMEM(16'h0196, 8'h04);
	ASSERTMEM(16'h0197, 8'h00);
	ASSERT(192'h000a_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_e11b, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDE4

`ifdef TEST_ALL
`define TEST_FDE4
`endif
`ifdef TEST_FDE4
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD E4_1 (CALL PO,nn ; taken)
	TESTCASE(" -- fd e4       call po,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000a_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'he4); SETMEM(2, 8'h1b); SETMEM(3, 8'he1); SETMEM(16'h0196, 8'hff); SETMEM(16'h0197, 8'hff);
	#(2* `CLKPERIOD * 21+`FIN)
	ASSERTMEM(16'h0196, 8'h04);
	ASSERTMEM(16'h0197, 8'h00);
	ASSERT(192'h000a_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_e11b, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDE4

`ifdef TEST_ALL
`define TEST_E4_1
`endif
`ifdef TEST_E4_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE E4_1 (CALL PO,nn ; taken)
	TESTCASE(" -- e4          call po,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'he4); SETMEM(1, 8'h1b); SETMEM(2, 8'he1);
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0003, 8'h00, 8'h01, 2'b00);
`endif // TEST_E4_1

`ifdef TEST_ALL
`define TEST_DDE4_1
`endif
`ifdef TEST_DDE4_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD E4_1 (CALL PO,nn ; taken)
	TESTCASE(" -- dd e4       call po,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'he4); SETMEM(2, 8'h1b); SETMEM(3, 8'he1);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDE4_1

`ifdef TEST_ALL
`define TEST_FDE4_1
`endif
`ifdef TEST_FDE4_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD E4_1 (CALL PO,nn ; taken)
	TESTCASE(" -- fd e4       call po,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'he4); SETMEM(2, 8'h1b); SETMEM(3, 8'he1);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDE4_1

`ifdef TEST_ALL
`define TEST_E5
`endif
`ifdef TEST_E5
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE E5 (PUSH HL)
	TESTCASE(" -- e5          push hl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h53e3_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'he5); SETMEM(16'h0197, 8'hff);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERTMEM(16'h0196, 8'h2f);
	ASSERTMEM(16'h0197, 8'h1a);
	ASSERT(192'h53e3_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0196_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_E5

`ifdef TEST_ALL
`define TEST_DDE5
`endif
`ifdef TEST_DDE5
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD E5 (PUSH IX)
	TESTCASE(" -- dd e5       push ix");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h53e3_1459_775f_dddd_0000_0000_0000_0000_1a2f_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'he5); SETMEM(16'h0196, 8'hff); SETMEM(16'h0197, 8'hff);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERTMEM(16'h0196, 8'h2f);
	ASSERTMEM(16'h0197, 8'h1a);
	ASSERT(192'h53e3_1459_775f_dddd_0000_0000_0000_0000_1a2f_0000_0196_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDE5

`ifdef TEST_ALL
`define TEST_FDE5
`endif
`ifdef TEST_FDE5
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD E5 (PUSH IX)
	TESTCASE(" -- fd e5       push iy");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h53e3_1459_775f_dddd_0000_0000_0000_0000_0000_1a2f_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'he5); SETMEM('h0196, 8'hff); SETMEM('h0197, 8'hff);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERTMEM(16'h0196, 8'h2f);
	ASSERTMEM(16'h0197, 8'h1a);
	ASSERT(192'h53e3_1459_775f_dddd_0000_0000_0000_0000_0000_1a2f_0196_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDE5

`ifdef TEST_ALL
`define TEST_E6
`endif
`ifdef TEST_E6
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE E6 (AND n)
	TESTCASE(" -- e6          and n");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h7500_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'he6); SETMEM(1, 8'h49);
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h4114_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0002, 8'h00, 8'h01, 2'b00);
`endif // TEST_E6

`ifdef TEST_ALL
`define TEST_DDE6
`endif
`ifdef TEST_DDE6
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD E6 (AND n)
	TESTCASE(" -- dd e6       and n");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h7500_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'he6); SETMEM(2, 8'h49);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h4114_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDE6

`ifdef TEST_ALL
`define TEST_FDE6
`endif
`ifdef TEST_FDE6
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD E6 (AND n)
	TESTCASE(" -- fd e6       and n");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h7500_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'he6); SETMEM(2, 8'h49);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h4114_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDE6

`ifdef TEST_ALL
`define TEST_E7
`endif
`ifdef TEST_E7
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE E7 (RST 20h)
	TESTCASE(" -- e7          rst 20h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0234, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(16'h0234, 8'he7); SETMEM(16'h0197, 8'hff);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERTMEM(16'h0196, 8'h35);
	ASSERTMEM(16'h0197, 8'h02);
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_0020, 8'h00, 8'h01, 2'b00);
`endif // TEST_E7

`ifdef TEST_ALL
`define TEST_DDE7
`endif
`ifdef TEST_DDE7
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD E7 (RST 20h)
	TESTCASE(" -- dd e7       rst 20h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0233, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(16'h0233, 8'hdd); SETMEM(16'h0234, 8'he7); SETMEM(16'h0197, 8'hff);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERTMEM(16'h0196, 8'h35);
	ASSERTMEM(16'h0197, 8'h02);
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_0020, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDE7

`ifdef TEST_ALL
`define TEST_FDE7
`endif
`ifdef TEST_FDE7
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD E7 (RST 20h)
	TESTCASE(" -- fd e7       rst 20h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0233, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(16'h0233, 8'hfd); SETMEM(16'h0234, 8'he7); SETMEM(16'h0197, 8'hff);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERTMEM(16'h0196, 8'h35);
	ASSERTMEM(16'h0197, 8'h02);
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_0020, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDE7

`ifdef TEST_ALL
`define TEST_E8
`endif
`ifdef TEST_E8
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE E8_1 (RET PE ; taken)
	TESTCASE(" -- e8          ret pe ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h009c_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'he8); SETMEM(16'h01f7, 8'he9); SETMEM(16'h01f8, 8'haf);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h009c_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f9_afe9, 8'h00, 8'h01, 2'b00);
`endif // TEST_E8

`ifdef TEST_ALL
`define TEST_DDE8
`endif
`ifdef TEST_DDE8
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD E8_1 (RET PE ; taken)
	TESTCASE(" -- dd e8       ret pe ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h009c_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'he8); SETMEM(16'h01f7, 8'he9); SETMEM(16'h01f8, 8'haf);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h009c_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f9_afe9, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDE8

`ifdef TEST_ALL
`define TEST_FDE8
`endif
`ifdef TEST_FDE8
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD E8_1 (RET PE ; taken)
	TESTCASE(" -- fd e8       ret pe ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h009c_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'he8); SETMEM(16'h01f7, 8'he9); SETMEM(16'h01f8, 8'haf);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h009c_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f9_afe9, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDE8

`ifdef TEST_ALL
`define TEST_E8_1
`endif
`ifdef TEST_E8_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE E8_1 (RET PE ; not taken)
	TESTCASE(" -- e8          ret pe ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'he8); SETMEM(16'h01f7, 8'he9); SETMEM(16'h01f8, 8'haf);
	#(2* `CLKPERIOD * 5+`FIN)
	ASSERT(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_E8_1

`ifdef TEST_ALL
`define TEST_DDE8_1
`endif
`ifdef TEST_DDE8_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD E8_1 (RET PE ; not taken)
	TESTCASE(" -- dd e8       ret pe ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'he8); SETMEM(16'h01f7, 8'he9); SETMEM(16'h01f8, 8'haf);
	#(2* `CLKPERIOD * 9+`FIN)
	ASSERT(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDE8_1

`ifdef TEST_ALL
`define TEST_FDE8_1
`endif
`ifdef TEST_FDE8_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD E8_1 (RET PE ; not taken)
	TESTCASE(" -- fd e8       ret pe ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'he8); SETMEM(16'h01f7, 8'he9); SETMEM(16'h01f8, 8'haf);
	#(2* `CLKPERIOD * 9+`FIN)
	ASSERT(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDE8_1

`ifdef TEST_ALL
`define TEST_E9
`endif
`ifdef TEST_E9
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE E9 (JP (HL))
	TESTCASE(" -- e9          jp (hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0245_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'he9); SETMEM(16'h0245, 8'h1b); SETMEM(16'h0246, 8'he1);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0087_0000_0000_0245_0000_0000_0000_0000_0000_0000_0000_0245, 8'h00, 8'h01, 2'b00);
`endif // TEST_E9

`ifdef TEST_ALL
`define TEST_DDE9
`endif
`ifdef TEST_DDE9
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD E9 (JP (IX))
	TESTCASE(" -- dd e9       jp (ix)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0245_0000_0000_0000_0000_2345_6789_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'he9); SETMEM(16'h0245, 8'h1b); SETMEM(16'h0246, 8'he1);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0087_0000_0000_0245_0000_0000_0000_0000_2345_6789_0000_2345, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDE9

`ifdef TEST_ALL
`define TEST_FDE9
`endif
`ifdef TEST_FDE9
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD E9 (JP (IY))
	TESTCASE(" -- fd e9       jp (iy)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0245_0000_0000_0000_0000_2345_6789_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'he9); SETMEM(16'h0245, 8'h1b); SETMEM(16'h0246, 8'he1);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0087_0000_0000_0245_0000_0000_0000_0000_2345_6789_0000_6789, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDE9

`ifdef TEST_ALL
`define TEST_EA
`endif
`ifdef TEST_EA
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE EA_1 (JP PE,nn ; taken)
	TESTCASE(" -- ea          jp pe,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hea); SETMEM(1, 8'h1b); SETMEM(2, 8'he1);
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_e11b, 8'h00, 8'h01, 2'b00);
`endif // TEST_EA

`ifdef TEST_ALL
`define TEST_DDEA
`endif
`ifdef TEST_DDEA
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD EA_1 (JP PE,nn ; taken)
	TESTCASE(" -- dd ea       jp pe,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hea); SETMEM(2, 8'h1b); SETMEM(3, 8'he1);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_e11b, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDEA

`ifdef TEST_ALL
`define TEST_FDEA
`endif
`ifdef TEST_FDEA
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD EA_1 (JP PE,nn ; taken)
	TESTCASE(" -- fd ea       jp pe,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hea); SETMEM(2, 8'h1b); SETMEM(3, 8'he1);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_e11b, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDEA

`ifdef TEST_ALL
`define TEST_EA_1
`endif
`ifdef TEST_EA_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE EA_2 (JP PE,nn ; not taken)
	TESTCASE(" -- ea          jp pe,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0083_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hea); SETMEM(1, 8'h1b); SETMEM(2, 8'he1);
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0083_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h01, 2'b00);
`endif // TEST_EA_1

`ifdef TEST_ALL
`define TEST_DDEA_1
`endif
`ifdef TEST_DDEA_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD EA_2 (JP PE,nn ; not taken)
	TESTCASE(" -- dd ea       jp pe,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0083_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hea); SETMEM(2, 8'h1b); SETMEM(3, 8'he1);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0083_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDEA_1

`ifdef TEST_ALL
`define TEST_FDEA_1
`endif
`ifdef TEST_FDEA_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD EA_2 (JP PE,nn ; not taken)
	TESTCASE(" -- fd ea       jp pe,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0083_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hea); SETMEM(2, 8'h1b); SETMEM(3, 8'he1);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0083_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDEA_1

`ifdef TEST_ALL
`define TEST_EB
`endif
`ifdef TEST_EB
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE EB (EX DE,HL)
	TESTCASE(" -- eb          ex de,hl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_6789_0245_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'heb);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0087_0000_0245_6789_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_EB

`ifdef TEST_ALL
`define TEST_DDEB
`endif
`ifdef TEST_DDEB
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD EB (EX DE,HL)
	TESTCASE(" -- dd eb       ex de,hl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_6789_0245_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'heb);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0087_0000_0245_6789_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDEB

`ifdef TEST_ALL
`define TEST_FDEB
`endif
`ifdef TEST_FDEB
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD EB (EX DE,HL)
	TESTCASE(" -- fd eb       ex de,hl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_6789_0245_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'heb);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0087_0000_0245_6789_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDEB

`ifdef TEST_ALL
`define TEST_EC
`endif
`ifdef TEST_EC
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE EC_1 (CALL PE,nn ; taken)
	TESTCASE(" -- ec          call pe,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hec); SETMEM(1, 8'h1b); SETMEM(2, 8'he1); SETMEM(16'h0197, 8'hff);
	#(2* `CLKPERIOD * 17+`FIN)
	ASSERTMEM(16'h0196, 8'h03);
	ASSERTMEM(16'h0197, 8'h00);
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_e11b, 8'h00, 8'h01, 2'b00);
`endif // TEST_EC

`ifdef TEST_ALL
`define TEST_DDEC
`endif
`ifdef TEST_DDEC
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD EC_1 (CALL PE,nn ; taken)
	TESTCASE(" -- dd ec       call pe,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hec); SETMEM(2, 8'h1b); SETMEM(3, 8'he1); SETMEM(16'h0196, 8'hff); SETMEM(16'h0197, 8'hff);
	#(2* `CLKPERIOD * 21+`FIN)
	ASSERTMEM(16'h0196, 8'h04);
	ASSERTMEM(16'h0197, 8'h00);
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_e11b, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDEC

`ifdef TEST_ALL
`define TEST_FDEC
`endif
`ifdef TEST_FDEC
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD EC_1 (CALL PE,nn ; taken)
	TESTCASE(" -- fd ec       call pe,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hec); SETMEM(2, 8'h1b); SETMEM(3, 8'he1); SETMEM(16'h0196, 8'hff); SETMEM(16'h0197, 8'hff);
	#(2* `CLKPERIOD * 21+`FIN)
	ASSERTMEM(16'h0196, 8'h04);
	ASSERTMEM(16'h0197, 8'h00);
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_e11b, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDEC

`ifdef TEST_ALL
`define TEST_EC_1
`endif
`ifdef TEST_EC_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE EC_1 (CALL PE,nn ; taken)
	TESTCASE(" -- ec          call pe,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000a_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hec); SETMEM(1, 8'h1b); SETMEM(2, 8'he1);
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h000a_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0003, 8'h00, 8'h01, 2'b00);
`endif // TEST_EC_1

`ifdef TEST_ALL
`define TEST_DDEC_1
`endif
`ifdef TEST_DDEC_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD EC_1 (CALL PE,nn ; taken)
	TESTCASE(" -- dd ec       call pe,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000a_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hec); SETMEM(2, 8'h1b); SETMEM(3, 8'he1);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h000a_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDEC_1

`ifdef TEST_ALL
`define TEST_FDEC_1
`endif
`ifdef TEST_FDEC_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD EC_1 (CALL PE,nn ; taken)
	TESTCASE(" -- fd ec       call pe,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000a_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hec); SETMEM(2, 8'h1b); SETMEM(3, 8'he1);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h000a_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDEC_1

`ifdef TEST_ALL
`define TEST_EE
`endif
`ifdef TEST_EE
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE EE (XOR n)
	TESTCASE(" -- ee          xor n");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h3e00_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hee); SETMEM(1, 8'hd0);
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'heeac_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0002, 8'h00, 8'h01, 2'b00);
`endif // TEST_EE

`ifdef TEST_ALL
`define TEST_DDEE
`endif
`ifdef TEST_DDEE
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD EE (XOR n)
	TESTCASE(" -- dd ee       xor n");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h3e00_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hee); SETMEM(2, 8'hd0);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'heeac_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDEE

`ifdef TEST_ALL
`define TEST_FDEE
`endif
`ifdef TEST_FDEE
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD EE (XOR n)
	TESTCASE(" -- fd ee       xor n");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h3e00_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hee); SETMEM(2, 8'hd0);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'heeac_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDEE

`ifdef TEST_ALL
`define TEST_EF
`endif
`ifdef TEST_EF
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE EF (RST 28h)
	TESTCASE(" -- ef          rst 28h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0234, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(16'h0234, 8'hef); SETMEM(16'h0197, 8'hff);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERTMEM(16'h0196, 8'h35);
	ASSERTMEM(16'h0197, 8'h02);
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_0028, 8'h00, 8'h01, 2'b00);
`endif // TEST_EF

`ifdef TEST_ALL
`define TEST_DDEF
`endif
`ifdef TEST_DDEF
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD EF (RST 28h)
	TESTCASE(" -- dd ef       rst 28h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0233, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(16'h0233, 8'hdd); SETMEM(16'h0234, 8'hef); SETMEM(16'h0196, 8'hff); SETMEM(16'h0197, 8'hff);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERTMEM(16'h0196, 8'h35);
	ASSERTMEM(16'h0197, 8'h02);
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_0028, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDEF

`ifdef TEST_ALL
`define TEST_FDEF
`endif
`ifdef TEST_FDEF
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD EF (RST 28h)
	TESTCASE(" -- fd ef       rst 28h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0233, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(16'h0233, 8'hfd); SETMEM(16'h0234, 8'hef); SETMEM(16'h0196, 8'hff); SETMEM(16'h0197, 8'hff);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERTMEM(16'h0196, 8'h35);
	ASSERTMEM(16'h0197, 8'h02);
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_0028, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDEF

`ifdef TEST_ALL
`define TEST_F0
`endif
`ifdef TEST_F0
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE F0_1 (RET P ; taken)
	TESTCASE(" -- f0          ret p ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0018_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hf0); SETMEM(16'h01f7, 8'he9); SETMEM(16'h01f8, 8'haf);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h0018_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f9_afe9, 8'h00, 8'h01, 2'b00);
`endif // TEST_F0

`ifdef TEST_ALL
`define TEST_DDF0
`endif
`ifdef TEST_DDF0
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD F0_1 (RET P ; taken)
	TESTCASE(" -- dd f0       ret p ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0018_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hf0); SETMEM(16'h01f7, 8'he9); SETMEM(16'h01f8, 8'haf);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h0018_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f9_afe9, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDF0

`ifdef TEST_ALL
`define TEST_FDF0
`endif
`ifdef TEST_FDF0
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD F0_1 (RET P ; taken)
	TESTCASE(" -- fd f0       ret p ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0018_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hf0); SETMEM(16'h01f7, 8'he9); SETMEM(16'h01f8, 8'haf);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h0018_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f9_afe9, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDF0

`ifdef TEST_ALL
`define TEST_F0_1
`endif
`ifdef TEST_F0_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE F0_1 (RET P ; not taken)
	TESTCASE(" -- f0          ret p ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hf0); SETMEM(16'h01f7, 8'he9); SETMEM(16'h01f8, 8'haf);
	#(2* `CLKPERIOD * 5+`FIN)
	ASSERT(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_F0_1

`ifdef TEST_ALL
`define TEST_DDF0_1
`endif
`ifdef TEST_DDF0_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD F0_1 (RET P ; not taken)
	TESTCASE(" -- dd f0       ret p ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hf0); SETMEM(16'h01f7, 8'he9); SETMEM(16'h01f8, 8'haf);
	#(2* `CLKPERIOD * 9+`FIN)
	ASSERT(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDF0_1

`ifdef TEST_ALL
`define TEST_FDF0_1
`endif
`ifdef TEST_FDF0_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD F0_1 (RET P ; not taken)
	TESTCASE(" -- fd f0       ret p ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hf0); SETMEM(16'h01f7, 8'he9); SETMEM(16'h01f8, 8'haf);
	#(2* `CLKPERIOD * 9+`FIN)
	ASSERT(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDF0_1

`ifdef TEST_ALL
`define TEST_F1
`endif
`ifdef TEST_F1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE F1 (POP AF)
	TESTCASE(" -- f1          pop af");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0143_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hf1); SETMEM(16'h0143, 8'hce); SETMEM(16'h0144, 8'he8);
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'he8ce_0000_0000_0000_0000_0000_0000_0000_0000_0000_0145_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_F1

`ifdef TEST_ALL
`define TEST_DDF1
`endif
`ifdef TEST_DDF1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD F1 (POP AF)
	TESTCASE(" -- dd f1       pop af");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0143_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hf1); SETMEM(16'h0143, 8'hce); SETMEM(16'h0144, 8'he8);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'he8ce_0000_0000_0000_0000_0000_0000_0000_0000_0000_0145_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDF1

`ifdef TEST_ALL
`define TEST_FDF1
`endif
`ifdef TEST_FDF1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD F1 (POP AF)
	TESTCASE(" -- fd f1       pop af");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0143_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hf1); SETMEM(16'h0143, 8'hce); SETMEM(16'h0144, 8'he8);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'he8ce_0000_0000_0000_0000_0000_0000_0000_0000_0000_0145_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDF1

`ifdef TEST_ALL
`define TEST_F2
`endif
`ifdef TEST_F2
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE F2_1 (JP P,nn ; taken)
	TESTCASE(" -- f2          jp p,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0007_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hf2); SETMEM(1, 8'h1b); SETMEM(2, 8'he1);
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0007_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_e11b, 8'h00, 8'h01, 2'b00);
`endif // TEST_F2

`ifdef TEST_ALL
`define TEST_DDF2
`endif
`ifdef TEST_DDF2
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD F2_1 (JP P,nn ; taken)
	TESTCASE(" -- dd f2       jp p,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0007_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hf2); SETMEM(2, 8'h1b); SETMEM(3, 8'he1);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0007_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_e11b, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDF2

`ifdef TEST_ALL
`define TEST_FDF2
`endif
`ifdef TEST_FDF2
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD F2_1 (JP P,nn ; taken)
	TESTCASE(" -- fd f2       jp p,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0007_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hf2); SETMEM(2, 8'h1b); SETMEM(3, 8'he1);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0007_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_e11b, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDF2

`ifdef TEST_ALL
`define TEST_F2_1
`endif
`ifdef TEST_F2_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE F2_2 (JP P,nn ; not taken)
	TESTCASE(" -- f2          jp p,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hf2); SETMEM(1, 8'h1b); SETMEM(2, 8'he1);
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h01, 2'b00);
`endif // TEST_F2_1

`ifdef TEST_ALL
`define TEST_DDF2_1
`endif
`ifdef TEST_DDF2_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD F2_2 (JP P,nn ; not taken)
	TESTCASE(" -- dd f2       jp p,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hf2); SETMEM(2, 8'h1b); SETMEM(3, 8'he1);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDF2_1

`ifdef TEST_ALL
`define TEST_FDF2_1
`endif
`ifdef TEST_FDF2_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD F2_2 (JP P,nn ; not taken)
	TESTCASE(" -- fd f2       jp p,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hf2); SETMEM(2, 8'h1b); SETMEM(3, 8'he1);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDF2_1

`ifdef TEST_ALL
`define TEST_F3
`endif
`ifdef TEST_F3
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE F3 (DI)
	TESTCASE(" -- f3          di");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0245_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b11);
	// memory data
	SETMEM(0, 8'hf3);
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0087_0000_0000_0245_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_F3

`ifdef TEST_ALL
`define TEST_DDF3
`endif
`ifdef TEST_DDF3
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD F3 (DI)
	TESTCASE(" -- dd f3       di");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0245_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b11);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hf3);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0087_0000_0000_0245_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDF3

`ifdef TEST_ALL
`define TEST_FDF3
`endif
`ifdef TEST_FDF3
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD F3 (DI)
	TESTCASE(" -- fd f3       di");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0245_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b11);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hf3);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0087_0000_0000_0245_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDF3

`ifdef TEST_ALL
`define TEST_F4
`endif
`ifdef TEST_F4
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE F4_1 (CALL P,nn ; taken)
	TESTCASE(" -- f4          call p,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000a_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hf4); SETMEM(1, 8'h1b); SETMEM(2, 8'he1); SETMEM('h0197, 8'hff);
	#(2* `CLKPERIOD * 17+`FIN)
	ASSERTMEM(16'h0196, 8'h03);
	ASSERTMEM(16'h0197, 8'h00);
	ASSERT(192'h000a_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_e11b, 8'h00, 8'h01, 2'b00);
`endif // TEST_F4

`ifdef TEST_ALL
`define TEST_DDF4
`endif
`ifdef TEST_DDF4
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD F4_1 (CALL P,nn ; taken)
	TESTCASE(" -- dd f4       call p,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000a_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hf4); SETMEM(2, 8'h1b); SETMEM(3, 8'he1); SETMEM('h0196, 8'hff); SETMEM(16'h0197, 8'hff);
	#(2* `CLKPERIOD * 21+`FIN)
	ASSERTMEM(16'h0196, 8'h04);
	ASSERTMEM(16'h0197, 8'h00);
	ASSERT(192'h000a_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_e11b, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDF4

`ifdef TEST_ALL
`define TEST_FDF4
`endif
`ifdef TEST_FDF4
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD F4_1 (CALL P,nn ; taken)
	TESTCASE(" -- fd f4       call p,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000a_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hf4); SETMEM(2, 8'h1b); SETMEM(3, 8'he1); SETMEM(16'h0196, 8'hff); SETMEM(16'h0197, 8'hff);
	#(2* `CLKPERIOD * 21+`FIN)
	ASSERTMEM(16'h0196, 8'h04);
	ASSERTMEM(16'h0197, 8'h00);
	ASSERT(192'h000a_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_e11b, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDF4

`ifdef TEST_ALL
`define TEST_F4_1
`endif
`ifdef TEST_F4_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE F4_1 (CALL P,nn ; taken)
	TESTCASE(" -- f4          call p,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h008e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hf4); SETMEM(1, 8'h1b); SETMEM(2, 8'he1);
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h008e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0003, 8'h00, 8'h01, 2'b00);
`endif // TEST_F4_1

`ifdef TEST_ALL
`define TEST_DDF4_1
`endif
`ifdef TEST_DDF4_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD F4_1 (CALL P,nn ; taken)
	TESTCASE(" -- dd f4       call p,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h008e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hf4); SETMEM(2, 8'h1b); SETMEM(3, 8'he1);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h008e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDF4_1

`ifdef TEST_ALL
`define TEST_FDF4_1
`endif
`ifdef TEST_FDF4_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD F4_1 (CALL P,nn ; taken)
	TESTCASE(" -- fd f4       call p,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h008e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hf4); SETMEM(2, 8'h1b); SETMEM(3, 8'he1);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h008e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDF4_1

`ifdef TEST_ALL
`define TEST_F5
`endif
`ifdef TEST_F5
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE F5 (PUSH AF)
	TESTCASE(" -- f5          push af");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h53e3_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hf5); SETMEM(16'h0197, 8'hff);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERTMEM(16'h0196, 8'he3);
	ASSERTMEM(16'h0197, 8'h53);
	ASSERT(192'h53e3_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0196_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_F5

`ifdef TEST_ALL
`define TEST_DDF5
`endif
`ifdef TEST_DDF5
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD F5 (PUSH AF)
	TESTCASE(" -- dd f5       push af");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h53e3_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hf5); SETMEM('h0196, 8'hff); SETMEM(16'h0197, 8'hff);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERTMEM(16'h0196, 8'he3);
	ASSERTMEM(16'h0197, 8'h53);
	ASSERT(192'h53e3_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0196_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDF5

`ifdef TEST_ALL
`define TEST_FDF5
`endif
`ifdef TEST_FDF5
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD F5 (PUSH AF)
	TESTCASE(" -- fd f5       push af");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h53e3_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hf5); SETMEM(16'h0196, 8'hff);  SETMEM(16'h0197, 8'hff);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERTMEM(16'h0196, 8'he3);
	ASSERTMEM(16'h0197, 8'h53);
	ASSERT(192'h53e3_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0196_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDF5

`ifdef TEST_ALL
`define TEST_F6
`endif
`ifdef TEST_F6
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE F6 (OR n)
	TESTCASE(" -- f6          or n");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0600_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hf6); SETMEM(1, 8'ha7);
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'ha7a0_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0002, 8'h00, 8'h01, 2'b00);
`endif // TEST_F6

`ifdef TEST_ALL
`define TEST_DDF6
`endif
`ifdef TEST_DDF6
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD F6 (OR n)
	TESTCASE(" -- dd f6       or n");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0600_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hf6); SETMEM(2, 8'ha7);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'ha7a0_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDF6

`ifdef TEST_ALL
`define TEST_FDF6
`endif
`ifdef TEST_FDF6
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD F6 (OR n)
	TESTCASE(" -- fd f6       or n");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0600_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hf6); SETMEM(2, 8'ha7);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'ha7a0_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDF6

`ifdef TEST_ALL
`define TEST_F7
`endif
`ifdef TEST_F7
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE F7 (RST 30h)
	TESTCASE(" -- f7          rst 30h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0234, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(16'h0234, 8'hf7); SETMEM(16'h0197, 8'hff);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERTMEM(16'h0196, 8'h35);
	ASSERTMEM(16'h0197, 8'h02);
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_0030, 8'h00, 8'h01, 2'b00);
`endif // TEST_F7

`ifdef TEST_ALL
`define TEST_DDF7
`endif
`ifdef TEST_DDF7
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD F7 (RST 30h)
	TESTCASE(" -- dd f7       rst 30h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0233, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(16'h0233, 8'hdd); SETMEM(16'h0234, 8'hf7); SETMEM(16'h0196, 8'hff); SETMEM(16'h0197, 8'hff);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERTMEM(16'h0196, 8'h35);
	ASSERTMEM(16'h0197, 8'h02);
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_0030, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDF7

`ifdef TEST_ALL
`define TEST_FDF7
`endif
`ifdef TEST_FDF7
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD F7 (RST 30h)
	TESTCASE(" -- fd f7       rst 30h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0233, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(16'h0233, 8'hfd); SETMEM(16'h0234, 8'hf7); SETMEM(16'h0196, 8'hff); SETMEM(16'h0197, 8'hff);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERTMEM(16'h0196, 8'h35);
	ASSERTMEM(16'h0197, 8'h02);
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_0030, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDF7

`ifdef TEST_ALL
`define TEST_F8
`endif
`ifdef TEST_F8
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE F8_1 (RET M ; taken)
	TESTCASE(" -- f8          ret m ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hf8); SETMEM(16'h01f7, 8'he9); SETMEM(16'h01f8, 8'haf);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f9_afe9, 8'h00, 8'h01, 2'b00);
`endif // TEST_F8

`ifdef TEST_ALL
`define TEST_DDF8
`endif
`ifdef TEST_DDF8
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD F8_1 (RET M ; taken)
	TESTCASE(" -- dd f8       ret m ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hf8); SETMEM(16'h01f7, 8'he9); SETMEM(16'h01f8, 8'haf);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f9_afe9, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDF8

`ifdef TEST_ALL
`define TEST_FDF8
`endif
`ifdef TEST_FDF8
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD F8_1 (RET M ; taken)
	TESTCASE(" -- fd f8       ret m ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hf8); SETMEM(16'h01f7, 8'he9); SETMEM(16'h01f8, 8'haf);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f9_afe9, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDF8

`ifdef TEST_ALL
`define TEST_F8_1
`endif
`ifdef TEST_F8_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE F8_1 (RET M ; not taken)
	TESTCASE(" -- f8          ret m ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0018_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hf8); SETMEM(16'h01f7, 8'he9); SETMEM(16'h01f8, 8'haf);
	#(2* `CLKPERIOD * 5+`FIN)
	ASSERT(192'h0018_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_F8_1

`ifdef TEST_ALL
`define TEST_DDF8_1
`endif
`ifdef TEST_DDF8_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD F8_1 (RET M ; not taken)
	TESTCASE(" -- dd f8       ret m ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0018_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hf8); SETMEM(16'h01f7, 8'he9); SETMEM(16'h01f8, 8'haf);
	#(2* `CLKPERIOD * 9+`FIN)
	ASSERT(192'h0018_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDF8_1

`ifdef TEST_ALL
`define TEST_FDF8_1
`endif
`ifdef TEST_FDF8_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD F8_1 (RET M ; not taken)
	TESTCASE(" -- fd f8       ret m ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0018_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hf8); SETMEM(16'h01f7, 8'he9); SETMEM(16'h01f8, 8'haf);
	#(2* `CLKPERIOD * 9+`FIN)
	ASSERT(192'h0018_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDF8_1

`ifdef TEST_ALL
`define TEST_F9
`endif
`ifdef TEST_F9
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE F9 (LD SP,HL)
	TESTCASE(" -- f9          ld sp,hl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0018_0000_0000_2345_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hf9); 
	#(2* `CLKPERIOD * 6+`FIN)
	ASSERT(192'h0018_0000_0000_2345_0000_0000_0000_0000_0000_0000_2345_0001, 8'h00, 8'h01, 2'b00);
`endif // TEST_F9

`ifdef TEST_ALL
`define TEST_DDF9
`endif
`ifdef TEST_DDF9
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD F9 (LD SP,IX)
	TESTCASE(" -- dd f9       ld sp,ix");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0018_0000_0000_2345_0000_0000_0000_0000_5678_9abc_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hf9); 
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0018_0000_0000_2345_0000_0000_0000_0000_5678_9abc_5678_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDF9

`ifdef TEST_ALL
`define TEST_FDF9
`endif
`ifdef TEST_FDF9
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD F9 (LD SP,IY)
	TESTCASE(" -- fd f9       ld sp,iy");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0018_0000_0000_2345_0000_0000_0000_0000_5678_9abc_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hf9); 
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0018_0000_0000_2345_0000_0000_0000_0000_5678_9abc_9abc_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDF9

`ifdef TEST_ALL
`define TEST_FA
`endif
`ifdef TEST_FA
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FA_1 (JP M,nn ; taken)
	TESTCASE(" -- fa          jp m,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfa); SETMEM(1, 8'h1b); SETMEM(2, 8'he1);
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_e11b, 8'h00, 8'h01, 2'b00);
`endif // TEST_FA

`ifdef TEST_ALL
`define TEST_DDFA
`endif
`ifdef TEST_DDFA
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD FA_1 (JP M,nn ; taken)
	TESTCASE(" -- dd fa       jp m,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hfa); SETMEM(2, 8'h1b); SETMEM(3, 8'he1);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_e11b, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDFA

`ifdef TEST_ALL
`define TEST_FDFA
`endif
`ifdef TEST_FDFA
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD FA_1 (JP M,nn ; taken)
	TESTCASE(" -- fd fa       jp m,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hfa); SETMEM(2, 8'h1b); SETMEM(3, 8'he1);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_e11b, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDFA

`ifdef TEST_ALL
`define TEST_FA_1
`endif
`ifdef TEST_FA_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FA_2 (JP M,nn ; not taken)
	TESTCASE(" -- fa          jp m,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0077_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfa); SETMEM(1, 8'h1b); SETMEM(2, 8'he1);
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0077_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h01, 2'b00);
`endif // TEST_FA_1

`ifdef TEST_ALL
`define TEST_DDFA_1
`endif
`ifdef TEST_DDFA_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD FA_2 (JP M,nn ; not taken)
	TESTCASE(" -- dd fa       jp m,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0077_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hfa); SETMEM(2, 8'h1b); SETMEM(3, 8'he1);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0077_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDFA_1

`ifdef TEST_ALL
`define TEST_FDFA_1
`endif
`ifdef TEST_FDFA_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD FA_2 (JP M,nn ; not taken)
	TESTCASE(" -- fd fa       jp m,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0077_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hfa); SETMEM(2, 8'h1b); SETMEM(3, 8'he1);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0077_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDFA_1

`ifdef TEST_ALL
`define TEST_FB
`endif
`ifdef TEST_FB
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FB (EI)
	TESTCASE(" -- fb 00       ei nop");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0245_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfb); SETMEM(1, 8'h00);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0087_0000_0000_0245_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b11);
`endif // TEST_FB

`ifdef TEST_ALL
`define TEST_DDFB
`endif
`ifdef TEST_DDFB
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD FB (EI)
	TESTCASE(" -- dd fb 00    ei nop");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0245_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hfb); SETMEM(2, 8'h00);
	#(2* `CLKPERIOD * 12+`FIN)
	ASSERT(192'h0087_0000_0000_0245_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h03, 2'b11);
`endif // TEST_DDFB

`ifdef TEST_ALL
`define TEST_FDFB
`endif
`ifdef TEST_FDFB
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD FB (EI)
	TESTCASE(" -- fd fb 00    ei nop");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0245_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hfb); SETMEM(2, 8'h00);
	#(2* `CLKPERIOD * 12+`FIN)
	ASSERT(192'h0087_0000_0000_0245_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h03, 2'b11);
`endif // TEST_FDFB

`ifdef TEST_ALL
`define TEST_FC
`endif
`ifdef TEST_FC
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FC_1 (CALL M,nn ; taken)
	TESTCASE(" -- fc          call m,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h008a_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfc); SETMEM(1, 8'h1b); SETMEM(2, 8'he1); SETMEM(16'h0197, 8'hff);
	#(2* `CLKPERIOD * 17+`FIN)
	ASSERTMEM(16'h0196, 8'h03);
	ASSERTMEM(16'h0197, 8'h00);
	ASSERT(192'h008a_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_e11b, 8'h00, 8'h01, 2'b00);
`endif // TEST_FC

`ifdef TEST_ALL
`define TEST_DDFC
`endif
`ifdef TEST_DDFC
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD FC_1 (CALL M,nn ; taken)
	TESTCASE(" -- dd fc       call m,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h008a_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hfc); SETMEM(2, 8'h1b); SETMEM(3, 8'he1); SETMEM(16'h0196, 8'hff); SETMEM(16'h0197, 8'hff);
	#(2* `CLKPERIOD * 21+`FIN)
	ASSERTMEM(16'h0196, 8'h04);
	ASSERTMEM(16'h0197, 8'h00);
	ASSERT(192'h008a_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_e11b, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDFC

`ifdef TEST_ALL
`define TEST_FDFC
`endif
`ifdef TEST_FDFC
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD FC_1 (CALL M,nn ; taken)
	TESTCASE(" -- fd fc       call m,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h008a_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hfc); SETMEM(2, 8'h1b); SETMEM(3, 8'he1); SETMEM(16'h0196, 8'hff); SETMEM(16'h0197, 8'hff);
	#(2* `CLKPERIOD * 21+`FIN)
	ASSERTMEM(16'h0196, 8'h04);
	ASSERTMEM(16'h0197, 8'h00);
	ASSERT(192'h008a_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_e11b, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDFC

`ifdef TEST_ALL
`define TEST_FC_1
`endif
`ifdef TEST_FC_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FC_1 (CALL M,nn ; taken)
	TESTCASE(" -- fc          call m,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfc); SETMEM(1, 8'h1b); SETMEM(2, 8'he1);
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0003, 8'h00, 8'h01, 2'b00);
`endif // TEST_FC_1

`ifdef TEST_ALL
`define TEST_DDFC_1
`endif
`ifdef TEST_DDFC_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD FC_1 (CALL M,nn ; taken)
	TESTCASE(" -- dd fc       call m,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hfc); SETMEM(2, 8'h1b); SETMEM(3, 8'he1);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDFC_1

`ifdef TEST_ALL
`define TEST_FDFC_1
`endif
`ifdef TEST_FDFC_1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD FC_1 (CALL M,nn ; taken)
	TESTCASE(" -- fd fc       call m,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hfc); SETMEM(2, 8'h1b); SETMEM(3, 8'he1);
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDFC_1

`ifdef TEST_ALL
`define TEST_FE
`endif
`ifdef TEST_FE
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FE (CP n)
	TESTCASE(" -- fe          cp n");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6900_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfe); SETMEM(1, 8'h82);
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h6987_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0002, 8'h00, 8'h01, 2'b00);
`endif // TEST_FE

`ifdef TEST_ALL
`define TEST_DDFE
`endif
`ifdef TEST_DDFE
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD FE (CP n)
	TESTCASE(" -- dd fe       cp n");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6900_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hfe); SETMEM(2, 8'h82);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h6987_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDFE

`ifdef TEST_ALL
`define TEST_FDFE
`endif
`ifdef TEST_FDFE
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD FE (CP n)
	TESTCASE(" -- fd fe       cp n");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6900_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hfe); SETMEM(2, 8'h82);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h6987_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0003, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDFE

`ifdef TEST_ALL
`define TEST_FF
`endif
`ifdef TEST_FF
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FF (RST 38h)
	TESTCASE(" -- ff          rst 38h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0234, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(16'h0234, 8'hff); SETMEM(16'h0197, 8'hff);
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERTMEM(16'h0196, 8'h35);
	ASSERTMEM(16'h0197, 8'h02);
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_0038, 8'h00, 8'h01, 2'b00);
	if (FAIL) TESTCASE(" -- ff          rst 38h");
`endif // TEST_FF

`ifdef TEST_ALL
`define TEST_DDFF
`endif
`ifdef TEST_DDFF
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD FF (RST 38h)
	TESTCASE(" -- dd ff       rst 38h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0233, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(16'h0233, 8'hdd); SETMEM(16'h0234, 8'hff); SETMEM(16'h0196, 8'hff); SETMEM(16'h0197, 8'hff);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERTMEM(16'h0196, 8'h35);
	ASSERTMEM(16'h0197, 8'h02);
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_0038, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDFF

`ifdef TEST_ALL
`define TEST_FDFF
`endif
`ifdef TEST_FDFF
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD FF (RST 38h)
	TESTCASE(" -- fd ff       rst 38h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0233, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(16'h0233, 8'hfd); SETMEM(16'h0234, 8'hff); SETMEM(16'h0196, 8'hff); SETMEM(16'h0197, 8'hff);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERTMEM(16'h0196, 8'h35);
	ASSERTMEM(16'h0197, 8'h02);
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_0038, 8'h00, 8'h02, 2'b00);
	//if (FAIL) TESTCASE(" -- fd ff       rst 38h");
`endif // TEST_FDFF

// *****************************************************************************************************
//
//  BIT instructions (CB)
//
// *****************************************************************************************************
`ifdef TEST_ALL
`define TEST_CB00
`endif
`ifdef TEST_CB00
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 00 (RLC B)
	TESTCASE(" -- cb 00       rlc b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hda00_e479_552e_a806_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h00);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hda8d_c979_552e_a806_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB00

`ifdef TEST_ALL
`define TEST_DDCB00
`endif
`ifdef TEST_DDCB00
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CB 00 (RLC (IX+d),B)
	TESTCASE(" -- dd cb 00    rlc (ix+d),b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h3c65_f0e4_09d1_646b_0000_0000_0000_0000_1da1_f08f_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd);  SETMEM(1, 8'hcb);  SETMEM(2, 8'h0d);  SETMEM(3, 8'h00);
	SETMEM(16'h1dae, 8'ha1);
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERTMEM(16'h1dae, 8'h43);
	ASSERT(192'h3c01_43e4_09d1_646b_0000_0000_0000_0000_1da1_f08f_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB00

`ifdef TEST_ALL
`define TEST_CB01
`endif
`ifdef TEST_CB01
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 01 (RLC C)
	TESTCASE(" -- cb 01       rlc c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h1000_b379_552e_a806_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h01);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h10a0_b3f2_552e_a806_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB00

`ifdef TEST_ALL
`define TEST_DDCB01
`endif
`ifdef TEST_DDCB01
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CB 01 (RLC (IX+d),C)
	TESTCASE(" -- dd cb 01    rlc (ix+d),c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf68f_e33b_2d4a_7725_0000_0000_0000_0000_28fd_f31b_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd);  SETMEM(1, 8'hcb);  SETMEM(2, 8'hb7);  SETMEM(3, 8'h01);
	SETMEM(16'h28b4, 8'he3);
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERTMEM(16'h28b4, 8'hc7);
	ASSERT(192'hf681_e3c7_2d4a_7725_0000_0000_0000_0000_28fd_f31b_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDCB01

`ifdef TEST_ALL
`define TEST_CB02
`endif
`ifdef TEST_CB002
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 02 (RLC D)
	TESTCASE(" -- cb 02       rlc d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2e00_e479_ae6e_a806_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h02);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h2e09_e479_5d6e_a806_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB02

`ifdef TEST_ALL
`define TEST_DDCB02
`endif
`ifdef TEST_DDCB02
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CB 02 (RLC (IX+d),D)
	TESTCASE(" -- dd cb 02    rlc (ix+d),d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'he20c_836e_513a_f840_0000_0000_0000_0000_c796_ae9b_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd);  SETMEM(1, 8'hcb);  SETMEM(2, 8'h91);  SETMEM(3, 8'h02);
	SETMEM(16'hc727, 8'h8d);
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERT(192'he20d_836e_1b3a_f840_0000_0000_0000_0000_c796_ae9b_0000_0004, 8'h00, 8'h02, 2'b00);
	ASSERTMEM(16'hc727, 8'h1b);
`endif // TEST_DDCB02

`ifdef TEST_ALL
`define TEST_CB03
`endif
`ifdef TEST_CB003
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 03 (RLC E)
	TESTCASE(" -- cb 03       rlc e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6800_e479_de3f_a806_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h03);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h682c_e479_de7e_a806_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB03

`ifdef TEST_ALL
`define TEST_DDCB03
`endif
`ifdef TEST_DDCB03
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CB 03 (RLC (IX+d),E)
	TESTCASE(" -- dd cb 03    rlc (ix+d),e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6224_3571_c519_48dc_0000_0000_0000_0000_041e_c07b_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd);  SETMEM(1, 8'hcb);  SETMEM(2, 8'h48);  SETMEM(3, 8'h03);
	SETMEM(16'h0466, 8'h78);
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERTMEM(16'h0466, 8'hf0);
	ASSERT(192'h62a4_3571_c5f0_48dc_0000_0000_0000_0000_041e_c07b_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDCB03

`ifdef TEST_ALL
`define TEST_CB04
`endif
`ifdef TEST_CB004
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 04 (RLC H)
	TESTCASE(" -- cb 04       rlc h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h8c00_e479_552e_67b0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h04);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h8c88_e479_552e_ceb0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB04

`ifdef TEST_ALL
`define TEST_DDCB04
`endif
`ifdef TEST_DDCB04
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CB 04 (RLC (IX+d),H)
	TESTCASE(" -- dd cb 04    rlc (ix+d),h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hb310_bfc4_64af_d622_0000_0000_0000_0000_5949_a989_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd);  SETMEM(1, 8'hcb);  SETMEM(2, 8'h48);  SETMEM(3, 8'h04);
	SETMEM(16'h5991, 8'h68);
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERTMEM(16'h5991, 8'hd0);
	ASSERT(192'hb380_bfc4_64af_d022_0000_0000_0000_0000_5949_a989_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDCB04

`ifdef TEST_ALL
`define TEST_CB05
`endif
`ifdef TEST_CB05
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 05 (RLC L)
	TESTCASE(" -- cb 05       rlc l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h3600_e479_552e_cb32_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h05);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h3620_e479_552e_cb64_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB05

`ifdef TEST_ALL
`define TEST_DDCB05
`endif
`ifdef TEST_DDCB05
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CB 05 (RLC (IX+d),L)
	TESTCASE(" -- dd cb 05    rlc (ix+d),l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0cf4_f636_90a6_6117_0000_0000_0000_0000_5421_90ee_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd);  SETMEM(1, 8'hcb);  SETMEM(2, 8'h07);  SETMEM(3, 8'h05);
	SETMEM(16'h5428, 8'h97);
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERTMEM(16'h5428, 8'h2f);
	ASSERT(192'h0c29_f636_90a6_612f_0000_0000_0000_0000_5421_90ee_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDCB05

`ifdef TEST_ALL
`define TEST_CB06
`endif
`ifdef TEST_CB06
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 06 (RLC (HL))
	TESTCASE(" -- cb 06       rlc (hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h8a00_e479_552e_0106_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h06); SETMEM(16'h0106, 8'hd4);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERTMEM(16'h0106, 8'ha9);
	ASSERT(192'h8aad_e479_552e_0106_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB06

`ifdef TEST_ALL
`define TEST_DDCB06
`endif
`ifdef TEST_DDCB06
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CB 06 (RLC C)
	TESTCASE(" -- dd cb 06    rlc (ix+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0cf4_f636_90a6_6117_0000_0000_0000_0000_5421_90ee_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hcb);  SETMEM(2, 8'h07); SETMEM(3, 8'h06);
	SETMEM(16'h5428, 8'h97);
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERTMEM(16'h5428, 8'h2f);
	ASSERT(192'h0c29_f636_90a6_6117_0000_0000_0000_0000_5421_90ee_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDCB06

`ifdef TEST_ALL
`define TEST_FDCB06
`endif
`ifdef TEST_FDCB06
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD CB 06 (RLC C)
	TESTCASE(" -- fd cb 06    rlc (iy+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf285_89a2_e78f_ef74_0000_0000_0000_0000_140d_ff27_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hfd); SETMEM(1, 8'hcb);  SETMEM(2, 8'h72); SETMEM(3, 8'h06);
	SETMEM(16'hff99, 8'hf1);
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERTMEM(16'hff99, 8'he3);
	ASSERT(192'hf2a1_89a2_e78f_ef74_0000_0000_0000_0000_140d_ff27_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_FDCB06

`ifdef TEST_ALL
`define TEST_CB07
`endif
`ifdef TEST_CB007
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 07 (RLC A)
	TESTCASE(" -- cb 07       rlc a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6d00_e479_552e_a806_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h07);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hda88_e479_552e_a806_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB07

`ifdef TEST_ALL
`define TEST_DDCB07
`endif
`ifdef TEST_DDCB07
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CB 07 (RLC (IX+d),L)
	TESTCASE(" -- dd cb 07    rlc (ix+d),a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6f4d_9ca3_bdf6_ed50_0000_0000_0000_0000_9803_55f9_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd);  SETMEM(1, 8'hcb);  SETMEM(2, 8'h42);  SETMEM(3, 8'h07);
	SETMEM(16'h9845, 8'hae);
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERTMEM(16'h9845, 8'h5d);
	ASSERT(192'h5d09_9ca3_bdf6_ed50_0000_0000_0000_0000_9803_55f9_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDCB07

`ifdef TEST_ALL
`define TEST_CB08
`endif
`ifdef TEST_CB08
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 08 (RRC B)
	TESTCASE(" -- cb 08       rrc b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h8000_cdb5_818e_2ee2_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h08);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h80a1_e6b5_818e_2ee2_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB08

`ifdef TEST_ALL
`define TEST_DDCB08
`endif
`ifdef TEST_DDCB08
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CB 08 (RRC (IX+d),b)
	TESTCASE(" -- dd cb 08    rrc (ix+d),b (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h02f4_1c66_6023_ae06_0000_0000_0000_0000_ef40_b006_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hcb);  SETMEM(2, 8'h0a); SETMEM(3, 8'h08);
	SETMEM(16'hef4a, 8'hda);
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERTMEM(16'hef4a, 8'h6d);
	ASSERT(192'h0228_6d66_6023_ae06_0000_0000_0000_0000_ef40_b006_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDCB08

`ifdef TEST_ALL
`define TEST_CB09
`endif
`ifdef TEST_CB09
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 09 (RRC C)
	TESTCASE(" -- cb 09       rrc c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h1800_125c_dd97_59c6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h09);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h182c_122e_dd97_59c6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB09

`ifdef TEST_ALL
`define TEST_DDCB09
`endif
`ifdef TEST_DDCB09
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CB 09 (RRC (IX+d),c)
	TESTCASE(" -- dd cb 09    rrc (ix+d),c (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9825_9258_54d5_5e1e_0000_0000_0000_0000_9d0b_6e58_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hcb);  SETMEM(2, 8'h3b); SETMEM(3, 8'h09);
	SETMEM(16'h9d46, 8'h6f);
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERTMEM(16'h9d46, 8'hb7);
	ASSERT(192'h98a5_92b7_54d5_5e1e_0000_0000_0000_0000_9d0b_6e58_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDCB09

`ifdef TEST_ALL
`define TEST_CB0A
`endif
`ifdef TEST_CB0A
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 0A (RRC D)
	TESTCASE(" -- cb 0a       rrc d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h1200_3ba1_7724_63ad_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h0a);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h12ad_3ba1_bb24_63ad_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB0A

`ifdef TEST_ALL
`define TEST_DDCB0A
`endif
`ifdef TEST_DDCB0A
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CB 0A (RRC (IX+d),d)
	TESTCASE(" -- dd cb 0A    rrc (ix+d),d (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hd2dd_6aac_e789_9293_0000_0000_0000_0000_1fb4_2498_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hcb);  SETMEM(2, 8'h83); SETMEM(3, 8'h0a);
	SETMEM(16'h1f37, 8'h78);
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERTMEM(16'h1f37, 8'h3c);
	ASSERT(192'hd22c_6aac_3c89_9293_0000_0000_0000_0000_1fb4_2498_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDCB0A

`ifdef TEST_ALL
`define TEST_CB0B
`endif
`ifdef TEST_CB0B
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 0B (RRC E)
	TESTCASE(" -- cb 0b       rrc e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h7600_2abf_b626_0289_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h0b);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h7600_2abf_b613_0289_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB0B

`ifdef TEST_ALL
`define TEST_DDCB0B
`endif
`ifdef TEST_DDCB0B
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CB 0B (RRC (IX+d),E)
	TESTCASE(" -- dd cb 0B    rrc (ix+d),e (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hb82c_b284_23f8_7e7d_0000_0000_0000_0000_cd09_6a03_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hcb);  SETMEM(2, 8'hfa); SETMEM(3, 8'h0b);
	SETMEM(16'hcd03, 8'h92);
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERTMEM(16'hcd03, 8'h49);
	ASSERT(192'hb808_b284_2349_7e7d_0000_0000_0000_0000_cd09_6a03_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDCB0B

`ifdef TEST_ALL
`define TEST_CB0C
`endif
`ifdef TEST_CB0C
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 0C (RRC H)
	TESTCASE(" -- cb 0c       rrc h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0e00_6fc5_2f12_34d9_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h0c);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0e08_6fc5_2f12_1ad9_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB0C

`ifdef TEST_ALL
`define TEST_DDCB0C
`endif
`ifdef TEST_DDCB0C
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CB 0C (RRC (IX+d),H)
	TESTCASE(" -- dd cb 0C    rrc (ix+d),h (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hdf8b_b6cc_ee8d_855a_0000_0000_0000_0000_bf6b_9b7d_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hcb);  SETMEM(2, 8'h79); SETMEM(3, 8'h0c);
	SETMEM(16'hbfe4, 8'h0d);
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERTMEM(16'hbfe4, 8'h86);
	ASSERT(192'hdf81_b6cc_ee8d_865a_0000_0000_0000_0000_bf6b_9b7d_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDCB0C

`ifdef TEST_ALL
`define TEST_CB0D
`endif
`ifdef TEST_CB0D
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 0D (RRC L)
	TESTCASE(" -- cb 0d       rrc l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6300_95a3_fcd2_519a_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h0d);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h630c_95a3_fcd2_514d_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB0D

`ifdef TEST_ALL
`define TEST_DDCB0D
`endif
`ifdef TEST_DDCB0D
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CB 0D (RRC (IX+d),L)
	TESTCASE(" -- dd cb 0d    rrc (ix+d),l (undoc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hbae3_ceec_bbaa_b65e_0000_0000_0000_0000_88bd_503e_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hcb);  SETMEM(2, 8'he4); SETMEM(3, 8'h0d);
	SETMEM(16'h88a1, 8'h1f);
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERTMEM(16'h88a1, 8'h8f);
	ASSERT(192'hba89_ceec_bbaa_b68f_0000_0000_0000_0000_88bd_503e_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDCB0D

`ifdef TEST_ALL
`define TEST_CB0E
`endif
`ifdef TEST_CB0E
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 0E (RRC (HL))
	TESTCASE(" -- cb 0e       rrc (hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hfc00_adf9_4925_013e_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h0e); SETMEM(16'h013e, 8'hd2);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERTMEM(16'h013e, 8'h69);
	ASSERT(192'hfc2c_adf9_4925_013e_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB0E

`ifdef TEST_ALL
`define TEST_DDCB0E
`endif
`ifdef TEST_DDCB0E
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CB 0E (RRC (IX+d),L)
	TESTCASE(" -- dd cb 0e    rrc (ix+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h1c36_890b_7830_060c_0000_0000_0000_0000_fd49_5d07_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hcb);  SETMEM(2, 8'hc6); SETMEM(3, 8'h0e);
	SETMEM(16'hfd0f, 8'had);
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERTMEM(16'hfd0f, 8'hd6);
	ASSERT(192'h1c81_890b_7830_060c_0000_0000_0000_0000_fd49_5d07_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDCB0E

`ifdef TEST_ALL
`define TEST_CB0F
`endif
`ifdef TEST_CB0F
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 0F (RRC A)
	TESTCASE(" -- cb 0f       rrc a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hc300_18f3_41b8_070b_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h0f);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'he1a5_18f3_41b8_070b_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB0F

`ifdef TEST_ALL
`define TEST_DDCB0F
`endif
`ifdef TEST_DDCB0F
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CB 0F (RRC (IX+d),A)
	TESTCASE(" -- dd cb 0f    rrc (ix+d),a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf5a7_fad4_fa4b_9c53_0000_0000_0000_0000_7447_2267_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hcb);  SETMEM(2, 8'h57); SETMEM(3, 8'h0f);
	SETMEM(16'h749e, 8'hf8);
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERTMEM(16'h749e, 8'h7c);
	ASSERT(192'h7c28_fad4_fa4b_9c53_0000_0000_0000_0000_7447_2267_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDCB0F

`ifdef TEST_ALL
`define TEST_CB10
`endif
`ifdef TEST_CB10
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 10 (RL B)
	TESTCASE(" -- cb 10       rl b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf800_dc25_33b3_0d74_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h10);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hf8ad_b825_33b3_0d74_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB10

`ifdef TEST_ALL
`define TEST_DDCB10
`endif
`ifdef TEST_DDCB10
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CB 0F (RRC (IX+d),A)
	TESTCASE(" -- dd cb 10    rl (ix+d),b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf3af_ba1f_5387_926e_0000_0000_0000_0000_bba2_ca47_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hcb);  SETMEM(2, 8'h4f); SETMEM(3, 8'h10);
	SETMEM(16'hbbf1, 8'h45);
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERTMEM(16'hbbf1, 8'h8b);
	ASSERT(192'hf38c_9b1f_5387_926e_0000_0000_0000_0000_bba2_ca47_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDCB10

`ifdef TEST_ALL
`define TEST_CB11
`endif
`ifdef TEST_CB11
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 11 (RL C)
	TESTCASE(" -- cb 11       rl c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6500_e25c_4b8a_ed42_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h11);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h65ac_e2b8_4b8a_ed42_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB11

`ifdef TEST_ALL
`define TEST_DDCB11
`endif
`ifdef TEST_DDCB11
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CB 0F (RRC (IX+d),A)
	TESTCASE(" -- dd cb 11    rl (ix+d),c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2a69_d604_a9aa_5b52_0000_0000_0000_0000_1809_d275_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hcb);  SETMEM(2, 8'heb); SETMEM(3, 8'h11);
	SETMEM(16'h17f4, 8'hd9);
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERTMEM(16'h17f4, 8'hb3);
	ASSERT(192'h2aa1_d6b3_a9aa_5b52_0000_0000_0000_0000_1809_d275_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDCB11

`ifdef TEST_ALL
`define TEST_CB12
`endif
`ifdef TEST_CB12
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 12 (RL D)
	TESTCASE(" -- cb 12       rl d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h7700_1384_0f50_29c6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h12);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h770c_1384_1e50_29c6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB12

`ifdef TEST_ALL
`define TEST_DDCB12
`endif
`ifdef TEST_DDCB12
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CB 0F (RRC (IX+d),A)
	TESTCASE(" -- dd cb 12    rl (ix+d),d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9287_c479_26d1_10ce_0000_0000_0000_0000_c0fb_2777_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hcb);  SETMEM(2, 8'ha6); SETMEM(3, 8'h12);
	SETMEM(16'hc0a1, 8'he2);
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERTMEM(16'hc0a1, 8'hc5);
	ASSERT(192'h9285_c479_c5d1_10ce_0000_0000_0000_0000_c0fb_2777_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDCB12

`ifdef TEST_ALL
`define TEST_CB13
`endif
`ifdef TEST_CB13
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 13 (RL E)
	TESTCASE(" -- cb 13       rl e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hce00_9f17_e128_3ed7_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h13);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hce04_9f17_e150_3ed7_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB13

`ifdef TEST_ALL
`define TEST_DDCB13
`endif
`ifdef TEST_DDCB13
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CB 0F (RRC (IX+d),A)
	TESTCASE(" -- dd cb 13    rl (ix+d),e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha507_580a_a48f_11cd_0000_0000_0000_0000_5ac4_ccc7_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hcb);  SETMEM(2, 8'hff); SETMEM(3, 8'h13);
	SETMEM(16'h5ac3, 8'ha7);
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERTMEM(16'h5ac3, 8'h4f);
	ASSERT(192'ha509_580a_a44f_11cd_0000_0000_0000_0000_5ac4_ccc7_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDCB13

`ifdef TEST_ALL
`define TEST_CB14
`endif
`ifdef TEST_CB14
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 14 (RL H)
	TESTCASE(" -- cb 14       rl h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hb200_541a_60c7_7c9a_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h14);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hb2a8_541a_60c7_f89a_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB14

`ifdef TEST_ALL
`define TEST_DDCB14
`endif
`ifdef TEST_DDCB14
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CB 0F (RRC (IX+d),A)
	TESTCASE(" -- dd cb 14    rl (ix+d),h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h294b_5b89_8467_0430_0000_0000_0000_0000_0977_c4e8_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hcb);  SETMEM(2, 8'hdd); SETMEM(3, 8'h14);
	SETMEM(16'h0954, 8'h85);
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERTMEM(16'h0954, 8'h0b);
	ASSERT(192'h2909_5b89_8467_0b30_0000_0000_0000_0000_0977_c4e8_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDCB14

`ifdef TEST_ALL
`define TEST_CB15
`endif
`ifdef TEST_CB15
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 15 (RL L)
	TESTCASE(" -- cb 15       rl l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2d00_c1df_6eab_03e2_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h15);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h2d81_c1df_6eab_03c4_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB15

`ifdef TEST_ALL
`define TEST_DDCB15
`endif
`ifdef TEST_DDCB15
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CB 0F (RRC (IX+d),A)
	TESTCASE(" -- dd cb 15    rl (ix+d),l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h1fd1_6d53_5b7c_a134_0000_0000_0000_0000_ede9_a85c_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hcb);  SETMEM(2, 8'h07); SETMEM(3, 8'h15);
	SETMEM(16'hedf0, 8'h0e);
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERTMEM(16'hedf0, 8'h1d);
	ASSERT(192'h1f0c_6d53_5b7c_a11d_0000_0000_0000_0000_ede9_a85c_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDCB15

`ifdef TEST_ALL
`define TEST_CB16
`endif
`ifdef TEST_CB16
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 16 (RL (HL))
	TESTCASE(" -- cb 16       rl (hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h3600_3b53_1a4a_024e_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h16); SETMEM(16'h024e, 8'hc3);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERTMEM(16'h024e, 8'h86);
	ASSERT(192'h3681_3b53_1a4a_024e_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB16

`ifdef TEST_ALL
`define TEST_DDCB16
`endif
`ifdef TEST_DDCB16
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CB 0F (RRC (IX+d),A)
	TESTCASE(" -- dd cb 16    rl (ix+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hda70_a1e4_00b0_92c8_0000_0000_0000_0000_16be_2c95_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hcb);  SETMEM(2, 8'h45); SETMEM(3, 8'h16);
	SETMEM(16'h1703, 8'h5b);
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERTMEM(16'h1703, 8'hb6);
	ASSERT(192'hdaa0_a1e4_00b0_92c8_0000_0000_0000_0000_16be_2c95_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDCB16

`ifdef TEST_ALL
`define TEST_CB17
`endif
`ifdef TEST_CB17
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 17 (RL A)
	TESTCASE(" -- cb 17       rl a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h5400_d090_f60d_0fa2_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h17);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha8a8_d090_f60d_0fa2_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB17

`ifdef TEST_ALL
`define TEST_DDCB17
`endif
`ifdef TEST_DDCB17
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CB 0F (RRC (IX+d),A)
	TESTCASE(" -- dd cb 17    rl (ix+d),a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h3300_cbd1_4e1a_cd27_0000_0000_0000_0000_b8c9_e6d4_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hcb);  SETMEM(2, 8'h1c); SETMEM(3, 8'h17);
	SETMEM(16'hb8e5, 8'h7e);
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERTMEM(16'hb8e5, 8'hfc);
	ASSERT(192'hfcac_cbd1_4e1a_cd27_0000_0000_0000_0000_b8c9_e6d4_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDCB17

`ifdef TEST_ALL
`define TEST_CB18
`endif
`ifdef TEST_CB18
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 18 (RR B)
	TESTCASE(" -- cb 18       rr b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h8600_c658_755f_9596_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h18);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h8624_6358_755f_9596_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB18

`ifdef TEST_ALL
`define TEST_DDCB18
`endif
`ifdef TEST_DDCB18
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CB 0F (RRC (IX+d),A)
	TESTCASE(" -- dd cb 18    rr (ix+d),b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hd980_4eb5_9cf9_b9f1_0000_0000_0000_0000_a189_bd7c_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hcb);  SETMEM(2, 8'h0e); SETMEM(3, 8'h18);
	SETMEM(16'ha197, 8'h90);
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERTMEM(16'ha197, 8'h48);
	ASSERT(192'hd90c_48b5_9cf9_b9f1_0000_0000_0000_0000_a189_bd7c_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDCB18

`ifdef TEST_ALL
`define TEST_CB19
`endif
`ifdef TEST_CB19
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 19 (RR C)
	TESTCASE(" -- cb 19       rr c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9600_beb3_7c22_71c8_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h19);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h960d_be59_7c22_71c8_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB19

`ifdef TEST_ALL
`define TEST_DDCB19
`endif
`ifdef TEST_DDCB19
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CB 0F (RRC (IX+d),A)
	TESTCASE(" -- dd cb 19    rr (ix+d),c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h23b7_595a_a756_cf2e_0000_0000_0000_0000_f0e7_26e4_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hcb);  SETMEM(2, 8'ha3); SETMEM(3, 8'h19);
	SETMEM(16'hf08a, 8'h37);
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERTMEM(16'hf08a, 8'h9b);
	ASSERT(192'h2389_599b_a756_cf2e_0000_0000_0000_0000_f0e7_26e4_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDCB19

`ifdef TEST_ALL
`define TEST_CB1A
`endif
`ifdef TEST_CB1A
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 1A (RR D)
	TESTCASE(" -- cb 1a       rr d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h3900_882f_543b_5279_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h1a);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h3928_882f_2a3b_5279_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB1A

`ifdef TEST_ALL
`define TEST_DDCB1A
`endif
`ifdef TEST_DDCB1A
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CB 0F (RRC (IX+d),A)
	TESTCASE(" -- dd cb 1a    rr (ix+d),d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h8b52_7e45_bd0f_37a6_0000_0000_0000_0000_de61_9cd9_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hcb);  SETMEM(2, 8'hac); SETMEM(3, 8'h1a);
	SETMEM(16'hde0d, 8'hcc);
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERTMEM(16'hde0d, 8'h66);
	ASSERT(192'h8b24_7e45_660f_37a6_0000_0000_0000_0000_de61_9cd9_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDCB1A

`ifdef TEST_ALL
`define TEST_CB1B
`endif
`ifdef TEST_CB1B
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 1B (RR E)
	TESTCASE(" -- cb 1b       rr e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9e00_b338_876c_e8b4_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h1b);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9e24_b338_8736_e8b4_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB1B

`ifdef TEST_ALL
`define TEST_DDCB1B
`endif
`ifdef TEST_DDCB1B
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CB 0F (RRC (IX+d),A)
	TESTCASE(" -- dd cb 1b    rr (ix+d),e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h5c79_1414_811c_5881_0000_0000_0000_0000_b7c3_d14f_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hcb);  SETMEM(2, 8'h05); SETMEM(3, 8'h1b);
	SETMEM(16'hb7c8, 8'h91);
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERTMEM(16'hb7c8, 8'hc8);
	ASSERT(192'h5c89_1414_81c8_5881_0000_0000_0000_0000_b7c3_d14f_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDCB1B

`ifdef TEST_ALL
`define TEST_CB1C
`endif
`ifdef TEST_CB1C
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 1C (RR H)
	TESTCASE(" -- cb 1c       rr h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h4b00_b555_238f_311d_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h1c);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h4b0d_b555_238f_181d_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB1C

`ifdef TEST_ALL
`define TEST_DDCB1C
`endif
`ifdef TEST_DDCB1C
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CB 0F (RRC (IX+d),A)
	TESTCASE(" -- dd cb 1c    rr (ix+d),h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hfafc_6277_8b67_d423_0000_0000_0000_0000_fef9_4a66_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hcb);  SETMEM(2, 8'hff); SETMEM(3, 8'h1c);
	SETMEM(16'hfef8, 8'h61);
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERTMEM(16'hfef8, 8'h30);
	ASSERT(192'hfa25_6277_8b67_3023_0000_0000_0000_0000_fef9_4a66_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDCB1C

`ifdef TEST_ALL
`define TEST_CB1D
`endif
`ifdef TEST_CB01D
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 1D (RR L)
	TESTCASE(" -- cb 1d       rr l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2100_3d7e_5e39_e451_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h1d);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h212d_3d7e_5e39_e428_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB1D

`ifdef TEST_ALL
`define TEST_DDCB1D
`endif
`ifdef TEST_DDCB1D
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CB 0F (RRC (IX+d),A)
	TESTCASE(" -- dd cb 1d    rr (ix+d),l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h76a5_324e_e641_58fa_0000_0000_0000_0000_5b63_e18b_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hcb);  SETMEM(2, 8'h3a); SETMEM(3, 8'h1d);
	SETMEM(16'h5b9d, 8'hf3);
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERTMEM(16'h5b9d, 8'hf9);
	ASSERT(192'h76ad_324e_e641_58f9_0000_0000_0000_0000_5b63_e18b_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDCB1D

`ifdef TEST_ALL
`define TEST_CB1E
`endif
`ifdef TEST_CB1E
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 1E (RR (HL))
	TESTCASE(" -- cb 1e       rr (hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h5e00_66b9_80dc_00ef_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h1e); SETMEM(16'h00ef, 8'h91);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERTMEM(16'h00ef, 8'h48);
	ASSERT(192'h5e0d_66b9_80dc_00ef_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB1E

`ifdef TEST_ALL
`define TEST_DDCB1E
`endif
`ifdef TEST_DDCB1E
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CB 0F (RRC (IX+d),A)
	TESTCASE(" -- dd cb 1e    rr (ix+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hc5d9_cd58_8967_f074_0000_0000_0000_0000_75b4_693a_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hcb);  SETMEM(2, 8'hce); SETMEM(3, 8'h1e);
	SETMEM(16'h7582, 8'h91);
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERTMEM(16'h7582, 8'hc8);
	ASSERT(192'hc589_cd58_8967_f074_0000_0000_0000_0000_75b4_693a_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDCB1E

`ifdef TEST_ALL
`define TEST_CB1F
`endif
`ifdef TEST_CB1F
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 1F (RR A)
	TESTCASE(" -- cb 1f       rr a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hed00_b838_8e18_ace7_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h1f);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h7621_b838_8e18_ace7_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB1F

`ifdef TEST_ALL
`define TEST_DDCB1F
`endif
`ifdef TEST_DDCB1F
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CB 0F (RRC (IX+d),A)
	TESTCASE(" -- dd cb 1f    rr (ix+d),a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hd28f_7f6d_2058_63e3_0000_0000_0000_0000_1d9b_baba_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hcb);  SETMEM(2, 8'ha8); SETMEM(3, 8'h1f);
	SETMEM(16'h1d43, 8'hb4);
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERTMEM(16'h1d43, 8'hda);
	ASSERT(192'hda88_7f6d_2058_63e3_0000_0000_0000_0000_1d9b_baba_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDCB1F

`ifdef TEST_ALL
`define TEST_CB20
`endif
`ifdef TEST_CB20
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 20 (SLA B)
	TESTCASE(" -- cb 20       sla b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hc700_0497_d72b_ccb6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h20);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hc708_0897_d72b_ccb6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB20

`ifdef TEST_ALL
`define TEST_DDCB20
`endif
`ifdef TEST_DDCB20
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CB 0F (RRC (IX+d),A)
	TESTCASE(" -- dd cb 20    sla (ix+d),b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h4ce5_739e_dc6c_18f4_0000_0000_0000_0000_dc39_8b0c_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hcb);  SETMEM(2, 8'he8); SETMEM(3, 8'h20);
	SETMEM(16'hdc21, 8'h0e);
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERTMEM(16'hdc21, 8'h1c);
	ASSERT(192'h4c08_1c9e_dc6c_18f4_0000_0000_0000_0000_dc39_8b0c_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDCB20

`ifdef TEST_ALL
`define TEST_CB21
`endif
`ifdef TEST_CB21
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 21 (SLA C)
	TESTCASE(" -- cb 21       sla c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2200_5cf4_938e_37a8_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h21);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h22ad_5ce8_938e_37a8_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB21

`ifdef TEST_ALL
`define TEST_DDCB21
`endif
`ifdef TEST_DDCB21
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CB 0F (RRC (IX+d),A)
	TESTCASE(" -- dd cb 21    sla (ix+d),c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hd29d_66dd_23ef_9096_0000_0000_0000_0000_3494_b6c3_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hcb);  SETMEM(2, 8'h9e); SETMEM(3, 8'h21);
	SETMEM(16'h3432, 8'hf7);
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERTMEM(16'h3432, 8'hee);
	ASSERT(192'hd2ad_66ee_23ef_9096_0000_0000_0000_0000_3494_b6c3_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDCB21

`ifdef TEST_ALL
`define TEST_CB22
`endif
`ifdef TEST_CB22
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 22 (SLA D)
	TESTCASE(" -- cb 22       sla d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h8500_0950_e7e8_0641_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h22);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h8589_0950_cee8_0641_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB22

`ifdef TEST_ALL
`define TEST_DDCB22
`endif
`ifdef TEST_DDCB22
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CB 0F (RRC (IX+d),A)
	TESTCASE(" -- dd cb 22    sla (ix+d),d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hfb5d_e0d0_7c02_b4b7_0000_0000_0000_0000_bd3f_385b_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hcb);  SETMEM(2, 8'h43); SETMEM(3, 8'h22);
	SETMEM(16'hbd82, 8'h9f);
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERTMEM(16'hbd82, 8'h3e);
	ASSERT(192'hfb29_e0d0_3e02_b4b7_0000_0000_0000_0000_bd3f_385b_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDCB22

`ifdef TEST_ALL
`define TEST_CB23
`endif
`ifdef TEST_CB23
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 23 (SLA E)
	TESTCASE(" -- cb 23       sla e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2100_2a7c_37d0_aa59_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h23);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h21a5_2a7c_37a0_aa59_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB23

`ifdef TEST_ALL
`define TEST_DDCB23
`endif
`ifdef TEST_DDCB23
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CB 0F (RRC (IX+d),A)
	TESTCASE(" -- dd cb 23    sla (ix+d),e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hc359_68b6_da84_b990_0000_0000_0000_0000_22dd_bd27_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hcb);  SETMEM(2, 8'hc1); SETMEM(3, 8'h23);
	SETMEM(16'h229e, 8'he0);
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERTMEM(16'h229e, 8'hc0);
	ASSERT(192'hc385_68b6_dac0_b990_0000_0000_0000_0000_22dd_bd27_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDCB23

`ifdef TEST_ALL
`define TEST_CB24
`endif
`ifdef TEST_CB24
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 24 (SLA H)
	TESTCASE(" -- cb 24       sla h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hfb00_b9de_7014_84b6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h24);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hfb09_b9de_7014_08b6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB24

`ifdef TEST_ALL
`define TEST_DDCB24
`endif
`ifdef TEST_DDCB24
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CB 0F (RRC (IX+d),A)
	TESTCASE(" -- dd cb 24    sla (ix+d),h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hbaf5_7b0b_560b_7c33_0000_0000_0000_0000_31f1_ddbd_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hcb);  SETMEM(2, 8'he8); SETMEM(3, 8'h24);
	SETMEM(16'h31d9, 8'hc3);
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERTMEM(16'h31d9, 8'h86);
	ASSERT(192'hba81_7b0b_560b_8633_0000_0000_0000_0000_31f1_ddbd_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDCB24

`ifdef TEST_ALL
`define TEST_CB25
`endif
`ifdef TEST_CB25
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 25 (SLA L)
	TESTCASE(" -- cb 25       sla l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h1500_6bbc_894e_85bc_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h25);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h152d_6bbc_894e_8578_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB25

`ifdef TEST_ALL
`define TEST_DDCB25
`endif
`ifdef TEST_DDCB25
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CB 0F (RRC (IX+d),A)
	TESTCASE(" -- dd cb 25    sla (ix+d),l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h43bb_a21b_2347_ae4a_0000_0000_0000_0000_cc63_fc94_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hcb);  SETMEM(2, 8'hc1); SETMEM(3, 8'h25);
	SETMEM(16'hcc24, 8'heb);
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERTMEM(16'hcc24, 8'hd6);
	ASSERT(192'h4381_a21b_2347_aed6_0000_0000_0000_0000_cc63_fc94_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDCB25

`ifdef TEST_ALL
`define TEST_CB26
`endif
`ifdef TEST_CB26
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 26 (SLA (HL))
	TESTCASE(" -- cb 26       sla (hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0a00_372e_e315_033a_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h26); SETMEM(16'h033a, 8'hee);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERTMEM(16'h033a, 8'hdc);
	ASSERT(192'h0a89_372e_e315_033a_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB26

`ifdef TEST_ALL
`define TEST_DDCB26
`endif
`ifdef TEST_DDCB26
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CB 0F (RRC (IX+d),A)
	TESTCASE(" -- dd cb 26    sla (ix+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2065_ff37_e41f_70e7_0000_0000_0000_0000_6528_a0d5_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hcb);  SETMEM(2, 8'hf7); SETMEM(3, 8'h26);
	SETMEM(16'h651f, 8'h89);
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERTMEM(16'h651f, 8'h12);
	ASSERT(192'h2005_ff37_e41f_70e7_0000_0000_0000_0000_6528_a0d5_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDCB26

`ifdef TEST_ALL
`define TEST_CB27
`endif
`ifdef TEST_CB27
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 27 (SLA A)
	TESTCASE(" -- cb 27       sla a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hbf00_bdba_67ab_5ea2_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h27);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h7e2d_bdba_67ab_5ea2_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB27

`ifdef TEST_ALL
`define TEST_DDCB27
`endif
`ifdef TEST_DDCB27
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CB 0F (RRC (IX+d),A)
	TESTCASE(" -- dd cb 27    sla (ix+d),a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha806_5669_1bee_f62c_0000_0000_0000_0000_1f69_3418_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hcb);  SETMEM(2, 8'hc3); SETMEM(3, 8'h27);
	SETMEM(16'h1f2c, 8'hac);
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERTMEM(16'h1f2c, 8'h58);
	ASSERT(192'h5809_5669_1bee_f62c_0000_0000_0000_0000_1f69_3418_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDCB27

`ifdef TEST_ALL
`define TEST_CB28
`endif
`ifdef TEST_CB28
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 28 (SRA B)
	TESTCASE(" -- cb 28       sra b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hc000_0435_3e0f_021b_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h28);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hc000_0235_3e0f_021b_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB28

`ifdef TEST_ALL
`define TEST_DDCB28
`endif
`ifdef TEST_DDCB28
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CB 0F (RRC (IX+d),A)
	TESTCASE(" -- dd cb 28    sra (ix+d),b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h7afd_64b8_51f7_7164_0000_0000_0000_0000_999b_8857_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hcb);  SETMEM(2, 8'hb6); SETMEM(3, 8'h28);
	SETMEM(16'h9951, 8'h24);
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERTMEM(16'h9951, 8'h12);
	ASSERT(192'h7a04_12b8_51f7_7164_0000_0000_0000_0000_999b_8857_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDCB28

`ifdef TEST_ALL
`define TEST_CB29
`endif
`ifdef TEST_CB29
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 29 (SRA C)
	TESTCASE(" -- cb 29       sra c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0600_f142_6ada_c306_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h29);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0624_f121_6ada_c306_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB29

`ifdef TEST_ALL
`define TEST_DDCB29
`endif
`ifdef TEST_DDCB29
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CB 0F (RRC (IX+d),A)
	TESTCASE(" -- dd cb 29    sra (ix+d),c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0404_b794_323f_fd34_0000_0000_0000_0000_20e7_c753_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hcb);  SETMEM(2, 8'h9c); SETMEM(3, 8'h29);
	SETMEM(16'h2083, 8'h82);
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERTMEM(16'h2083, 8'hc1);
	ASSERT(192'h0480_b7c1_323f_fd34_0000_0000_0000_0000_20e7_c753_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDCB29

`ifdef TEST_ALL
`define TEST_CB2A
`endif
`ifdef TEST_CB2A
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 2A (SRA D)
	TESTCASE(" -- cb 2a       sra d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h3000_ec3a_7f7d_3473_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h2a);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h302d_ec3a_3f7d_3473_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB2A

`ifdef TEST_ALL
`define TEST_DDCB2A
`endif
`ifdef TEST_DDCB2A
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CB 0F (RRC (IX+d),A)
	TESTCASE(" -- dd cb 2a    sra (ix+d),d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h4524_afde_0c08_75d7_0000_0000_0000_0000_9505_b624_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hcb);  SETMEM(2, 8'hd8); SETMEM(3, 8'h2a);
	SETMEM(16'h94dd, 8'h7c);
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERTMEM(16'h94dd, 8'h3e);
	ASSERT(192'h4528_afde_3e08_75d7_0000_0000_0000_0000_9505_b624_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDCB2A

`ifdef TEST_ALL
`define TEST_CB2B
`endif
`ifdef TEST_CB2B
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 2B (SRA E)
	TESTCASE(" -- cb 2b       sra e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'he000_ccf0_bbda_b78a_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h2b);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'he0ac_ccf0_bbed_b78a_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB2B

`ifdef TEST_ALL
`define TEST_DDCB2B
`endif
`ifdef TEST_DDCB2B
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CB 0F (RRC (IX+d),A)
	TESTCASE(" -- dd cb 2b    sra (ix+d),e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h8324_e290_26be_7ddd_0000_0000_0000_0000_b484_571c_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hcb);  SETMEM(2, 8'hbd); SETMEM(3, 8'h2b);
	SETMEM(16'hb441, 8'h44);
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERTMEM(16'hb441, 8'h22);
	ASSERT(192'h8324_e290_2622_7ddd_0000_0000_0000_0000_b484_571c_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDCB2B

`ifdef TEST_ALL
`define TEST_CB2C
`endif
`ifdef TEST_CB2C
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 2C (SRA H)
	TESTCASE(" -- cb 2c       sra h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h5b00_25c0_996d_1e7b_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h2c);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h5b0c_25c0_996d_0f7b_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB2C

`ifdef TEST_ALL
`define TEST_DDCB2C
`endif
`ifdef TEST_DDCB2C
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CB 0F (RRC (IX+d),A)
	TESTCASE(" -- dd cb 2c    sra (ix+d),h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hc688_0c94_6e4b_7dc7_0000_0000_0000_0000_fe28_dc80_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hcb);  SETMEM(2, 8'h2c); SETMEM(3, 8'h2c);
	SETMEM(16'hfe54, 8'h81);
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERTMEM(16'hfe54, 8'hc0);
	ASSERT(192'hc685_0c94_6e4b_c0c7_0000_0000_0000_0000_fe28_dc80_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDCB2C

`ifdef TEST_ALL
`define TEST_CB2D
`endif
`ifdef TEST_CB2D
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 2D (SRA L)
	TESTCASE(" -- cb 2d       sra l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h5e00_c51b_58e3_78ea_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h2d);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h5ea4_c51b_58e3_78f5_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB2D

`ifdef TEST_ALL
`define TEST_DDCB2D
`endif
`ifdef TEST_DDCB2D
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CB 0F (RRC (IX+d),A)
	TESTCASE(" -- dd cb 2b    sra (ix+d),l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hce28_d2ae_c9be_4236_0000_0000_0000_0000_b4ed_6de3_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hcb);  SETMEM(2, 8'h9b); SETMEM(3, 8'h2d);
	SETMEM(16'hb488, 8'h44);
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERTMEM(16'hb488, 8'h22);
	ASSERT(192'hce24_d2ae_c9be_4222_0000_0000_0000_0000_b4ed_6de3_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDCB2D

`ifdef TEST_ALL
`define TEST_CB2E
`endif
`ifdef TEST_CB2E
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 2E (SRA (HL))
	TESTCASE(" -- cb 2e       sra (hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h3900_a2cd_0629_02bf_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h2e); SETMEM(16'h02bf, 8'hb5);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERTMEM(16'h02bf, 8'hda);
	ASSERT(192'h3989_a2cd_0629_02bf_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB2E

`ifdef TEST_ALL
`define TEST_DDCB2E
`endif
`ifdef TEST_DDCB2E
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CB 0F (RRC (IX+d),A)
	TESTCASE(" -- dd cb 2e    sra (ix+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h50b0_de74_eca8_83ff_0000_0000_0000_0000_69d8_75c7_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hcb);  SETMEM(2, 8'h3d); SETMEM(3, 8'h2e);
	SETMEM(16'h6a15, 8'h05);
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERTMEM(16'h6a15, 8'h02);
	ASSERT(192'h5001_de74_eca8_83ff_0000_0000_0000_0000_69d8_75c7_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDCB2E

`ifdef TEST_ALL
`define TEST_CB2F
`endif
`ifdef TEST_CB2F
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 2F (SRA A)
	TESTCASE(" -- cb 2f       sra a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'haa00_a194_d0e3_5c65_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h2f);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hd580_a194_d0e3_5c65_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB2F

`ifdef TEST_ALL
`define TEST_DDCB2F
`endif
`ifdef TEST_DDCB2F
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CB 0F (RRC (IX+d),A)
	TESTCASE(" -- dd cb 2f    sra (ix+d),a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'haec6_759b_3059_01b9_0000_0000_0000_0000_7a30_dd56_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hdd); SETMEM(1, 8'hcb);  SETMEM(2, 8'hd3); SETMEM(3, 8'h2f);
	SETMEM(16'h7a03, 8'hf2);
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERTMEM(16'h7a03, 8'hf9);
	ASSERT(192'hf9ac_759b_3059_01b9_0000_0000_0000_0000_7a30_dd56_0000_0004, 8'h00, 8'h02, 2'b00);
`endif // TEST_DDCB2F

`ifdef TEST_ALL
`define TEST_CB30
`endif
`ifdef TEST_CB30
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 30 (SLL B)
	TESTCASE(" -- cb 30       sll b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hcd00_7a81_d67b_656b_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h30);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hcda4_f581_d67b_656b_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB30

`ifdef TEST_ALL
`define TEST_CB31
`endif
`ifdef TEST_CB31
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 31 (SLL C)
	TESTCASE(" -- cb 31       sll c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2800_e7fa_6d8c_75a4_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h31);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h28a5_e7f5_6d8c_75a4_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB31

`ifdef TEST_ALL
`define TEST_CB32
`endif
`ifdef TEST_CB32
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 32 (SLL D)
	TESTCASE(" -- cb 32       sll d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h1300_3f36_f608_5e56_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h32);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h13ad_3f36_ed08_5e56_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB32

`ifdef TEST_ALL
`define TEST_CB33
`endif
`ifdef TEST_CB33
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 33 (SLL E)
	TESTCASE(" -- cb 33       sll e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hd500_9720_7644_038f_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h33);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hd588_9720_7689_038f_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB33

`ifdef TEST_ALL
`define TEST_CB34
`endif
`ifdef TEST_CB34
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 34 (SLL H)
	TESTCASE(" -- cb 34       sll h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h1200_77f6_0206_fb38_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h34);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h12a1_77f6_0206_f738_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB34

`ifdef TEST_ALL
`define TEST_CB35
`endif
`ifdef TEST_CB35
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 35 (SLL L)
	TESTCASE(" -- cb 35       sll l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h3c00_fd68_ea91_7861_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h35);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h3c84_fd68_ea91_78c3_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB35

`ifdef TEST_ALL
`define TEST_CB36
`endif
`ifdef TEST_CB36
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 36 (SLL (HL))
	TESTCASE(" -- cb 36       sll (hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h8a00_1185_1dde_0138_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h36); SETMEM(16'h0138, 8'hf1);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERTMEM(16'h0138, 8'he3);
	ASSERT(192'h8aa1_1185_1dde_0138_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB36

`ifdef TEST_ALL
`define TEST_CB37
`endif
`ifdef TEST_CB37
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 37 (SLL A)
	TESTCASE(" -- cb 37       sll a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h4300_d7bc_9133_6e56_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h37);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h8784_d7bc_9133_6e56_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB37

`ifdef TEST_ALL
`define TEST_CB38
`endif
`ifdef TEST_CB38
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 38 (SRL B)
	TESTCASE(" -- cb 38       srl b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hdf00_7c1b_9f9f_4ff2_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h38);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hdf28_3e1b_9f9f_4ff2_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB38

`ifdef TEST_ALL
`define TEST_CB39
`endif
`ifdef TEST_CB39
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 39 (SRL C)
	TESTCASE(" -- cb 39       srl c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6600_b702_14f5_3c17_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h39);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6600_b701_14f5_3c17_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB39

`ifdef TEST_ALL
`define TEST_CB3A
`endif
`ifdef TEST_CB3A
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 3A (SRL D)
	TESTCASE(" -- cb 3a       srl d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hd100_5c5f_e42e_f1b1_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h3a);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hd124_5c5f_722e_f1b1_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB3A

`ifdef TEST_ALL
`define TEST_CB3B
`endif
`ifdef TEST_CB3B
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 3B (SRL E)
	TESTCASE(" -- cb 3b       srl e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hb200_38c8_a560_7419_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h3b);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hb224_38c8_a530_7419_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB3B

`ifdef TEST_ALL
`define TEST_CB3C
`endif
`ifdef TEST_CB3C
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 3C (SRL H)
	TESTCASE(" -- cb 3c       srl h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h7800_cfae_66d8_2ad8_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h3c);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h7800_cfae_66d8_15d8_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB3C

`ifdef TEST_ALL
`define TEST_CB3D
`endif
`ifdef TEST_CB3D
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 3D (SRL L)
	TESTCASE(" -- cb 3d       srl l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'he600_dcda_06aa_46cd_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h3d);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'he625_dcda_06aa_4666_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB3D

`ifdef TEST_ALL
`define TEST_CB3E
`endif
`ifdef TEST_CB3E
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 3E (SRL (HL))
	TESTCASE(" -- cb 3e       srl (hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha900_6a34_e8d0_006c_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h3e); SETMEM(16'h006c, 8'ha0);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERTMEM(16'h006c, 8'h50);
	ASSERT(192'ha904_6a34_e8d0_006c_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB3E

`ifdef TEST_ALL
`define TEST_CB3F
`endif
`ifdef TEST_CB3F
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 3F (SRL A)
	TESTCASE(" -- cb 3f       srl a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf100_ceea_721e_77f0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h3f);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h782d_ceea_721e_77f0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB3F

`ifdef TEST_ALL
`define TEST_CB40
`endif
`ifdef TEST_CB40
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 40 (BIT 0,B)
	TESTCASE(" -- cb 40       bit 0,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9e00_bcb2_efaa_505f_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h40);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9e7c_bcb2_efaa_505f_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB40

`ifdef TEST_ALL
`define TEST_CB41
`endif
`ifdef TEST_CB41
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 41 (BIT 0,C)
	TESTCASE(" -- cb 41       bit 0,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9e00_1b43_efaa_505f_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h41);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9e10_1b43_efaa_505f_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB41

`ifdef TEST_ALL
`define TEST_CB42
`endif
`ifdef TEST_CB42
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 42 (BIT 0,D)
	TESTCASE(" -- cb 42       bit 0,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9e00_bcb2_7d4f_505f_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h42);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9e38_bcb2_7d4f_505f_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB42

`ifdef TEST_ALL
`define TEST_CB43
`endif
`ifdef TEST_CB43
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 43 (BIT 0,E)
	TESTCASE(" -- cb 43       bit 0,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9e00_bcb2_f1d0_505f_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h43);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9e54_bcb2_f1d0_505f_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB43

`ifdef TEST_ALL
`define TEST_CB44
`endif
`ifdef TEST_CB44
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 44 (BIT 0,H)
	TESTCASE(" -- cb 44       bit 0,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9e00_bcb2_efaa_5b92_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h44);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9e18_bcb2_efaa_5b92_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB44

`ifdef TEST_ALL
`define TEST_CB45
`endif
`ifdef TEST_CB45
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 45 (BIT 0,L)
	TESTCASE(" -- cb 45       bit 0,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9e00_bcb2_efaa_409b_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h45);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9e18_bcb2_efaa_409b_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB45

`ifdef TEST_ALL
`define TEST_CB46
`endif
`ifdef TEST_CB46
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 46 (BIT 0,(HL))
	TESTCASE(" -- cb 46       bit 0,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9e00_bcb2_efaa_0131_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h46); SETMEM(16'h0131, 8'hd5);
	#(2* `CLKPERIOD * 12+`FIN)
	ASSERTMEM(16'h0131, 8'hd5);
	ASSERT(192'h9e10_bcb2_efaa_0131_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB46

`ifdef TEST_ALL
`define TEST_CB47
`endif
`ifdef TEST_CB47
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 47 (BIT 0,A)
	TESTCASE(" -- cb 47       bit 0,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h1000_bcb2_efaa_505f_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h47);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h1054_bcb2_efaa_505f_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB47

`ifdef TEST_ALL
`define TEST_CB48
`endif
`ifdef TEST_CB48
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 48 (BIT 1,B)
	TESTCASE(" -- cb 48       bit 1,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha900_6264_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h48);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha930_6264_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB48

`ifdef TEST_ALL
`define TEST_CB49
`endif
`ifdef TEST_CB49
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 49 (BIT 1,C)
	TESTCASE(" -- cb 49       bit 1,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha900_d0f7_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h49);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha930_d0f7_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB49

`ifdef TEST_ALL
`define TEST_CB4A
`endif
`ifdef TEST_CB4A
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 4A (BIT 1,D)
	TESTCASE(" -- cb 4a       bit 1,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha900_6264_5b29_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h4a);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha918_6264_5b29_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB4A

`ifdef TEST_ALL
`define TEST_CB4B
`endif
`ifdef TEST_CB4B
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 4B (BIT 1,E)
	TESTCASE(" -- cb 4b       bit 1,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha900_6264_095f_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h4b);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha918_6264_095f_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB4B

`ifdef TEST_ALL
`define TEST_CB4C
`endif
`ifdef TEST_CB4C
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 4C (BIT 1,H)
	TESTCASE(" -- cb 4c       bit 1,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha900_6264_e833_6d5d_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h4c);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha97c_6264_e833_6d5d_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB4C

`ifdef TEST_ALL
`define TEST_CB4D
`endif
`ifdef TEST_CB4D
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 4D (BIT 1,L)
	TESTCASE(" -- cb 4d       bit 1,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha900_6264_e833_158d_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h4d);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha95c_6264_e833_158d_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB4D

`ifdef TEST_ALL
`define TEST_CB4E
`endif
`ifdef TEST_CB4E
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 4E (BIT 1,(HL))
	TESTCASE(" -- cb 4e       bit 1,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h4e); SETMEM(2, 8'h00); SETMEM(16'h01a3, 8'h5b);
	#(2* `CLKPERIOD * 12+`FIN)
	ASSERTMEM(16'h01a3, 8'h5b);
	ASSERT(192'h2610_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB4E

`ifdef TEST_ALL
`define TEST_CB4F
`endif
`ifdef TEST_CB4F
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 4F (BIT 1,A)
	TESTCASE(" -- cb 4f       bit 1,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h1700_6264_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h4f);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h1710_6264_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB4F

`ifdef TEST_ALL
`define TEST_CB50
`endif
`ifdef TEST_CB50
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 50 (BIT 2,B)
	TESTCASE(" -- cb 50       bit 2,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9e00_2749_efaa_505f_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h50);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9e30_2749_efaa_505f_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB50

`ifdef TEST_ALL
`define TEST_CB51
`endif
`ifdef TEST_CB51
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 51 (BIT 2,C)
	TESTCASE(" -- cb 51       bit 2,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9e00_b7db_efaa_505f_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h51);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9e5c_b7db_efaa_505f_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB51

`ifdef TEST_ALL
`define TEST_CB52
`endif
`ifdef TEST_CB52
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 52 (BIT 2,D)
	TESTCASE(" -- cb 52       bit 2,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9e00_bcb2_7d4f_505f_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h52);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9e38_bcb2_7d4f_505f_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB52

`ifdef TEST_ALL
`define TEST_CB53
`endif
`ifdef TEST_CB53
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 53 (BIT 2,E)
	TESTCASE(" -- cb 53       bit 2,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9e00_bcb2_f1d0_505f_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h53);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9e54_bcb2_f1d0_505f_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB53

`ifdef TEST_ALL
`define TEST_CB54
`endif
`ifdef TEST_CB54
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 54 (BIT 2,H)
	TESTCASE(" -- cb 54       bit 2,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9e00_bcb2_efaa_1999_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h54);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9e5c_bcb2_efaa_1999_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB54

`ifdef TEST_ALL
`define TEST_CB55
`endif
`ifdef TEST_CB55
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 55 (BIT 2,L)
	TESTCASE(" -- cb 55       bit 2,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9e00_bcb2_efaa_fb4b_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h55);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9e5c_bcb2_efaa_fb4b_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB55

`ifdef TEST_ALL
`define TEST_CB56
`endif
`ifdef TEST_CB56
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 56 (BIT 2,(HL))
	TESTCASE(" -- cb 56       bit 2,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9e00_bcb2_efaa_0131_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h56); SETMEM(16'h0131, 8'hd5);
	#(2* `CLKPERIOD * 12+`FIN)
	ASSERTMEM(16'h0131, 8'hd5);
	ASSERT(192'h9e10_bcb2_efaa_0131_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB56

`ifdef TEST_ALL
`define TEST_CB57
`endif
`ifdef TEST_CB57
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 57 (BIT 2,A)
	TESTCASE(" -- cb 57       bit 2,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h1000_bcb2_efaa_505f_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h57);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h1054_bcb2_efaa_505f_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB57

`ifdef TEST_ALL
`define TEST_CB58
`endif
`ifdef TEST_CB58
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 88 (BIT 3,B)
	TESTCASE(" -- cb 58       bit 3,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha900_1aee_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h58);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha918_1aee_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB58

`ifdef TEST_ALL
`define TEST_CB59
`endif
`ifdef TEST_CB59
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 59 (BIT 3,C)
	TESTCASE(" -- cb 59       bit 3,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha900_5e68_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h59);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha938_5e68_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB59

`ifdef TEST_ALL
`define TEST_CB5A
`endif
`ifdef TEST_CB5A
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 5A (BIT 3,D)
	TESTCASE(" -- cb 5a       bit 3,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha900_6264_5b29_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h5a);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha918_6264_5b29_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB5A

`ifdef TEST_ALL
`define TEST_CB5B
`endif
`ifdef TEST_CB5B
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 5B (BIT 3,E)
	TESTCASE(" -- cb 5b       bit 3,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha900_6264_095f_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h5b);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha918_6264_095f_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB5B

`ifdef TEST_ALL
`define TEST_CB5C
`endif
`ifdef TEST_CB5C
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 5C (BIT 3,H)
	TESTCASE(" -- cb 5c       bit 3,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha900_6264_e833_13e9_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h5c);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha954_6264_e833_13e9_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB5C

`ifdef TEST_ALL
`define TEST_CB5D
`endif
`ifdef TEST_CB5D
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 5D (BIT 3,L)
	TESTCASE(" -- cb 5d       bit 3,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha900_6264_e833_ee49_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h5d);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha918_6264_e833_ee49_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB5D

`ifdef TEST_ALL
`define TEST_CB5E
`endif
`ifdef TEST_CB5E
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 5E (BIT 3,(HL))
	TESTCASE(" -- cb 5e       bit 3,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h5e); SETMEM(2, 8'h00); SETMEM(16'h01a3, 8'h5b);
	#(2* `CLKPERIOD * 12+`FIN)
	ASSERTMEM(16'h01a3, 8'h5b);
	ASSERT(192'h2610_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB5E

`ifdef TEST_ALL
`define TEST_CB5F
`endif
`ifdef TEST_CB5F
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 5F (BIT 3,A)
	TESTCASE(" -- cb 5f       bit 3,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h8c00_6264_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h5f);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h8c18_6264_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB5F

`ifdef TEST_ALL
`define TEST_CB60
`endif
`ifdef TEST_CB60
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 60 (BIT 4,B)
	TESTCASE(" -- cb 60       bit 4,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9e00_34b5_efaa_505f_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h60);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9e30_34b5_efaa_505f_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB60

`ifdef TEST_ALL
`define TEST_CB61
`endif
`ifdef TEST_CB61
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 61 (BIT 4,C)
	TESTCASE(" -- cb 61       bit 4,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9e00_219f_efaa_505f_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h61);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9e18_219f_efaa_505f_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB61

`ifdef TEST_ALL
`define TEST_CB62
`endif
`ifdef TEST_CB62
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 62 (BIT 4,D)
	TESTCASE(" -- cb 62       bit 4,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9e00_bcb2_7d4f_505f_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h62);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9e38_bcb2_7d4f_505f_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB62

`ifdef TEST_ALL
`define TEST_CB63
`endif
`ifdef TEST_CB63
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 63 (BIT 4,E)
	TESTCASE(" -- cb 63       bit 4,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9e00_bcb2_f627_505f_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h63);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9e74_bcb2_f627_505f_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB63

`ifdef TEST_ALL
`define TEST_CB64
`endif
`ifdef TEST_CB64
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 64 (BIT 4,H)
	TESTCASE(" -- cb 64       bit 4,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9e00_bcb2_efaa_ea94_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h64);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9e7c_bcb2_efaa_ea94_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB64

`ifdef TEST_ALL
`define TEST_CB65
`endif
`ifdef TEST_CB65
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 65 (BIT 4,L)
	TESTCASE(" -- cb 65       bit 4,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9e00_bcb2_efaa_fb4b_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h65);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9e5c_bcb2_efaa_fb4b_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB65

`ifdef TEST_ALL
`define TEST_CB66
`endif
`ifdef TEST_CB66
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 66 (BIT 4,(HL))
	TESTCASE(" -- cb 66       bit 4,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9e00_bcb2_efaa_0131_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h66); SETMEM(16'h0131, 8'hd5);
	#(2* `CLKPERIOD * 12+`FIN)
	ASSERTMEM(16'h0131, 8'hd5);
	ASSERT(192'h9e10_bcb2_efaa_0131_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB66

`ifdef TEST_ALL
`define TEST_CB67
`endif
`ifdef TEST_CB67
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 67 (BIT 4,A)
	TESTCASE(" -- cb 67       bit 4,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h8600_bcb2_efaa_505f_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h67);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h8654_bcb2_efaa_505f_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB67

`ifdef TEST_ALL
`define TEST_CB68
`endif
`ifdef TEST_CB68
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 68 (BIT 5,B)
	TESTCASE(" -- cb 68       bit 5,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha900_0f6a_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h68);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha95c_0f6a_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB68

`ifdef TEST_ALL
`define TEST_CB69
`endif
`ifdef TEST_CB69
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 69 (BIT 5,C)
	TESTCASE(" -- cb 69       bit 5,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha900_5e68_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h69);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha938_5e68_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB69

`ifdef TEST_ALL
`define TEST_CB6A
`endif
`ifdef TEST_CB6A
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 6A (BIT 5,D)
	TESTCASE(" -- cb 6a       bit 5,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha900_6264_86d4_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h6a);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha954_6264_86d4_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB6A

`ifdef TEST_ALL
`define TEST_CB6B
`endif
`ifdef TEST_CB6B
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 6B (BIT 5,E)
	TESTCASE(" -- cb 6b       bit 5,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha900_6264_7635_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h6b);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha930_6264_7635_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB6B

`ifdef TEST_ALL
`define TEST_CB6C
`endif
`ifdef TEST_CB6C
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 6C (BIT 5,H)
	TESTCASE(" -- cb 6c       bit 5,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha900_6264_e833_13e9_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h6c);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha954_6264_e833_13e9_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB6C

`ifdef TEST_ALL
`define TEST_CB6D
`endif
`ifdef TEST_CB6D
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 6D (BIT 5,L)
	TESTCASE(" -- cb 6d       bit 5,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha900_6264_e833_d9ad_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h6d);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha938_6264_e833_d9ad_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB6D

`ifdef TEST_ALL
`define TEST_CB6E
`endif
`ifdef TEST_CB6E
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 6E (BIT 5,(HL))
	TESTCASE(" -- cb 6e       bit 5,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h6e); SETMEM(2, 8'h00); SETMEM(16'h01a3, 8'h31);
	#(2* `CLKPERIOD * 12+`FIN)
	ASSERTMEM(16'h01a3, 8'h31);
	ASSERT(192'h2610_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB6E

`ifdef TEST_ALL
`define TEST_CB6F
`endif
`ifdef TEST_CB6F
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 6F (BIT 5,A)
	TESTCASE(" -- cb 6f       bit 5,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha100_6264_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h6f);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha130_6264_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB6F

`ifdef TEST_ALL
`define TEST_CB70
`endif
`ifdef TEST_CB70
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 70 (BIT 6,B)
	TESTCASE(" -- cb 70       bit 6,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9e00_957a_efaa_505f_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h70);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9e54_957a_efaa_505f_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB70

`ifdef TEST_ALL
`define TEST_CB71
`endif
`ifdef TEST_CB71
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 71 (BIT 6,C)
	TESTCASE(" -- cb 71       bit 6,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9e00_095e_efaa_505f_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h71);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9e18_095e_efaa_505f_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB71

`ifdef TEST_ALL
`define TEST_CB72
`endif
`ifdef TEST_CB72
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 72 (BIT 6,D)
	TESTCASE(" -- cb 72       bit 6,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9e00_bcb2_7d4f_505f_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h72);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9e38_bcb2_7d4f_505f_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB72

`ifdef TEST_ALL
`define TEST_CB73
`endif
`ifdef TEST_CB73
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 73 (BIT 6,E)
	TESTCASE(" -- cb 73       bit 6,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9e00_bcb2_f627_505f_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h73);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9e74_bcb2_f627_505f_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB73

`ifdef TEST_ALL
`define TEST_CB74
`endif
`ifdef TEST_CB74
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 74 (BIT 6,H)
	TESTCASE(" -- cb 74       bit 6,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9e00_bcb2_efaa_983d_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h74);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9e5c_bcb2_efaa_983d_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB74

`ifdef TEST_ALL
`define TEST_CB75
`endif
`ifdef TEST_CB75
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 75 (BIT 6,L)
	TESTCASE(" -- cb 75       bit 6,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9e00_bcb2_efaa_d18d_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h75);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9e5c_bcb2_efaa_d18d_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB75

`ifdef TEST_ALL
`define TEST_CB76
`endif
`ifdef TEST_CB76
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 76 (BIT 6,(HL))
	TESTCASE(" -- cb 76       bit 6,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9e00_bcb2_efaa_0131_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h76); SETMEM(16'h0131, 8'hd5);
	#(2* `CLKPERIOD * 12+`FIN)
	ASSERTMEM(16'h0131, 8'hd5);
	ASSERT(192'h9e10_bcb2_efaa_0131_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB76

`ifdef TEST_ALL
`define TEST_CB77
`endif
`ifdef TEST_CB77
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 77 (BIT 6,A)
	TESTCASE(" -- cb 77       bit 6,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h8600_bcb2_efaa_505f_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h77);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h8654_bcb2_efaa_505f_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB77

`ifdef TEST_ALL
`define TEST_CB78
`endif
`ifdef TEST_CB78
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 78 (BIT 7,B)
	TESTCASE(" -- cb 78       bit 7,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha900_0f6a_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h78);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha95c_0f6a_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB78

`ifdef TEST_ALL
`define TEST_CB79
`endif
`ifdef TEST_CB79
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 79 (BIT 7,C)
	TESTCASE(" -- cb 79       bit 7,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha900_5e9e_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h79);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha998_5e9e_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB79

`ifdef TEST_ALL
`define TEST_CB7A
`endif
`ifdef TEST_CB7A
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 7A (BIT 7,D)
	TESTCASE(" -- cb 7a       bit 7,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha900_6264_63d4_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h7a);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha974_6264_63d4_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB7A

`ifdef TEST_ALL
`define TEST_CB7B
`endif
`ifdef TEST_CB7B
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 7B (BIT 7,E)
	TESTCASE(" -- cb 7b       bit 7,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha900_6264_76bd_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h7b);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha9b8_6264_76bd_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB7B

`ifdef TEST_ALL
`define TEST_CB7C
`endif
`ifdef TEST_CB7C
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 7C (BIT 7,H)
	TESTCASE(" -- cb 7c       bit 7,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha900_6264_e833_13e9_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h7c);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha954_6264_e833_13e9_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB7C

`ifdef TEST_ALL
`define TEST_CB7D
`endif
`ifdef TEST_CB7D
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 7D (BIT 7,L)
	TESTCASE(" -- cb 7d       bit 7,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha900_6264_e833_d99b_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h7d);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha998_6264_e833_d99b_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB7D

`ifdef TEST_ALL
`define TEST_CB7E
`endif
`ifdef TEST_CB7E
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 7E (BIT 7,(HL))
	TESTCASE(" -- cb 7e       bit 7,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h7e); SETMEM(2, 8'h00); SETMEM(16'h01a3, 8'hd7);
	#(2* `CLKPERIOD * 12+`FIN)
	ASSERTMEM(16'h01a3, 8'hd7);
	ASSERT(192'h2690_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB7E

`ifdef TEST_ALL
`define TEST_CB7F
`endif
`ifdef TEST_CB7F
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 7F (BIT 7,A)
	TESTCASE(" -- cb 7f       bit 7,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_6264_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h7f);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a7c_6264_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB7F

`ifdef TEST_ALL
`define TEST_CB80
`endif
`ifdef TEST_CB80
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 80 (RES 0,B)
	TESTCASE(" -- cb 80       res 0,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h80);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB80

`ifdef TEST_ALL
`define TEST_CB81
`endif
`ifdef TEST_CB81
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 81 (RES 0,C)
	TESTCASE(" -- cb 81       res 0,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_947e_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h81);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_947e_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB81

`ifdef TEST_ALL
`define TEST_CB82
`endif
`ifdef TEST_CB82
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 82 (RES 0,D)
	TESTCASE(" -- cb 82       res 0,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h82);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB82

`ifdef TEST_ALL
`define TEST_CB83
`endif
`ifdef TEST_CB83
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 83 (RES 0,E)
	TESTCASE(" -- cb 83       res 0,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_ccf6_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h83);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_ccf6_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB83

`ifdef TEST_ALL
`define TEST_CB84
`endif
`ifdef TEST_CB84
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 84 (RES 0,H)
	TESTCASE(" -- cb 84       res 0,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h84);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6ce0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB84

`ifdef TEST_ALL
`define TEST_CB85
`endif
`ifdef TEST_CB85
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 85 (RES 0,L)
	TESTCASE(" -- cb 85       res 0,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h85);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB85

`ifdef TEST_ALL
`define TEST_CB86
`endif
`ifdef TEST_CB86
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 86 (RES 0,(HL))
	TESTCASE(" -- cb 86       res 0,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h86); SETMEM(2, 8'h00); SETMEM(16'h01a3, 8'hd7);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERTMEM(16'h01a3, 8'hd6);
	ASSERT(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB86

`ifdef TEST_ALL
`define TEST_CB87
`endif
`ifdef TEST_CB87
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 87 (RES 0,A)
	TESTCASE(" -- cb 87       res 0,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h87);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB87

`ifdef TEST_ALL
`define TEST_CB88
`endif
`ifdef TEST_CB88
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 88 (RES 1,B)
	TESTCASE(" -- cb 88       res 1,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h88);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB88

`ifdef TEST_ALL
`define TEST_CB89
`endif
`ifdef TEST_CB89
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 89 (RES 1,C)
	TESTCASE(" -- cb 89       res 1,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_947e_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h89);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_947c_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB89

`ifdef TEST_ALL
`define TEST_CB8A
`endif
`ifdef TEST_CB8A
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 8A (RES 1,D)
	TESTCASE(" -- cb 8a       res 1,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h8a);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB8A

`ifdef TEST_ALL
`define TEST_CB8B
`endif
`ifdef TEST_CB8B
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 8B (RES 1,E)
	TESTCASE(" -- cb 8b       res 1,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_ccf6_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h8b);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_ccf4_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB8B

`ifdef TEST_ALL
`define TEST_CB8C
`endif
`ifdef TEST_CB8C
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 8C (RES 1,H)
	TESTCASE(" -- cb 8c       res 1,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h8c);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB8C

`ifdef TEST_ALL
`define TEST_CB8D
`endif
`ifdef TEST_CB8D
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 8D (RES 1,L)
	TESTCASE(" -- cb 8d       res 1,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h8d);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB8D

`ifdef TEST_ALL
`define TEST_CB8E
`endif
`ifdef TEST_CB8E
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 8E (RES 1,(HL))
	TESTCASE(" -- cb 8e       res 1,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h8e); SETMEM(2, 8'h00); SETMEM(16'h01a3, 8'hd7);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERTMEM(16'h01a3, 8'hd5);
	ASSERT(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB8E

`ifdef TEST_ALL
`define TEST_CB8F
`endif
`ifdef TEST_CB8F
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 8F (RES 1,A)
	TESTCASE(" -- cb 8F       res 1,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h8f);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6800_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB8F

`ifdef TEST_ALL
`define TEST_CB90
`endif
`ifdef TEST_CB90
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 90 (RES 2,B)
	TESTCASE(" -- cb 90       res 2,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h90);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB90

`ifdef TEST_ALL
`define TEST_CB91
`endif
`ifdef TEST_CB91
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 91 (RES 2,C)
	TESTCASE(" -- cb 91       res 2,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_947e_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h91);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_947a_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB91

`ifdef TEST_ALL
`define TEST_CB92
`endif
`ifdef TEST_CB92
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 92 (RES 2,D)
	TESTCASE(" -- cb 92       res 2,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h92);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB92

`ifdef TEST_ALL
`define TEST_CB93
`endif
`ifdef TEST_CB93
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 93 (RES 2,E)
	TESTCASE(" -- cb 93       res 2,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_ccf6_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h93);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_ccf2_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB93

`ifdef TEST_ALL
`define TEST_CB94
`endif
`ifdef TEST_CB94
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 94 (RES 2,H)
	TESTCASE(" -- cb 94       res 2,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h94);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_69e0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB94

`ifdef TEST_ALL
`define TEST_CB95
`endif
`ifdef TEST_CB95
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 95 (RES 2,L)
	TESTCASE(" -- cb 95       res 2,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h95);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB95

`ifdef TEST_ALL
`define TEST_CB96
`endif
`ifdef TEST_CB96
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 96 (RES 2,(HL))
	TESTCASE(" -- cb 96       res 2,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h96); SETMEM(2, 8'h00); SETMEM(16'h01a3, 8'hd7);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERTMEM(16'h01a3, 8'hd3);
	ASSERT(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB96

`ifdef TEST_ALL
`define TEST_CB97
`endif
`ifdef TEST_CB97
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 97 (RES 2,A)
	TESTCASE(" -- cb 97       res 2,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h97);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB97

`ifdef TEST_ALL
`define TEST_CB98
`endif
`ifdef TEST_CB98
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 98 (RES 3,B)
	TESTCASE(" -- cb 98       res 3,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h98);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB98

`ifdef TEST_ALL
`define TEST_CB99
`endif
`ifdef TEST_CB99
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 99 (RES 3,C)
	TESTCASE(" -- cb 99       res 3,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_947e_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h99);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_9476_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB99

`ifdef TEST_ALL
`define TEST_CB9A
`endif
`ifdef TEST_CB9A
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 9A (RES 3,D)
	TESTCASE(" -- cb 9a       res 3,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h9a);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e033_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB9A

`ifdef TEST_ALL
`define TEST_CB9B
`endif
`ifdef TEST_CB9B
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 9B (RES 3,E)
	TESTCASE(" -- cb 9b       res 3,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_ccf6_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h9b);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_ccf6_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB9B

`ifdef TEST_ALL
`define TEST_CB9C
`endif
`ifdef TEST_CB9C
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 9C (RES 3,H)
	TESTCASE(" -- cb 9c       res 3,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h9c);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_65e0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB9C

`ifdef TEST_ALL
`define TEST_CB9D
`endif
`ifdef TEST_CB9D
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 9D (RES 3,L)
	TESTCASE(" -- cb 9d       res 3,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h9d);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB9D

`ifdef TEST_ALL
`define TEST_CB9E
`endif
`ifdef TEST_CB9E
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 9E (RES 3,(HL))
	TESTCASE(" -- cb 9e       res 3,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h9e); SETMEM(2, 8'h00); SETMEM(16'h01a3, 8'hd7);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERTMEM(16'h01a3, 8'hd7);
	ASSERT(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB9E

`ifdef TEST_ALL
`define TEST_CB9F
`endif
`ifdef TEST_CB9F
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 9F (RES 3,A)
	TESTCASE(" -- cb 9F       res 3,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'h9f);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6200_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CB9F

`ifdef TEST_ALL
`define TEST_CBA0
`endif
`ifdef TEST_CBA0
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB A0 (RES 4,B)
	TESTCASE(" -- cb a0       res 4,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'ha0);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_602f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBA0

`ifdef TEST_ALL
`define TEST_CBA1
`endif
`ifdef TEST_CBA1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB A1 (RES 4,C)
	TESTCASE(" -- cb a1       res 4,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_947e_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'ha1);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_946e_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBA1

`ifdef TEST_ALL
`define TEST_CBA2
`endif
`ifdef TEST_CBA2
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB A2 (RES 4,D)
	TESTCASE(" -- cb a2       res 4,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'ha2);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBA2

`ifdef TEST_ALL
`define TEST_CBA3
`endif
`ifdef TEST_CBA3
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB A3 (RES 4,E)
	TESTCASE(" -- cb a3       res 4,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_ccf6_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'ha3);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_cce6_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBA3

`ifdef TEST_ALL
`define TEST_CBA4
`endif
`ifdef TEST_CBA4
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB A4 (RES 4,H)
	TESTCASE(" -- cb a4       res 4,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'ha4);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBA4

`ifdef TEST_ALL
`define TEST_CBA5
`endif
`ifdef TEST_CBA5
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB A5 (RES 4,L)
	TESTCASE(" -- cb a5       res 4,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'ha5);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBA5

`ifdef TEST_ALL
`define TEST_CBA6
`endif
`ifdef TEST_CBA6
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB A6 (RES 4,(HL))
	TESTCASE(" -- cb a6       res 4,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'ha6); SETMEM(2, 8'h00); SETMEM(16'h01a3, 8'hd7);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERTMEM(16'h01a3, 8'hc7);
	ASSERT(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBA6

`ifdef TEST_ALL
`define TEST_CBA7
`endif
`ifdef TEST_CBA7
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB A7 (RES 4,A)
	TESTCASE(" -- cb a7       res 4,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'ha7);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBA7

`ifdef TEST_ALL
`define TEST_CBA8
`endif
`ifdef TEST_CBA8
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB A8 (RES 4,B)
	TESTCASE(" -- cb a8       res 5,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'ha8);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_502f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBA8

`ifdef TEST_ALL
`define TEST_CBA9
`endif
`ifdef TEST_CBA9
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB A9 (RES 5,C)
	TESTCASE(" -- cb a9       res 5,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_947e_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'ha9);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_945e_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBA9

`ifdef TEST_ALL
`define TEST_CBAA
`endif
`ifdef TEST_CBAA
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB AA (RES 5,D)
	TESTCASE(" -- cb aa       res 5,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'haa);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_c833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBAA

`ifdef TEST_ALL
`define TEST_CBAB
`endif
`ifdef TEST_CBAB
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB AB (RES 5,E)
	TESTCASE(" -- cb ab       res 5,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_ccf6_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hab);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_ccd6_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBAB

`ifdef TEST_ALL
`define TEST_CBAC
`endif
`ifdef TEST_CBAC
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB AC (RES 5,H)
	TESTCASE(" -- cb ac       res 5,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hac);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_4de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBAC

`ifdef TEST_ALL
`define TEST_CBAD
`endif
`ifdef TEST_CBAD
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB AD (RES 5,L)
	TESTCASE(" -- cb ad       res 5,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'had);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6dc0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBAD

`ifdef TEST_ALL
`define TEST_CBAE
`endif
`ifdef TEST_CBAE
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB AE (RES 5,(HL))
	TESTCASE(" -- cb ae       res 5,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hae); SETMEM(2, 8'h00); SETMEM(16'h01a3, 8'hd7);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERTMEM(16'h01a3, 8'hd7);
	ASSERT(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBAE

`ifdef TEST_ALL
`define TEST_CBAF
`endif
`ifdef TEST_CBAF
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB AF (RES 5,A)
	TESTCASE(" -- cb aF       res 5,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'haf);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h4a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBAF

`ifdef TEST_ALL
`define TEST_CBB0
`endif
`ifdef TEST_CBB0
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB B0 (RES 6,B)
	TESTCASE(" -- cb b0       res 6,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hb0);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_302f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBB0

`ifdef TEST_ALL
`define TEST_CBB1
`endif
`ifdef TEST_CBB1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB B1 (RES 6,C)
	TESTCASE(" -- cb b1       res 6,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_947e_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hb1);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_943e_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBB1

`ifdef TEST_ALL
`define TEST_CBB2
`endif
`ifdef TEST_CBB2
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB B2 (RES 6,D)
	TESTCASE(" -- cb b2       res 6,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hb2);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_a833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBB2

`ifdef TEST_ALL
`define TEST_CBB3
`endif
`ifdef TEST_CBB3
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB B3 (RES 6,E)
	TESTCASE(" -- cb b3       res 6,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_ccf6_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hb3);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_ccb6_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBB3

`ifdef TEST_ALL
`define TEST_CBB4
`endif
`ifdef TEST_CBB4
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB B4 (RES 6,H)
	TESTCASE(" -- cb b4       res 6,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hb4);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_2de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBB4

`ifdef TEST_ALL
`define TEST_CBB5
`endif
`ifdef TEST_CBB5
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB B5 (RES 6,L)
	TESTCASE(" -- cb b5       res 6,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hb5);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6da0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBB5

`ifdef TEST_ALL
`define TEST_CBB6
`endif
`ifdef TEST_CBB6
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB B6 (RES 6,(HL))
	TESTCASE(" -- cb b6       res 6,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hb6); SETMEM(2, 8'h00); SETMEM(16'h01a3, 8'hd7);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERTMEM(16'h01a3, 8'h97);
	ASSERT(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBB6

`ifdef TEST_ALL
`define TEST_CBB7
`endif
`ifdef TEST_CBB7
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB B7 (RES 6,A)
	TESTCASE(" -- cb b7       res 6,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hb7);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h2a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBB7

`ifdef TEST_ALL
`define TEST_CBB8
`endif
`ifdef TEST_CBB8
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB B8 (RES 6,B)
	TESTCASE(" -- cb b8       res 7,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hb8);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBB8

`ifdef TEST_ALL
`define TEST_CBB9
`endif
`ifdef TEST_CBB9
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB B9 (RES 7,C)
	TESTCASE(" -- cb b9       res 7,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_947e_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hb9);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_947e_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBB9

`ifdef TEST_ALL
`define TEST_CBBA
`endif
`ifdef TEST_CBBA
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB BA (RES 7,D)
	TESTCASE(" -- cb ba       res 7,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hba);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_6833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBBA

`ifdef TEST_ALL
`define TEST_CBBB
`endif
`ifdef TEST_CBBB
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB BB (RES 7,E)
	TESTCASE(" -- cb bb       res 7,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_ccf6_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hbb);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_cc76_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBBB

`ifdef TEST_ALL
`define TEST_CBBC
`endif
`ifdef TEST_CBBC
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB BC (RES 7,H)
	TESTCASE(" -- cb bc       res 7,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hbc);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBBC

`ifdef TEST_ALL
`define TEST_CBBD
`endif
`ifdef TEST_CBBD
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB BD (RES 7,L)
	TESTCASE(" -- cb bd       res 7,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hbd);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6d60_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBBD

`ifdef TEST_ALL
`define TEST_CBBE
`endif
`ifdef TEST_CBBE
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB BE (RES 7,(HL))
	TESTCASE(" -- cb be       res 7,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hbe); SETMEM(2, 8'h00); SETMEM(16'h01a3, 8'hd7);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERTMEM(16'h01a3, 8'h57);
	ASSERT(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBBE

`ifdef TEST_ALL
`define TEST_CBBF
`endif
`ifdef TEST_CBBF
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB BF (RES 7,A)
	TESTCASE(" -- cb bF       res 7,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hbf);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBBF

`ifdef TEST_ALL
`define TEST_CBC0
`endif
`ifdef TEST_CBC0
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB C0 (SET 0,B)
	TESTCASE(" -- cb c0       set 0,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hc0);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_712f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBC0

`ifdef TEST_ALL
`define TEST_CBC1
`endif
`ifdef TEST_CBC1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB C1 (SET 0,C)
	TESTCASE(" -- cb c1       set 0,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hc1);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBC1

`ifdef TEST_ALL
`define TEST_CBC2
`endif
`ifdef TEST_CBC2
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB C2 (SET 0,D)
	TESTCASE(" -- cb c2       set 0,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hc2);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e933_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBC2

`ifdef TEST_ALL
`define TEST_CBC3
`endif
`ifdef TEST_CBC3
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB C3 (SET 0,E)
	TESTCASE(" -- cb c3       set 0,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hc3);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBC3

`ifdef TEST_ALL
`define TEST_CBC4
`endif
`ifdef TEST_CBC4
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB C4 (SET 0,H)
	TESTCASE(" -- cb c4       set 0,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hc4);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBC4

`ifdef TEST_ALL
`define TEST_CBC5
`endif
`ifdef TEST_CBC5
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB C5 (SET 0,L)
	TESTCASE(" -- cb c5       set 0,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hc5);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de1_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBC5

`ifdef TEST_ALL
`define TEST_CBC6
`endif
`ifdef TEST_CBC6
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB C6 (SET 0,(HL))
	TESTCASE(" -- cb c6       set 0,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hc6); SETMEM(2, 8'h00); SETMEM(16'h01a3, 8'hd7);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERTMEM(16'h01a3, 8'hd7);
	ASSERT(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBC6

`ifdef TEST_ALL
`define TEST_CBC7
`endif
`ifdef TEST_CBC7
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB C7 (SET 0,A)
	TESTCASE(" -- cb c7       set 0,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hc7);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6b00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBC8

`ifdef TEST_ALL
`define TEST_CBC8
`endif
`ifdef TEST_CBC8
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB C8 (SET 1,B)
	TESTCASE(" -- cb c8       set 1,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hc8);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_722f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBC8

`ifdef TEST_ALL
`define TEST_CBC9
`endif
`ifdef TEST_CBC9
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB C9 (SET 1,C)
	TESTCASE(" -- cb c9       set 1,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hc9);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBC9

`ifdef TEST_ALL
`define TEST_CBCA
`endif
`ifdef TEST_CBCA
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB CA (SET 1,D)
	TESTCASE(" -- cb ca       set 1,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hca);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_ea33_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBCA

`ifdef TEST_ALL
`define TEST_CBCB
`endif
`ifdef TEST_CBCB
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB CB (SET 1,E)
	TESTCASE(" -- cb cb       set 1,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hcb);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBCB

`ifdef TEST_ALL
`define TEST_CBCC
`endif
`ifdef TEST_CBCC
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB CC (SET 1,H)
	TESTCASE(" -- cb cc       set 1,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hcc);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6fe0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBCC

`ifdef TEST_ALL
`define TEST_CBCD
`endif
`ifdef TEST_CBCD
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB CD (SET 1,L)
	TESTCASE(" -- cb cd       set 1,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hcd);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de2_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBCD

`ifdef TEST_ALL
`define TEST_CBCE
`endif
`ifdef TEST_CBCE
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB CE (SET 1,(HL))
	TESTCASE(" -- cb ce       set 1,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hce); SETMEM(2, 8'h00); SETMEM(16'h01a3, 8'hd7);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERTMEM(16'h01a3, 8'hd7);
	ASSERT(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBCE

`ifdef TEST_ALL
`define TEST_CBCF
`endif
`ifdef TEST_CBCF
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB CF (SET 1,A)
	TESTCASE(" -- cb cf       set 1,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hcf);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBCF

`ifdef TEST_ALL
`define TEST_CBD0
`endif
`ifdef TEST_CBD0
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB D0 (SET 2,B)
	TESTCASE(" -- cb d0       set 2,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hd0);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_742f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBD0

`ifdef TEST_ALL
`define TEST_CBD1
`endif
`ifdef TEST_CBD1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB D1 (SET 2,C)
	TESTCASE(" -- cb d1       set 2,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hd1);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBD1

`ifdef TEST_ALL
`define TEST_CBD2
`endif
`ifdef TEST_CBD2
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB D2 (SET 2,D)
	TESTCASE(" -- cb d2       set 2,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hd2);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_ec33_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBD2

`ifdef TEST_ALL
`define TEST_CBD3
`endif
`ifdef TEST_CBD3
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB D3 (SET 2,E)
	TESTCASE(" -- cb d3       set 2,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hd3);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e837_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBD3

`ifdef TEST_ALL
`define TEST_CBD4
`endif
`ifdef TEST_CBD4
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB D4 (SET 2,H)
	TESTCASE(" -- cb d4       set 2,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hd4);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBD4

`ifdef TEST_ALL
`define TEST_CBD5
`endif
`ifdef TEST_CBD5
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB D5 (SET 2,L)
	TESTCASE(" -- cb d5       set 2,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hd5);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de4_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBD5

`ifdef TEST_ALL
`define TEST_CBD6
`endif
`ifdef TEST_CBD6
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB D6 (SET 2,(HL))
	TESTCASE(" -- cb d6       set 2,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hd6); SETMEM(2, 8'h00); SETMEM(16'h01a3, 8'hd7);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERTMEM(16'h01a3, 8'hd7);
	ASSERT(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBD6

`ifdef TEST_ALL
`define TEST_CBD7
`endif
`ifdef TEST_CBD7
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB D7 (SET 2,A)
	TESTCASE(" -- cb d7       set 2,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hd7);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6e00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBD7

`ifdef TEST_ALL
`define TEST_CBD8
`endif
`ifdef TEST_CBD8
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB D8 (SET 3,B)
	TESTCASE(" -- cb d8       set 3,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hd8);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_782f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBD8

`ifdef TEST_ALL
`define TEST_CBD9
`endif
`ifdef TEST_CBD9
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB D9 (SET 3,C)
	TESTCASE(" -- cb d9       set 3,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hd9);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBD9

`ifdef TEST_ALL
`define TEST_CBDA
`endif
`ifdef TEST_CBDA
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB DA (SET 3,D)
	TESTCASE(" -- cb da       set 3,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hda);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBDA

`ifdef TEST_ALL
`define TEST_CBDB
`endif
`ifdef TEST_CBDB
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB DB (SET 3,E)
	TESTCASE(" -- cb db       set 3,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hdb);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e83b_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBDB

`ifdef TEST_ALL
`define TEST_CBDC
`endif
`ifdef TEST_CBDC
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB DC (SET 3,H)
	TESTCASE(" -- cb dc       set 3,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hdc);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBDC

`ifdef TEST_ALL
`define TEST_CBDD
`endif
`ifdef TEST_CBDD
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB DD (SET 3,L)
	TESTCASE(" -- cb dd       set 3,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hdd);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de8_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBDD

`ifdef TEST_ALL
`define TEST_CBDE
`endif
`ifdef TEST_CBDE
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB DE (SET 3,(HL))
	TESTCASE(" -- cb de       set 3,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hde); SETMEM(2, 8'h00); SETMEM(16'h01a3, 8'hd7);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERTMEM(16'h01a3, 8'hdf);
	ASSERT(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBDE

`ifdef TEST_ALL
`define TEST_CBDF
`endif
`ifdef TEST_CBDF
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB DF (SET 3,A)
	TESTCASE(" -- cb df       set 3,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hdf);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBDF

`ifdef TEST_ALL
`define TEST_CBE0
`endif
`ifdef TEST_CBE0
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB E0 (SET 4,B)
	TESTCASE(" -- cb e0       set 4,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'he0);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBE0

`ifdef TEST_ALL
`define TEST_CBE1
`endif
`ifdef TEST_CBE1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB E1 (SET 4,C)
	TESTCASE(" -- cb e1       set 4,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'he1);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_703f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBE1

`ifdef TEST_ALL
`define TEST_CBE2
`endif
`ifdef TEST_CBE2
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB E2 (SET 4,D)
	TESTCASE(" -- cb e2       set 4,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'he2);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_f833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBE2

`ifdef TEST_ALL
`define TEST_CBE3
`endif
`ifdef TEST_CBE3
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB E3 (SET 4,E)
	TESTCASE(" -- cb e3       set 4,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'he3);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBE3

`ifdef TEST_ALL
`define TEST_CBE4
`endif
`ifdef TEST_CBE4
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB E4 (SET 4,H)
	TESTCASE(" -- cb e4       set 4,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'he4);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_7de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBE4

`ifdef TEST_ALL
`define TEST_CBE5
`endif
`ifdef TEST_CBE5
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB E5 (SET 4,L)
	TESTCASE(" -- cb e5       set 4,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'he5);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6df0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBE5

`ifdef TEST_ALL
`define TEST_CBE6
`endif
`ifdef TEST_CBE6
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB E6 (SET 4,(HL))
	TESTCASE(" -- cb e6       set 4,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'he6); SETMEM(2, 8'h00); SETMEM(16'h01a3, 8'hd7);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERTMEM(16'h01a3, 8'hd7);
	ASSERT(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBE6

`ifdef TEST_ALL
`define TEST_CBE7
`endif
`ifdef TEST_CBE7
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB E7 (SET 4,A)
	TESTCASE(" -- cb e7       set 4,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'he7);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h7a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBE7

`ifdef TEST_ALL
`define TEST_CBE8
`endif
`ifdef TEST_CBE8
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB E8 (SET 5,B)
	TESTCASE(" -- cb e8       set 5,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'he8);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBE8

`ifdef TEST_ALL
`define TEST_CBE9
`endif
`ifdef TEST_CBE9
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB E9 (SET 5,C)
	TESTCASE(" -- cb e9       set 5,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'he9);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBE9

`ifdef TEST_ALL
`define TEST_CBEA
`endif
`ifdef TEST_CBEA
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB EA (SET 5,D)
	TESTCASE(" -- cb ea       set 5,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hea);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBEA

`ifdef TEST_ALL
`define TEST_CBEB
`endif
`ifdef TEST_CBEB
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB EB (SET 5,E)
	TESTCASE(" -- cb eb       set 5,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'heb);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBEB

`ifdef TEST_ALL
`define TEST_CBEC
`endif
`ifdef TEST_CBEC
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB EC (SET 5,H)
	TESTCASE(" -- cb ec       set 5,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hec);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBEC

`ifdef TEST_ALL
`define TEST_CBED
`endif
`ifdef TEST_CBED
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB ED (SET 5,L)
	TESTCASE(" -- cb ed       set 5,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hed);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBED

`ifdef TEST_ALL
`define TEST_CBEE
`endif
`ifdef TEST_CBEE
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB EE (SET 5,(HL))
	TESTCASE(" -- cb ee       set 5,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hee); SETMEM(2, 8'h00); SETMEM(16'h01a3, 8'hd7);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERTMEM(16'h01a3, 8'hf7);
	ASSERT(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBEE

`ifdef TEST_ALL
`define TEST_CBEF
`endif
`ifdef TEST_CBEF
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB EF (SET 5,A)
	TESTCASE(" -- cb ef       set 5,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hef);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBEF

`ifdef TEST_ALL
`define TEST_CBF0
`endif
`ifdef TEST_CBF0
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB F0 (SET 6,B)
	TESTCASE(" -- cb f0       set 6,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hf0);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBF0

`ifdef TEST_ALL
`define TEST_CBF1
`endif
`ifdef TEST_CBF1
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB F1 (SET 6,C)
	TESTCASE(" -- cb f1       set 6,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hf1);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_706f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBF1

`ifdef TEST_ALL
`define TEST_CBF2
`endif
`ifdef TEST_CBF2
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB F2 (SET 6,D)
	TESTCASE(" -- cb f2       set 6,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hf2);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBF2

`ifdef TEST_ALL
`define TEST_CBF3
`endif
`ifdef TEST_CBF3
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB F3 (SET 6,E)
	TESTCASE(" -- cb f3       set 6,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hf3);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e873_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBF3

`ifdef TEST_ALL
`define TEST_CBF4
`endif
`ifdef TEST_CBF4
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB F4 (SET 6,H)
	TESTCASE(" -- cb f4       set 6,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hf4);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBF4

`ifdef TEST_ALL
`define TEST_CBF5
`endif
`ifdef TEST_CBF5
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB F5 (SET 6,L)
	TESTCASE(" -- cb f5       set 6,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hf5);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBF5

`ifdef TEST_ALL
`define TEST_CBF6
`endif
`ifdef TEST_CBF6
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB F6 (SET 6,(HL))
	TESTCASE(" -- cb f6       set 6,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hf6); SETMEM(2, 8'h00); SETMEM(16'h01a3, 8'hd7);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERTMEM(16'h01a3, 8'hd7);
	ASSERT(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBF6

`ifdef TEST_ALL
`define TEST_CBF7
`endif
`ifdef TEST_CBF7
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB F7 (SET 6,A)
	TESTCASE(" -- cb f7       set 6,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hf7);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBF7

`ifdef TEST_ALL
`define TEST_CBF8
`endif
`ifdef TEST_CBF8
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB F8 (SET 7,B)
	TESTCASE(" -- cb f8       set 7,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hf8);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_f02f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBF8

`ifdef TEST_ALL
`define TEST_CBF9
`endif
`ifdef TEST_CBF9
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB F9 (SET 7,C)
	TESTCASE(" -- cb f9       set 7,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hf9);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_70af_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBF9

`ifdef TEST_ALL
`define TEST_CBFA
`endif
`ifdef TEST_CBFA
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB FA (SET 7,D)
	TESTCASE(" -- cb fa       set 7,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hfa);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBFA

`ifdef TEST_ALL
`define TEST_CBFB
`endif
`ifdef TEST_CBFB
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB FB (SET 7,E)
	TESTCASE(" -- cb fb       set 7,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hfb);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e8b3_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBFB

`ifdef TEST_ALL
`define TEST_CBFC
`endif
`ifdef TEST_CBFC
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB FC (SET 7,H)
	TESTCASE(" -- cb fc       set 7,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hfc);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_ede0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBFC

`ifdef TEST_ALL
`define TEST_CBFD
`endif
`ifdef TEST_CBFD
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB FD (SET 7,L)
	TESTCASE(" -- cb fd       set 7,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hfd);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBFD

`ifdef TEST_ALL
`define TEST_CBFE
`endif
`ifdef TEST_CBFE
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB FE (SET 7,(HL))
	TESTCASE(" -- cb fe       set 7,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hfe); SETMEM(2, 8'h00); SETMEM(16'h01a3, 8'hd7);
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERTMEM(16'h01a3, 8'hd7);
	ASSERT(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBFE

`ifdef TEST_ALL
`define TEST_CBFF
`endif
`ifdef TEST_CBFF
	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB FF (SET 7,A)
	TESTCASE(" -- cb ff       set 7,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	SETMEM(0, 8'hcb);  SETMEM(1, 8'hff);
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hea00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
`endif // TEST_CBFF

	$finish;
end

	 always #(`CLKPERIOD) i_clk = ~i_clk;


endmodule