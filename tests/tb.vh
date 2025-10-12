`ifndef COMMON_VH
`define COMMON_VH

`timescale 1ns/1ns
`default_nettype none
`define CLKPERIOD 10
`define FIN 20

module tb();
 
	reg i_clk = 0;          // Signals driven from within a process (an initial or always block) must be type reg
	reg i_reset_btn =1;
 
	always #( `CLKPERIOD / 2 ) i_clk = ~i_clk;  // 100MHz clock
 
	initial begin
		#( `CLKPERIOD * 3 ) i_reset_btn = 0;     // release reset after 2 clock cycles
	end

wire cpu_busak_n;
reg cpu_int_n = 1'b1;
 
//------------- CPU ----------------------
wire [7:0] cpu_di;
wire [7:0] cpu_do;
wire [15:0] cpu_a;

wire cpu_clk = i_clk;
wire cpu_reset = i_reset_btn;
wire cpu_m1_n, cpu_rfsh_n,cpu_mreq_n,cpu_iorq_n,cpu_rd_n, cpu_wr_n, cpu_halt_n;

tv80s cpu (
    .reset(cpu_reset), .clk(cpu_clk), .cen(1'b1),
    .m1_n(cpu_m1_n), .mreq_n(cpu_mreq_n), .iorq_n(cpu_iorq_n), .rd_n(cpu_rd_n), .wr_n(cpu_wr_n), 
    .rfsh_n(cpu_rfsh_n), .halt_n(cpu_halt_n), .busak_n(cpu_busak_n), 
    .A(cpu_a), .di(cpu_di), .dout(cpu_do),
    .wait_n(1'b1), .int_n(cpu_int_n), .nmi_n(1'b1), .busrq_n(1'b1)    // all inactive for now
);

//------------- MEMORY / IO ----------------------
 
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

// IRQ device
wire [7:0] irq_data = 8'he7; // RST 20H / IRQ vector for IM 0 / IM 2

assign cpu_di = cpu_m1_n == 1'b0 && cpu_iorq_n == 1'b0 ? irq_data 
			  : cpu_rd_n == 1'b0 && cpu_iorq_n == 1'b0 ? io_o 
			  : cpu_rd_n == 1'b0 && cpu_mreq_n == 1'b0 ? mem_o
			  : 8'hzz;


reg FAIL = 1'b0;
reg [0:48*8] TESTCASE;

task SETUP;
	// - AF BC DE HL AF' BC' DE' HL' IX IY SP PC I R IFF
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

endmodule

`endif // COMMON_VH