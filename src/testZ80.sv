module testZ80 (
    // Clock & Reset
    input wire clk, reset
);

	
    reg [7:0] mem [0:65535];
	reg [7:0] io[0:255];
    wire [15:0] A;
    reg [7:0]  di;
	wire [7:0] dout;
    wire mreq_n, iorq_n, rd_n, wr_n;

    tv80s cpu (
        .reset (reset), .clk (clk), .cen (1'b1),
        .A (A), .di (di), .dout (dout),
        .mreq_n (mreq_n), .iorq_n (iorq_n), .rd_n (rd_n), .wr_n (wr_n),

        .wait_n (1'b1), .int_n (1'b1), .nmi_n (1'b1), .busrq_n (1'b1),
        .m1_n (), .rfsh_n (), .halt_n (), .busak_n ()
    );

	always@(posedge clk) begin
		if(!mreq_n && !rd_n) begin
			di <= mem[A];
		end
		if(!mreq_n && !wr_n) begin
			mem[A] <= dout;
		end
		if(!iorq_n && !rd_n) begin
			di <= io[A[7:0]];
		end
		if(!iorq_n && !wr_n) begin
			io[A[7:0]] <= dout;
		end
	end


endmodule