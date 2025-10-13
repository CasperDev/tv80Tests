
`timescale 1ns/100ps
`default_nettype none
`define CLKPERIOD 5

module tb();

    reg i_clk = 0;          // Signals driven from within a process (an initial or always block) must be type reg
    reg i_reset_btn =1;

    initial begin
        $dumpfile("fuse.vcd");    // where to write the dump
        $dumpvars;                  // dump EVERYTHING
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
 
reg [7:0] mem[0:1023];
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

	integer testlen;

reg FAIL = 1'b0;
reg [0:48*8] TESTCASE;
task ASSERT;
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	input [191:0] REGS;
	input [7:0] I;
	input [7:0] R;
	input [1:0] IFF;
	reg alt;
	begin
		FAIL = 1'b0;
	alt = cpu.core.Alternate;
	//if (cpu.state != cpu.ST_FETCH_M1_T1) $display("* FAIL *: [CPU state] other than ST_FETCH_M1_T1, %b", cpu.state);
	if (cpu.core.PC != REGS[15:0]) begin FAIL = 1'b1; $display("* FAIL *: [PC] expected=%4h, actual=%4h",REGS[15:0],cpu.core.PC); end;
	if (cpu.core.SP != REGS[31:16]) begin FAIL = 1'b1; $display("* FAIL *: [SP] expected=%4h, actual=%4h",REGS[31:16],cpu.core.SP); end;
	if (cpu.core.ACC != REGS[191:184]) begin FAIL = 1'b1; $display("* FAIL *: [A] expected=%2h, actual=%2h",REGS[191:184],cpu.core.ACC); end;
	if (cpu.core.F != REGS[183:176]) begin FAIL = 1'b1; $display("* FAIL *: [F] expected=%2h, actual=%2h",REGS[183:176],cpu.core.F); end;
	if (cpu.core.Ap != REGS[127:120]) begin FAIL = 1'b1; $display("* FAIL *: [A'] expected=%2h, actual=%2h",REGS[127:120],cpu.core.Ap); end;
	if (cpu.core.Fp != REGS[119:112]) begin FAIL = 1'b1; $display("* FAIL *: [F'] expected=%2h, actual=%2h",REGS[119:112],cpu.core.Fp); end;
	if (cpu.core.regs.RegsH[{alt,2'b00}] != REGS[175:168]) begin FAIL = 1'b1; $display("* FAIL *: [B] expected=%2h, actual=%2h",REGS[175:168],cpu.core.regs.RegsH[{alt,2'b00}]); end;
	if (cpu.core.regs.RegsL[{alt,2'b00}] != REGS[167:160]) begin FAIL = 1'b1; $display("* FAIL *: [C] expected=%2h, actual=%2h",REGS[167:160],cpu.core.regs.RegsL[{alt,2'b00}]); end;
	if (cpu.core.regs.RegsH[{alt,2'b01}] != REGS[159:152]) begin FAIL = 1'b1; $display("* FAIL *: [D] expected=%2h, actual=%2h",REGS[159:152],cpu.core.regs.RegsH[{alt,2'b01}]); end;
	if (cpu.core.regs.RegsL[{alt,2'b01}] != REGS[151:144]) begin FAIL = 1'b1; $display("* FAIL *: [E] expected=%2h, actual=%2h",REGS[151:144],cpu.core.regs.RegsL[{alt,2'b01}]); end;
	if (cpu.core.regs.RegsH[{alt,2'b10}] != REGS[143:136]) begin FAIL = 1'b1; $display("* FAIL *: [H] expected=%2h, actual=%2h",REGS[143:136],cpu.core.regs.RegsH[{alt,2'b10}]); end;
	if (cpu.core.regs.RegsL[{alt,2'b10}] != REGS[135:128]) begin FAIL = 1'b1; $display("* FAIL *: [L] expected=%2h, actual=%2h",REGS[135:128],cpu.core.regs.RegsL[{alt,2'b10}]); end;
	if (cpu.core.regs.RegsH[{!alt,2'b00}] != REGS[111:104]) begin FAIL = 1'b1; $display("* FAIL *: [B'] expected=%2h, actual=%2h",REGS[111:104],cpu.core.regs.RegsH[{!alt,2'b00}]); end;
	if (cpu.core.regs.RegsL[{!alt,2'b00}] != REGS[103:96]) begin FAIL = 1'b1; $display("* FAIL *: [C'] expected=%2h, actual=%2h",REGS[103:96],cpu.core.regs.RegsL[{!alt,2'b00}]); end;
	if (cpu.core.regs.RegsH[{!alt,2'b01}] != REGS[95:88]) begin FAIL = 1'b1; $display("* FAIL *: [D'] expected=%2h, actual=%2h",REGS[95:88],cpu.core.regs.RegsH[{!alt,2'b01}]); end;
	if (cpu.core.regs.RegsL[{!alt,2'b01}] != REGS[87:80]) begin FAIL = 1'b1; $display("* FAIL *: [E'] expected=%2h, actual=%2h",REGS[87:80],cpu.core.regs.RegsL[{!alt,2'b01}]); end;
	if (cpu.core.regs.RegsH[{!alt,2'b10}] != REGS[79:72]) begin FAIL = 1'b1; $display("* FAIL *: [H'] expected=%2h, actual=%2h",REGS[79:72],cpu.core.regs.RegsH[{!alt,2'b10}]); end;
	if (cpu.core.regs.RegsL[{!alt,2'b10}] != REGS[71:64]) begin FAIL = 1'b1; $display("* FAIL *: [L'] expected=%2h, actual=%2h",REGS[71:64],cpu.core.regs.RegsL[{!alt,2'b10}]); end;
	if (cpu.core.regs.RegsH[3] != REGS[63:56]) begin FAIL = 1'b1; $display("* FAIL *: [IXH] expected=%2h, actual=%2h",REGS[63:56],cpu.core.regs.RegsH[3]); end;
	if (cpu.core.regs.RegsL[3] != REGS[55:48]) begin FAIL = 1'b1; $display("* FAIL *: [IXL] expected=%2h, actual=%2h",REGS[55:48],cpu.core.regs.RegsL[3]); end;
	if (cpu.core.regs.RegsH[7] != REGS[47:40]) begin FAIL = 1'b1; $display("* FAIL *: [IYH] expected=%2h, actual=%2h",REGS[47:40],cpu.core.regs.RegsH[7]); end;
	if (cpu.core.regs.RegsL[7] != REGS[39:32]) begin FAIL = 1'b1; $display("* FAIL *: [IYL] expected=%2h, actual=%2h",REGS[39:32],cpu.core.regs.RegsL[7]); end;
	if (cpu.core.I != I) begin FAIL = 1'b1; $display("* FAIL *: [I] expected=%2h, actual=%2h",I,cpu.core.I); end;
	if (cpu.core.R != R) begin FAIL = 1'b1; $display("* FAIL *: [R] expected=%2h, actual=%2h",R,cpu.core.R); end;
	if (cpu.core.IntE_FF1 != IFF[0]) begin FAIL = 1'b1; $display("* FAIL *: [IFF1] expected=1'b1 actual=%1b",cpu.core.IntE_FF1); end;
	if (cpu.core.IntE_FF2 != IFF[1]) begin FAIL = 1'b1; $display("* FAIL *: [IFF2] expected=1'b1, actual=%1b",cpu.core.IntE_FF2); end;
	if (FAIL) $display("%s",TESTCASE);
	end
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
`define TESTAREA
`ifdef TESTAREA

	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	TESTCASE = " -- 00          nop";
	// -----------------------------------------------------
	//       - AF    BC   DE   HL   AF'  BC'  DE'  HL'  IX   IY   SP   PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	mem[0] = 8'h00;
	#(2* `CLKPERIOD * 4+`FIN);
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 00 (NOP undoc)
	$display(" -- dd 00       DD nop");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd;  mem[1] = 8'h00;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 00 (NOP undoc)
	$display(" -- fd 00       FD nop");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd;  mem[1] = 8'h00;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 01 (LD BC,$3412)
	$display(" -- 01 12 34    ld bc,$3412");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h01; mem[1] = 8'h12; mem[2] = 8'h34;
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0000_3412_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 01 (LD BC,$3412)
	$display(" -- dd 01 12 34 ld DD bc,$3412");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd;  mem[1] = 8'h01; mem[2] = 8'h12; mem[3] = 8'h34;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h6a00_3412_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0004, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 01 (LD BC,$3412)
	$display(" -- fd 01 12 34 FD ld bc,$3412");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd;  mem[1] = 8'h01; mem[2] = 8'h12; mem[3] = 8'h34;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h6a00_3412_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0004, 8'h00, 8'h02, 2'b00);

	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 02 (LD BC,$3412)
	$display(" -- 02          ld (bc),a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h5600_0001_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h02; mem[1] = 8'h00;
	#(2* `CLKPERIOD * 7)
	ASSERT(192'h5600_0001_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
	if (mem[1] != 8'h56) $display("* FAIL *: [MEMWR] expected=56, actual=%2h",mem[1]);

	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 02 (LD BC,$3412)
	$display(" -- dd 02       DD ld (bc),a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h5600_0134_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h02;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h5600_0134_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0134] != 8'h56) $display("* FAIL *: [MEMWR] expected=56, actual=%2h",mem[16'h0134]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 02 (LD BC,$3412)
	$display(" -- fd 02       FD ld (bc),a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h5600_0134_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h02;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h5600_0134_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0134] != 8'h56) $display("* FAIL *: [MEMWR] expected=56, actual=%2h",mem[16'h0134]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 03 (INC BC)
	$display(" -- 03          inc bc");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_789a_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h03;
	#(2* `CLKPERIOD * 6+`FIN)
	ASSERT(192'h0000_789b_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 03 (INC BC)
	$display(" -- dd 03       DD inc bc");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_789a_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h03;
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0000_789b_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 03 (INC BC)
	$display(" -- fd 03       FD inc bc");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_789a_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h03;
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0000_789b_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 04 (INC B)
	$display(" -- 04          inc b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_ff00_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h04;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0050_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 04 (INC B)
	$display(" -- dd 04       DD inc b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_ff00_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h04;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0050_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 04 (INC B)
	$display(" -- fd 04       FD inc b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_ff00_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h04;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0050_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 05 (DEC B)
	$display(" -- 05          dec b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h05;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h00ba_ff00_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 05 (DEC B)
	$display(" -- dd 05       DD dec b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h05;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h00ba_ff00_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 05 (DEC B)
	$display(" -- fd 05       FD dec b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h05;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h00ba_ff00_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 06 (LD B,n)
	$display(" -- 06          ld b,$BC");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h06; mem[1] = 8'hbc;
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h0000_bc00_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 06 (LD B,n)
	$display(" -- dd 06       DD ld b,$CB");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h06; mem[2] = 8'hcb;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h0000_cb00_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 06 (LD B,n)
	$display(" -- fd 06       FD ld b,$CB");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h06; mem[2] = 8'hcb;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h0000_cb00_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 07 (RLCA)
	$display(" -- 07          rlca");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h8800_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h07;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h1101_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 07 (RLCA)
	$display(" -- dd 07       DD rlca");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h8800_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h07;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h1101_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 07 (RLCA)
	$display(" -- fd 07       FD rlca");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h8800_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h07;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h1101_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 08 (EX AF,AF')
	$display(" -- 08          ex af,af'");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hdef0_0000_0000_0000_1234_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h08;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h1234_0000_0000_0000_def0_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 08 (EX AF,AF')
	$display(" -- dd 08       DD ex af,af'");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hdef0_0000_0000_0000_1234_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h08;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h1234_0000_0000_0000_def0_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 08 (EX AF,AF')
	$display(" -- fd 08       FD ex af,af'");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hdef0_0000_0000_0000_1234_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h08;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h1234_0000_0000_0000_def0_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 09 (ADD HL,BC)
	$display(" -- 09          add hl,bc");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_5678_0000_9abc_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h09;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h0030_5678_0000_f134_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 09 (ADD IX,BC)
	$display(" -- dd 09       add ix,bc");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_5678_0000_1abc_0000_0000_0000_0000_9abc_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h09;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h0030_5678_0000_1abc_0000_0000_0000_0000_f134_0000_0000_0002, 8'h00, 8'h02, 2'b00);

	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 09 (ADD IY,BC)
	$display(" -- fd 09       add iy,bc");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_5678_0000_1abc_0000_0000_0000_0000_0000_9abc_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h09;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h0030_5678_0000_1abc_0000_0000_0000_0000_0000_f134_0000_0002, 8'h00, 8'h02, 2'b00);

	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 0A (LD A,(BC))
	$display(" -- 0A          ld a,(bc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0122_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h0a;  mem[16'h0122] = 8'hde;
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'hde00_0122_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 0A (LD A,(BC))
	$display(" -- dd 0A       DD ld a,(bc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0122_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h0a;  mem[16'h0122] = 8'hde;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'hde00_0122_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 0A (LD A,(BC))
	$display(" -- fd 0A       FD ld a,(bc)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0122_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h0a; mem[16'h0122] = 8'hde;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'hde00_0122_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 0B (DEC BC)
	$display(" -- 0B          dec bc");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h0b;
	#(2* `CLKPERIOD * 6+`FIN)
	ASSERT(192'h0000_ffff_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 0B (DEC BC)
	$display(" -- dd 0B       DD dec bc");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h0b;
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0000_ffff_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 0B (DEC BC)
	$display(" -- fd 0B       FD dec bc");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h0b;
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0000_ffff_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 0C (INC C)
	$display(" -- 0C          inc c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_007f_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h0c;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0094_0080_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 0C (INC C)
	$display(" -- dd 0C       DD inc c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_007f_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h0c;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0094_0080_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 0C (INC C)
	$display(" -- fd 0C       FD inc c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_007f_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h0c;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0094_0080_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 0D (DEC C)
	$display(" -- 0D          dec c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0080_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h0d;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h003e_007f_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 0D (DEC C)
	$display(" -- dd 0D       DD dec c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0080_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h0d;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h003e_007f_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 0D (DEC C)
	$display(" -- fd 0D       FD dec c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0080_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h0d;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h003e_007f_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 0E (LD C,n)
	$display(" -- 0E          ld c,$f0");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h0e; mem[1] = 8'hf0;
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h0000_00f0_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 0E (LD C,n)
	$display(" -- dd 0E       ld c,$f0");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h0e; mem[2] = 8'hf0;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h0000_00f0_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 0E (LD C,n)
	$display(" -- fd 0E       ld c,$f0");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h0e; mem[2] = 8'hf0;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h0000_00f0_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 0F (RRCA)
	$display(" -- 0F          rrca");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h4100_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h0f;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'ha021_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 0F (RRCA)
	$display(" -- dd 0F       DD rrca");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h4100_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h0f;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha021_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 0F (RRCA)
	$display(" -- fd 0F       FD rrca");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h4100_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h0f;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha021_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 10 (DJNZ d)
	$display(" -- 00          nop");
	$display(" -- 10 fd       djnz -3");
	$display(" -- 03          inc c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0800_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h00; mem[1] = 8'h10; mem[2] = 8'hfd; mem[3] = 8'h0c;
	#(2* `CLKPERIOD * 135+`FIN)
	ASSERT(192'h0000_0001_0000_0000_0000_0000_0000_0000_0000_0000_0000_0004, 8'h00, 8'h11, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 10 (DJNZ d)
	$display(" -- dd          DD");
	$display(" -- 10 fd       djnz -3");
	$display(" -- 03          inc c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0800_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h10; mem[2] = 8'hfd; mem[3] = 8'h0c;
	#(2* `CLKPERIOD * 135+`FIN)
	ASSERT(192'h0000_0001_0000_0000_0000_0000_0000_0000_0000_0000_0000_0004, 8'h00, 8'h11, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 10 (DJNZ d)
	$display(" -- fd          FD");
	$display(" -- 10 fd       djnz -3");
	$display(" -- 03          inc c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0800_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h10; mem[2] = 8'hfd; mem[3] = 8'h0c;
	#(2* `CLKPERIOD * 135+`FIN)
	ASSERT(192'h0000_0001_0000_0000_0000_0000_0000_0000_0000_0000_0000_0004, 8'h00, 8'h11, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 11 (LD DE,nn)
	$display(" -- 11 9a bc    ld de, $bc9a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_8123_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h11; mem[1] = 8'hab; mem[2] = 8'hcd;
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0000_0000_cdab_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 11 (LD DE,nn)
	$display(" -- dd 11 9a bc DD ld de, $bc9a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_8123_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h11; mem[2] = 8'hab; mem[3] = 8'hcd;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0000_0000_cdab_0000_0000_0000_0000_0000_0000_0000_0000_0004, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 11 (LD DE,nn)
	$display(" -- fd 11 9a bc FD ld de, $bc9a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_8123_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h11; mem[2] = 8'hab; mem[3] = 8'hcd;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0000_0000_cdab_0000_0000_0000_0000_0000_0000_0000_0000_0004, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 12 (LD (DE),a)
	$display(" -- 12          ld (de),a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h5600_0000_0080_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h12;
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h5600_0000_0080_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
	if (mem[8'h80] != 8'h56) $display("* FAIL *: [MEMWR] expected=56, actual=%2h",mem[8'h80]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 12 (LD (DE),a)
	$display(" -- dd 12       ld (de),a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h5600_0000_00dd_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h12;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h5600_0000_00dd_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
	if (mem[8'hdd] != 8'h56) $display("* FAIL *: [MEMWR] expected=56, actual=%2h",mem[8'hdd]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 12 (LD (DE),a)
	$display(" -- fd 12       ld (de),a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h5600_0000_00fd_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h12;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h5600_0000_00fd_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
	if (mem[8'hfd] != 8'h56) $display("* FAIL *: [MEMWR] expected=56, actual=%2h",mem[8'hfd]);



	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 13 (INC DE)
	$display(" -- 13          inc de");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_def0_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h13;
	#(2* `CLKPERIOD * 6+`FIN)
	ASSERT(192'h0000_0000_def1_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 13 (INC DE)
	$display(" -- dd 13       DD inc de");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_def0_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h13;
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0000_0000_def1_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);



	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 13 (INC DE)
	$display(" -- fd 13       FD inc de");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_def0_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h13;
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0000_0000_def1_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 14 (INC D)
	$display(" -- 14          inc d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_2700_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h14;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0028_0000_2800_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 14 (INC D)
	$display(" -- dd 14       DD inc d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_2700_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h14;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0028_0000_2800_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 14 (INC D)
	$display(" -- fd 14       FD inc d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_2700_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h14;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0028_0000_2800_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 15 (DEC D)
	$display(" -- 15          dec d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_1000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h15;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h001a_0000_0f00_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 15 (DEC D)
	$display(" -- dd 15       DD dec d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_1000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h15;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h001a_0000_0f00_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 15 (DEC D)
	$display(" -- fd 15       FD dec d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_1000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h15;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h001a_0000_0f00_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 16 (LD D,n)
	$display(" -- 16          ld d,$12");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h16; mem[1] = 8'h12;
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h0000_0000_1200_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 16 (LD D,n)
	$display(" -- dd 16       ld d,$dd");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h16; mem[2] = 8'hdd;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h0000_0000_dd00_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 16 (LD D,n)
	$display(" -- fd 16       ld d,$fd");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h16; mem[2] = 8'hfd;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h0000_0000_fd00_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 17 (RLA)
	$display(" -- 17          rla");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0801_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h17;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h1100_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 17 (RLA)
	$display(" -- dd 17       DD rla");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0801_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h17;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h1100_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 17 (RLA)
	$display(" -- fd 17       FD rla");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0801_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h17;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h1100_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 18 (JR d')
	$display(" -- 18          jr $40");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h18; mem[1] = 8'h40;
	#(2* `CLKPERIOD * 12+`FIN)
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0042, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 18 (JR d')
	$display(" -- dd 18       jr $fe");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h18; mem[2] = 8'hfe;
	#(2* `CLKPERIOD * 16+`FIN)
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 18 (JR d')
	$display(" -- fd 18       jr $fd");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h18; mem[2] = 8'hfd;
	#(2* `CLKPERIOD * 16+`FIN)
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 19 (ADD HL,DE)
	$display(" -- 19          add hl,de");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_3456_789a_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h19;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h0028_0000_3456_acf0_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 19 (ADD IX,DE)
	$display(" -- dd 19       add ix,de");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_3456_bcde_0000_0000_0000_0000_789a_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h19;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h0028_0000_3456_bcde_0000_0000_0000_0000_acf0_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 19 (ADD IY,DE)
	$display(" -- fd 19       add iy,de");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_3456_bcde_0000_0000_0000_0000_0000_789a_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h19;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h0028_0000_3456_bcde_0000_0000_0000_0000_0000_acf0_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 1A (LD A,(DE))
	$display(" -- 1A          ld a,(de)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0081_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h1a; mem[8'h81] = 8'h13;
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h1300_0000_0081_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 1A (LD A,(DE))
	$display(" -- dd 1A       DD ld a,(de)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_00dd_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h1a; mem[8'hdd] = 8'h13;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h1300_0000_00dd_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 1A (LD A,(DE))
	$display(" -- fd 1A       FD ld a,(de)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_00dd_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h1a; mem[8'hdd] = 8'h13;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h1300_0000_00dd_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 1B (DEC DE)
	$display(" -- 1B          dec de");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_e5d4_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h1b;
	#(2* `CLKPERIOD * 6+`FIN)
	ASSERT(192'h0000_0000_e5d3_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 1B (DEC DE)
	$display(" -- dd 1B       DD dec de");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_e5d4_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h1b;
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0000_0000_e5d3_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 1B (DEC DE)
	$display(" -- fd 1B       FD dec de");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_e5d4_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h1b;
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0000_0000_e5d3_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 1C (INC E)
	$display(" -- 1c          inc e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_00aa_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h1c;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h00a8_0000_00ab_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 1C (INC E)
	$display(" -- dd 1c       DD inc e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_00aa_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h1c;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h00a8_0000_00ab_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 1C (INC E)
	$display(" -- fd 1c       FD inc e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_00aa_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h1c;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h00a8_0000_00ab_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 1D (DEC E)
	$display(" -- 1d          dec e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_00aa_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h1d;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h00aa_0000_00a9_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 1D (DEC E)
	$display(" -- dd 1d       DD dec e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_00aa_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h1d;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h00aa_0000_00a9_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 1D (DEC E)
	$display(" -- fd 1d       FD dec e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_00aa_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h1d;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h00aa_0000_00a9_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 1E (LD E,n)
	$display(" -- 1E          ld e,$ef");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h1e; mem[1] = 8'hef;
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h0000_0000_00ef_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 1E (LD E,n)
	$display(" -- dd 1e       DD ld e,$dd");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h1e; mem[2] = 8'hdd;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h0000_0000_00dd_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 1E (LD E,n)
	$display(" -- fd 1e       FD ld e,$fd");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h1e; mem[2] = 8'hfd;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h0000_0000_00fd_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 1F (RRA)
	$display(" -- 1F          rra");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h01c4_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h1f;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h00c5_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 1F (RRA)
	$display(" -- dd 1f       DD rra");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h01c4_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h1f;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h00c5_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 1F (RRA)
	$display(" -- fd 1f       DD rra");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h01c4_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h1f;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h00c5_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 20_1 (JR NZ,d)
	$display(" -- 20 40       jr nz,40 ;jump");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h20; mem[1] = 8'h40;
	#(2* `CLKPERIOD * 12+`FIN)
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0042, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 20_1 (JR NZ,d)
	$display(" -- dd 20 40    DD jr nz,$40 ;jump");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h20; mem[2] = 8'h40;
	#(2* `CLKPERIOD * 16+`FIN)
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0043, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 20_1 (JR NZ,d)
	$display(" -- fd 20 40    FD jr nz,$40 ;jump");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h20; mem[2] = 8'h40;
	#(2* `CLKPERIOD * 16+`FIN)
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0043, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 20_1 (JR NZ,d)
	$display(" -- 20 40       jr nz,40 ;no jump");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0040_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h20; mem[1] = 8'h40;
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h0040_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 20_1 (JR NZ,d)
	$display(" -- dd 20 40    DD jr nz,40 ;no jump");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0040_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h20; mem[2] = 8'h40;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h0040_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 20_1 (JR NZ,d)
	$display(" -- fd 20 40    FD jr nz,40 ;no jump");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0040_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h20; mem[2] = 8'h40;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h0040_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 21 (LD HL,nn)
	$display(" -- 21 28 ed    ld hl, $ed28");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h21; mem[1] = 8'h28; mem[2] = 8'hed;
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0000_0000_0000_ed28_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 21 (LD IX,nn)
	$display(" -- dd 21 28 ed ld ix,$ed28");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h21; mem[2] = 8'h28; mem[3] = 8'hed;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_ed28_0000_0000_0004, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 21 (LD IY,nn)
	$display(" -- fd 21 28 ed ld iy,$ed28");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h21; mem[2] = 8'h28; mem[3] = 8'hed;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_ed28_0000_0004, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 22 (LD (nn),hl)
	$display(" -- 22 c3 01    ld ($01c3),hl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0080_c64c_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h22; mem[1] = 8'hc3; mem[2] = 8'h01;
	#(2* `CLKPERIOD * 16+`FIN)
	ASSERT(192'h0000_0000_0080_c64c_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h01, 2'b00);
	if (mem[16'h01c3] != 8'h4c) $display("* FAIL *: [MEMWR] expected=4c, actual=%2h",mem[16'h01c3]);
	if (mem[16'h01c4] != 8'hc6) $display("* FAIL *: [MEMWR] expected=c6, actual=%2h",mem[16'h01c4]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 22 (LD (nn),ix)
	$display(" -- dd 22 c3 01 ld ($01c3),ix");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0080_c64c_0000_0000_0000_0000_dd22_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h22; mem[2] = 8'hc3; mem[3] = 8'h01;
	#(2* `CLKPERIOD * 20+`FIN)
	ASSERT(192'h0000_0000_0080_c64c_0000_0000_0000_0000_dd22_0000_0000_0004, 8'h00, 8'h02, 2'b00);
	if (mem[16'h01c3] != 8'h22) $display("* FAIL *: [MEMWR] expected=22, actual=%2h",mem[16'h01c3]);
	if (mem[16'h01c4] != 8'hdd) $display("* FAIL *: [MEMWR] expected=dd, actual=%2h",mem[16'h01c4]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 22 (LD (nn),ix)
	$display(" -- fd 22 c3 01 ld ($01c3),iy");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0080_c64c_0000_0000_0000_0000_0000_fd33_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h22; mem[2] = 8'hc3; mem[3] = 8'h01;
	#(2* `CLKPERIOD * 20+`FIN)
	ASSERT(192'h0000_0000_0080_c64c_0000_0000_0000_0000_0000_fd33_0000_0004, 8'h00, 8'h02, 2'b00);
	if (mem[16'h01c3] != 8'h33) $display("* FAIL *: [MEMWR] expected=33, actual=%2h",mem[16'h01c3]);
	if (mem[16'h01c4] != 8'hfd) $display("* FAIL *: [MEMWR] expected=fd, actual=%2h",mem[16'h01c4]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 23 (INC HL)
	$display(" -- 23          inc hl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_9c4e_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h23;
	#(2* `CLKPERIOD * 6+`FIN)
	ASSERT(192'h0000_0000_0000_9c4f_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 23 (INC IX)
	$display(" -- dd 23       inc ix");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_9c4e_0000_0000_0000_0000_abcd_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h23;
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0000_0000_0000_9c4e_0000_0000_0000_0000_abce_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 23 (INC IY)
	$display(" -- fd 23       inc iy");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_9c4e_0000_0000_0000_0000_abcd_1234_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h23;
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0000_0000_0000_9c4e_0000_0000_0000_0000_abcd_1235_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 24 (INC D)
	$display(" -- 24          inc h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_7200_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h24;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0020_0000_0000_7300_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 24 (INC IXH)
	$display(" -- dd 24       inc ixh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_7200_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h24;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0000_0000_0000_7200_0000_0000_0000_0000_0100_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 24 (INC IYH)
	$display(" -- fd 24       inc iyh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_7200_0000_0000_0000_0000_0000_7200_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h24;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0020_0000_0000_7200_0000_0000_0000_0000_0000_7300_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 25 (DEC H)
	$display(" -- 25          dec h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_a500_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h25;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h00a2_0000_0000_a400_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 25 (DEC IXH)
	$display(" -- dd 25       dec ixh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_a500_0000_0000_0000_0000_a500_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h25;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h00a2_0000_0000_a500_0000_0000_0000_0000_a400_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 25 (DEC IYH)
	$display(" -- fd 25       dec iyh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_a500_0000_0000_0000_0000_0000_a500_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h25;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h00a2_0000_0000_a500_0000_0000_0000_0000_0000_a400_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 26 (LD H,n)
	$display(" -- 26 3a       ld h,$3a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h26; mem[1] = 8'h3a;
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h0000_0000_0000_3a00_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 26 (LD IXH,n)
	$display(" -- dd 26 3a    ld ixh,$3a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h26; mem[2] = 8'h3a;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_3a00_0000_0000_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 26 (LD IYH,n)
	$display(" -- fd 26 3a    ld iyh,$3a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h26; mem[2] = 8'h3a;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_3a00_0000_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 27 (DAA)
	$display(" -- 27          daa -- 1");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9a02_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h27;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h3423_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 27 (DAA)
	$display(" -- dd 27       DD daa -- 1");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9a02_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h27;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h3423_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 27 (DAA)
	$display(" -- fd 27       FD daa -- 1");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9a02_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h27;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h3423_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 27 (DAA)
	$display(" -- 27          daa -- 2");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h1f00_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h27;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h2530_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 27 (DAA)
	$display(" -- dd 27       daa -- 2");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h1f00_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h27;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h2530_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 27 (DAA)
	$display(" -- fd 27       daa -- 2");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h1f00_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h27;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h2530_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 28 (JR Z,d')
	$display(" -- 28          jr Z,-114 ;no jump");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h28; mem[1] = 8'h8e;
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 28 (JR Z,d')
	$display(" -- dd 28       jr Z,-114 ;no jump");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h28; mem[2] = 8'h8e;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 28 (JR Z,d')
	$display(" -- fd 28       jr Z,-114 ;no jump");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h28; mem[2] = 8'h8e;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 28 (JR Z,d')
	$display(" -- 28          jr Z,-114 ;jump");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0040_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h28; mem[1] = 8'h8e;
	#(2* `CLKPERIOD * 12+`FIN)
	ASSERT(192'h0040_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_ff90, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 28 (JR Z,d')
	$display(" -- dd 28       jr Z,-114 ;jump");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0040_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h28; mem[2] = 8'h8e;
	#(2* `CLKPERIOD * 16+`FIN)
	ASSERT(192'h0040_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_ff91, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 28 (JR Z,d')
	$display(" -- fd 28       jr Z,-114 ;jump");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0040_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h28; mem[2] = 8'h8e;
	#(2* `CLKPERIOD * 16+`FIN)
	ASSERT(192'h0040_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_ff91, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 29 (ADD HL,HL)
	$display(" -- 29          add hl,hl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_cdfa_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h29;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h0019_0000_0000_9bf4_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 29 (ADD IX,IX)
	$display(" -- DD 29       add ix,ix");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_1234_0000_0000_0000_0000_cdfa_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h29;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h0019_0000_0000_1234_0000_0000_0000_0000_9bf4_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 29 (ADD IY,IY)
	$display(" -- FD 29       add iy,iy");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_1234_0000_0000_0000_0000_0000_cdfa_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h29;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h0019_0000_0000_1234_0000_0000_0000_0000_0000_9bf4_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 2A (LD HL,(nn))
	$display(" -- 2A          ld hl,(nn)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h2a; mem[1] = 8'h3a; mem[2] = 8'h01; mem[16'h013a] = 8'hc4; mem[16'h013b] = 8'hde;
	#(2* `CLKPERIOD * 16+`FIN)
	ASSERT(192'h0000_0000_0000_dec4_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 2A (LD IX,(nn))
	$display(" -- dd 2A       ld ix,(nn)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_8899_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h2a; mem[2] = 8'hdd; mem[3] = 8'h01; mem[16'h01dd] = 8'hc4; mem[16'h01de] = 8'hde;
	#(2* `CLKPERIOD * 20+`FIN)
	ASSERT(192'h0000_0000_0000_8899_0000_0000_0000_0000_dec4_0000_0000_0004, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 2A (LD IX,(nn))
	$display(" -- fd 2A       ld iy,(nn)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_8899_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h2a; mem[2] = 8'hdd; mem[3] = 8'h01; mem[16'h01dd] = 8'hc4; mem[16'h01de] = 8'hde;
	#(2* `CLKPERIOD * 20+`FIN)
	ASSERT(192'h0000_0000_0000_8899_0000_0000_0000_0000_0000_dec4_0000_0004, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 2B (DEC HL)
	$display(" -- 2B          dec hl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_9e66_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h2b;
	#(2* `CLKPERIOD * 6+`FIN)
	ASSERT(192'h0000_0000_0000_9e65_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 2B (DEC IX)
	$display(" -- dd 2b       dec ix");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_9e66_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h2b;
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0000_0000_0000_9e66_0000_0000_0000_0000_ffff_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 2B (DEC IY)
	$display(" -- fd 2b       dec iy");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_9e66_0000_0000_0000_0000_0000_0001_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h2b;
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0000_0000_0000_9e66_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 2C (INC L)
	$display(" -- 2C          inc l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0026_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h2c;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0020_0000_0000_0027_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 2C (INC IXL)
	$display(" -- dd 2c       inc ixl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0026_0000_0000_0000_0000_0026_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h2c;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0020_0000_0000_0026_0000_0000_0000_0000_0027_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 2C (INC IYL)
	$display(" -- fd 2c       inc iyl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0026_0000_0000_0000_0000_0026_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h2c;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0000_0000_0000_0026_0000_0000_0000_0000_0026_0001_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 2D (DEC L)
	$display(" -- 2D          dec l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0032_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h2d;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0022_0000_0000_0031_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 2D (DEC IXL)
	$display(" -- dd 2d       dec ixl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0032_0000_0000_0000_0000_0032_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h2d;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0022_0000_0000_0032_0000_0000_0000_0000_0031_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 2D (DEC IYL)
	$display(" -- fd 2d       dec iyl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0032_0000_0000_0000_0000_0032_0032_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h2d;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0022_0000_0000_0032_0000_0000_0000_0000_0032_0031_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 2E (LD L,n)
	$display(" -- 2E          ld l,$18");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h2e; mem[1] = 8'h18;
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h0000_0000_0000_0018_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 2E (LD IXL,n)
	$display(" -- dd 2e       ld ixl,$18");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h2e; mem[2] = 8'h18;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_0018_0000_0000_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 2E (LD IYL,n)
	$display(" -- fd 2e       ld iyl,$18");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h2e; mem[2] = 8'h18;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0018_0000_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 2F (CPL)
	$display(" -- 2F          cpl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h8900_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h2f;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h7632_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 2F (CPL)
	$display(" -- dd 2f       DD cpl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h8900_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h2f;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h7632_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 2F (CPL)
	$display(" -- fd 2f       FD cpl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h8900_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h2f;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h7632_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);

	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 30_1 (JR NC,d)
	$display(" -- 30 50       jr nc,$50 ;jump");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0036_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h30; mem[1] = 8'h50;
	#(2* `CLKPERIOD * 12+`FIN)
	ASSERT(192'h0036_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0052, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 30_1 (JR NC,d)
	$display(" -- dd 30 50    jr nc,$50 ;jump");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0036_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h30; mem[2] = 8'h50;
	#(2* `CLKPERIOD * 16+`FIN)
	ASSERT(192'h0036_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0053, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 30_1 (JR NC,d)
	$display(" -- fd 30 50    jr nc,$50 ;jump");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0036_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h30; mem[2] = 8'h50;
	#(2* `CLKPERIOD * 16+`FIN)
	ASSERT(192'h0036_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0053, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 30_2 (JR NC,d)
	$display(" -- 30 50       jr nc,$50 ;no jump");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0037_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h30; mem[1] = 8'h50;
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h0037_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 30_2 (JR NC,d)
	$display(" -- dd 30 50    jr nc,$50 ;no jump");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0037_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h30; mem[2] = 8'h50;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h0037_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 30_2 (JR NC,d)
	$display(" -- fd 30 50    jr nc,$50 ;no jump");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0037_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h30; mem[2] = 8'h50;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h0037_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 31 (LD SP,nn)
	$display(" -- 31 d4 61    ld sp, $61d4");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h31; mem[1] = 8'hd4; mem[2] = 8'h61;
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_61d4_0003, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 31 (LD SP,nn)
	$display(" -- dd 31 d4 dd ld sp, $ddd4");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h31; mem[2] = 8'hd4; mem[3] = 8'hdd;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_ddd4_0004, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 31 (LD SP,nn)
	$display(" -- fd 31 d4 fd ld sp, $fdd4");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h31; mem[2] = 8'hd4; mem[3] = 8'hfd;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_fdd4_0004, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 32 (LD (nn),a)
	$display(" -- 32 ad 01    ld ($01ad),a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0e00_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h32; mem[1] = 8'had; mem[2] = 8'h01;
	#(2* `CLKPERIOD * 13+`FIN)
	ASSERT(192'h0e00_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h01, 2'b00);
	if (mem[16'h01ad] != 8'h0e) $display("* FAIL *: [MEMWR] expected=0e, actual=%2h",mem[16'h01ad]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 32 (LD (nn),a)
	$display(" -- dd 32 ad 01 ld ($01ad),a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0e00_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h32; mem[2] = 8'had; mem[3] = 8'h01;
	#(2* `CLKPERIOD * 17+`FIN)
	ASSERT(192'h0e00_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0004, 8'h00, 8'h02, 2'b00);
	if (mem[16'h01ad] != 8'h0e) $display("* FAIL *: [MEMWR] expected=0e, actual=%2h",mem[16'h01ad]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 32 (LD (nn),a)
	$display(" -- fd 32 ad 01 ld ($01ad),a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0e00_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h32; mem[2] = 8'had; mem[3] = 8'h01;
	#(2* `CLKPERIOD * 17+`FIN)
	ASSERT(192'h0e00_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0004, 8'h00, 8'h02, 2'b00);
	if (mem[16'h01ad] != 8'h0e) $display("* FAIL *: [MEMWR] expected=0e, actual=%2h",mem[16'h01ad]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 33 (INC SP)
	$display(" -- 33          inc sp");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_a55a_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h33;
	#(2* `CLKPERIOD * 6+`FIN)
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_a55b_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 33 (INC SP)
	$display(" -- dd 33       inc sp");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_a55a_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h33;
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_a55b_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 33 (INC SP)
	$display(" -- fd 33       inc sp");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_a55a_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h33;
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_a55b_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 34 (INC (HL))
	$display(" -- 34          inc (hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_011d_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h34; mem[16'h011d] = 8'hfd; 
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h00a8_0000_0000_011d_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
	if (mem[16'h011d] != 8'hfe) $display("* FAIL *: [MEMWR] expected=fe, actual=%2h",mem[16'h011d]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 34 (INC (IX+d))
	$display(" -- dd 34 34    inc (ix+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_011d_0000_0000_0000_0000_0101_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h34; mem[2] = 8'h34; mem[16'h0135] = 8'hdd; 
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERT(192'h0088_0000_0000_011d_0000_0000_0000_0000_0101_0000_0000_0003, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0135] != 8'hde) $display("* FAIL *: [MEMWR] expected=de, actual=%2h",mem[16'h0135]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 34 (INC (IY+d))
	$display(" -- fd 34 fe    inc (iy+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_011d_0000_0000_0000_0000_0000_0101_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h34; mem[2] = 8'hfe; mem[16'h00ff] = 8'hfd; 
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERT(192'h00a8_0000_0000_011d_0000_0000_0000_0000_0000_0101_0000_0003, 8'h00, 8'h02, 2'b00);
	if (mem[16'h00ff] != 8'hfe) $display("* FAIL *: [MEMWR] expected=fe, actual=%2h",mem[16'h00ff]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 35 (DEC (HL))
	$display(" -- 35          dec (hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_01a5_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h35; mem[16'h01a5] = 8'h82;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h0082_0000_0000_01a5_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
	if (mem[16'h01a5] != 8'h81) $display("* FAIL *: [MEMWR] expected=81, actual=%2h",mem[16'h01a5]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 35 (DEC (IX+d))
	$display(" -- dd 35 34    dec (ix+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_011d_0000_0000_0000_0000_0101_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h35; mem[2] = 8'h34; mem[16'h0135] = 8'hdd; 
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERT(192'h008a_0000_0000_011d_0000_0000_0000_0000_0101_0000_0000_0003, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0135] != 8'hdc) $display("* FAIL *: [MEMWR] expected=dc, actual=%2h",mem[16'h0135]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 35 (DEC (IY+d))
	$display(" -- fd 35 fe    dec (iy+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_011d_0000_0000_0000_0000_0000_0101_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h35; mem[2] = 8'hfe; mem[16'h00ff] = 8'hfd; 
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERT(192'h00aa_0000_0000_011d_0000_0000_0000_0000_0000_0101_0000_0003, 8'h00, 8'h02, 2'b00);
	if (mem[16'h00ff] != 8'hfc) $display("* FAIL *: [MEMWR] expected=fc, actual=%2h",mem[16'h00ff]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 36 (LD (HL),n)
	$display(" -- 36 7c       ld (hl),$7c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0129_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h36; mem[1] = 8'h7c;
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0000_0000_0000_0129_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h01, 2'b00);
	if (mem[16'h0129] != 8'h7c) $display("* FAIL *: [MEMWR] expected=7c, actual=%2h",mem[16'h0129]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 36 (LD (IX+d),$77)
	$display(" -- dd 36 34 77 ld (ix+d),$77");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_011d_0000_0000_0000_0000_0101_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h36; mem[2] = 8'h34; mem[3] = 8'h77; mem[16'h0135] = 8'hdd; 
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'h0000_0000_0000_011d_0000_0000_0000_0000_0101_0000_0000_0004, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0135] != 8'h77) $display("* FAIL *: [MEMWR] expected=77, actual=%2h",mem[16'h0135]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 36 (LD (IY+d),n)
	$display(" -- fd 36 fe 66 ld (iy+d),$66");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_011d_0000_0000_0000_0000_0000_0101_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h36; mem[2] = 8'hfe; mem[3] = 8'h66; mem[16'h00ff] = 8'hfd; 
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'h0000_0000_0000_011d_0000_0000_0000_0000_0000_0101_0000_0004, 8'h00, 8'h02, 2'b00);
	if (mem[16'h00ff] != 8'h66) $display("* FAIL *: [MEMWR] expected=66, actual=%2h",mem[16'h00ff]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 37 (SCF)
	$display(" -- 37          scf ;1");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h00ff_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h37;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h00c5_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 37 (SCF)
	$display(" -- dd 37       DD scf ;1");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h00ff_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h37;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h00c5_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 37 (SCF)
	$display(" -- fd 37       FD scf ;1");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h00ff_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h37;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h00c5_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 37 (SCF)
	$display(" -- 37          scf ;2");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hff00_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h37;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hff29_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 37 (SCF)
	$display(" -- 37          scf ;3");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hffff_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h37;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hffed_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 37 (SCF)
	$display(" -- 37          scf ;4");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h37;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0001_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 38 (JR C,d')
	$display(" -- 38 66       jr C,$66 ;no jump");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h00b2_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h38; mem[1] = 8'h66;
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h00b2_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 38 (JR C,d')
	$display(" -- dd 38 66    jr C,$66 ;no jump");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h00b2_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h38; mem[2] = 8'h66;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h00b2_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 38 (JR C,d')
	$display(" -- fd 38 66    jr C,$66 ;no jump");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h00b2_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h38; mem[2] = 8'h66;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h00b2_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 38 (JR C,d')
	$display(" -- 38 66       jr C,$66 ;jump");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h00b3_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h38; mem[1] = 8'h66;
	#(2* `CLKPERIOD * 12+`FIN)
	ASSERT(192'h00b3_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0068, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 38 (JR C,d')
	$display(" -- dd 38 66    jr C,$66 ;jump");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h00b3_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h38; mem[2] = 8'h66;
	#(2* `CLKPERIOD * 16+`FIN)
	ASSERT(192'h00b3_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0069, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 38 (JR C,d')
	$display(" -- fd 38 66    jr C,$66 ;jump");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h00b3_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h38; mem[2] = 8'h66;
	#(2* `CLKPERIOD * 16+`FIN)
	ASSERT(192'h00b3_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0069, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 39 (ADD HL,SP)
	$display(" -- 39          add hl,sp");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_1aef_0000_0000_0000_0000_0000_0000_c534_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h39;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h0030_0000_0000_e023_0000_0000_0000_0000_0000_0000_c534_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 39 (ADD IX,SP)
	$display(" -- dd 39       add ix,sp");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_abcd_0000_0000_0000_0000_1aef_0000_c534_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h39;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h0030_0000_0000_abcd_0000_0000_0000_0000_e023_0000_c534_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 39 (ADD IY,SP)
	$display(" -- fd 39       add iy,sp");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_abcd_0000_0000_0000_0000_0000_1aef_c534_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h39;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h0030_0000_0000_abcd_0000_0000_0000_0000_0000_e023_c534_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 3A (LD A,(nn))
	$display(" -- 3A          ld a,(nn)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h3a; mem[1] = 8'h99; mem[2] = 8'h02; mem[16'h0299] = 8'h28;
	#(2* `CLKPERIOD * 13+`FIN)
	ASSERT(192'h2800_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 3A (LD A,(nn))
	$display(" -- dd 3A       ld a,(nn)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h3a; mem[2] = 8'h99; mem[3] = 8'h02; mem[16'h0299] = 8'h28;
	#(2* `CLKPERIOD * 17+`FIN)
	ASSERT(192'h2800_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0004, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 3A (LD A,(nn))
	$display(" -- fd 3A       ld a,(nn)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h3a; mem[2] = 8'h99; mem[3] = 8'h02; mem[16'h0299] = 8'h28;
	#(2* `CLKPERIOD * 17+`FIN)
	ASSERT(192'h2800_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0004, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 3B (DEC SP)
	$display(" -- 3B          dec sp");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_9d36_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h3b;
	#(2* `CLKPERIOD * 6+`FIN)
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_9d35_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 3B (DEC SP)
	$display(" -- dd 3B       dec sp");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_9d36_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h3b;
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_9d35_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 3B (DEC SP)
	$display(" -- fd 3B       dec sp");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_9d36_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h3b;
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_9d35_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 3C (INC A)
	$display(" -- 3C          inc a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hcf00_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h3c;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hd090_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 3C (INC A)
	$display(" -- dd 3C       inc a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hcf00_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h3c;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hd090_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 3C (INC A)
	$display(" -- fd 3C       inc a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hcf00_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h3c;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hd090_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 3D (DEC A)
	$display(" -- 3D          dec a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hea00_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h3d;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'he9aa_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 3D (DEC A)
	$display(" -- dd 3D       dec a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hea00_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h3d;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'he9aa_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 3D (DEC A)
	$display(" -- fd 3D       dec a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hea00_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h3d;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'he9aa_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 3E (LD A,n)
	$display(" -- 3E          ld a,$d6");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h3e; mem[1] = 8'hd6;
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'hd600_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 3E (LD A,n)
	$display(" -- dd 3E       ld a,$d6");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h3e; mem[2] = 8'hd6;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'hd600_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 3E (LD A,n)
	$display(" -- fd 3E       ld a,$d6");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h3e; mem[2] = 8'hd6;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'hd600_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 3F (CCF)
	$display(" -- 3F          ccf");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h005b_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h3f;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0050_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 3F (CCF)
	$display(" -- dd 3F       ccf");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h005b_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h3f;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0050_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 3F (CCF)
	$display(" -- fd 3F       ccf");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h005b_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h3f;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0050_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 40 (LD B,B)
	$display(" -- 40          ld b,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h40;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 40 (LD B,B)
	$display(" -- dd 40       ld b,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h40;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 40 (LD B,B)
	$display(" -- fd 40       ld b,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h40;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 41 (LD B,C)
	$display(" -- 41          ld b,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h41;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_9898_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 41 (LD B,C)
	$display(" -- dd 41       ld b,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h41;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_9898_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 41 (LD B,C)
	$display(" -- fd 41       ld b,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h41;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_9898_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 42 (LD B,D)
	$display(" -- 42          ld b,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h42;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_9098_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 42 (LD B,D)
	$display(" -- dd 42       ld b,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h42;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_9098_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 42 (LD B,D)
	$display(" -- fd 42       ld b,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h42;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_9098_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 43 (LD B,E)
	$display(" -- 43          ld b,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h43;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_d898_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 43 (LD B,E)
	$display(" -- dd 43       ld b,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h43;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_d898_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 43 (LD B,E)
	$display(" -- fd 43       ld b,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h43;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_d898_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 44 (LD B,H)
	$display(" -- 44          ld b,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h44;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_a198_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 44 (LD B,H)
	$display(" -- dd 44       ld b,ixh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_dd00_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h44;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_dd98_90d8_a169_0000_0000_0000_0000_dd00_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 44 (LD B,H)
	$display(" -- fd 44       ld b,iyh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_fd00_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h44;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_fd98_90d8_a169_0000_0000_0000_0000_0000_fd00_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 45 (LD B,L)
	$display(" -- 45          ld b,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h45; 
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_6998_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 45 (LD B,L)
	$display(" -- dd 45       ld b,ixl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_00dd_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h45; mem[2] = 8'h00; 
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_dd98_90d8_a169_0000_0000_0000_0000_00dd_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 45 (LD B,L)
	$display(" -- fd 45       ld b,iyl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_00dd_00fd_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h45; 
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_fd98_90d8_a169_0000_0000_0000_0000_00dd_00fd_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 46 (LD B,(HL))
	$display(" -- 46          ld b,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h46; mem[16'h0169] = 8'h50;
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h0200_5098_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 46 (LD B,(IX+d))
	$display(" -- dd 46       ld b,(ix+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_01dd_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h46; mem[2] = 8'h00; mem[16'h01dd] = 8'h50;
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'h0200_5098_90d8_0169_0000_0000_0000_0000_01dd_0000_0000_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 46 (LD B,(IY+d))
	$display(" -- fd 46       ld b,(iy+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_01fd_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h46; mem[2] = 8'h02; mem[16'h01ff] = 8'h50;
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'h0200_5098_90d8_0169_0000_0000_0000_0000_0000_01fd_0000_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 47 (LD B,A)
	$display(" -- 47          ld b,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h47;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_0298_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 47 (LD B,A)
	$display(" -- dd 47       ld b,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h47;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_0298_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 47 (LD B,A)
	$display(" -- fd 47       ld b,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h47;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_0298_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 48 (LD C,B)
	$display(" -- 48          ld c,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h48;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cfcf_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 48 (LD C,B)
	$display(" -- dd 48       ld c,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h48;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cfcf_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 48 (LD C,B)
	$display(" -- fd 48       ld c,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h48;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cfcf_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 49 (LD C,C)
	$display(" -- 49          ld c,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h49;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 49 (LD C,C)
	$display(" -- dd 49       ld c,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h49;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 49 (LD C,C)
	$display(" -- fd 49       ld c,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h49;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 4A (LD C,D)
	$display(" -- 4a          ld c,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h4a;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf90_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 4A (LD C,D)
	$display(" -- dd 4a       ld c,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h4a;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf90_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 4A (LD C,D)
	$display(" -- fd 4a       ld c,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h4a;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf90_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 4B (LD C,E)
	$display(" -- 4b          ld c,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h4b;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cfd8_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 4B (LD C,E)
	$display(" -- dd 4b       ld c,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h4b;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cfd8_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 4B (LD C,E)
	$display(" -- fd 4b       ld c,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h4b;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cfd8_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 4C (LD C,H)
	$display(" -- 4c          ld c,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h4c;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cfa1_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 4C (LD C,IXH)
	$display(" -- dd 4c       ld c,ixh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_1100_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h4c;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf11_90d8_a169_0000_0000_0000_0000_1100_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 4C (LD C,H)
	$display(" -- fd 4c       ld c,iyh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_2200_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h4c;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf22_90d8_a169_0000_0000_0000_0000_0000_2200_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 4D (LD C,L)
	$display(" -- 4D          ld c,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h4d;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf69_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 4D (LD C,IXL)
	$display(" -- dd 4D       ld c,ixl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0011_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h4d;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf11_90d8_a169_0000_0000_0000_0000_0011_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 4D (LD C,IYL)
	$display(" -- fd 4D       ld c,iyl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0011_0022_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h4d;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf22_90d8_a169_0000_0000_0000_0000_0011_0022_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 4E (LD C,(HL))
	$display(" -- 4e          ld c,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h4e; mem[16'h0169] = 8'h77;
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h0200_cf77_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 4E (LD C,(IX+d))
	$display(" -- dd 4e       ld c,(ix+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0167_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h4e; mem[2] = 8'h02; mem[16'h0169] = 8'h77;
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'h0200_cf77_90d8_0169_0000_0000_0000_0000_0167_0000_0000_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 4E (LD C,(IY+d))
	$display(" -- fd 4e       ld c,(iy+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_01aa_0167_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h4e; mem[2] = 8'h03; mem[16'h016a] = 8'h77;
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'h0200_cf77_90d8_0169_0000_0000_0000_0000_01aa_0167_0000_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 4F (LD C,A)
	$display(" -- 4f          ld c,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h4f;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf02_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 4F (LD C,A)
	$display(" -- dd 4f       ld c,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h4f;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf02_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 4F (LD C,A)
	$display(" -- fd 4f       ld c,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h4f;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf02_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 50 (LD D,B)
	$display(" -- 50          ld d,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h50;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_cfd8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 50 (LD D,B)
	$display(" -- dd 50       ld d,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h50;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_cfd8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 50 (LD D,B)
	$display(" -- fd 50       ld d,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h50;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_cfd8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 51 (LD D,C)
	$display(" -- 51          ld d,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h51;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_98d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 51 (LD D,C)
	$display(" -- dd 51       ld d,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h51;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_98d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 51 (LD D,C)
	$display(" -- fd 51       ld d,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h51;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_98d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 52 (LD D,D)
	$display(" -- 52          ld d,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h52;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 52 (LD D,D)
	$display(" -- dd 52       ld d,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h52;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 52 (LD D,D)
	$display(" -- fd 52       ld d,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h52;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 53 (LD D,E)
	$display(" -- 53          ld d,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h53;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_d8d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 53 (LD D,E)
	$display(" -- dd 53       ld d,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h53;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_d8d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 53 (LD D,E)
	$display(" -- fd 53       ld d,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h53;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_d8d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 54 (LD B,H)
	$display(" -- 54          ld d,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h54;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_a1d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 54 (LD B,IXH)
	$display(" -- dd 54       ld d,ixh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_1100_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h54;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_11d8_a169_0000_0000_0000_0000_1100_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 54 (LD B,IYH)
	$display(" -- fd 54       ld d,iyh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_1100_2200_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h54;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_22d8_a169_0000_0000_0000_0000_1100_2200_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 55 (LD D,L)
	$display(" -- 55          ld d,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h55; 
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_69d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 55 (LD D,IXL)
	$display(" -- dd 55       ld d,ixl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_00dd_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h55; 
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_ddd8_a169_0000_0000_0000_0000_00dd_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 55 (LD D,IYL)
	$display(" -- fd 55       ld d,iyl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_00dd_00fd_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h55; 
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_fdd8_a169_0000_0000_0000_0000_00dd_00fd_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 56 (LD D,(HL))
	$display(" -- 56          ld d,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h56; mem[16'h0169] = 8'haa;
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h0200_cf98_aad8_0169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 56 (LD D,(IX+d))
	$display(" -- dd 56       ld d,(ix+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_00dd_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h56; mem[2] = 8'h02; mem[16'h00df] = 8'haa;
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'h0200_cf98_aad8_0169_0000_0000_0000_0000_00dd_0000_0000_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 56 (LD D,(IX+d))
	$display(" -- fd 56       ld d,(iy+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_00dd_00fd_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h56; mem[2] = 8'hff; mem[16'h00fc] = 8'haa;
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'h0200_cf98_aad8_0169_0000_0000_0000_0000_00dd_00fd_0000_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 57 (LD D,A)
	$display(" -- 57          ld d,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h57;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_02d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 57 (LD D,A)
	$display(" -- dd 57       ld d,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h57;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_02d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 57 (LD D,A)
	$display(" -- fd 57       ld d,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h57;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_02d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 58 (LD E,B)
	$display(" -- 58          ld e,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h58;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_90cf_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 58 (LD E,B)
	$display(" -- dd 58       ld e,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h58;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90cf_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 58 (LD E,B)
	$display(" -- fd 58       ld e,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h58;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90cf_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 59 (LD E,C)
	$display(" -- 59          ld e,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h59;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_9098_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 59 (LD E,C)
	$display(" -- dd 59       ld e,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h59;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_9098_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 59 (LD E,C)
	$display(" -- fd 59       ld e,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h59;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_9098_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 5A (LD E,D)
	$display(" -- 5a          ld e,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h5a;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_9090_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 5A (LD E,D)
	$display(" -- dd 5a       ld e,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h5a;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_9090_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 5A (LD E,D)
	$display(" -- fd 5a       ld e,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h5a;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_9090_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 5B (LD E,E)
	$display(" -- 5b          ld e,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h5b;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 5B (LD E,E)
	$display(" -- dd 5b       ld e,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h5b;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 5B (LD E,E)
	$display(" -- fd 5b       ld e,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h5b;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 5C (LD E,H)
	$display(" -- 5c          ld e,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h5c;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_90a1_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 5C (LD E,IXH)
	$display(" -- dd 5c       ld e,ixh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_1100_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h5c;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_9011_a169_0000_0000_0000_0000_1100_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 5C (LD E,IXH)
	$display(" -- fd 5c       ld e,iyh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_1100_2200_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h5c;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_9022_a169_0000_0000_0000_0000_1100_2200_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 5D (LD E,L)
	$display(" -- 5D          ld e,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h5d;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_9069_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 5D (LD E,IXL)
	$display(" -- dd 5D       ld e,ixl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_00dd_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h5d;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90dd_a169_0000_0000_0000_0000_00dd_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 5D (LD E,IYL)
	$display(" -- fd 5D       ld e,iyl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_00dd_00fd_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h5d;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90fd_a169_0000_0000_0000_0000_00dd_00fd_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 5E (LD E,(HL))
	$display(" -- 5e          ld e,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h5e; mem[16'h0169] = 8'h55;
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h0200_cf98_9055_0169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 5E (LD E,(IX+d))
	$display(" -- dd 5e       ld e,(ix+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0169_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h5e; mem[2] = 8'h00; mem[16'h0169] = 8'h55;
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'h0200_cf98_9055_0169_0000_0000_0000_0000_0169_0000_0000_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 5E (LD E,(IY+d))
	$display(" -- fd 5e       ld e,(iy+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0169_0068_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h5e; mem[2] = 8'h00; mem[16'h0068] = 8'h55;
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'h0200_cf98_9055_0169_0000_0000_0000_0000_0169_0068_0000_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 5F (LD E,A)
	$display(" -- 5f          ld e,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h5f;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_9002_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 5F (LD E,A)
	$display(" -- dd 5f       ld e,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h5f;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_9002_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 5F (LD E,A)
	$display(" -- fd 5f       ld e,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h5f;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_9002_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 60 (LD H,B)
	$display(" -- 60          ld h,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h60;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_90d8_cf69_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 60 (LD IXH,B)
	$display(" -- dd 60       ld ixh,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h60;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_cf00_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 60 (LD IYH,B)
	$display(" -- fd 60       ld iyh,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h60;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_cf00_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 61 (LD H,C)
	$display(" -- 61          ld h,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h61;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_90d8_9869_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 61 (LD IXH,C)
	$display(" -- dd 61       ld ixh,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h61;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_9800_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 61 (LD IYH,C)
	$display(" -- fd 61       ld iyh,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h61;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_9800_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 62 (LD H,D)
	$display(" -- 62          ld h,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h62;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_90d8_9069_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 62 (LD IXH,D)
	$display(" -- dd 62       ld ixh,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h62;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_9000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 62 (LD IYH,D)
	$display(" -- fd 62       ld iyh,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h62;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_9000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 63 (LD H,E)
	$display(" -- 63          ld h,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h63;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_90d8_d869_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 63 (LD IXH,E)
	$display(" -- dd 63       ld ixh,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h63;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_d800_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 63 (LD IYH,E)
	$display(" -- fd 63       ld iyh,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h63;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_d800_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 64 (LD H,H)
	$display(" -- 64          ld h,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h64;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 64 (LD IXH,IXH)
	$display(" -- dd 64       ld ixh,ixh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_1234_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h64;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_1234_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 64 (LD IYH,IYH)
	$display(" -- fd 64       ld iyh,iyh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_5678_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h64;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_5678_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 65 (LD H,L)
	$display(" -- 65          ld h,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h65; 
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_90d8_6969_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 65 (LD IXH,IXL)
	$display(" -- dd 65       ld ixh,ixl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_1234_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h65;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_3434_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 65 (LD IYH,IYL)
	$display(" -- fd 65       ld iyh,iyl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_5678_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h65;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_7878_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 66 (LD H,(HL))
	$display(" -- 66          ld h,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h66; mem[16'h0169] = 8'h11;
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h0200_cf98_90d8_1169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 66 (LD H,(IX+d))
	$display(" -- dd 66       ld h,(ix+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_1234_0000_0000_0000_0000_0169_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h66; mem[2] = 8'h00; mem[16'h0169] = 8'h55;
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'h0200_cf98_90d8_5534_0000_0000_0000_0000_0169_0000_0000_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 66 (LD H,(IY+d))
	$display(" -- fd 66       ld h,(iy+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_1234_0000_0000_0000_0000_0000_0168_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h66; mem[2] = 8'h01; mem[16'h0169] = 8'haa;
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'h0200_cf98_90d8_aa34_0000_0000_0000_0000_0000_0168_0000_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 67 (LD D,A)
	$display(" -- 67          ld h,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h67;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h2200_cf98_90d8_2269_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 67 (LD IXH,A)
	$display(" -- DD 67       ld ixh,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h67;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h2200_cf98_90d8_a169_0000_0000_0000_0000_2200_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 67 (LD IYH,A)
	$display(" -- fd 67       ld iyh,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h67;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h2200_cf98_90d8_a169_0000_0000_0000_0000_0000_2200_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 68 (LD L,B)
	$display(" -- 68          ld l,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h68;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_90d8_a1cf_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 68 (LD IXL,B)
	$display(" -- dd 68       ld ixl,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h68;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_00cf_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 68 (LD IYL,B)
	$display(" -- fd 68       ld iyl,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h68;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_00cf_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 69 (LD L,C)
	$display(" -- 69          ld l,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h69;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_90d8_a198_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 69 (LD IXL,C)
	$display(" -- dd 69       ld ixl,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h69;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0098_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 69 (LD IYL,C)
	$display(" -- fd 69       ld iyl,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h69;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0098_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 6A (LD L,D)
	$display(" -- 6a          ld l,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h6a;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_90d8_a190_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 6A (LD IXL,D)
	$display(" -- dd 6a       ld ixl,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h6a;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0090_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 6A (LD IYL,D)
	$display(" -- fd 6a       ld iyl,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h6a;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0090_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 6B (LD L,E)
	$display(" -- 6b          ld l,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h6b;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_90d8_a1d8_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 6B (LD IXL,E)
	$display(" -- dd 6b       ld ixl,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h6b;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_00d8_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 6B (LD IYL,E)
	$display(" -- fd 6b       ld iyl,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h6b;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_00d8_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 6C (LD L,H)
	$display(" -- 6c          ld l,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h6c;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_90d8_a1a1_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 6C (LD IXL,IXH)
	$display(" -- dd 6c       ld ixl,ixh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_1234_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h6c;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_1212_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 6C (LD IYL,IYH)
	$display(" -- fd 6c       ld iyl,iyh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_5678_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h6c;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_5656_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 6D (LD L,L)
	$display(" -- 6D          ld l,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h6d;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 6D (LD IXL,IXL)
	$display(" -- dd 6d       ld ixl,ixl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_1234_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h6d;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_1234_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 6D (LD IYL,IYL)
	$display(" -- fd 6d       ld iyl,iyl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_5678_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h6d;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_5678_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 6E (LD L,(HL))
	$display(" -- 6e          ld l,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h6e; mem[16'h0169] = 8'h33;
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h0200_cf98_90d8_0133_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 6E (LD L,(IX+d))
	$display(" -- dd 6e       ld l,(ix+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_01dd_0000_0000_0000_0000_0160_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h6e; mem[2] = 8'h09; mem[16'h0169] = 8'h33;
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'h0200_cf98_90d8_0133_0000_0000_0000_0000_0160_0000_0000_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 6E (LD L,(IY+d))
	$display(" -- fd 6e       ld l,(iy+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_01dd_0000_0000_0000_0000_0000_0160_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h6e; mem[2] = 8'h09; mem[16'h0169] = 8'h33;
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'h0200_cf98_90d8_0133_0000_0000_0000_0000_0000_0160_0000_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 6F (LD L,A)
	$display(" -- 6f          ld l,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h6f;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_90d8_a102_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 6F (LD IXL,A)
	$display(" -- dd 6f       ld ixl,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h6f;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0002_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 6F (LD IYL,A)
	$display(" -- fd 6f       ld iyl,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h6f;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0002_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 70 (LD (HL),B)
	$display(" -- 70          ld (hl),b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h70; mem[16'h0169] = 8'ha5;
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
	if (mem[16'h0169] != 8'hcf) $display("* FAIL *: [MEMWR] expected=cf, actual=%2h",mem[16'h0169]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 70 (LD (IX+d),B)
	$display(" -- dd 70       ld (ix+d),b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0168_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h70; mem[2] = 8'h01; mem[16'h0169] = 8'ha5;
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0168_0000_0000_0003, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0169] != 8'hcf) $display("* FAIL *: [MEMWR] expected=cf, actual=%2h",mem[16'h0169]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 70 (LD (IY+d),B)
	$display(" -- fd 70       ld (iy+d),b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_00fd_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h70; mem[2] = 8'h03; mem[16'h0100] = 8'ha5;
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_00fd_0000_0003, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0100] != 8'hcf) $display("* FAIL *: [MEMWR] expected=cf, actual=%2h",mem[16'h0100]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 71 (LD (HL),C)
	$display(" -- 71          ld (hl),c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h71; mem[16'h0169] = 8'ha5;
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
	if (mem[16'h0169] != 8'h98) $display("* FAIL *: [MEMWR] expected=98, actual=%2h",mem[16'h0169]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 71 (LD (IX+d),C)
	$display(" -- dd 71       ld (ix+d),c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0168_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h71; mem[2] = 8'h01; mem[16'h0169] = 8'ha5;
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0168_0000_0000_0003, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0169] != 8'h98) $display("* FAIL *: [MEMWR] expected=98, actual=%2h",mem[16'h0169]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 71 (LD (IY+d),C)
	$display(" -- fd 71       ld (iy+d),c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_00fd_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h71; mem[2] = 8'h03; mem[16'h0100] = 8'ha5;
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_00fd_0000_0003, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0100] != 8'h98) $display("* FAIL *: [MEMWR] expected=98, actual=%2h",mem[16'h0100]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 72 (LD (HL),D)
	$display(" -- 72          ld (hl),d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h72; mem[16'h0169] = 8'ha5;
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
	if (mem[16'h0169] != 8'h90) $display("* FAIL *: [MEMWR] expected=90, actual=%2h",mem[16'h0169]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 72 (LD (IX+d),D)
	$display(" -- dd 72       ld (ix+d),d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0168_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h72; mem[2] = 8'h01; mem[16'h0169] = 8'ha5;
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0168_0000_0000_0003, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0169] != 8'h90) $display("* FAIL *: [MEMWR] expected=90, actual=%2h",mem[16'h0169]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 72 (LD (IY+d),D)
	$display(" -- fd 72       ld (iy+d),d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_00fd_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h72; mem[2] = 8'h03; mem[16'h0100] = 8'ha5;
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_00fd_0000_0003, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0100] != 8'h90) $display("* FAIL *: [MEMWR] expected=90, actual=%2h",mem[16'h0100]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 73 (LD (HL),E)
	$display(" -- 73          ld (hl),e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h73; mem[16'h0169] = 8'ha5;
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
	if (mem[16'h0169] != 8'hd8) $display("* FAIL *: [MEMWR] expected=d8, actual=%2h",mem[16'h0169]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 73 (LD (IX+d),eB)
	$display(" -- dd 73       ld (ix+d),e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0168_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h73; mem[2] = 8'h01; mem[16'h0169] = 8'ha5;
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0168_0000_0000_0003, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0169] != 8'hd8) $display("* FAIL *: [MEMWR] expected=d8, actual=%2h",mem[16'h0169]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 73 (LD (IY+d),E)
	$display(" -- fd 73       ld (iy+d),e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_00fd_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h73; mem[2] = 8'h03; mem[16'h0100] = 8'ha5;
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_00fd_0000_0003, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0100] != 8'hd8) $display("* FAIL *: [MEMWR] expected=d8, actual=%2h",mem[16'h0100]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 74 (LD (HL),H)
	$display(" -- 74          ld (hl),h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h74; mem[16'h0169] = 8'ha5;
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
	if (mem[16'h0169] != 8'h01) $display("* FAIL *: [MEMWR] expected=01, actual=%2h",mem[16'h0169]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 74 (LD (IX+d),H)
	$display(" -- dd 74       ld (ix+d),h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0168_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h74; mem[2] = 8'h01; mem[16'h0169] = 8'ha5;
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0168_0000_0000_0003, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0169] != 8'h01) $display("* FAIL *: [MEMWR] expected=01, actual=%2h",mem[16'h0169]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 74 (LD (IY+d),H)
	$display(" -- fd 74       ld (iy+d),h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_00fd_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h74; mem[2] = 8'h03; mem[16'h0100] = 8'ha5;
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_00fd_0000_0003, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0100] != 8'h01) $display("* FAIL *: [MEMWR] expected=01, actual=%2h",mem[16'h0100]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 75 (LD (HL),L)
	$display(" -- 75          ld (hl),l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h75; mem[16'h0169] = 8'ha5;
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
	if (mem[16'h0169] != 8'h69) $display("* FAIL *: [MEMWR] expected=69, actual=%2h",mem[16'h0169]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 75 (LD (IX+d),L)
	$display(" -- dd 75       ld (ix+d),l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0168_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h75; mem[2] = 8'h01; mem[16'h0169] = 8'ha5;
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0168_0000_0000_0003, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0169] != 8'h69) $display("* FAIL *: [MEMWR] expected=69, actual=%2h",mem[16'h0169]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 75 (LD (IY+d),L)
	$display(" -- fd 75       ld (iy+d),l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_00fd_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h75; mem[2] = 8'h03; mem[16'h0100] = 8'ha5;
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_00fd_0000_0003, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0100] != 8'h69) $display("* FAIL *: [MEMWR] expected=69, actual=%2h",mem[16'h0100]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 76 (HALT)
	$display(" -- 76          halt");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h76; mem[16'h0169] = 8'h11;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
	if (cpu.core.Halt_FF != 1'b1) $display("* FAIL *: [HALT] expected=1, actual=0");


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 76 (HALT)
	$display(" -- dd 76       halt");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h76; mem[16'h0169] = 8'h11;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
	if (cpu.core.Halt_FF != 1'b1) $display("* FAIL *: [HALT] expected=1, actual=0");


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 76 (HALT)
	$display(" -- fd 76       halt");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h76; mem[16'h0169] = 8'h11;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
	if (cpu.core.Halt_FF != 1'b1) $display("* FAIL *: [HALT] expected=1, actual=0");


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 77 (LD (HL),A)
	$display(" -- 77          ld (hl),a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h77; mem[16'h0169] = 8'ha5;
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);
	if (mem[16'h0169] != 8'h02) $display("* FAIL *: [MEMWR] expected=02, actual=%2h",mem[16'h0169]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 77 (LD (IX+d),A)
	$display(" -- dd 77       ld (ix+d),a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0168_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h77; mem[2] = 8'h01; mem[16'h0169] = 8'ha5;
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0168_0000_0000_0003, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0169] != 8'h02) $display("* FAIL *: [MEMWR] expected=02, actual=%2h",mem[16'h0169]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 77 (LD (IY+d),A)
	$display(" -- fd 77       ld (iy+d),a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_00fd_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h77; mem[2] = 8'h03; mem[16'h0100] = 8'ha5;
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_00fd_0000_0003, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0100] != 8'h02) $display("* FAIL *: [MEMWR] expected=02, actual=%2h",mem[16'h0100]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 78 (LD A,B)
	$display(" -- 78          ld a,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h78;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hcf00_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 78 (LD A,B)
	$display(" -- dd 78       ld a,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h78;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hcf00_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 78 (LD A,B)
	$display(" -- fd 78       ld a,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h78;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hcf00_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 79 (LD A,C)
	$display(" -- 79          ld a,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h79;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h9800_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 79 (LD A,C)
	$display(" -- dd 79       ld a,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h79;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9800_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 79 (LD A,C)
	$display(" -- fd 79       ld a,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h79;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9800_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 7A (LD A,D)
	$display(" -- 7a          ld a,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h7a;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h9000_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 7A (LD A,D)
	$display(" -- dd 7a       ld a,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h7a;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9000_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 7A (LD A,D)
	$display(" -- fd 7a       ld a,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h7a;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9000_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 7B (LD A,E)
	$display(" -- 7b          ld a,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h7b;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hd800_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 7B (LD A,E)
	$display(" -- dd 7b       ld a,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h7b;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hd800_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 7B (LD A,E)
	$display(" -- fd 7b       ld a,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h7b;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hd800_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 7C (LD A,H)
	$display(" -- 7c          ld a,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h7c;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'ha100_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 7C (LD A,IXH)
	$display(" -- dd 7c       ld a,ixh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_1234_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h7c;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h1200_cf98_90d8_a169_0000_0000_0000_0000_1234_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 7C (LD A,IYH)
	$display(" -- fd 7c       ld a,iyh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_1234_5678_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h7c;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h5600_cf98_90d8_a169_0000_0000_0000_0000_1234_5678_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 7D (LD A,L)
	$display(" -- 7D          ld a,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h7d;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h6900_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 7D (LD A,IXL)
	$display(" -- dd 7d       ld a,ixl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_1234_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h7d;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h3400_cf98_90d8_a169_0000_0000_0000_0000_1234_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 7D (LD A,IYL)
	$display(" -- fd 7d       ld a,iyl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_1234_5678_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h7d;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h7800_cf98_90d8_a169_0000_0000_0000_0000_1234_5678_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 7E (LD A,(HL))
	$display(" -- 7e          ld a,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h7e; mem[16'h0169] = 8'h33;
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h3300_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 7E (LD A,(IX+d))
	$display(" -- dd 7e       ld a,(ix+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0123_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h7e; mem[2] = 8'h40; mem[16'h0163] = 8'h33;
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'h3300_cf98_90d8_0169_0000_0000_0000_0000_0123_0000_0000_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 7E (LD A,(IY+d))
	$display(" -- fd 7e       ld a,(iy+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_0169_0000_0000_0000_0000_0123_0100_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h7e; mem[2] = 8'h63; mem[16'h0163] = 8'h44;
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'h4400_cf98_90d8_0169_0000_0000_0000_0000_0123_0100_0000_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 7F (LD A,A)
	$display(" -- 7f          ld a,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h7f;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 7F (LD A,A)
	$display(" -- dd 7f       ld a,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h7f;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 7F (LD A,A)
	$display(" -- fd 7f       ld a,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h7f;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0200_cf98_90d8_a169_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 80 (ADD A,B)
	$display(" -- 80          add a,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h80;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0411_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 80 (ADD A,B)
	$display(" -- dd 80       add a,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h80;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0411_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 80 (ADD A,B)
	$display(" -- fd 80       add a,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h80;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0411_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 81 (ADD A,C)
	$display(" -- 81          add a,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h81;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h3031_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 81 (ADD A,C)
	$display(" -- dd 81       add a,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h81;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h3031_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 81 (ADD A,C)
	$display(" -- fd 81       add a,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h81;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h3031_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 82 (ADD A,D)
	$display(" -- 82          add a,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h82;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h1501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 82 (ADD A,D)
	$display(" -- dd 82       add a,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h82;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h1501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 82 (ADD A,D)
	$display(" -- fd 82       add a,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h82;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h1501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 83 (ADD A,E)
	$display(" -- 83          add a,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h83;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0211_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 83 (ADD A,E)
	$display(" -- dd 83       add a,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h83;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0211_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 83 (ADD A,E)
	$display(" -- fd 83       add a,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h83;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0211_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 84 (ADD A,H)
	$display(" -- 84          add a,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h84;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hd191_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 84 (ADD A,IXH)
	$display(" -- dd 84       add a,ixh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_1234_0000_0000_0000_0000_dca6_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h84;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hd191_0f3b_200d_1234_0000_0000_0000_0000_dca6_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 84 (ADD A,IYH)
	$display(" -- fd 84       add a,iyh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_1234_0000_0000_0000_0000_0000_dca6_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h84;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hd191_0f3b_200d_1234_0000_0000_0000_0000_0000_dca6_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 85 (ADD A,L)
	$display(" -- 85          add a,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h85;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h9b89_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 85 (ADD A,IXL)
	$display(" -- dd 85       add a,ixl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_1234_0000_0000_0000_0000_dca6_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h85;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9b89_0f3b_200d_1234_0000_0000_0000_0000_dca6_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 85 (ADD A,IXL)
	$display(" -- fd 85       add a,iyl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_1234_0000_0000_0000_0000_0000_dca6_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h85;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9b89_0f3b_200d_1234_0000_0000_0000_0000_0000_dca6_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 86 (ADD A,(HL))
	$display(" -- 86          add a,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h86; mem[16'h0169] = 8'h49;
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h3e29_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 86 (ADD A,(IX+d))
	$display(" -- dd 86       add a,(ix+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_cf98_90d8_0169_0000_0000_0000_0000_0160_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h86; mem[2] = 8'h09; mem[16'h0169] = 8'h49;
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'h3e29_cf98_90d8_0169_0000_0000_0000_0000_0160_0000_0000_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 86 (ADD A,(IX+d))
	$display(" -- fd 86       add a,(iy+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_cf98_90d8_0169_0000_0000_0000_0000_0000_0160_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h86; mem[2] = 8'h09; mem[16'h0169] = 8'h49;
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'h3e29_cf98_90d8_0169_0000_0000_0000_0000_0000_0160_0000_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 87 (ADD A,A)
	$display(" -- 87          add a,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h87;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'heaa9_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 87 (ADD A,A)
	$display(" -- dd 87       add a,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h87;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'heaa9_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 87 (ADD A,A)
	$display(" -- fd 87       add a,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h87;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'heaa9_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 88 (ADC A,B)
	$display(" -- 88          adc a,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h88;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0411_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 88 (ADC A,B)
	$display(" -- dd 88       adc a,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h88;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0411_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 88 (ADC A,B)
	$display(" -- fd 88       adc a,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h88;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0411_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 89 (ADC A,C)
	$display(" -- 89          adc a,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h89;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h3031_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 89 (ADC A,C)
	$display(" -- dd 89       adc a,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h89;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h3031_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 89 (ADC A,C)
	$display(" -- fd 89       adc a,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h89;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h3031_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 8A (ADC A,D)
	$display(" -- 8a          adc a,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h8a;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h1501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 8A (ADC A,D)
	$display(" -- dd 8a       adc a,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h8a;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h1501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 8A (ADC A,D)
	$display(" -- fd 8a       adc a,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h8a;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h1501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 8B (ADC A,E)
	$display(" -- 8b          adc a,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h8b;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0211_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 8B (ADC A,E)
	$display(" -- dd 8b       adc a,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h8b;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0211_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 8B (ADC A,E)
	$display(" -- fd 8b       adc a,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h8b;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0211_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 8C (ADC A,H)
	$display(" -- 8c          adc a,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h8c;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hd191_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 8C (ADC A,IXH)
	$display(" -- dd 8c       adc a,ixh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_1234_0000_0000_0000_0000_dca6_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h8c;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hd191_0f3b_200d_1234_0000_0000_0000_0000_dca6_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 8C (ADC A,IYH)
	$display(" -- fd 8c       adc a,iyh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_1234_0000_0000_0000_0000_0000_dca6_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h8c;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hd191_0f3b_200d_1234_0000_0000_0000_0000_0000_dca6_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 8D (ADC A,L)
	$display(" -- 8d          adc a,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h8d;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h9b89_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 8D (ADC A,L)
	$display(" -- dd 8d       adc a,ixl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_1234_0000_0000_0000_0000_dca6_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h8d;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9b89_0f3b_200d_1234_0000_0000_0000_0000_dca6_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 8D (ADC A,L)
	$display(" -- fd 8d       adc a,iyl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_1234_0000_0000_0000_0000_0000_dca6_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h8d;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9b89_0f3b_200d_1234_0000_0000_0000_0000_0000_dca6_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 8e (ADC A,(HL))
	$display(" -- 8e          adc a,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h8e; mem[16'h0169] = 8'h49;
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h3e29_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 8e (ADC A,(IX+d))
	$display(" -- dd 8e       adc a,(ix+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_cf98_90d8_0169_0000_0000_0000_0000_0160_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h8e; mem[2] = 8'h09; mem[16'h0169] = 8'h49;
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'h3e29_cf98_90d8_0169_0000_0000_0000_0000_0160_0000_0000_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 8e (ADC A,(IY+d))
	$display(" -- fd 8e       adc a,(iy+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_cf98_90d8_0169_0000_0000_0000_0000_0000_0160_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h8e; mem[2] = 8'h09; mem[16'h0169] = 8'h49;
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'h3e29_cf98_90d8_0169_0000_0000_0000_0000_0000_0160_0000_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 8F (ADC A,A)
	$display(" -- 8f          adc a,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h8f;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'heaa9_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 8F (ADC A,A)
	$display(" -- dd 8f       adc a,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h8f;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'heaa9_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 8F (ADC A,A)
	$display(" -- fd 8f       adc a,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h8f;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'heaa9_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 8F (ADC A,A)
	$display(" -- 8f          adc a,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h8f;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'heba9_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 8F (ADC A,A)
	$display(" -- dd 8f       adc a,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h8f;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'heba9_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 8F (ADC A,A)
	$display(" -- fd 8f       adc a,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h8f;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'heba9_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 90 (SUB A,B)
	$display(" -- 90          sub a,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h90;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'he6b2_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 90 (SUB A,B)
	$display(" -- dd 90       sub a,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h90;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'he6b2_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 90 (SUB A,B)
	$display(" -- fd 90       sub a,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h90;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'he6b2_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 91 (SUB A,C)
	$display(" -- 91          sub a,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h91;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hbaba_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 91 (SUB A,C)
	$display(" -- dd 91       sub a,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h91;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hbaba_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 91 (SUB A,C)
	$display(" -- fd 91       sub a,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h91;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hbaba_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 92 (SUB A,D)
	$display(" -- 92          sub a,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h92;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hd582_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 92 (SUB A,D)
	$display(" -- dd 92       sub a,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h92;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hd582_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 92 (SUB A,D)
	$display(" -- fd 92       sub a,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h92;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hd582_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 93 (SUB A,E)
	$display(" -- 93          sub a,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h93;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'he8ba_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 93 (SUB A,E)
	$display(" -- dd 93       sub a,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h93;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'he8ba_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 93 (SUB A,E)
	$display(" -- fd 93       sub a,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h93;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'he8ba_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 94 (SUB A,H)
	$display(" -- 94          sub a,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h94;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h191a_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 94 (SUB A,IXH)
	$display(" -- dd 94       sub a,ixh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf501_0f3b_200d_dca6_0000_0000_0000_0000_dca6_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h94;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h191a_0f3b_200d_dca6_0000_0000_0000_0000_dca6_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 94 (SUB A,IYH)
	$display(" -- fd 94       sub a,iyh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf501_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h94;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h191a_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 95 (SUB A,L)
	$display(" -- 95          sub a,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h95;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h4f1a_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 95 (SUB A,IXL)
	$display(" -- dd 95       sub a,ixl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf501_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h95;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h4f1a_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 95 (SUB A,IYL)
	$display(" -- fd 95       sub a,iyl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf501_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h95;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h4f1a_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 96 (SUB A,(HL))
	$display(" -- 96          sub a,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h96; mem[16'h0169] = 8'h49;
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'hacba_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 96 (SUB A,(IX+d))
	$display(" -- dd 96       sub a,(ix+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_cf98_90d8_0169_0000_0000_0000_0000_0160_0020_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h96; mem[2] = 8'h06; mem[16'h0166] = 8'h49;
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'hacba_cf98_90d8_0169_0000_0000_0000_0000_0160_0020_0000_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 96 (SUB A,(IY+d))
	$display(" -- fd 96       sub a,(iy+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_cf98_90d8_0169_0000_0000_0000_0000_0160_0020_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h96; mem[2] = 8'h46; mem[16'h0066] = 8'h49;
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'hacba_cf98_90d8_0169_0000_0000_0000_0000_0160_0020_0000_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 97 (SUB A,A)
	$display(" -- 97          sub a,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h97;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0042_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 97 (SUB A,A)
	$display(" -- dd 97       sub a,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h97;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0042_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 97 (SUB A,A)
	$display(" -- fd 97       sub a,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h97;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0042_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 98 (SBC A,B)
	$display(" -- 98          sbc a,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h98;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'he6b2_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 98 (SBC A,B)
	$display(" -- dd 98       sbc a,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h98;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'he6b2_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 98 (SBC A,B)
	$display(" -- fd 98       sbc a,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h98;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'he6b2_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 99 (SBC A,C)
	$display(" -- 99          sbc a,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h99;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hbaba_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 99 (SBC A,C)
	$display(" -- dd 99       sbc a,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h99;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hbaba_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 99 (SBC A,C)
	$display(" -- fd 99       sbc a,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h99;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hbaba_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 9A (SBC A,D)
	$display(" -- 9a          sbc a,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h9a;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hd582_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 9A (SBC A,D)
	$display(" -- dd 9a       sbc a,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h9a;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hd582_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 9A (SBC A,D)
	$display(" -- fd 9a       sbc a,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h9a;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hd582_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 9B (SBC A,E)
	$display(" -- 9b          sbc a,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h9b;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'he8ba_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 9B (SBC A,E)
	$display(" -- dd 9b       sbc a,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h9b;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'he8ba_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 9B (SBC A,E)
	$display(" -- fd 9b       sbc a,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h9b;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'he8ba_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 9C (SBC A,H)
	$display(" -- 9c          sbc a,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h9c;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h191a_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 9C (SBC A,IXH)
	$display(" -- dd 9c       sbc a,ixh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h9c;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h191a_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 9C (SBC A,IYH)
	$display(" -- fd 9c       sbc a,iyh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h9c;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h191a_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 9D (SBC A,L)
	$display(" -- 9d          sbc a,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h9d;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h4f1a_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 9D (SBC A,IXL)
	$display(" -- dd 9d       sbc a,ixl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h9d;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h4f1a_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 9D (SBC A,IYL)
	$display(" -- fd 9d       sbc a,iyl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h9d;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h4f1a_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 9E (SBC A,(HL))
	$display(" -- 9E          sbc a,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h9e; mem[16'h0169] = 8'h49;
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'hacba_cf98_90d8_0169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 9E (SBC A,(IX+d))
	$display(" -- dd 9E       sbc a,(ix+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_cf98_90d8_0169_0000_0000_0000_0000_0160_0160_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h9e; mem[2] = 8'h09; mem[16'h0169] = 8'h49;
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'hacba_cf98_90d8_0169_0000_0000_0000_0000_0160_0160_0000_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 9E (SBC A,(IX+d))
	$display(" -- fd 9E       sbc a,(ix+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_cf98_90d8_0169_0000_0000_0000_0000_0160_0160_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h9e; mem[2] = 8'h09; mem[16'h0169] = 8'h49;
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'hacba_cf98_90d8_0169_0000_0000_0000_0000_0160_0160_0000_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 9F (SBC A,A)
	$display(" -- 9f          sbc a,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h9f;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0042_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 9F (SBC A,A)
	$display(" -- dd 9f       sbc a,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h9f;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0042_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 9F (SBC A,A)
	$display(" -- fd 9f       sbc a,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h9f;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0042_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE 9F (SBC A,A) w/Carry
	$display(" -- 9f          sbc a,a ; w/ Carry");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'h9f;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hffbb_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD 9F (SBC A,A) w/Carry
	$display(" -- dd 9f       sbc a,a ; w/ Carry");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'h9f;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hffbb_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD 9F (SBC A,A) w/Carry
	$display(" -- fd 9f       sbc a,a ; w/ Carry");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf501_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'h9f;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hffbb_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE A0 (AND A,B)
	$display(" -- a0          and a,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'ha0;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0514_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD A0 (AND A,B)
	$display(" -- dd a0       and a,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'ha0;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0514_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD A0 (AND A,B)
	$display(" -- fd a0       and a,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'ha0;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0514_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE A1 (AND A,C)
	$display(" -- a1          and a,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'ha1;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h3130_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD A1 (AND A,C)
	$display(" -- dd a1       and a,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'ha1;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h3130_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD A1 (AND A,C)
	$display(" -- fd a1       and a,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'ha1;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h3130_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE A2 (AND A,D)
	$display(" -- a2          and a,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'ha2;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h2030_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD A2 (AND A,D)
	$display(" -- dd a2       and a,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'ha2;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h2030_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD A2 (AND A,D)
	$display(" -- fd a2       and a,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'ha2;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h2030_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE A3 (AND A,E)
	$display(" -- a3          and a,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'ha3;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0514_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD A3 (AND A,E)
	$display(" -- dd a3       and a,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'ha3;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0514_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD A3 (AND A,E)
	$display(" -- fd a3       and a,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'ha3;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0514_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE A4 (AND A,H)
	$display(" -- a4          and a,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'ha4;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hd494_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD A4 (AND A,IXH)
	$display(" -- dd a4       and a,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'ha4;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hd494_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD A4 (AND A,IXH)
	$display(" -- fd a4       and a,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'ha4;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hd494_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE A5 (AND A,L)
	$display(" -- a5          and a,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'ha5;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'ha4b0_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD A5 (AND A,IXL)
	$display(" -- dd a5       and a,ixl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'ha5;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha4b0_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD A5 (AND A,IXL)
	$display(" -- fd a5       and a,iyl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'ha5;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha4b0_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE A6 (AND A,(HL))
	$display(" -- a6          and a,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_0169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'ha6; mem[16'h0169] = 8'h49;
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h4114_0f3b_200d_0169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD A6 (AND A,(HL))
	$display(" -- dd a6       and a,(ix+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_0169_0000_0000_0000_0000_0160_0100_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'ha6; mem[2] = 8'h01; mem[16'h0161] = 8'h49;
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'h4114_0f3b_200d_0169_0000_0000_0000_0000_0160_0100_0000_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD A6 (AND A,(HL))
	$display(" -- fd a6       and a,(iy+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_0169_0000_0000_0000_0000_0160_0100_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'ha6; mem[2] = 8'h62; mem[16'h0162] = 8'h49;
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'h4114_0f3b_200d_0169_0000_0000_0000_0000_0160_0100_0000_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE A7 (AND A,A)
	$display(" -- a7          and a,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'ha7;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hf5b4_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD A7 (AND A,A)
	$display(" -- dd a7       and a,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'ha7;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hf5b4_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD A7 (AND A,A)
	$display(" -- fd a7       and a,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'ha7;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hf5b4_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE A8 (XOR A,B)
	$display(" -- a8          xor a,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'ha8;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hfaac_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD A8 (XOR A,B)
	$display(" -- dd a8       xor a,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'ha8;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hfaac_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD A8 (XOR A,B)
	$display(" -- fd a8       xor a,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'ha8;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hfaac_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE A9 (XOR A,C)
	$display(" -- a9          xor a,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'ha9;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hce88_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD A9 (XOR A,C)
	$display(" -- dd a9       xor a,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'ha9;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hce88_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD A9 (XOR A,C)
	$display(" -- fd a9       xor a,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'ha9;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hce88_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE AA (XOR A,D)
	$display(" -- aa          xor a,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'haa;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hd580_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD AA (XOR A,D)
	$display(" -- dd aa       xor a,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'haa;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hd580_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD AA (XOR A,D)
	$display(" -- fd aa       xor a,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'haa;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hd580_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE AB (XOR A,E)
	$display(" -- ab          xor a,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hab;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hf8a8_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD AB (XOR A,E)
	$display(" -- dd ab       xor a,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hab;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hf8a8_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD AB (XOR A,E)
	$display(" -- fd ab       xor a,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hab;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hf8a8_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE AC (XOR A,H)
	$display(" -- ac          xor a,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hac;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h2928_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD AC (XOR A,IXH)
	$display(" -- dd ac       xor a,ixh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hac;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h2928_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD AC (XOR A,IYH)
	$display(" -- fd ac       xor a,iyh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hac;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h2928_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE AD (XOR A,L)
	$display(" -- ad          xor a,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'had;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h5304_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD AD (XOR A,IXL)
	$display(" -- dd ad       xor a,ixl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'had;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h5304_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD AD (XOR A,IYL)
	$display(" -- fd ad       xor a,iyl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'had;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h5304_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE AE (XOR A,(HL))
	$display(" -- ae          xor a,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_0169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hae; mem[16'h0169] = 8'h49;
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'hbca8_0f3b_200d_0169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD AE (XOR A,(IX+d))
	$display(" -- dd ae       xor a,(ix+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_0169_0000_0000_0000_0000_0160_00ff_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hae; mem[2] = 8'h09; mem[16'h0169] = 8'h49;
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'hbca8_0f3b_200d_0169_0000_0000_0000_0000_0160_00ff_0000_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD AE (XOR A,(IX+d))
	$display(" -- fd ae       xor a,(iy+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_0169_0000_0000_0000_0000_0160_00ff_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hae; mem[2] = 8'h01; mem[16'h0100] = 8'h49;
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'hbca8_0f3b_200d_0169_0000_0000_0000_0000_0160_00ff_0000_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE AF (XOR A,A)
	$display(" -- af          xor a,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'haf;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0044_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD AF (XOR A,A)
	$display(" -- dd af       xor a,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'haf;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0044_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD AF (XOR A,A)
	$display(" -- fd af       xor a,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'haf;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0044_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE B0 (OR A,B)
	$display(" -- b0          or a,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hb0;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hffac_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD B0 (OR A,B)
	$display(" -- dd b0       or a,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hb0;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hffac_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD B0 (OR A,B)
	$display(" -- fd b0       or a,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hb0;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hffac_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE B1 (OR A,C)
	$display(" -- b1          or a,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hb1;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hffac_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD B1 (OR A,C)
	$display(" -- dd b1       or a,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hb1;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hffac_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD B1 (OR A,C)
	$display(" -- fd b1       or a,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hb1;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hffac_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE B2 (OR A,D)
	$display(" -- b2          or a,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hb2;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hf5a4_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD B2 (OR A,D)
	$display(" -- dd b2       or a,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hb2;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hf5a4_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD B2 (OR A,D)
	$display(" -- fd b2       or a,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hb2;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hf5a4_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE B3 (OR A,C)
	$display(" -- b3          or a,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hb3;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hfda8_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD B3 (OR A,E)
	$display(" -- dd b3       or a,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hb3;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hfda8_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD B3 (OR A,E)
	$display(" -- fd b3       or a,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hb3;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hfda8_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE B4 (OR A,H)
	$display(" -- b4          or a,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hb4;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hfda8_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD B4 (OR A,IXH)
	$display(" -- dd b4       or a,ixh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hb4;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hfda8_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD B4 (OR A,IXH)
	$display(" -- fd b4       or a,iyh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hb4;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hfda8_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE B5 (OR A,L)
	$display(" -- b5          or a,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hb5;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hf7a0_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD B5 (OR A,IXL)
	$display(" -- dd b5       or a,ixl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hb5;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hf7a0_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD B5 (OR A,IYL)
	$display(" -- fd b5       or a,iyl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hb5;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hf7a0_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE B6 (OR A,(HL))
	$display(" -- b6          or a,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_0169_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hb6; mem[16'h0169] = 8'h49;
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'hfda8_0f3b_200d_0169_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD B6 (OR A,(IX+d))
	$display(" -- dd b6       or a,(ix+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_0169_0000_0000_0000_0000_0160_0160_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hb6; mem[2] = 8'h09; mem[16'h0169] = 8'h49;
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'hfda8_0f3b_200d_0169_0000_0000_0000_0000_0160_0160_0000_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD B6 (OR A,(IY+d))
	$display(" -- fd b6       or a,(iy+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_0169_0000_0000_0000_0000_0160_0160_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hb6; mem[2] = 8'h09; mem[16'h0169] = 8'h49;
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'hfda8_0f3b_200d_0169_0000_0000_0000_0000_0160_0160_0000_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE B7 (OR A,A)
	$display(" -- b7          or a,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hb7;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hf5a4_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD B7 (OR A,A)
	$display(" -- dd b7       or a,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hb7;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hf5a4_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD B7 (OR A,A)
	$display(" -- fd b7       or a,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hb7;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hf5a4_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE B8 (CP B)
	$display(" -- b8          cp b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hb8;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hf59a_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD B8 (CP B)
	$display(" -- dd b8       cp b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hb8;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hf59a_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD B8 (CP B)
	$display(" -- fd b8       cp b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hb8;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hf59a_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE B9 (CP C)
	$display(" -- b9          cp c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hb9;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hf5ba_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD B9 (CP C)
	$display(" -- dd b9       cp c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hb9;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hf5ba_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD B9 (CP C)
	$display(" -- fd b9       cp c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hb9;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hf5ba_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE BA (CP D)
	$display(" -- ba          cp d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hba;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hf5a2_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD BA (CP D)
	$display(" -- dd ba       cp d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hba;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hf5a2_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD BA (CP D)
	$display(" -- fd ba       cp d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hba;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hf5a2_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE BB (CP E)
	$display(" -- bb          cp e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hbb;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hf59a_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD BB (CP E)
	$display(" -- dd bb       cp e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hbb;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hf59a_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD BB (CP E)
	$display(" -- fd bb       cp e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hbb;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hf59a_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE BC (CP H)
	$display(" -- bc          cp h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hbc;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hf51a_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD BC (CP IXH)
	$display(" -- dd bc       cp ixh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hbc;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hf51a_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD BC (CP IYH)
	$display(" -- fd bc       cp iyh");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hbc;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hf51a_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE BD (CP L)
	$display(" -- bd          cp l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hbd;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hf532_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD BD (CP IXL)
	$display(" -- dd bd       cp ixl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hbd;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hf532_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD BD (CP IYL)
	$display(" -- fd bd       cp iyl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hbd;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hf532_0f3b_200d_dca6_0000_0000_0000_0000_dca6_dca6_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE BE (CP (HL))
	$display(" -- be          cp (hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_01c6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hbe; mem['h01c6] = 8'h49;
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'hf59a_0f3b_200d_01c6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD BE (CP (IX+d))
	$display(" -- dd be       cp (ix+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_01c6_0000_0000_0000_0000_01d0_01e0_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hbe; mem[2] = 8'h0d; mem['h01dd] = 8'h49;
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'hf59a_0f3b_200d_01c6_0000_0000_0000_0000_01d0_01e0_0000_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD BE (CP (IY+d))
	$display(" -- fd be       cp (iy+d)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_01c6_0000_0000_0000_0000_01d0_01e0_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hbe; mem[2] = 8'h0d; mem['h01ed] = 8'h49;
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'hf59a_0f3b_200d_01c6_0000_0000_0000_0000_01d0_01e0_0000_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE BF (CP A)
	$display(" -- bf          cp a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hbf;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'hf562_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD BF (CP A)
	$display(" -- dd bf       cp a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hbf;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hf562_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD BF (CP A)
	$display(" -- fd bf       cp a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf500_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hbf;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hf562_0f3b_200d_dca6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE C0_1 (RET NZ ; taken)
	$display(" -- c0          ret nz ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hc0; mem[16'h01f7] = 8'he9; mem[16'h01f8] = 8'haf;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f9_afe9, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD C0_1 (RET NZ ; taken)
	$display(" -- DD c0       ret nz ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hc0; mem[16'h01f7] = 8'he9; mem[16'h01f8] = 8'haf;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f9_afe9, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD C0_1 (RET NZ ; taken)
	$display(" -- FD c0       ret nz ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hc0; mem[16'h01f7] = 8'he9; mem[16'h01f8] = 8'haf;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f9_afe9, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE C0_1 (RET NZ ; not taken)
	$display(" -- c0          ret nz ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h00d8_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hc0; mem[16'h01f7] = 8'he9; mem[16'h01f8] = 8'haf;
	#(2* `CLKPERIOD * 5+`FIN)
	ASSERT(192'h00d8_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE C1 (POP BC)
	$display(" -- c1          pop bc");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0143_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hc1; mem[16'h0143] = 8'hce; mem[16'h0144] = 8'he8;
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0000_e8ce_0000_0000_0000_0000_0000_0000_0000_0000_0145_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD C1 (POP BC)
	$display(" -- dd c1       pop bc");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0143_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hc1; mem[16'h0143] = 8'hce; mem[16'h0144] = 8'he8;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0000_e8ce_0000_0000_0000_0000_0000_0000_0000_0000_0145_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD C1 (POP BC)
	$display(" -- fd c1       pop bc");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0143_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hc1; mem[16'h0143] = 8'hce; mem[16'h0144] = 8'he8;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0000_e8ce_0000_0000_0000_0000_0000_0000_0000_0000_0145_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE C2_1 (JP NZ,nn ; taken)
	$display(" -- c2          jp nz,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hc2; mem[1] = 8'h1b; mem[2] = 8'he1;
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_e11b, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD C2_1 (JP NZ,nn ; taken)
	$display(" -- dd c2       jp nz,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hc2; mem[2] = 8'h1b; mem[3] = 8'he1;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_e11b, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD C2_1 (JP NZ,nn ; taken)
	$display(" -- fd c2       jp nz,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hc2; mem[2] = 8'h1b; mem[3] = 8'he1;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_e11b, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE C2_1 (JP NZ,nn ; not taken)
	$display(" -- c2          jp nz,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h00c7_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hc2; mem[1] = 8'h1b; mem[2] = 8'he1;
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h00c7_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD C2_1 (JP NZ,nn ; not taken)
	$display(" -- dd c2       jp nz,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h00c7_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hc2; mem[2] = 8'h1b; mem[3] = 8'he1;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h00c7_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0004, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD C2_1 (JP NZ,nn ; not taken)
	$display(" -- fd c2       jp nz,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h00c7_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hc2; mem[2] = 8'h1b; mem[3] = 8'he1;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h00c7_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0004, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE C3 (JP nn)
	$display(" -- c3          jp $7ced");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hc3; mem[1] = 8'hed; mem[2] = 8'h7c;
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_7ced, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD C3 (JP nn)
	$display(" -- dd c3       jp $7ced");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hc3; mem[2] = 8'hed; mem[3] = 8'h7c;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_7ced, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD C3 (JP nn)
	$display(" -- fd c3       jp $7ced");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hc3; mem[2] = 8'hed; mem[3] = 8'h7c;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_7ced, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE C4_1 (CALL NZ,nn ; taken)
	$display(" -- c4          call nz,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hc4; mem[1] = 8'h1b; mem[2] = 8'he1; mem['h0197] = 8'hff;
	#(2* `CLKPERIOD * 17+`FIN)
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_e11b, 8'h00, 8'h01, 2'b00);
	if (mem[16'h0198] != 8'h03) $display("* FAIL *: [MEMWR] expected=03, actual=%2h",mem[16'h0198]);
	if (mem[16'h0197] != 8'h00) $display("* FAIL *: [MEMWR] expected=00, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD C4_1 (CALL NZ,nn ; taken)
	$display(" -- dd c4       call nz,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hc4; mem[2] = 8'h1b; mem[3] = 8'he1; mem['h0197] = 8'hff;
	#(2* `CLKPERIOD * 21+`FIN)
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_e11b, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0198] != 8'h04) $display("* FAIL *: [MEMWR] expected=04, actual=%2h",mem[16'h0198]);
	if (mem[16'h0197] != 8'h00) $display("* FAIL *: [MEMWR] expected=00, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD C4_1 (CALL NZ,nn ; taken)
	$display(" -- fd c4       call nz,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hc4; mem[2] = 8'h1b; mem[3] = 8'he1; mem['h0197] = 8'hff;
	#(2* `CLKPERIOD * 21+`FIN)
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_e11b, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0198] != 8'h04) $display("* FAIL *: [MEMWR] expected=04, actual=%2h",mem[16'h0198]);
	if (mem[16'h0197] != 8'h00) $display("* FAIL *: [MEMWR] expected=00, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE C4_1 (CALL NZ,nn ; taken)
	$display(" -- c4          call nz,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h004e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hc4; mem[1] = 8'h1b; mem[2] = 8'he1;
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h004e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0003, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD C4_1 (CALL NZ,nn ; taken)
	$display(" -- dd c4       call nz,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h004e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hc4; mem[2] = 8'h1b; mem[3] = 8'he1;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h004e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0004, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD C4_1 (CALL NZ,nn ; taken)
	$display(" -- fd c4       call nz,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h004e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hc4; mem[2] = 8'h1b; mem[3] = 8'he1;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h004e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0004, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE C5 (PUSH BC)
	$display(" -- c5          push bc");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h53e3_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hc5; mem['h0197] = 8'hff;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h53e3_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0196_0001, 8'h00, 8'h01, 2'b00);
	if (mem[16'h0198] != 8'h59) $display("* FAIL *: [MEMWR] expected=59, actual=%2h",mem[16'h0198]);
	if (mem[16'h0197] != 8'h14) $display("* FAIL *: [MEMWR] expected=14, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD C5 (PUSH BC)
	$display(" -- dd c5       push bc");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h53e3_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hc5; mem['h0197] = 8'hff;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h53e3_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0196_0002, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0198] != 8'h59) $display("* FAIL *: [MEMWR] expected=59, actual=%2h",mem[16'h0198]);
	if (mem[16'h0197] != 8'h14) $display("* FAIL *: [MEMWR] expected=14, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD C5 (PUSH BC)
	$display(" -- fd c5       push bc");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h53e3_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hc5; mem['h0197] = 8'hff;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h53e3_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0196_0002, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0198] != 8'h59) $display("* FAIL *: [MEMWR] expected=59, actual=%2h",mem[16'h0198]);
	if (mem[16'h0197] != 8'h14) $display("* FAIL *: [MEMWR] expected=14, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE C6 (ADD a,n)
	$display(" -- c6          add a,n");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hca00_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0100, 8'h00, 8'h00, 2'b00);
	// memory data
	mem['h0100] = 8'hc6; mem['h0101] = 8'h6f;
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h3939_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0102, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD C6 (ADD a,n)
	$display(" -- dd c6       add a,n");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hca00_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0100, 8'h00, 8'h00, 2'b00);
	// memory data
	mem['h0100] = 8'hdd; mem['h0101] = 8'hc6; mem['h0102] = 8'h6f;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h3939_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0103, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD C6 (ADD a,n)
	$display(" -- fd c6       add a,n");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hca00_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0100, 8'h00, 8'h00, 2'b00);
	// memory data
	mem['h0100] = 8'hfd; mem['h0101] = 8'hc6; mem['h0102] = 8'h6f;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h3939_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0103, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE C7 (RST 00h)
	$display(" -- c7          rst 00h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0234, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[16'h0234] = 8'hc7;  mem[16'h0197] = 8'hff;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_0000, 8'h00, 8'h01, 2'b00);
	if (mem[16'h0198] != 8'h35) $display("* FAIL *: [MEMWR] expected=35, actual=%2h",mem[16'h0198]);
	if (mem[16'h0197] != 8'h02) $display("* FAIL *: [MEMWR] expected=02, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD C7 (RST 00h)
	$display(" -- dd c7       rst 00h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0234, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[16'h0234] = 8'hdd; mem[16'h0235] = 8'hc7; mem[16'h0197] = 8'hff;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_0000, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0198] != 8'h35) $display("* FAIL *: [MEMWR] expected=35, actual=%2h",mem[16'h0198]);
	if (mem[16'h0197] != 8'h02) $display("* FAIL *: [MEMWR] expected=02, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD C7 (RST 00h)
	$display(" -- fd c7       rst 00h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0234, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[16'h0234] = 8'hdd; mem[16'h0235] = 8'hc7; mem[16'h0197] = 8'hff;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_0000, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0198] != 8'h35) $display("* FAIL *: [MEMWR] expected=35, actual=%2h",mem[16'h0198]);
	if (mem[16'h0197] != 8'h02) $display("* FAIL *: [MEMWR] expected=02, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE C8_1 (RET Z ; taken)
	$display(" -- c8          ret z ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h00d8_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hc8; mem[16'h01f7] = 8'he9; mem[16'h01f8] = 8'haf;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h00d8_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f9_afe9, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD C8_1 (RET Z ; taken)
	$display(" -- dd c8       ret z ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h00d8_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hc8; mem[16'h01f7] = 8'he9; mem[16'h01f8] = 8'haf;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h00d8_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f9_afe9, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD C8_1 (RET Z ; taken)
	$display(" -- fd c8       ret z ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h00d8_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hc8; mem[16'h01f7] = 8'he9; mem[16'h01f8] = 8'haf;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h00d8_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f9_afe9, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE C8_1 (RET Z ; not taken)
	$display(" -- c8          ret z ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hc8; mem[16'h01f7] = 8'he9; mem[16'h01f8] = 8'haf;
	#(2* `CLKPERIOD * 5+`FIN)
	ASSERT(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD C8_1 (RET Z ; not taken)
	$display(" -- dd c8       ret z ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hc8; mem[16'h01f7] = 8'he9; mem[16'h01f8] = 8'haf;
	#(2* `CLKPERIOD * 9+`FIN)
	ASSERT(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD C8_1 (RET Z ; not taken)
	$display(" -- fd c8       ret z ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hc8; mem[16'h01f7] = 8'he9; mem[16'h01f8] = 8'haf;
	#(2* `CLKPERIOD * 9+`FIN)
	ASSERT(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE C9 (RET)
	$display(" -- c9          ret");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h00d8_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hc9; mem[16'h01f7] = 8'he9; mem[16'h01f8] = 8'haf;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h00d8_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f9_afe9, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD C9 (RET)
	$display(" -- dd c9       ret");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h00d8_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hc9; mem[16'h01f7] = 8'he9; mem[16'h01f8] = 8'haf;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h00d8_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f9_afe9, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD C9 (RET)
	$display(" -- fd c9       ret");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h00d8_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hc9; mem[16'h01f7] = 8'he9; mem[16'h01f8] = 8'haf;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h00d8_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f9_afe9, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CA_1 (JP Z,nn ; taken)
	$display(" -- ca          jp z,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h00c7_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hca; mem[1] = 8'h1b; mem[2] = 8'he1;
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h00c7_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_e11b, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CA_1 (JP Z,nn ; taken)
	$display(" -- dd ca       jp z,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h00c7_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hca; mem[2] = 8'h1b; mem[3] = 8'he1;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h00c7_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_e11b, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD CA_1 (JP Z,nn ; taken)
	$display(" -- fd ca       jp z,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h00c7_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hca; mem[2] = 8'h1b; mem[3] = 8'he1;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h00c7_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_e11b, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CA_2 (JP Z,nn ; not taken)
	$display(" -- ca          jp z,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hca; mem[1] = 8'h1b; mem[2] = 8'he1;
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CA_2 (JP Z,nn ; not taken)
	$display(" -- dd ca       jp z,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hca; mem[2] = 8'h1b; mem[3] = 8'he1;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0004, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD CA_2 (JP Z,nn ; not taken)
	$display(" -- fd ca       jp z,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hca; mem[2] = 8'h1b; mem[3] = 8'he1;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0004, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CC_1 (CALL Z,nn ; taken)
	$display(" -- cc          call z,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h004e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcc; mem[1] = 8'h1b; mem[2] = 8'he1; mem['h0197] = 8'hff;
	#(2* `CLKPERIOD * 17+`FIN)
	ASSERT(192'h004e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_e11b, 8'h00, 8'h01, 2'b00);
	if (mem[16'h0198] != 8'h03) $display("* FAIL *: [MEMWR] expected=03, actual=%2h",mem[16'h0198]);
	if (mem[16'h0197] != 8'h00) $display("* FAIL *: [MEMWR] expected=00, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CC_1 (CALL Z,nn ; taken)
	$display(" -- dd cc       call z,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h004e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hcc; mem[2] = 8'h1b; mem[3] = 8'he1; mem['h0197] = 8'hff;
	#(2* `CLKPERIOD * 21+`FIN)
	ASSERT(192'h004e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_e11b, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0198] != 8'h03) $display("* FAIL *: [MEMWR] expected=03, actual=%2h",mem[16'h0198]);
	if (mem[16'h0197] != 8'h00) $display("* FAIL *: [MEMWR] expected=00, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD CC_1 (CALL Z,nn ; taken)
	$display(" -- fd cc       call z,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h004e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hcc; mem[2] = 8'h1b; mem[3] = 8'he1; mem['h0197] = 8'hff;
	#(2* `CLKPERIOD * 21+`FIN)
	ASSERT(192'h004e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_e11b, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0198] != 8'h03) $display("* FAIL *: [MEMWR] expected=03, actual=%2h",mem[16'h0198]);
	if (mem[16'h0197] != 8'h00) $display("* FAIL *: [MEMWR] expected=00, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CC_1 (CALL Z,nn ; taken)
	$display(" -- cc          call z,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcc; mem[1] = 8'h1b; mem[2] = 8'he1;
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0003, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CC_1 (CALL Z,nn ; taken)
	$display(" -- dd cc       call z,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hcc; mem[2] = 8'h1b; mem[3] = 8'he1;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0004, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD CC_1 (CALL Z,nn ; taken)
	$display(" -- fd cc       call z,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hcc; mem[2] = 8'h1b; mem[3] = 8'he1;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0004, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CD (CALL nn)
	$display(" -- cd          call $e11b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h004e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcd; mem[1] = 8'h1b; mem[2] = 8'he1; mem['h0197] = 8'hff;
	#(2* `CLKPERIOD * 17+`FIN)
	ASSERT(192'h004e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_e11b, 8'h00, 8'h01, 2'b00);
	if (mem[16'h0198] != 8'h03) $display("* FAIL *: [MEMWR] expected=03, actual=%2h",mem[16'h0198]);
	if (mem[16'h0197] != 8'h00) $display("* FAIL *: [MEMWR] expected=00, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CD (CALL nn)
	$display(" -- dd cd       call $e11b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h004e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hcd; mem[2] = 8'h1b; mem[3] = 8'he1; mem['h0197] = 8'hff;
	#(2* `CLKPERIOD * 21+`FIN)
	ASSERT(192'h004e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_e11b, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0198] != 8'h03) $display("* FAIL *: [MEMWR] expected=03, actual=%2h",mem[16'h0198]);
	if (mem[16'h0197] != 8'h00) $display("* FAIL *: [MEMWR] expected=00, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD CD (CALL nn)
	$display(" -- fd cd       call $e11b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h004e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hcd; mem[2] = 8'h1b; mem[3] = 8'he1; mem['h0197] = 8'hff;
	#(2* `CLKPERIOD * 21+`FIN)
	ASSERT(192'h004e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_e11b, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0198] != 8'h03) $display("* FAIL *: [MEMWR] expected=03, actual=%2h",mem[16'h0198]);
	if (mem[16'h0197] != 8'h00) $display("* FAIL *: [MEMWR] expected=00, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CE (ADC a,n)
	$display(" -- ce          adc a,n");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hca01_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hce; mem[1] = 8'h6f;
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h3a39_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0002, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CE (ADC a,n)
	$display(" -- dd ce       adc a,n");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hca01_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hce; mem[2] = 8'h6f;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h3a39_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD CE (ADC a,n)
	$display(" -- fd ce       adc a,n");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hca01_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hce; mem[2] = 8'h6f;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h3a39_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CF (RST 08h)
	$display(" -- cf          rst 08h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0234, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[16'h0234] = 8'hcf;  mem[16'h0197] = 8'hff;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_0008, 8'h00, 8'h01, 2'b00);
	if (mem[16'h0198] != 8'h35) $display("* FAIL *: [MEMWR] expected=35, actual=%2h",mem[16'h0198]);
	if (mem[16'h0197] != 8'h02) $display("* FAIL *: [MEMWR] expected=02, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD CF (RST 08h)
	$display(" -- dd cf       rst 08h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0234, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[16'h0234] = 8'hdd; mem[16'h0235] = 8'hcf;  mem[16'h0197] = 8'hff;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_0008, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0198] != 8'h35) $display("* FAIL *: [MEMWR] expected=35, actual=%2h",mem[16'h0198]);
	if (mem[16'h0197] != 8'h02) $display("* FAIL *: [MEMWR] expected=02, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD CF (RST 08h)
	$display(" -- fd cf       rst 08h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0234, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[16'h0234] = 8'hfd; mem[16'h0235] = 8'hcf;  mem[16'h0197] = 8'hff;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_0008, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0198] != 8'h35) $display("* FAIL *: [MEMWR] expected=35, actual=%2h",mem[16'h0198]);
	if (mem[16'h0197] != 8'h02) $display("* FAIL *: [MEMWR] expected=02, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE D0_1 (RET NC ; taken)
	$display(" -- d0          ret nc ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hd0; mem[16'h01f7] = 8'he9; mem[16'h01f8] = 8'haf;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f9_afe9, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD D0_1 (RET NC ; taken)
	$display(" -- dd d0       ret nc ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hd0; mem[16'h01f7] = 8'he9; mem[16'h01f8] = 8'haf;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f9_afe9, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD D0_1 (RET NC ; taken)
	$display(" -- fd d0       ret nc ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hd0; mem[16'h01f7] = 8'he9; mem[16'h01f8] = 8'haf;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f9_afe9, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE D0_1 (RET NC ; not taken)
	$display(" -- d0          ret nc ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0099_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hd0; mem[16'h01f7] = 8'he9; mem[16'h01f8] = 8'haf;
	#(2* `CLKPERIOD * 5+`FIN)
	ASSERT(192'h0099_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD D0_1 (RET NC ; not taken)
	$display(" -- dd d0       ret nc ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0099_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hd0; mem[16'h01f7] = 8'he9; mem[16'h01f8] = 8'haf;
	#(2* `CLKPERIOD * 9+`FIN)
	ASSERT(192'h0099_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD D0_1 (RET NC ; not taken)
	$display(" -- fd d0       ret nc ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0099_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hd0; mem[16'h01f7] = 8'he9; mem[16'h01f8] = 8'haf;
	#(2* `CLKPERIOD * 9+`FIN)
	ASSERT(192'h0099_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE C1 (POP DE)
	$display(" -- d1          pop de");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0143_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hd1; mem[16'h0143] = 8'hce; mem[16'h0144] = 8'he8;
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0000_0000_e8ce_0000_0000_0000_0000_0000_0000_0000_0145_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD C1 (POP DE)
	$display(" -- dd d1       pop de");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0143_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hd1; mem[16'h0143] = 8'hce; mem[16'h0144] = 8'he8;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0000_0000_e8ce_0000_0000_0000_0000_0000_0000_0000_0145_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD C1 (POP DE)
	$display(" -- fd d1       pop de");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0143_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hd1; mem[16'h0143] = 8'hce; mem[16'h0144] = 8'he8;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0000_0000_e8ce_0000_0000_0000_0000_0000_0000_0000_0145_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE D2_1 (JP NC,nn ; taken)
	$display(" -- d2          jp nc,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0086_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hd2; mem[1] = 8'h1b; mem[2] = 8'he1;
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0086_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_e11b, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD D2_1 (JP NC,nn ; taken)
	$display(" -- dd d2       jp nc,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0086_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hd2; mem[2] = 8'h1b; mem[3] = 8'he1;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0086_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_e11b, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD D2_1 (JP NC,nn ; taken)
	$display(" -- fd d2       jp nc,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0086_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hd2; mem[2] = 8'h1b; mem[3] = 8'he1;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0086_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_e11b, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE D2_2 (JP NC,nn ; not taken)
	$display(" -- d2          jp nc,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hd2; mem[1] = 8'h1b; mem[2] = 8'he1;
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD D2_2 (JP NC,nn ; not taken)
	$display(" -- dd d2       jp nc,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hd2; mem[2] = 8'h1b; mem[3] = 8'he1;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0004, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD D2_2 (JP NC,nn ; not taken)
	$display(" -- fd d2       jp nc,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hd2; mem[2] = 8'h1b; mem[3] = 8'he1;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0004, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE D3 (OUT (n),a)
	$display(" -- d3          out ($18),a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha200_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hd3; mem[1] = 8'h18;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'ha200_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h01, 2'b00);
	if (io[8'h18] != 8'ha2) $display("* FAIL *: [IOWR] expected=a2, actual=%2h",io[8'h18]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD D3 (OUT (n),a)
	$display(" -- dd d3       out ($18),a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha200_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hd3; mem[2] = 8'h18;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'ha200_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h02, 2'b00);
	if (io[8'h18] != 8'ha2) $display("* FAIL *: [IOWR] expected=a2, actual=%2h",io[8'h18]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD D3 (OUT (n),a)
	$display(" -- fd d3       out ($18),a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha200_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hd3; mem[2] = 8'h18;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'ha200_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h02, 2'b00);
	if (io[8'h18] != 8'ha2) $display("* FAIL *: [IOWR] expected=a2, actual=%2h",io[8'h18]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE D4_1 (CALL NC,nn ; taken)
	$display(" -- d4          call nc,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hd4; mem[1] = 8'h1b; mem[2] = 8'he1; mem['h0197] = 8'hff;
	#(2* `CLKPERIOD * 17+`FIN)
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_e11b, 8'h00, 8'h01, 2'b00);
	if (mem[16'h0198] != 8'h03) $display("* FAIL *: [MEMWR] expected=03, actual=%2h",mem[16'h0198]);
	if (mem[16'h0197] != 8'h00) $display("* FAIL *: [MEMWR] expected=00, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD D4_1 (CALL NC,nn ; taken)
	$display(" -- dd d4       call nc,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hd4; mem[2] = 8'h1b; mem[3] = 8'he1; mem['h0197] = 8'hff;
	#(2* `CLKPERIOD * 21+`FIN)
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_e11b, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0198] != 8'h03) $display("* FAIL *: [MEMWR] expected=03, actual=%2h",mem[16'h0198]);
	if (mem[16'h0197] != 8'h00) $display("* FAIL *: [MEMWR] expected=00, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD D4_1 (CALL NC,nn ; taken)
	$display(" -- fd d4       call nc,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hd4; mem[2] = 8'h1b; mem[3] = 8'he1; mem['h0197] = 8'hff;
	#(2* `CLKPERIOD * 21+`FIN)
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_e11b, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0198] != 8'h03) $display("* FAIL *: [MEMWR] expected=03, actual=%2h",mem[16'h0198]);
	if (mem[16'h0197] != 8'h00) $display("* FAIL *: [MEMWR] expected=00, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE D4_1 (CALL NC,nn ; taken)
	$display(" -- d4          call nc,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h004f_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hd4; mem[1] = 8'h1b; mem[2] = 8'he1;
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h004f_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0003, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD D4_1 (CALL NC,nn ; taken)
	$display(" -- dd d4       call nc,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h004f_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hd4; mem[2] = 8'h1b; mem[3] = 8'he1;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h004f_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0004, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD D4_1 (CALL NC,nn ; taken)
	$display(" -- fd d4       call nc,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h004f_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hd4; mem[2] = 8'h1b; mem[3] = 8'he1;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h004f_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0004, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE D5 (PUSH DE)
	$display(" -- d5          push de");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h53e3_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hd5; mem['h0197] = 8'hff;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h53e3_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0196_0001, 8'h00, 8'h01, 2'b00);
	if (mem[16'h0198] != 8'h5f) $display("* FAIL *: [MEMWR] expected=5f, actual=%2h",mem[16'h0198]);
	if (mem[16'h0197] != 8'h77) $display("* FAIL *: [MEMWR] expected=77, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD D5 (PUSH DE)
	$display(" -- dd d5       push de");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h53e3_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hd5; mem['h0197] = 8'hff;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h53e3_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0196_0002, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0198] != 8'h5f) $display("* FAIL *: [MEMWR] expected=5f, actual=%2h",mem[16'h0198]);
	if (mem[16'h0197] != 8'h77) $display("* FAIL *: [MEMWR] expected=77, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD D5 (PUSH DE)
	$display(" -- fd d5       push de");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h53e3_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hd5; mem['h0197] = 8'hff;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h53e3_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0196_0002, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0198] != 8'h5f) $display("* FAIL *: [MEMWR] expected=5f, actual=%2h",mem[16'h0198]);
	if (mem[16'h0197] != 8'h77) $display("* FAIL *: [MEMWR] expected=77, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE D6 (SUB n)
	$display(" -- d6          sub n");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h3901_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hd6; mem[1] = 8'hdf;
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h5a1b_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0002, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD D6 (SUB n)
	$display(" -- dd d6       sub n");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h3901_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hd6; mem[2] = 8'hdf;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h5a1b_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD D6 (SUB n)
	$display(" -- fd d6       sub n");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h3901_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hd6; mem[2] = 8'hdf;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h5a1b_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE D7 (RST 10h)
	$display(" -- d7          rst 10h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0234, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[16'h0234] = 8'hd7;  mem[16'h0196] = 8'hff; mem[16'h0197] = 8'hff;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_0010, 8'h00, 8'h01, 2'b00);
	if (mem[16'h0196] != 8'h35) $display("* FAIL *: [MEMWR] expected=35, actual=%2h",mem[16'h0196]);
	if (mem[16'h0197] != 8'h02) $display("* FAIL *: [MEMWR] expected=02, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD D7 (RST 10h)
	$display(" -- dd d7       rst 10h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0234, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[16'h0234] = 8'hdd;  mem[16'h0235] = 8'hd7;  mem[16'h0196] = 8'hff;   mem[16'h0197] = 8'hff;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_0010, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0196] != 8'h36) $display("* FAIL *: [MEMWR] expected=36, actual=%2h",mem[16'h0196]);
	if (mem[16'h0197] != 8'h02) $display("* FAIL *: [MEMWR] expected=02, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD D7 (RST 10h)
	$display(" -- fd d7       rst 10h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0234, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[16'h0234] = 8'hfd;  mem[16'h0235] = 8'hd7;  mem[16'h0196] = 8'hff; mem[16'h0197] = 8'hff;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_0010, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0196] != 8'h36) $display("* FAIL *: [MEMWR] expected=36, actual=%2h",mem[16'h0196]);
	if (mem[16'h0197] != 8'h02) $display("* FAIL *: [MEMWR] expected=02, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE D8_1 (RET C ; taken)
	$display(" -- d8          ret c ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0099_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hd8; mem[16'h01f7] = 8'he9; mem[16'h01f8] = 8'haf;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h0099_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f9_afe9, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD D8_1 (RET C ; taken)
	$display(" -- dd d8       ret c ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0099_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hd8; mem[16'h01f7] = 8'he9; mem[16'h01f8] = 8'haf;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h0099_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f9_afe9, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD D8_1 (RET C ; taken)
	$display(" -- fd d8       ret c ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0099_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hd8; mem[16'h01f7] = 8'he9; mem[16'h01f8] = 8'haf;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h0099_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f9_afe9, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE D8_1 (RET C ; not taken)
	$display(" -- d8          ret c ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hd8; mem[16'h01f7] = 8'he9; mem[16'h01f8] = 8'haf;
	#(2* `CLKPERIOD * 5+`FIN)
	ASSERT(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD D8_1 (RET C ; not taken)
	$display(" -- dd d8       ret c ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hd8; mem[16'h01f7] = 8'he9; mem[16'h01f8] = 8'haf;
	#(2* `CLKPERIOD * 9+`FIN)
	ASSERT(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD D8_1 (RET C ; not taken)
	$display(" -- fd d8       ret c ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hd8; mem[16'h01f7] = 8'he9; mem[16'h01f8] = 8'haf;
	#(2* `CLKPERIOD * 9+`FIN)
	ASSERT(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE D9 (EXX)
	$display(" -- d9          exx");
	// -----------------------------------------------------
	// -       AF    BC   DE   HL   AF'  BC'  DE'  HL'  IX   IY   SP   PC
	SETUP(192'h4d94_e07a_e35b_9d64_1a64_c930_3d01_7d02_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hd9;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h4d94_c930_3d01_7d02_1a64_e07a_e35b_9d64_0000_0000_01f7_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD D9 (EXX)
	$display(" -- dd d9       exx");
	// -----------------------------------------------------
	// -       AF    BC   DE   HL   AF'  BC'  DE'  HL'  IX   IY   SP   PC
	SETUP(192'h4d94_e07a_e35b_9d64_1a64_c930_3d01_7d02_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hd9;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h4d94_c930_3d01_7d02_1a64_e07a_e35b_9d64_0000_0000_01f7_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FF DD D9 (EXX)
	$display(" -- fd d9       exx");
	// -----------------------------------------------------
	// -       AF    BC   DE   HL   AF'  BC'  DE'  HL'  IX   IY   SP   PC
	SETUP(192'h4d94_e07a_e35b_9d64_1a64_c930_3d01_7d02_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hd9;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h4d94_c930_3d01_7d02_1a64_e07a_e35b_9d64_0000_0000_01f7_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DA_1 (JP C,nn ; taken)
	$display(" -- da          jp c,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hda; mem[1] = 8'h1b; mem[2] = 8'he1;
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_e11b, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD DA_1 (JP C,nn ; taken)
	$display(" -- dd da       jp c,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hda; mem[2] = 8'h1b; mem[3] = 8'he1;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_e11b, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD DA_1 (JP C,nn ; taken)
	$display(" -- fd da       jp c,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hda; mem[2] = 8'h1b; mem[3] = 8'he1;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_e11b, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DA_2 (JP C,nn ; not taken)
	$display(" -- da          jp c,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0086_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hda; mem[1] = 8'h1b; mem[2] = 8'he1;
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0086_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD DA_2 (JP C,nn ; not taken)
	$display(" -- dd da       jp c,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0086_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hda; mem[2] = 8'h1b; mem[3] = 8'he1;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0086_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0004, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD DA_2 (JP C,nn ; not taken)
	$display(" -- fd da       jp c,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0086_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hda; mem[2] = 8'h1b; mem[3] = 8'he1;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0086_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0004, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DB (IN A,(n))
	$display(" -- db          in a,(n)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0086_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdb; mem[1] = 8'h1b; io[8'h1b] = 8'he1;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'he186_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD DB (IN A,(n))
	$display(" -- dd db       in a,(n)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0086_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hdb; mem[2] = 8'h1b; io[8'h1b] = 8'he1;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'he186_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD DB (IN A,(n))
	$display(" -- fd db       in a,(n)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0086_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hdb; mem[2] = 8'h1b; io[8'h1b] = 8'he1;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'he186_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DC_1 (CALL C,nn ; taken)
	$display(" -- dc          call c,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000f_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdc; mem[1] = 8'h1b; mem[2] = 8'he1; mem['h0196] = 8'hff; mem['h0197] = 8'hff;
	#(2* `CLKPERIOD * 17+`FIN)
	ASSERT(192'h000f_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_e11b, 8'h00, 8'h01, 2'b00);
	if (mem[16'h0196] != 8'h03) $display("* FAIL *: [MEMWR] expected=03, actual=%2h",mem[16'h0196]);
	if (mem[16'h0197] != 8'h00) $display("* FAIL *: [MEMWR] expected=00, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD DC_1 (CALL C,nn ; taken)
	$display(" -- dd dc       call c,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000f_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hdc; mem[2] = 8'h1b; mem[3] = 8'he1; mem['h0196] = 8'hff; mem['h0197] = 8'hff;
	#(2* `CLKPERIOD * 21+`FIN)
	ASSERT(192'h000f_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_e11b, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0196] != 8'h04) $display("* FAIL *: [MEMWR] expected=04, actual=%2h",mem[16'h0196]);
	if (mem[16'h0197] != 8'h00) $display("* FAIL *: [MEMWR] expected=00, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD DC_1 (CALL C,nn ; taken)
	$display(" -- fd dc       call c,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000f_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hdc; mem[2] = 8'h1b; mem[3] = 8'he1; mem['h0196] = 8'hff; mem['h0197] = 8'hff;
	#(2* `CLKPERIOD * 21+`FIN)
	ASSERT(192'h000f_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_e11b, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0196] != 8'h04) $display("* FAIL *: [MEMWR] expected=04, actual=%2h",mem[16'h0196]);
	if (mem[16'h0197] != 8'h00) $display("* FAIL *: [MEMWR] expected=00, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DC_1 (CALL C,nn ; taken)
	$display(" -- dc          call c,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h004e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdc; mem[1] = 8'h1b; mem[2] = 8'he1;
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h004e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0003, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD DC_1 (CALL C,nn ; taken)
	$display(" -- dd dc       call c,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h004e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hdc; mem[2] = 8'h1b; mem[3] = 8'he1;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h004e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0004, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD DC_1 (CALL C,nn ; taken)
	$display(" -- fd dc       call c,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h004e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hdc; mem[2] = 8'h1b; mem[3] = 8'he1;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h004e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0004, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DE (SBC a,n)
	$display(" -- de          sbc a,n");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'he78d_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hde; mem[1] = 8'ha1;
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h4502_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0002, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD DE (SBC a,n)
	$display(" -- dd de       sbc a,n");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'he78d_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hde; mem[2] = 8'ha1;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h4502_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD DE (SBC a,n)
	$display(" -- fd de       sbc a,n");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'he78d_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hde; mem[2] = 8'ha1;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h4502_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DF (RST 18h)
	$display(" -- df          rst 18h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0234, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[16'h0234] = 8'hdf;  mem[16'h0196] = 8'hff; mem[16'h0197] = 8'hff;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_0018, 8'h00, 8'h01, 2'b00);
	if (mem[16'h0196] != 8'h35) $display("* FAIL *: [MEMWR] expected=35, actual=%2h",mem[16'h0196]);
	if (mem[16'h0197] != 8'h02) $display("* FAIL *: [MEMWR] expected=02, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD DF (RST 18h)
	$display(" -- dd df       rst 18h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0233, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[16'h0233] = 8'hdd;  mem[16'h0234] = 8'hdf;  mem[16'h0196] = 8'hff; mem[16'h0197] = 8'hff;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_0018, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0196] != 8'h35) $display("* FAIL *: [MEMWR] expected=35, actual=%2h",mem[16'h0196]);
	if (mem[16'h0197] != 8'h02) $display("* FAIL *: [MEMWR] expected=02, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD DF (RST 18h)
	$display(" -- fd df       rst 18h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0233, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[16'h0233] = 8'hfd;  mem[16'h0234] = 8'hdf;  mem[16'h0196] = 8'hff; mem[16'h0197] = 8'hff;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_0018, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0196] != 8'h35) $display("* FAIL *: [MEMWR] expected=35, actual=%2h",mem[16'h0196]);
	if (mem[16'h0197] != 8'h02) $display("* FAIL *: [MEMWR] expected=02, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE E0_1 (RET PO ; taken)
	$display(" -- e0          ret po ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'he0; mem[16'h01f7] = 8'he9; mem[16'h01f8] = 8'haf;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f9_afe9, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD E0_1 (RET PO ; taken)
	$display(" -- dd e0       ret po ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'he0; mem[16'h01f7] = 8'he9; mem[16'h01f8] = 8'haf;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f9_afe9, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD E0_1 (RET PO ; taken)
	$display(" -- fd e0       ret po ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'he0; mem[16'h01f7] = 8'he9; mem[16'h01f8] = 8'haf;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f9_afe9, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE E0_1 (RET PO ; not taken)
	$display(" -- e0          ret po ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h009c_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'he0; mem[16'h01f7] = 8'he9; mem[16'h01f8] = 8'haf;
	#(2* `CLKPERIOD * 5+`FIN)
	ASSERT(192'h009c_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD E0_1 (RET PO ; not taken)
	$display(" -- dd e0       ret po ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h009c_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'he0; mem[16'h01f7] = 8'he9; mem[16'h01f8] = 8'haf;
	#(2* `CLKPERIOD * 9+`FIN)
	ASSERT(192'h009c_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD E0_1 (RET PO ; not taken)
	$display(" -- fd e0       ret po ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h009c_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'he0; mem[16'h01f7] = 8'he9; mem[16'h01f8] = 8'haf;
	#(2* `CLKPERIOD * 9+`FIN)
	ASSERT(192'h009c_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE E1 (POP HL)
	$display(" -- e1          pop hl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0143_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'he1; mem[16'h0143] = 8'hce; mem[16'h0144] = 8'he8;
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0000_0000_0000_e8ce_0000_0000_0000_0000_0000_0000_0145_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD E1 (POP IX)
	$display(" -- dd e1       pop ix");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0143_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'he1; mem[16'h0143] = 8'hce; mem[16'h0144] = 8'he8;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_e8ce_0000_0145_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD E1 (POP IY)
	$display(" -- fd e1       pop iy");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0143_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'he1; mem[16'h0143] = 8'hce; mem[16'h0144] = 8'he8;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_e8ce_0145_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE E2_1 (JP PO,nn ; taken)
	$display(" -- e2          jp po,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0083_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'he2; mem[1] = 8'h1b; mem[2] = 8'he1;
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0083_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_e11b, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD E2_1 (JP PO,nn ; taken)
	$display(" -- dd e2       jp po,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0083_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'he2; mem[2] = 8'h1b; mem[3] = 8'he1;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0083_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_e11b, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD E2_1 (JP PO,nn ; taken)
	$display(" -- fd e2       jp po,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0083_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'he2; mem[2] = 8'h1b; mem[3] = 8'he1;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0083_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_e11b, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE E2_2 (JP PE,nn ; not taken)
	$display(" -- e2          jp po,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'he2; mem[1] = 8'h1b; mem[2] = 8'he1;
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD E2_2 (JP PE,nn ; not taken)
	$display(" -- dd e2       jp po,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'he2; mem[2] = 8'h1b; mem[3] = 8'he1;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0004, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD E2_2 (JP PE,nn ; not taken)
	$display(" -- fd e2       jp po,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'he2; mem[2] = 8'h1b; mem[3] = 8'he1;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0004, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE E3 (EX (SP),HL)
	$display(" -- e3          ex (sp),hl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000a_0000_0000_5432_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'he3; mem['h0198] = 8'h8e; mem['h0199] = 8'he1;
	#(2* `CLKPERIOD * 19+`FIN)
	ASSERT(192'h000a_0000_0000_e18e_0000_0000_0000_0000_0000_0000_0198_0001, 8'h00, 8'h01, 2'b00);
	if (mem[16'h0198] != 8'h32) $display("* FAIL *: [MEMWR] expected=32, actual=%2h",mem[16'h0198]);
	if (mem[16'h0199] != 8'h54) $display("* FAIL *: [MEMWR] expected=54, actual=%2h",mem[16'h0199]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD E3 (EX (SP),IX)
	$display(" -- dd e3       ex (sp),ix");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000a_0000_0000_5432_0000_0000_0000_0000_1234_5678_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'he3; mem['h0198] = 8'h8e; mem['h0199] = 8'he1;
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERT(192'h000a_0000_0000_5432_0000_0000_0000_0000_e18e_5678_0198_0002, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0198] != 8'h34) $display("* FAIL *: [MEMWR] expected=34, actual=%2h",mem[16'h0198]);
	if (mem[16'h0199] != 8'h12) $display("* FAIL *: [MEMWR] expected=12, actual=%2h",mem[16'h0199]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD E3 (EX (SP),IY)
	$display(" -- fd e3       ex (sp),iy");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000a_0000_0000_5432_0000_0000_0000_0000_1234_5678_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'he3; mem['h0198] = 8'h8e; mem['h0199] = 8'he1;
	#(2* `CLKPERIOD * 23+`FIN)
	ASSERT(192'h000a_0000_0000_5432_0000_0000_0000_0000_1234_e18e_0198_0002, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0198] != 8'h78) $display("* FAIL *: [MEMWR] expected=78, actual=%2h",mem[16'h0198]);
	if (mem[16'h0199] != 8'h56) $display("* FAIL *: [MEMWR] expected=56, actual=%2h",mem[16'h0199]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE E4_1 (CALL PO,nn ; taken)
	$display(" -- e4          call po,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000a_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'he4; mem[1] = 8'h1b; mem[2] = 8'he1; mem['h0196] = 8'hff;  mem['h0197] = 8'hff;
	#(2* `CLKPERIOD * 17+`FIN)
	ASSERT(192'h000a_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_e11b, 8'h00, 8'h01, 2'b00);
	if (mem[16'h0196] != 8'h03) $display("* FAIL *: [MEMWR] expected=03, actual=%2h",mem[16'h0196]);
	if (mem[16'h0197] != 8'h00) $display("* FAIL *: [MEMWR] expected=00, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD E4_1 (CALL PO,nn ; taken)
	$display(" -- dd e4       call po,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000a_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'he4; mem[2] = 8'h1b; mem[3] = 8'he1; mem['h0196] = 8'hff; mem['h0197] = 8'hff;
	#(2* `CLKPERIOD * 21+`FIN)
	ASSERT(192'h000a_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_e11b, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0196] != 8'h04) $display("* FAIL *: [MEMWR] expected=04, actual=%2h",mem[16'h0196]);
	if (mem[16'h0197] != 8'h00) $display("* FAIL *: [MEMWR] expected=00, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD E4_1 (CALL PO,nn ; taken)
	$display(" -- fd e4       call po,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000a_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'he4; mem[2] = 8'h1b; mem[3] = 8'he1; mem['h0196] = 8'hff; mem['h0197] = 8'hff;
	#(2* `CLKPERIOD * 21+`FIN)
	ASSERT(192'h000a_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_e11b, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0196] != 8'h04) $display("* FAIL *: [MEMWR] expected=04, actual=%2h",mem[16'h0196]);
	if (mem[16'h0197] != 8'h00) $display("* FAIL *: [MEMWR] expected=00, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE E4_1 (CALL PO,nn ; taken)
	$display(" -- e4          call po,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'he4; mem[1] = 8'h1b; mem[2] = 8'he1;
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0003, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD E4_1 (CALL PO,nn ; taken)
	$display(" -- dd e4       call po,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'he4; mem[2] = 8'h1b; mem[3] = 8'he1;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0004, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD E4_1 (CALL PO,nn ; taken)
	$display(" -- fd e4       call po,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'he4; mem[2] = 8'h1b; mem[3] = 8'he1;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0004, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE E5 (PUSH HL)
	$display(" -- e5          push hl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h53e3_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'he5; mem['h0197] = 8'hff;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h53e3_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0196_0001, 8'h00, 8'h01, 2'b00);
	if (mem[16'h0196] != 8'h2f) $display("* FAIL *: [MEMWR] expected=2f, actual=%2h",mem[16'h0196]);
	if (mem[16'h0197] != 8'h1a) $display("* FAIL *: [MEMWR] expected=1a, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD E5 (PUSH IX)
	$display(" -- dd e5       push ix");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h53e3_1459_775f_dddd_0000_0000_0000_0000_1a2f_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'he5; mem['h0196] = 8'hff; mem['h0197] = 8'hff;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h53e3_1459_775f_dddd_0000_0000_0000_0000_1a2f_0000_0196_0002, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0196] != 8'h2f) $display("* FAIL *: [MEMWR] expected=2f, actual=%2h",mem[16'h0196]);
	if (mem[16'h0197] != 8'h1a) $display("* FAIL *: [MEMWR] expected=1a, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD E5 (PUSH IX)
	$display(" -- fd e5       push iy");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h53e3_1459_775f_dddd_0000_0000_0000_0000_0000_1a2f_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'he5; mem['h0196] = 8'hff; mem['h0197] = 8'hff;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h53e3_1459_775f_dddd_0000_0000_0000_0000_0000_1a2f_0196_0002, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0196] != 8'h2f) $display("* FAIL *: [MEMWR] expected=2f, actual=%2h",mem[16'h0196]);
	if (mem[16'h0197] != 8'h1a) $display("* FAIL *: [MEMWR] expected=1a, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE E6 (AND n)
	$display(" -- e6          and n");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h7500_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'he6; mem[1] = 8'h49;
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h4114_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0002, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD E6 (AND n)
	$display(" -- dd e6       and n");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h7500_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'he6; mem[2] = 8'h49;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h4114_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD E6 (AND n)
	$display(" -- fd e6       and n");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h7500_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'he6; mem[2] = 8'h49;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h4114_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE E7 (RST 20h)
	$display(" -- e7          rst 20h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0234, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[16'h0234] = 8'he7;  mem[16'h0197] = 8'hff;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_0020, 8'h00, 8'h01, 2'b00);
	if (mem[16'h0196] != 8'h35) $display("* FAIL *: [MEMWR] expected=35, actual=%2h",mem[16'h0196]);
	if (mem[16'h0197] != 8'h02) $display("* FAIL *: [MEMWR] expected=02, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD E7 (RST 20h)
	$display(" -- dd e7       rst 20h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0233, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[16'h0233] = 8'hdd; mem[16'h0234] = 8'he7; mem[16'h0197] = 8'hff;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_0020, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0196] != 8'h35) $display("* FAIL *: [MEMWR] expected=35, actual=%2h",mem[16'h0196]);
	if (mem[16'h0197] != 8'h02) $display("* FAIL *: [MEMWR] expected=02, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD E7 (RST 20h)
	$display(" -- fd e7       rst 20h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0233, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[16'h0233] = 8'hfd; mem[16'h0234] = 8'he7; mem[16'h0197] = 8'hff;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_0020, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0196] != 8'h35) $display("* FAIL *: [MEMWR] expected=35, actual=%2h",mem[16'h0196]);
	if (mem[16'h0197] != 8'h02) $display("* FAIL *: [MEMWR] expected=02, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE E8_1 (RET PE ; taken)
	$display(" -- e8          ret pe ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h009c_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'he8; mem[16'h01f7] = 8'he9; mem[16'h01f8] = 8'haf;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h009c_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f9_afe9, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD E8_1 (RET PE ; taken)
	$display(" -- dd e8       ret pe ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h009c_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'he8; mem[16'h01f7] = 8'he9; mem[16'h01f8] = 8'haf;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h009c_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f9_afe9, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD E8_1 (RET PE ; taken)
	$display(" -- fd e8       ret pe ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h009c_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'he8; mem[16'h01f7] = 8'he9; mem[16'h01f8] = 8'haf;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h009c_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f9_afe9, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE E8_1 (RET PE ; not taken)
	$display(" -- e8          ret pe ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'he8; mem[16'h01f7] = 8'he9; mem[16'h01f8] = 8'haf;
	#(2* `CLKPERIOD * 5+`FIN)
	ASSERT(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD E8_1 (RET PE ; not taken)
	$display(" -- dd e8       ret pe ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'he8; mem[16'h01f7] = 8'he9; mem[16'h01f8] = 8'haf;
	#(2* `CLKPERIOD * 9+`FIN)
	ASSERT(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD E8_1 (RET PE ; not taken)
	$display(" -- fd e8       ret pe ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'he8; mem[16'h01f7] = 8'he9; mem[16'h01f8] = 8'haf;
	#(2* `CLKPERIOD * 9+`FIN)
	ASSERT(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE E9 (JP (HL))
	$display(" -- e9          jp (hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0245_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'he9; mem['h0245] = 8'h1b; mem['h0246] = 8'he1;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0087_0000_0000_0245_0000_0000_0000_0000_0000_0000_0000_0245, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD E9 (JP (IX))
	$display(" -- dd e9       jp (ix)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0245_0000_0000_0000_0000_2345_6789_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'he9; mem['h0245] = 8'h1b; mem['h0246] = 8'he1;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0087_0000_0000_0245_0000_0000_0000_0000_2345_6789_0000_2345, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD E9 (JP (IY))
	$display(" -- fd e9       jp (iy)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0245_0000_0000_0000_0000_2345_6789_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'he9; mem['h0245] = 8'h1b; mem['h0246] = 8'he1;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0087_0000_0000_0245_0000_0000_0000_0000_2345_6789_0000_6789, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE EA_1 (JP PE,nn ; taken)
	$display(" -- ea          jp pe,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hea; mem[1] = 8'h1b; mem[2] = 8'he1;
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_e11b, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD EA_1 (JP PE,nn ; taken)
	$display(" -- dd ea       jp pe,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hea; mem[2] = 8'h1b; mem[3] = 8'he1;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_e11b, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD EA_1 (JP PE,nn ; taken)
	$display(" -- fd ea       jp pe,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hea; mem[2] = 8'h1b; mem[3] = 8'he1;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_e11b, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE EA_2 (JP PE,nn ; not taken)
	$display(" -- ea          jp pe,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0083_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hea; mem[1] = 8'h1b; mem[2] = 8'he1;
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0083_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD EA_2 (JP PE,nn ; not taken)
	$display(" -- dd ea       jp pe,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0083_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hea; mem[2] = 8'h1b; mem[3] = 8'he1;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0083_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0004, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD EA_2 (JP PE,nn ; not taken)
	$display(" -- fd ea       jp pe,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0083_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hea; mem[2] = 8'h1b; mem[3] = 8'he1;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0083_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0004, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE EB (EX DE,HL)
	$display(" -- eb          ex de,hl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_6789_0245_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'heb;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0087_0000_0245_6789_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD EB (EX DE,HL)
	$display(" -- dd eb       ex de,hl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_6789_0245_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'heb;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0087_0000_0245_6789_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD EB (EX DE,HL)
	$display(" -- fd eb       ex de,hl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_6789_0245_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'heb;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0087_0000_0245_6789_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE EC_1 (CALL PE,nn ; taken)
	$display(" -- ec          call pe,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hec; mem[1] = 8'h1b; mem[2] = 8'he1; mem['h0197] = 8'hff;
	#(2* `CLKPERIOD * 17+`FIN)
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_e11b, 8'h00, 8'h01, 2'b00);
	if (mem[16'h0196] != 8'h03) $display("* FAIL *: [MEMWR] expected=03, actual=%2h",mem[16'h0196]);
	if (mem[16'h0197] != 8'h00) $display("* FAIL *: [MEMWR] expected=00, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD EC_1 (CALL PE,nn ; taken)
	$display(" -- dd ec       call pe,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hec; mem[2] = 8'h1b; mem[3] = 8'he1; mem['h0196] = 8'hff; mem['h0197] = 8'hff;
	#(2* `CLKPERIOD * 21+`FIN)
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_e11b, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0196] != 8'h04) $display("* FAIL *: [MEMWR] expected=04, actual=%2h",mem[16'h0196]);
	if (mem[16'h0197] != 8'h00) $display("* FAIL *: [MEMWR] expected=00, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD EC_1 (CALL PE,nn ; taken)
	$display(" -- fd ec       call pe,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hec; mem[2] = 8'h1b; mem[3] = 8'he1; mem['h0196] = 8'hff; mem['h0197] = 8'hff;
	#(2* `CLKPERIOD * 21+`FIN)
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_e11b, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0196] != 8'h04) $display("* FAIL *: [MEMWR] expected=04, actual=%2h",mem[16'h0196]);
	if (mem[16'h0197] != 8'h00) $display("* FAIL *: [MEMWR] expected=00, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE EC_1 (CALL PE,nn ; taken)
	$display(" -- ec          call pe,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000a_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hec; mem[1] = 8'h1b; mem[2] = 8'he1;
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h000a_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0003, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD EC_1 (CALL PE,nn ; taken)
	$display(" -- dd ec       call pe,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000a_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hec; mem[2] = 8'h1b; mem[3] = 8'he1;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h000a_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0004, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD EC_1 (CALL PE,nn ; taken)
	$display(" -- fd ec       call pe,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000a_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hec; mem[2] = 8'h1b; mem[3] = 8'he1;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h000a_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0004, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE EE (XOR n)
	$display(" -- ee          xor n");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h3e00_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hee; mem[1] = 8'hd0;
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'heeac_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0002, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD EE (XOR n)
	$display(" -- dd ee       xor n");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h3e00_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hee; mem[2] = 8'hd0;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'heeac_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD EE (XOR n)
	$display(" -- fd ee       xor n");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h3e00_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hee; mem[2] = 8'hd0;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'heeac_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE EF (RST 28h)
	$display(" -- ef          rst 28h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0234, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[16'h0234] = 8'hef;  mem[16'h0197] = 8'hff;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_0028, 8'h00, 8'h01, 2'b00);
	if (mem[16'h0196] != 8'h35) $display("* FAIL *: [MEMWR] expected=35, actual=%2h",mem[16'h0196]);
	if (mem[16'h0197] != 8'h02) $display("* FAIL *: [MEMWR] expected=02, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD EF (RST 28h)
	$display(" -- dd ef       rst 28h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0233, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[16'h0233] = 8'hdd;  mem[16'h0234] = 8'hef;  mem[16'h0196] = 8'hff;  mem[16'h0197] = 8'hff;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_0028, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0196] != 8'h35) $display("* FAIL *: [MEMWR] expected=35, actual=%2h",mem[16'h0196]);
	if (mem[16'h0197] != 8'h02) $display("* FAIL *: [MEMWR] expected=02, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD EF (RST 28h)
	$display(" -- fd ef       rst 28h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0233, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[16'h0233] = 8'hfd;  mem[16'h0234] = 8'hef;  mem[16'h0196] = 8'hff;  mem[16'h0197] = 8'hff;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_0028, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0196] != 8'h35) $display("* FAIL *: [MEMWR] expected=35, actual=%2h",mem[16'h0196]);
	if (mem[16'h0197] != 8'h02) $display("* FAIL *: [MEMWR] expected=02, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE F0_1 (RET P ; taken)
	$display(" -- f0          ret p ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0018_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hf0; mem[16'h01f7] = 8'he9; mem[16'h01f8] = 8'haf;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h0018_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f9_afe9, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD F0_1 (RET P ; taken)
	$display(" -- dd f0       ret p ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0018_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hf0; mem[16'h01f7] = 8'he9; mem[16'h01f8] = 8'haf;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h0018_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f9_afe9, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD F0_1 (RET P ; taken)
	$display(" -- fd f0       ret p ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0018_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hf0; mem[16'h01f7] = 8'he9; mem[16'h01f8] = 8'haf;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h0018_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f9_afe9, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE F0_1 (RET P ; not taken)
	$display(" -- f0          ret p ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hf0; mem[16'h01f7] = 8'he9; mem[16'h01f8] = 8'haf;
	#(2* `CLKPERIOD * 5+`FIN)
	ASSERT(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD F0_1 (RET P ; not taken)
	$display(" -- dd f0       ret p ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hf0; mem[16'h01f7] = 8'he9; mem[16'h01f8] = 8'haf;
	#(2* `CLKPERIOD * 9+`FIN)
	ASSERT(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD F0_1 (RET P ; not taken)
	$display(" -- fd f0       ret p ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hf0; mem[16'h01f7] = 8'he9; mem[16'h01f8] = 8'haf;
	#(2* `CLKPERIOD * 9+`FIN)
	ASSERT(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE F1 (POP AF)
	$display(" -- f1          pop af");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0143_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hf1; mem[16'h0143] = 8'hce; mem[16'h0144] = 8'he8;
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'he8ce_0000_0000_0000_0000_0000_0000_0000_0000_0000_0145_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD F1 (POP AF)
	$display(" -- dd f1       pop af");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0143_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hf1; mem[16'h0143] = 8'hce; mem[16'h0144] = 8'he8;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'he8ce_0000_0000_0000_0000_0000_0000_0000_0000_0000_0145_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD F1 (POP AF)
	$display(" -- fd f1       pop af");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0143_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hf1; mem[16'h0143] = 8'hce; mem[16'h0144] = 8'he8;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'he8ce_0000_0000_0000_0000_0000_0000_0000_0000_0000_0145_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE F2_1 (JP P,nn ; taken)
	$display(" -- f2          jp p,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0007_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hf2; mem[1] = 8'h1b; mem[2] = 8'he1;
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0007_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_e11b, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD F2_1 (JP P,nn ; taken)
	$display(" -- dd f2       jp p,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0007_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hf2; mem[2] = 8'h1b; mem[3] = 8'he1;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0007_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_e11b, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD F2_1 (JP P,nn ; taken)
	$display(" -- fd f2       jp p,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0007_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hf2; mem[2] = 8'h1b; mem[3] = 8'he1;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0007_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_e11b, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE F2_2 (JP P,nn ; not taken)
	$display(" -- f2          jp p,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hf2; mem[1] = 8'h1b; mem[2] = 8'he1;
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD F2_2 (JP P,nn ; not taken)
	$display(" -- dd f2       jp p,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hf2; mem[2] = 8'h1b; mem[3] = 8'he1;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0004, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD F2_2 (JP P,nn ; not taken)
	$display(" -- fd f2       jp p,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hf2; mem[2] = 8'h1b; mem[3] = 8'he1;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0004, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE F3 (DI)
	$display(" -- f3          di");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0245_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b11);
	// memory data
	mem[0] = 8'hf3;
	#(2* `CLKPERIOD * 4+`FIN)
	ASSERT(192'h0087_0000_0000_0245_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD F3 (DI)
	$display(" -- dd f3       di");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0245_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b11);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hf3;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0087_0000_0000_0245_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD F3 (DI)
	$display(" -- fd f3       di");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0245_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b11);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hf3;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0087_0000_0000_0245_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE F4_1 (CALL P,nn ; taken)
	$display(" -- f4          call p,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000a_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hf4; mem[1] = 8'h1b; mem[2] = 8'he1; mem['h0197] = 8'hff;
	#(2* `CLKPERIOD * 17+`FIN)
	ASSERT(192'h000a_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_e11b, 8'h00, 8'h01, 2'b00);
	if (mem[16'h0196] != 8'h03) $display("* FAIL *: [MEMWR] expected=03, actual=%2h",mem[16'h0196]);
	if (mem[16'h0197] != 8'h00) $display("* FAIL *: [MEMWR] expected=00, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD F4_1 (CALL P,nn ; taken)
	$display(" -- dd f4       call p,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000a_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hf4; mem[2] = 8'h1b; mem[3] = 8'he1; mem['h0196] = 8'hff; mem['h0197] = 8'hff;
	#(2* `CLKPERIOD * 21+`FIN)
	ASSERT(192'h000a_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_e11b, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0196] != 8'h04) $display("* FAIL *: [MEMWR] expected=04, actual=%2h",mem[16'h0196]);
	if (mem[16'h0197] != 8'h00) $display("* FAIL *: [MEMWR] expected=00, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD F4_1 (CALL P,nn ; taken)
	$display(" -- fd f4       call p,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000a_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hf4; mem[2] = 8'h1b; mem[3] = 8'he1; mem['h0196] = 8'hff; mem['h0197] = 8'hff;
	#(2* `CLKPERIOD * 21+`FIN)
	ASSERT(192'h000a_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_e11b, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0196] != 8'h04) $display("* FAIL *: [MEMWR] expected=04, actual=%2h",mem[16'h0196]);
	if (mem[16'h0197] != 8'h00) $display("* FAIL *: [MEMWR] expected=00, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE F4_1 (CALL P,nn ; taken)
	$display(" -- f4          call p,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h008e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hf4; mem[1] = 8'h1b; mem[2] = 8'he1;
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h008e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0003, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD F4_1 (CALL P,nn ; taken)
	$display(" -- dd f4       call p,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h008e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hf4; mem[2] = 8'h1b; mem[3] = 8'he1;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h008e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0004, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD F4_1 (CALL P,nn ; taken)
	$display(" -- fd f4       call p,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h008e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hf4; mem[2] = 8'h1b; mem[3] = 8'he1;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h008e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0004, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE F5 (PUSH AF)
	$display(" -- f5          push af");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h53e3_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hf5; mem['h0197] = 8'hff;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h53e3_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0196_0001, 8'h00, 8'h01, 2'b00);
	if (mem[16'h0196] != 8'he3) $display("* FAIL *: [MEMWR] expected=e3, actual=%2h",mem[16'h0196]);
	if (mem[16'h0197] != 8'h53) $display("* FAIL *: [MEMWR] expected=53, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD F5 (PUSH AF)
	$display(" -- dd f5       push af");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h53e3_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hf5; mem['h0196] = 8'hff;  mem['h0197] = 8'hff;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h53e3_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0196_0002, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0196] != 8'he3) $display("* FAIL *: [MEMWR] expected=e3, actual=%2h",mem[16'h0196]);
	if (mem[16'h0197] != 8'h53) $display("* FAIL *: [MEMWR] expected=53, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD F5 (PUSH AF)
	$display(" -- fd f5       push af");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h53e3_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hf5; mem['h0196] = 8'hff;  mem['h0197] = 8'hff;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h53e3_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0196_0002, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0196] != 8'he3) $display("* FAIL *: [MEMWR] expected=e3, actual=%2h",mem[16'h0196]);
	if (mem[16'h0197] != 8'h53) $display("* FAIL *: [MEMWR] expected=53, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE F6 (OR n)
	$display(" -- f6          or n");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0600_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hf6; mem[1] = 8'ha7;
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'ha7a0_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0002, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD F6 (OR n)
	$display(" -- dd f6       or n");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0600_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hf6; mem[2] = 8'ha7;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'ha7a0_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD F6 (OR n)
	$display(" -- fd f6       or n");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0600_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hf6; mem[2] = 8'ha7;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'ha7a0_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE F7 (RST 30h)
	$display(" -- f7          rst 30h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0234, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[16'h0234] = 8'hf7;  mem[16'h0197] = 8'hff;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_0030, 8'h00, 8'h01, 2'b00);
	if (mem[16'h0196] != 8'h35) $display("* FAIL *: [MEMWR] expected=35, actual=%2h",mem[16'h0196]);
	if (mem[16'h0197] != 8'h02) $display("* FAIL *: [MEMWR] expected=02, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD F7 (RST 30h)
	$display(" -- dd f7       rst 30h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0233, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[16'h0233] = 8'hdd; mem[16'h0234] = 8'hf7; mem[16'h0196] = 8'hff; mem[16'h0197] = 8'hff;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_0030, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0196] != 8'h35) $display("* FAIL *: [MEMWR] expected=35, actual=%2h",mem[16'h0196]);
	if (mem[16'h0197] != 8'h02) $display("* FAIL *: [MEMWR] expected=02, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD F7 (RST 30h)
	$display(" -- fd f7       rst 30h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0233, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[16'h0233] = 8'hfd; mem[16'h0234] = 8'hf7; mem[16'h0196] = 8'hff; mem[16'h0197] = 8'hff;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_0030, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0196] != 8'h35) $display("* FAIL *: [MEMWR] expected=35, actual=%2h",mem[16'h0196]);
	if (mem[16'h0197] != 8'h02) $display("* FAIL *: [MEMWR] expected=02, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE F8_1 (RET M ; taken)
	$display(" -- f8          ret m ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hf8; mem[16'h01f7] = 8'he9; mem[16'h01f8] = 8'haf;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f9_afe9, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD F8_1 (RET M ; taken)
	$display(" -- dd f8       ret m ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hf8; mem[16'h01f7] = 8'he9; mem[16'h01f8] = 8'haf;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f9_afe9, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD F8_1 (RET M ; taken)
	$display(" -- fd f8       ret m ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hf8; mem[16'h01f7] = 8'he9; mem[16'h01f8] = 8'haf;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h0098_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f9_afe9, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE F8_1 (RET M ; not taken)
	$display(" -- f8          ret m ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0018_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hf8; mem[16'h01f7] = 8'he9; mem[16'h01f8] = 8'haf;
	#(2* `CLKPERIOD * 5+`FIN)
	ASSERT(192'h0018_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD F8_1 (RET M ; not taken)
	$display(" -- dd f8       ret m ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0018_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hf8; mem[16'h01f7] = 8'he9; mem[16'h01f8] = 8'haf;
	#(2* `CLKPERIOD * 9+`FIN)
	ASSERT(192'h0018_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD F8_1 (RET M ; not taken)
	$display(" -- fd f8       ret m ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0018_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hf8; mem[16'h01f7] = 8'he9; mem[16'h01f8] = 8'haf;
	#(2* `CLKPERIOD * 9+`FIN)
	ASSERT(192'h0018_0000_0000_0000_0000_0000_0000_0000_0000_0000_01f7_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE F9 (LD SP,HL)
	$display(" -- f9          ld sp,hl");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0018_0000_0000_2345_0000_0000_0000_0000_0000_0000_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hf9; 
	#(2* `CLKPERIOD * 6+`FIN)
	ASSERT(192'h0018_0000_0000_2345_0000_0000_0000_0000_0000_0000_2345_0001, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD F9 (LD SP,IX)
	$display(" -- dd f9       ld sp,ix");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0018_0000_0000_2345_0000_0000_0000_0000_5678_9abc_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hf9; 
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0018_0000_0000_2345_0000_0000_0000_0000_5678_9abc_5678_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD F9 (LD SP,IY)
	$display(" -- fd f9       ld sp,iy");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0018_0000_0000_2345_0000_0000_0000_0000_5678_9abc_01f7_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hf9; 
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0018_0000_0000_2345_0000_0000_0000_0000_5678_9abc_9abc_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FA_1 (JP M,nn ; taken)
	$display(" -- fa          jp m,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfa; mem[1] = 8'h1b; mem[2] = 8'he1;
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_e11b, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD FA_1 (JP M,nn ; taken)
	$display(" -- dd fa       jp m,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hfa; mem[2] = 8'h1b; mem[3] = 8'he1;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_e11b, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD FA_1 (JP M,nn ; taken)
	$display(" -- fd fa       jp m,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hfa; mem[2] = 8'h1b; mem[3] = 8'he1;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0087_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_e11b, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FA_2 (JP M,nn ; not taken)
	$display(" -- fa          jp m,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0077_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfa; mem[1] = 8'h1b; mem[2] = 8'he1;
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h0077_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD FA_2 (JP M,nn ; not taken)
	$display(" -- dd fa       jp m,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0077_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hfa; mem[2] = 8'h1b; mem[3] = 8'he1;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0077_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0004, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD FA_2 (JP M,nn ; not taken)
	$display(" -- fd fa       jp m,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0077_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hfa; mem[2] = 8'h1b; mem[3] = 8'he1;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h0077_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0004, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FB (EI)
	$display(" -- fb 00       ei nop");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0245_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfb; mem[1] = 8'h00;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0087_0000_0000_0245_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b11);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD FB (EI)
	$display(" -- dd fb 00    ei nop");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0245_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hfb; mem[2] = 8'h00;
	#(2* `CLKPERIOD * 12+`FIN)
	ASSERT(192'h0087_0000_0000_0245_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h03, 2'b11);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD FB (EI)
	$display(" -- fd fb 00    ei nop");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0087_0000_0000_0245_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hfb; mem[2] = 8'h00;
	#(2* `CLKPERIOD * 12+`FIN)
	ASSERT(192'h0087_0000_0000_0245_0000_0000_0000_0000_0000_0000_0000_0003, 8'h00, 8'h03, 2'b11);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FC_1 (CALL M,nn ; taken)
	$display(" -- fc          call m,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h008a_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfc; mem[1] = 8'h1b; mem[2] = 8'he1; mem['h0197] = 8'hff;
	#(2* `CLKPERIOD * 17+`FIN)
	ASSERT(192'h008a_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_e11b, 8'h00, 8'h01, 2'b00);
	if (mem[16'h0196] != 8'h03) $display("* FAIL *: [MEMWR] expected=03, actual=%2h",mem[16'h0196]);
	if (mem[16'h0197] != 8'h00) $display("* FAIL *: [MEMWR] expected=00, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD FC_1 (CALL M,nn ; taken)
	$display(" -- dd fc       call m,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h008a_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hfc; mem[2] = 8'h1b; mem[3] = 8'he1; mem['h0196] = 8'hff;  mem['h0197] = 8'hff;
	#(2* `CLKPERIOD * 21+`FIN)
	ASSERT(192'h008a_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_e11b, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0196] != 8'h04) $display("* FAIL *: [MEMWR] expected=04, actual=%2h",mem[16'h0196]);
	if (mem[16'h0197] != 8'h00) $display("* FAIL *: [MEMWR] expected=00, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD FC_1 (CALL M,nn ; taken)
	$display(" -- fd fc       call m,$e11b ; taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h008a_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hfc; mem[2] = 8'h1b; mem[3] = 8'he1; mem['h0196] = 8'hff;  mem['h0197] = 8'hff;
	#(2* `CLKPERIOD * 21+`FIN)
	ASSERT(192'h008a_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_e11b, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0196] != 8'h04) $display("* FAIL *: [MEMWR] expected=04, actual=%2h",mem[16'h0196]);
	if (mem[16'h0197] != 8'h00) $display("* FAIL *: [MEMWR] expected=00, actual=%2h",mem[16'h0197]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FC_1 (CALL M,nn ; taken)
	$display(" -- fc          call m,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfc; mem[1] = 8'h1b; mem[2] = 8'he1;
	#(2* `CLKPERIOD * 10+`FIN)
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0003, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD FC_1 (CALL M,nn ; taken)
	$display(" -- dd fc       call m,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hfc; mem[2] = 8'h1b; mem[3] = 8'he1;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0004, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD FC_1 (CALL M,nn ; taken)
	$display(" -- fd fc       call m,$e11b ; not taken");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hfc; mem[2] = 8'h1b; mem[3] = 8'he1;
	#(2* `CLKPERIOD * 14+`FIN)
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0004, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FE (CP n)
	$display(" -- fe          cp n");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6900_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfe; mem[1] = 8'h82;
	#(2* `CLKPERIOD * 7+`FIN)
	ASSERT(192'h6987_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0002, 8'h00, 8'h01, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD FE (CP n)
	$display(" -- dd fe       cp n");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6900_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hdd; mem[1] = 8'hfe; mem[2] = 8'h82;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h6987_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FD FE (CP n)
	$display(" -- fd fe       cp n");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6900_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hfd; mem[1] = 8'hfe; mem[2] = 8'h82;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h6987_1459_775f_1a2f_0000_0000_0000_0000_0000_0000_0198_0003, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE FF (RST 38h)
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0234, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[16'h0234] = 8'hff;  mem[16'h0197] = 8'hff;
	#(2* `CLKPERIOD * 11+`FIN)
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_0038, 8'h00, 8'h01, 2'b00);
	if (mem[16'h0196] != 8'h35) $display("* FAIL *: [MEMWR] expected=35, actual=%2h",mem[16'h0196]);
	if (mem[16'h0197] != 8'h02) $display("* FAIL *: [MEMWR] expected=02, actual=%2h",mem[16'h0197]);
	if (FAIL) $display(" -- ff          rst 38h");


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE DD FF (RST 38h)
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0233, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[16'h0233] = 8'hdd;  mem[16'h0234] = 8'hff; mem[16'h0196] = 8'hff; mem[16'h0197] = 8'hff;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_0038, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0196] != 8'h35) $display("* FAIL *: [MEMWR] expected=35, actual=%2h",mem[16'h0196]);
	if (mem[16'h0197] != 8'h02) $display("* FAIL *: [MEMWR] expected=02, actual=%2h",mem[16'h0197]);
	if (FAIL) $display(" -- dd ff       rst 38h");


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	TESTCASE = "FUSE FD FF (RST 38h)";
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0198_0233, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[16'h0233] = 8'hfd;  mem[16'h0234] = 8'hff; mem[16'h0196] = 8'hff; mem[16'h0197] = 8'hff;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h000e_0000_0000_0000_0000_0000_0000_0000_0000_0000_0196_0038, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0196] != 8'h35) $display("* FAIL *: [MEMWR] expected=35, actual=%2h",mem[16'h0196]);
	if (mem[16'h0197] != 8'h02) $display("* FAIL *: [MEMWR] expected=02, actual=%2h",mem[16'h0197]);
	//if (FAIL) $display(" -- fd ff       rst 38h");



// *****************************************************************************************************
//
//  BIT instructions (CB)
//
// *****************************************************************************************************

	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 00 (RLC B)
	$display(" -- cb 00       rlc b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hda00_e479_552e_a806_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h00;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hda8d_c979_552e_a806_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 01 (RLC C)
	$display(" -- cb 01       rlc c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h1000_b379_552e_a806_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h01;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h10a0_b3f2_552e_a806_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 02 (RLC D)
	$display(" -- cb 02       rlc d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2e00_e479_ae6e_a806_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h02;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h2e09_e479_5d6e_a806_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 03 (RLC E)
	$display(" -- cb 03       rlc e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6800_e479_de3f_a806_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h03;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h682c_e479_de7e_a806_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 04 (RLC H)
	$display(" -- cb 04       rlc h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h8c00_e479_552e_67b0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h04;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h8c88_e479_552e_ceb0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 05 (RLC L)
	$display(" -- cb 05       rlc l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h3600_e479_552e_cb32_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h05;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h3620_e479_552e_cb64_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 06 (RLC (HL))
	$display(" -- cb 06       rlc (hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h8a00_e479_552e_0106_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h06; mem[16'h0106] = 8'hd4;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h8aad_e479_552e_0106_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0106] != 8'ha9) $display("* FAIL *: [MEMWR] expected=a9, actual=%2h",mem[16'h0106]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 07 (RLC A)
	$display(" -- cb 07       rlc a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6d00_e479_552e_a806_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h07;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hda88_e479_552e_a806_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 08 (RRC B)
	$display(" -- cb 08       rrc b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h8000_cdb5_818e_2ee2_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h08;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h80a1_e6b5_818e_2ee2_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 09 (RRC C)
	$display(" -- cb 09       rrc c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h1800_125c_dd97_59c6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h09;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h182c_122e_dd97_59c6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 0A (RRC D)
	$display(" -- cb 0a       rrc d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h1200_3ba1_7724_63ad_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h0a;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h12ad_3ba1_bb24_63ad_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 0B (RRC E)
	$display(" -- cb 0b       rrc e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h7600_2abf_b626_0289_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h0b;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h7600_2abf_b613_0289_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 0C (RRC H)
	$display(" -- cb 0c       rrc h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0e00_6fc5_2f12_34d9_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h0c;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0e08_6fc5_2f12_1ad9_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 0D (RRC L)
	$display(" -- cb 0d       rrc l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6300_95a3_fcd2_519a_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h0d;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h630c_95a3_fcd2_514d_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 0E (RRC (HL))
	$display(" -- cb 0e       rrc (hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hfc00_adf9_4925_013e_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h0e; mem[16'h013e] = 8'hd2;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'hfc2c_adf9_4925_013e_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
	if (mem[16'h013e] != 8'h69) $display("* FAIL *: [MEMWR] expected=69, actual=%2h",mem[16'h013e]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 0F (RRC A)
	$display(" -- cb 0f       rrc a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hc300_18f3_41b8_070b_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h0f;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'he1a5_18f3_41b8_070b_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 10 (RL B)
	$display(" -- cb 10       rl b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf800_dc25_33b3_0d74_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h10;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hf8ad_b825_33b3_0d74_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 11 (RL C)
	$display(" -- cb 11       rl c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6500_e25c_4b8a_ed42_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h11;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h65ac_e2b8_4b8a_ed42_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 12 (RL D)
	$display(" -- cb 12       rl d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h7700_1384_0f50_29c6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h12;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h770c_1384_1e50_29c6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 13 (RL E)
	$display(" -- cb 13       rl e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hce00_9f17_e128_3ed7_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h13;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hce04_9f17_e150_3ed7_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 14 (RL H)
	$display(" -- cb 14       rl h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hb200_541a_60c7_7c9a_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h14;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hb2a8_541a_60c7_f89a_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 15 (RL L)
	$display(" -- cb 15       rl l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2d00_c1df_6eab_03e2_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h15;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h2d81_c1df_6eab_03c4_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 16 (RL (HL))
	$display(" -- cb 16       rl (hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h3600_3b53_1a4a_024e_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h16; mem[16'h024e] = 8'hc3;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h3681_3b53_1a4a_024e_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
	if (mem[16'h024e] != 8'h86) $display("* FAIL *: [MEMWR] expected=86, actual=%2h",mem[16'h024e]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 17 (RL A)
	$display(" -- cb 17       rl a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h5400_d090_f60d_0fa2_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h17;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha8a8_d090_f60d_0fa2_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 18 (RR B)
	$display(" -- cb 18       rr b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h8600_c658_755f_9596_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h18;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h8624_6358_755f_9596_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 19 (RR C)
	$display(" -- cb 19       rr c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9600_beb3_7c22_71c8_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h19;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h960d_be59_7c22_71c8_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 1A (RR D)
	$display(" -- cb 1a       rr d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h3900_882f_543b_5279_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h1a;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h3928_882f_2a3b_5279_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 1B (RR E)
	$display(" -- cb 1b       rr e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9e00_b338_876c_e8b4_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h1b;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9e24_b338_8736_e8b4_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 1C (RR H)
	$display(" -- cb 1c       rr h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h4b00_b555_238f_311d_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h1c;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h4b0d_b555_238f_181d_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 1D (RR L)
	$display(" -- cb 1d       rr l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2100_3d7e_5e39_e451_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h1d;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h212d_3d7e_5e39_e428_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 1E (RR (HL))
	$display(" -- cb 1e       rr (hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h5e00_66b9_80dc_00ef_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h1e; mem[16'h00ef] = 8'h91;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h5e0d_66b9_80dc_00ef_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
	if (mem[16'h00ef] != 8'h48) $display("* FAIL *: [MEMWR] expected=48, actual=%2h",mem[16'h00ef]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 1F (RR A)
	$display(" -- cb 1f       rr a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hed00_b838_8e18_ace7_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h1f;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h7621_b838_8e18_ace7_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 20 (SLA B)
	$display(" -- cb 20       sla b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hc700_0497_d72b_ccb6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h20;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hc708_0897_d72b_ccb6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 21 (SLA C)
	$display(" -- cb 21       sla c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2200_5cf4_938e_37a8_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h21;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h22ad_5ce8_938e_37a8_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 22 (SLA D)
	$display(" -- cb 22       sla d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h8500_0950_e7e8_0641_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h22;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h8589_0950_cee8_0641_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 23 (SLA E)
	$display(" -- cb 23       sla e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2100_2a7c_37d0_aa59_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h23;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h21a5_2a7c_37a0_aa59_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 24 (SLA H)
	$display(" -- cb 24       sla h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hfb00_b9de_7014_84b6_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h24;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hfb09_b9de_7014_08b6_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 25 (SLA L)
	$display(" -- cb 25       sla l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h1500_6bbc_894e_85bc_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h25;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h152d_6bbc_894e_8578_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 26 (SLA (HL))
	$display(" -- cb 26       sla (hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0a00_372e_e315_033a_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h26; mem[16'h033a] = 8'hee;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h0a89_372e_e315_033a_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
	if (mem[16'h033a] != 8'hdc) $display("* FAIL *: [MEMWR] expected=dc, actual=%2h",mem[16'h033a]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 27 (SLA A)
	$display(" -- cb 27       sla a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hbf00_bdba_67ab_5ea2_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h27;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h7e2d_bdba_67ab_5ea2_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 28 (SRA B)
	$display(" -- cb 28       sra b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hc000_0435_3e0f_021b_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h28;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hc000_0235_3e0f_021b_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 29 (SRA C)
	$display(" -- cb 29       sra c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h0600_f142_6ada_c306_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h29;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h0624_f121_6ada_c306_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 2A (SRA D)
	$display(" -- cb 2a       sra d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h3000_ec3a_7f7d_3473_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h2a;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h302d_ec3a_3f7d_3473_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 2B (SRA E)
	$display(" -- cb 2b       sra e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'he000_ccf0_bbda_b78a_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h2b;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'he0ac_ccf0_bbed_b78a_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 2C (SRA H)
	$display(" -- cb 2c       sra h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h5b00_25c0_996d_1e7b_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h2c;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h5b0c_25c0_996d_0f7b_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 2D (SRA L)
	$display(" -- cb 2d       sra l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h5e00_c51b_58e3_78ea_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h2d;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h5ea4_c51b_58e3_78f5_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 2E (SRA (HL))
	$display(" -- cb 2e       sra (hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h3900_a2cd_0629_02bf_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h2e; mem[16'h02bf] = 8'hb5;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h3989_a2cd_0629_02bf_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
	if (mem[16'h02bf] != 8'hda) $display("* FAIL *: [MEMWR] expected=da, actual=%2h",mem[16'h02bf]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 2F (SRA A)
	$display(" -- cb 2f       sra a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'haa00_a194_d0e3_5c65_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h2f;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hd580_a194_d0e3_5c65_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 30 (SLL B)
	$display(" -- cb 30       sll b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hcd00_7a81_d67b_656b_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h30;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hcda4_f581_d67b_656b_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 31 (SLL C)
	$display(" -- cb 31       sll c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2800_e7fa_6d8c_75a4_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h31;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h28a5_e7f5_6d8c_75a4_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 32 (SLL D)
	$display(" -- cb 32       sll d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h1300_3f36_f608_5e56_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h32;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h13ad_3f36_ed08_5e56_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 33 (SLL E)
	$display(" -- cb 33       sll e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hd500_9720_7644_038f_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h33;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hd588_9720_7689_038f_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 34 (SLL H)
	$display(" -- cb 34       sll h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h1200_77f6_0206_fb38_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h34;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h12a1_77f6_0206_f738_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 35 (SLL L)
	$display(" -- cb 35       sll l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h3c00_fd68_ea91_7861_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h35;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h3c84_fd68_ea91_78c3_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 36 (SLL (HL))
	$display(" -- cb 36       sll (hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h8a00_1185_1dde_0138_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h36; mem[16'h0138] = 8'hf1;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h8aa1_1185_1dde_0138_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0138] != 8'he3) $display("* FAIL *: [MEMWR] expected=e3, actual=%2h",mem[16'h0138]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 37 (SLL A)
	$display(" -- cb 37       sll a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h4300_d7bc_9133_6e56_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h37;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h8784_d7bc_9133_6e56_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 38 (SRL B)
	$display(" -- cb 38       srl b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hdf00_7c1b_9f9f_4ff2_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h38;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hdf28_3e1b_9f9f_4ff2_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 39 (SRL C)
	$display(" -- cb 39       srl c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6600_b702_14f5_3c17_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h39;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6600_b701_14f5_3c17_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 3A (SRL D)
	$display(" -- cb 3a       srl d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hd100_5c5f_e42e_f1b1_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h3a;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hd124_5c5f_722e_f1b1_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 3B (SRL E)
	$display(" -- cb 3b       srl e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hb200_38c8_a560_7419_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h3b;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hb224_38c8_a530_7419_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 3C (SRL H)
	$display(" -- cb 3c       srl h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h7800_cfae_66d8_2ad8_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h3c;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h7800_cfae_66d8_15d8_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 3D (SRL L)
	$display(" -- cb 3d       srl l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'he600_dcda_06aa_46cd_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h3d;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'he625_dcda_06aa_4666_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 3E (SRL (HL))
	$display(" -- cb 3e       srl (hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha900_6a34_e8d0_006c_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h3e; mem[16'h006c] = 8'ha0;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'ha904_6a34_e8d0_006c_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
	if (mem[16'h006c] != 8'h50) $display("* FAIL *: [MEMWR] expected=50, actual=%2h",mem[16'h006c]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 3F (SRL A)
	$display(" -- cb 3f       srl a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'hf100_ceea_721e_77f0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h3f;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h782d_ceea_721e_77f0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 40 (BIT 0,B)
	$display(" -- cb 40       bit 0,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9e00_bcb2_efaa_505f_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h40;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9e7c_bcb2_efaa_505f_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 41 (BIT 0,C)
	$display(" -- cb 41       bit 0,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9e00_1b43_efaa_505f_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h41;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9e10_1b43_efaa_505f_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 42 (BIT 0,D)
	$display(" -- cb 42       bit 0,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9e00_bcb2_7d4f_505f_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h42;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9e38_bcb2_7d4f_505f_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 43 (BIT 0,E)
	$display(" -- cb 43       bit 0,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9e00_bcb2_f1d0_505f_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h43;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9e54_bcb2_f1d0_505f_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 44 (BIT 0,H)
	$display(" -- cb 44       bit 0,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9e00_bcb2_efaa_5b92_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h44;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9e18_bcb2_efaa_5b92_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 45 (BIT 0,L)
	$display(" -- cb 45       bit 0,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9e00_bcb2_efaa_409b_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h45;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9e18_bcb2_efaa_409b_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 46 (BIT 0,(HL))
	$display(" -- cb 46       bit 0,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9e00_bcb2_efaa_0131_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h46; mem[16'h0131] = 8'hd5;
	#(2* `CLKPERIOD * 12+`FIN)
	ASSERT(192'h9e10_bcb2_efaa_0131_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0131] != 8'hd5) $display("* FAIL *: [MEMWR] expected=d5, actual=%2h",mem[16'h0131]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 47 (BIT 0,A)
	$display(" -- cb 47       bit 0,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h1000_bcb2_efaa_505f_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h47;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h1054_bcb2_efaa_505f_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 48 (BIT 1,B)
	$display(" -- cb 48       bit 1,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha900_6264_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h48;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha930_6264_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 49 (BIT 1,C)
	$display(" -- cb 49       bit 1,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha900_d0f7_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h49;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha930_d0f7_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 4A (BIT 1,D)
	$display(" -- cb 4a       bit 1,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha900_6264_5b29_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h4a;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha918_6264_5b29_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 4B (BIT 1,E)
	$display(" -- cb 4b       bit 1,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha900_6264_095f_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h4b;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha918_6264_095f_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 4C (BIT 1,H)
	$display(" -- cb 4c       bit 1,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha900_6264_e833_6d5d_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h4c;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha97c_6264_e833_6d5d_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 4D (BIT 1,L)
	$display(" -- cb 4d       bit 1,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha900_6264_e833_158d_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h4d;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha95c_6264_e833_158d_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);

	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 4E (BIT 1,(HL))
	$display(" -- cb 4e       bit 1,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h4e; mem[2] = 8'h00; mem[16'h01a3] = 8'h5b;
	#(2* `CLKPERIOD * 12+`FIN)
	ASSERT(192'h2610_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
	if (mem[16'h01a3] != 8'h5b) $display("* FAIL *: [MEMWR] expected=5b, actual=%2h",mem[16'h01a3]);

	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 4F (BIT 1,A)
	$display(" -- cb 4f       bit 1,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h1700_6264_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h4f;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h1710_6264_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 50 (BIT 2,B)
	$display(" -- cb 50       bit 2,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9e00_2749_efaa_505f_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h50;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9e30_2749_efaa_505f_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 51 (BIT 2,C)
	$display(" -- cb 51       bit 2,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9e00_b7db_efaa_505f_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h51;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9e5c_b7db_efaa_505f_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 52 (BIT 2,D)
	$display(" -- cb 52       bit 2,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9e00_bcb2_7d4f_505f_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h52;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9e38_bcb2_7d4f_505f_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 53 (BIT 2,E)
	$display(" -- cb 53       bit 2,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9e00_bcb2_f1d0_505f_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h53;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9e54_bcb2_f1d0_505f_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 54 (BIT 2,H)
	$display(" -- cb 54       bit 2,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9e00_bcb2_efaa_1999_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h54;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9e5c_bcb2_efaa_1999_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 55 (BIT 2,L)
	$display(" -- cb 55       bit 2,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9e00_bcb2_efaa_fb4b_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h55;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9e5c_bcb2_efaa_fb4b_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 56 (BIT 2,(HL))
	$display(" -- cb 56       bit 2,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9e00_bcb2_efaa_0131_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h56; mem[16'h0131] = 8'hd5;
	#(2* `CLKPERIOD * 12+`FIN)
	ASSERT(192'h9e10_bcb2_efaa_0131_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0131] != 8'hd5) $display("* FAIL *: [MEMWR] expected=d5, actual=%2h",mem[16'h0131]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 57 (BIT 2,A)
	$display(" -- cb 57       bit 2,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h1000_bcb2_efaa_505f_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h57;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h1054_bcb2_efaa_505f_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 88 (BIT 3,B)
	$display(" -- cb 58       bit 3,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha900_1aee_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h58;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha918_1aee_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 59 (BIT 3,C)
	$display(" -- cb 59       bit 3,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha900_5e68_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h59;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha938_5e68_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 5A (BIT 3,D)
	$display(" -- cb 5a       bit 3,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha900_6264_5b29_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h5a;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha918_6264_5b29_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 5B (BIT 3,E)
	$display(" -- cb 5b       bit 3,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha900_6264_095f_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h5b;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha918_6264_095f_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 5C (BIT 3,H)
	$display(" -- cb 5c       bit 3,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha900_6264_e833_13e9_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h5c;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha954_6264_e833_13e9_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 5D (BIT 3,L)
	$display(" -- cb 5d       bit 3,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha900_6264_e833_ee49_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h5d;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha918_6264_e833_ee49_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);

	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 5E (BIT 3,(HL))
	$display(" -- cb 5e       bit 3,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h5e; mem[2] = 8'h00; mem[16'h01a3] = 8'h5b;
	#(2* `CLKPERIOD * 12+`FIN)
	ASSERT(192'h2610_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
	if (mem[16'h01a3] != 8'h5b) $display("* FAIL *: [MEMWR] expected=5b, actual=%2h",mem[16'h01a3]);

	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 5F (BIT 3,A)
	$display(" -- cb 5f       bit 3,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h8c00_6264_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h5f;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h8c18_6264_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 60 (BIT 4,B)
	$display(" -- cb 60       bit 4,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9e00_34b5_efaa_505f_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h60;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9e30_34b5_efaa_505f_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 61 (BIT 4,C)
	$display(" -- cb 61       bit 4,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9e00_219f_efaa_505f_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h61;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9e18_219f_efaa_505f_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 62 (BIT 4,D)
	$display(" -- cb 62       bit 4,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9e00_bcb2_7d4f_505f_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h62;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9e38_bcb2_7d4f_505f_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 63 (BIT 4,E)
	$display(" -- cb 63       bit 4,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9e00_bcb2_f627_505f_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h63;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9e74_bcb2_f627_505f_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 64 (BIT 4,H)
	$display(" -- cb 64       bit 4,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9e00_bcb2_efaa_ea94_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h64;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9e7c_bcb2_efaa_ea94_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 65 (BIT 4,L)
	$display(" -- cb 65       bit 4,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9e00_bcb2_efaa_fb4b_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h65;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9e5c_bcb2_efaa_fb4b_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 66 (BIT 4,(HL))
	$display(" -- cb 66       bit 4,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9e00_bcb2_efaa_0131_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h66; mem[16'h0131] = 8'hd5;
	#(2* `CLKPERIOD * 12+`FIN)
	ASSERT(192'h9e10_bcb2_efaa_0131_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0131] != 8'hd5) $display("* FAIL *: [MEMWR] expected=d5, actual=%2h",mem[16'h0131]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 67 (BIT 4,A)
	$display(" -- cb 67       bit 4,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h8600_bcb2_efaa_505f_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h67;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h8654_bcb2_efaa_505f_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 68 (BIT 5,B)
	$display(" -- cb 68       bit 5,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha900_0f6a_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h68;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha95c_0f6a_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 69 (BIT 5,C)
	$display(" -- cb 69       bit 5,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha900_5e68_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h69;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha938_5e68_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 6A (BIT 5,D)
	$display(" -- cb 6a       bit 5,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha900_6264_86d4_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h6a;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha954_6264_86d4_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 6B (BIT 5,E)
	$display(" -- cb 6b       bit 5,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha900_6264_7635_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h6b;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha930_6264_7635_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 6C (BIT 5,H)
	$display(" -- cb 6c       bit 5,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha900_6264_e833_13e9_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h6c;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha954_6264_e833_13e9_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 6D (BIT 5,L)
	$display(" -- cb 6d       bit 5,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha900_6264_e833_d9ad_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h6d;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha938_6264_e833_d9ad_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);

	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 6E (BIT 5,(HL))
	$display(" -- cb 6e       bit 5,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h6e; mem[2] = 8'h00; mem[16'h01a3] = 8'h31;
	#(2* `CLKPERIOD * 12+`FIN)
	ASSERT(192'h2610_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
	if (mem[16'h01a3] != 8'h31) $display("* FAIL *: [MEMWR] expected=31, actual=%2h",mem[16'h01a3]);

	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 6F (BIT 5,A)
	$display(" -- cb 6f       bit 5,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha100_6264_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h6f;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha130_6264_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 70 (BIT 6,B)
	$display(" -- cb 70       bit 6,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9e00_957a_efaa_505f_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h70;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9e54_957a_efaa_505f_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 71 (BIT 6,C)
	$display(" -- cb 71       bit 6,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9e00_095e_efaa_505f_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h71;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9e18_095e_efaa_505f_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 72 (BIT 6,D)
	$display(" -- cb 72       bit 6,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9e00_bcb2_7d4f_505f_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h72;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9e38_bcb2_7d4f_505f_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 73 (BIT 6,E)
	$display(" -- cb 73       bit 6,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9e00_bcb2_f627_505f_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h73;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9e74_bcb2_f627_505f_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 74 (BIT 6,H)
	$display(" -- cb 74       bit 6,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9e00_bcb2_efaa_983d_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h74;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9e5c_bcb2_efaa_983d_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 75 (BIT 6,L)
	$display(" -- cb 75       bit 6,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9e00_bcb2_efaa_d18d_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h75;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h9e5c_bcb2_efaa_d18d_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 76 (BIT 6,(HL))
	$display(" -- cb 76       bit 6,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h9e00_bcb2_efaa_0131_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h76; mem[16'h0131] = 8'hd5;
	#(2* `CLKPERIOD * 12+`FIN)
	ASSERT(192'h9e10_bcb2_efaa_0131_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
	if (mem[16'h0131] != 8'hd5) $display("* FAIL *: [MEMWR] expected=d5, actual=%2h",mem[16'h0131]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 77 (BIT 6,A)
	$display(" -- cb 77       bit 6,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h8600_bcb2_efaa_505f_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h77;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h8654_bcb2_efaa_505f_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 78 (BIT 7,B)
	$display(" -- cb 78       bit 7,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha900_0f6a_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h78;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha95c_0f6a_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 79 (BIT 7,C)
	$display(" -- cb 79       bit 7,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha900_5e9e_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h79;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha998_5e9e_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 7A (BIT 7,D)
	$display(" -- cb 7a       bit 7,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha900_6264_63d4_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h7a;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha974_6264_63d4_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 7B (BIT 7,E)
	$display(" -- cb 7b       bit 7,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha900_6264_76bd_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h7b;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha9b8_6264_76bd_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 7C (BIT 7,H)
	$display(" -- cb 7c       bit 7,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha900_6264_e833_13e9_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h7c;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha954_6264_e833_13e9_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 7D (BIT 7,L)
	$display(" -- cb 7d       bit 7,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'ha900_6264_e833_d99b_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h7d;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'ha998_6264_e833_d99b_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);

	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 7E (BIT 7,(HL))
	$display(" -- cb 7e       bit 7,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h7e; mem[2] = 8'h00; mem[16'h01a3] = 8'hd7;
	#(2* `CLKPERIOD * 12+`FIN)
	ASSERT(192'h2690_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
	if (mem[16'h01a3] != 8'hd7) $display("* FAIL *: [MEMWR] expected=d7, actual=%2h",mem[16'h01a3]);

	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 7F (BIT 7,A)
	$display(" -- cb 7f       bit 7,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_6264_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h7f;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a7c_6264_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 80 (RES 0,B)
	$display(" -- cb 80       res 0,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h80;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 81 (RES 0,C)
	$display(" -- cb 81       res 0,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_947e_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h81;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_947e_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 82 (RES 0,D)
	$display(" -- cb 82       res 0,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h82;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 83 (RES 0,E)
	$display(" -- cb 83       res 0,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_ccf6_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h83;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_ccf6_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 84 (RES 0,H)
	$display(" -- cb 84       res 0,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h84;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6ce0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 85 (RES 0,L)
	$display(" -- cb 85       res 0,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h85;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 86 (RES 0,(HL))
	$display(" -- cb 86       res 0,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h86; mem[2] = 8'h00; mem[16'h01a3] = 8'hd7;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
	if (mem[16'h01a3] != 8'hd6) $display("* FAIL *: [MEMWR] expected=d6, actual=%2h",mem[16'h01a3]);

	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 87 (RES 0,A)
	$display(" -- cb 87       res 0,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h87;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 88 (RES 1,B)
	$display(" -- cb 88       res 1,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h88;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 89 (RES 1,C)
	$display(" -- cb 89       res 1,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_947e_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h89;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_947c_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 8A (RES 1,D)
	$display(" -- cb 8a       res 1,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h8a;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 8B (RES 1,E)
	$display(" -- cb 8b       res 1,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_ccf6_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h8b;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_ccf4_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 8C (RES 1,H)
	$display(" -- cb 8c       res 1,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h8c;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 8D (RES 1,L)
	$display(" -- cb 8d       res 1,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h8d;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 8E (RES 1,(HL))
	$display(" -- cb 8e       res 1,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h8e; mem[2] = 8'h00; mem[16'h01a3] = 8'hd7;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
	if (mem[16'h01a3] != 8'hd5) $display("* FAIL *: [MEMWR] expected=d5, actual=%2h",mem[16'h01a3]);

	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 8F (RES 1,A)
	$display(" -- cb 8F       res 1,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h8f;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6800_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 90 (RES 2,B)
	$display(" -- cb 90       res 2,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h90;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 91 (RES 2,C)
	$display(" -- cb 91       res 2,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_947e_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h91;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_947a_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 92 (RES 2,D)
	$display(" -- cb 92       res 2,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h92;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 93 (RES 2,E)
	$display(" -- cb 93       res 2,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_ccf6_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h93;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_ccf2_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 94 (RES 2,H)
	$display(" -- cb 94       res 2,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h94;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_69e0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 95 (RES 2,L)
	$display(" -- cb 95       res 2,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h95;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 96 (RES 2,(HL))
	$display(" -- cb 96       res 2,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h96; mem[2] = 8'h00; mem[16'h01a3] = 8'hd7;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
	if (mem[16'h01a3] != 8'hd3) $display("* FAIL *: [MEMWR] expected=d3, actual=%2h",mem[16'h01a3]);

	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 97 (RES 2,A)
	$display(" -- cb 97       res 2,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h97;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 98 (RES 3,B)
	$display(" -- cb 98       res 3,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h98;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 99 (RES 3,C)
	$display(" -- cb 99       res 3,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_947e_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h99;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_9476_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 9A (RES 3,D)
	$display(" -- cb 9a       res 3,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h9a;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e033_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 9B (RES 3,E)
	$display(" -- cb 9b       res 3,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_ccf6_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h9b;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_ccf6_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 9C (RES 3,H)
	$display(" -- cb 9c       res 3,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h9c;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_65e0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 9D (RES 3,L)
	$display(" -- cb 9d       res 3,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h9d;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 9E (RES 3,(HL))
	$display(" -- cb 9e       res 3,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h9e; mem[2] = 8'h00; mem[16'h01a3] = 8'hd7;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
	if (mem[16'h01a3] != 8'hd7) $display("* FAIL *: [MEMWR] expected=d7, actual=%2h",mem[16'h01a3]);

	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB 9F (RES 3,A)
	$display(" -- cb 9F       res 3,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'h9f;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6200_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB A0 (RES 4,B)
	$display(" -- cb a0       res 4,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'ha0;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_602f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB A1 (RES 4,C)
	$display(" -- cb a1       res 4,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_947e_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'ha1;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_946e_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB A2 (RES 4,D)
	$display(" -- cb a2       res 4,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'ha2;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB A3 (RES 4,E)
	$display(" -- cb a3       res 4,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_ccf6_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'ha3;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_cce6_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB A4 (RES 4,H)
	$display(" -- cb a4       res 4,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'ha4;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB A5 (RES 4,L)
	$display(" -- cb a5       res 4,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'ha5;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB A6 (RES 4,(HL))
	$display(" -- cb a6       res 4,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'ha6; mem[2] = 8'h00; mem[16'h01a3] = 8'hd7;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
	if (mem[16'h01a3] != 8'hc7) $display("* FAIL *: [MEMWR] expected=c7, actual=%2h",mem[16'h01a3]);

	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB A7 (RES 4,A)
	$display(" -- cb a7       res 4,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'ha7;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB A8 (RES 4,B)
	$display(" -- cb a8       res 5,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'ha8;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_502f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB A9 (RES 5,C)
	$display(" -- cb a9       res 5,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_947e_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'ha9;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_945e_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB AA (RES 5,D)
	$display(" -- cb aa       res 5,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'haa;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_c833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB AB (RES 5,E)
	$display(" -- cb ab       res 5,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_ccf6_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hab;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_ccd6_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB AC (RES 5,H)
	$display(" -- cb ac       res 5,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hac;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_4de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB AD (RES 5,L)
	$display(" -- cb ad       res 5,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'had;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6dc0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB AE (RES 5,(HL))
	$display(" -- cb ae       res 5,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hae; mem[2] = 8'h00; mem[16'h01a3] = 8'hd7;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
	if (mem[16'h01a3] != 8'hd7) $display("* FAIL *: [MEMWR] expected=d7, actual=%2h",mem[16'h01a3]);

	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB AF (RES 5,A)
	$display(" -- cb aF       res 5,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'haf;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h4a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB B0 (RES 6,B)
	$display(" -- cb b0       res 6,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hb0;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_302f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB B1 (RES 6,C)
	$display(" -- cb b1       res 6,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_947e_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hb1;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_943e_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB B2 (RES 6,D)
	$display(" -- cb b2       res 6,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hb2;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_a833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB B3 (RES 6,E)
	$display(" -- cb b3       res 6,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_ccf6_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hb3;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_ccb6_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB B4 (RES 6,H)
	$display(" -- cb b4       res 6,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hb4;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_2de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB B5 (RES 6,L)
	$display(" -- cb b5       res 6,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hb5;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6da0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB B6 (RES 6,(HL))
	$display(" -- cb b6       res 6,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hb6; mem[2] = 8'h00; mem[16'h01a3] = 8'hd7;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
	if (mem[16'h01a3] != 8'h97) $display("* FAIL *: [MEMWR] expected=97, actual=%2h",mem[16'h01a3]);

	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB B7 (RES 6,A)
	$display(" -- cb b7       res 6,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hb7;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h2a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB B8 (RES 6,B)
	$display(" -- cb b8       res 7,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hb8;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB B9 (RES 7,C)
	$display(" -- cb b9       res 7,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_947e_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hb9;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_947e_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB BA (RES 7,D)
	$display(" -- cb ba       res 7,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hba;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_6833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB BB (RES 7,E)
	$display(" -- cb bb       res 7,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_ccf6_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hbb;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_cc76_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB BC (RES 7,H)
	$display(" -- cb bc       res 7,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hbc;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB BD (RES 7,L)
	$display(" -- cb bd       res 7,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hbd;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6d60_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB BE (RES 7,(HL))
	$display(" -- cb be       res 7,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hbe; mem[2] = 8'h00; mem[16'h01a3] = 8'hd7;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
	if (mem[16'h01a3] != 8'h57) $display("* FAIL *: [MEMWR] expected=57, actual=%2h",mem[16'h01a3]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB BF (RES 7,A)
	$display(" -- cb bF       res 7,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hbf;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB C0 (SET 0,B)
	$display(" -- cb c0       set 0,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hc0;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_712f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB C1 (SET 0,C)
	$display(" -- cb c1       set 0,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hc1;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB C2 (SET 0,D)
	$display(" -- cb c2       set 0,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hc2;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e933_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB C3 (SET 0,E)
	$display(" -- cb c3       set 0,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hc3;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB C4 (SET 0,H)
	$display(" -- cb c4       set 0,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hc4;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB C5 (SET 0,L)
	$display(" -- cb c5       set 0,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hc5;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de1_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB C6 (SET 0,(HL))
	$display(" -- cb c6       set 0,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hc6; mem[2] = 8'h00; mem[16'h01a3] = 8'hd7;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
	if (mem[16'h01a3] != 8'hd7) $display("* FAIL *: [MEMWR] expected=d7, actual=%2h",mem[16'h01a3]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB C7 (SET 0,A)
	$display(" -- cb c7       set 0,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hc7;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6b00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB C8 (SET 1,B)
	$display(" -- cb c8       set 1,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hc8;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_722f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB C9 (SET 1,C)
	$display(" -- cb c9       set 1,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hc9;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB CA (SET 1,D)
	$display(" -- cb ca       set 1,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hca;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_ea33_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB CB (SET 1,E)
	$display(" -- cb cb       set 1,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hcb;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB CC (SET 1,H)
	$display(" -- cb cc       set 1,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hcc;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6fe0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB CD (SET 1,L)
	$display(" -- cb cd       set 1,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hcd;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de2_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB CE (SET 1,(HL))
	$display(" -- cb ce       set 1,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hce; mem[2] = 8'h00; mem[16'h01a3] = 8'hd7;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
	if (mem[16'h01a3] != 8'hd7) $display("* FAIL *: [MEMWR] expected=d7, actual=%2h",mem[16'h01a3]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB CF (SET 1,A)
	$display(" -- cb cf       set 1,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hcf;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB D0 (SET 2,B)
	$display(" -- cb d0       set 2,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hd0;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_742f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB D1 (SET 2,C)
	$display(" -- cb d1       set 2,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hd1;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB D2 (SET 2,D)
	$display(" -- cb d2       set 2,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hd2;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_ec33_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB D3 (SET 2,E)
	$display(" -- cb d3       set 2,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hd3;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e837_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB D4 (SET 2,H)
	$display(" -- cb d4       set 2,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hd4;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB D5 (SET 2,L)
	$display(" -- cb d5       set 2,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hd5;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de4_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB D6 (SET 2,(HL))
	$display(" -- cb d6       set 2,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hd6; mem[2] = 8'h00; mem[16'h01a3] = 8'hd7;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
	if (mem[16'h01a3] != 8'hd7) $display("* FAIL *: [MEMWR] expected=d7, actual=%2h",mem[16'h01a3]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB D7 (SET 2,A)
	$display(" -- cb d7       set 2,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hd7;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6e00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB D8 (SET 3,B)
	$display(" -- cb d8       set 3,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hd8;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_782f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB D9 (SET 3,C)
	$display(" -- cb d9       set 3,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hd9;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB DA (SET 3,D)
	$display(" -- cb da       set 3,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hda;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB DB (SET 3,E)
	$display(" -- cb db       set 3,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hdb;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e83b_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB DC (SET 3,H)
	$display(" -- cb dc       set 3,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hdc;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB DD (SET 3,L)
	$display(" -- cb dd       set 3,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hdd;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de8_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB DE (SET 3,(HL))
	$display(" -- cb de       set 3,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hde; mem[2] = 8'h00; mem[16'h01a3] = 8'hd7;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
	if (mem[16'h01a3] != 8'hdf) $display("* FAIL *: [MEMWR] expected=df, actual=%2h",mem[16'h01a3]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB DF (SET 3,A)
	$display(" -- cb df       set 3,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hdf;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB E0 (SET 4,B)
	$display(" -- cb e0       set 4,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'he0;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB E1 (SET 4,C)
	$display(" -- cb e1       set 4,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'he1;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_703f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB E2 (SET 4,D)
	$display(" -- cb e2       set 4,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'he2;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_f833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB E3 (SET 4,E)
	$display(" -- cb e3       set 4,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'he3;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB E4 (SET 4,H)
	$display(" -- cb e4       set 4,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'he4;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_7de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB E5 (SET 4,L)
	$display(" -- cb e5       set 4,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'he5;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6df0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB E6 (SET 4,(HL))
	$display(" -- cb e6       set 4,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'he6; mem[2] = 8'h00; mem[16'h01a3] = 8'hd7;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
	if (mem[16'h01a3] != 8'hd7) $display("* FAIL *: [MEMWR] expected=d7, actual=%2h",mem[16'h01a3]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB E7 (SET 4,A)
	$display(" -- cb e7       set 4,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'he7;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h7a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB E8 (SET 5,B)
	$display(" -- cb e8       set 5,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'he8;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB E9 (SET 5,C)
	$display(" -- cb e9       set 5,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'he9;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB EA (SET 5,D)
	$display(" -- cb ea       set 5,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hea;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB EB (SET 5,E)
	$display(" -- cb eb       set 5,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'heb;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB EC (SET 5,H)
	$display(" -- cb ec       set 5,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hec;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB ED (SET 5,L)
	$display(" -- cb ed       set 5,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hed;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB EE (SET 5,(HL))
	$display(" -- cb ee       set 5,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hee; mem[2] = 8'h00; mem[16'h01a3] = 8'hd7;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
	if (mem[16'h01a3] != 8'hf7) $display("* FAIL *: [MEMWR] expected=f7, actual=%2h",mem[16'h01a3]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB EF (SET 5,A)
	$display(" -- cb ef       set 5,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hef;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB F0 (SET 6,B)
	$display(" -- cb f0       set 6,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hf0;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB F1 (SET 6,C)
	$display(" -- cb f1       set 6,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hf1;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_706f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB F2 (SET 6,D)
	$display(" -- cb f2       set 6,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hf2;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB F3 (SET 6,E)
	$display(" -- cb f3       set 6,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hf3;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e873_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB F4 (SET 6,H)
	$display(" -- cb f4       set 6,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hf4;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB F5 (SET 6,L)
	$display(" -- cb f5       set 6,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hf5;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB F6 (SET 6,(HL))
	$display(" -- cb f6       set 6,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hf6; mem[2] = 8'h00; mem[16'h01a3] = 8'hd7;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
	if (mem[16'h01a3] != 8'hd7) $display("* FAIL *: [MEMWR] expected=d7, actual=%2h",mem[16'h01a3]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB F7 (SET 6,A)
	$display(" -- cb f7       set 6,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hf7;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB F8 (SET 7,B)
	$display(" -- cb f8       set 7,b");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hf8;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_f02f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB F9 (SET 7,C)
	$display(" -- cb f9       set 7,c");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hf9;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_70af_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB FA (SET 7,D)
	$display(" -- cb fa       set 7,d");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hfa;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB FB (SET 7,E)
	$display(" -- cb fb       set 7,e");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hfb;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e8b3_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB FC (SET 7,H)
	$display(" -- cb fc       set 7,h");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hfc;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_ede0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB FD (SET 7,L)
	$display(" -- cb fd       set 7,l");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hfd;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB FE (SET 7,(HL))
	$display(" -- cb fe       set 7,(hl)");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hfe; mem[2] = 8'h00; mem[16'h01a3] = 8'hd7;
	#(2* `CLKPERIOD * 15+`FIN)
	ASSERT(192'h2600_9207_459a_01a3_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);
	if (mem[16'h01a3] != 8'hd7) $display("* FAIL *: [MEMWR] expected=d7, actual=%2h",mem[16'h01a3]);


	i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    // --------------- TEST --------------------------------
	// FUSE CB FF (SET 7,A)
	$display(" -- cb ff       set 7,a");
	// -----------------------------------------------------
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC
	SETUP(192'h6a00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b00);
	// memory data
	mem[0] = 8'hcb;  mem[1] = 8'hff;
	#(2* `CLKPERIOD * 8+`FIN)
	ASSERT(192'hea00_702f_e833_6de0_0000_0000_0000_0000_0000_0000_0000_0002, 8'h00, 8'h02, 2'b00);

`endif

	$finish;
end

	 always #(`CLKPERIOD) i_clk = ~i_clk;


endmodule