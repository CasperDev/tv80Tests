`timescale 1ns/1ns
`define CLKPERIOD 5
`define FIN 20

module tb_f3;

    reg i_clk = 0;          // Signals driven from within a process (an initial or always block) must be type reg
    reg i_reset_btn =1;

    string vcd_path;

	initial begin
		if (!$value$plusargs("vcd=%s", vcd_path))
			vcd_path = "default.vcd"; // domyślna nazwa, gdyby nie podano parametru
		$dumpfile(vcd_path);
		$dumpvars(0,tb_f3);
	end

	always #`CLKPERIOD i_clk = ~i_clk;

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
	input HaltFF;
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
	if (cpu.core.IntE_FF1 != IFF[0]) begin SETFAIL(); $display("- FAIL: [IFF1] expected=%1b actual=%1b",IFF[0],cpu.core.IntE_FF1); end;
	if (cpu.core.IntE_FF2 != IFF[1]) begin SETFAIL(); $display("- FAIL: [IFF2] expected=%1b, actual=%1b",IFF[1],cpu.core.IntE_FF2); end;
	if (cpu.core.Halt_FF != HaltFF) begin SETFAIL(); $display("- FAIL: [HALT] expected=%1b, actual=%1b",HaltFF,cpu.core.Halt_FF); end;
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
	input HaltFF;
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
		cpu.core.Halt_FF = HaltFF;
	end
endtask



initial begin
	TESTCASE("Test - f3");
    i_reset_btn = 1; #30; i_reset_btn = 0; #5;
    SETUP(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000, 8'h00, 8'h00, 2'b11, 1'b0);
    SETMEM(16'h0000, 8'hf3);
    #(2* `CLKPERIOD * 4 + `FIN)
	
    ASSERT(192'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001, 8'h00, 8'h01, 2'b00, 1'b0);
    $finish;
end
endmodule
