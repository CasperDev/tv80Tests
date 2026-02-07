//
// TV80 8-Bit Microprocessor Core
// Based on the VHDL T80 core by Daniel Wallner (jesus@opencores.org)
//
// Copyright (c) 2004 Guy Hutchison (ghutchis@opencores.org)
//
// Permission is hereby granted, free of charge, to any person obtaining a
// copy of this software and associated documentation files (the "Software"),
// to deal in the Software without restriction, including without limitation
// the rights to use, copy, modify, merge, publish, distribute, sublicense,
// and/or sell copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included
// in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
// IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
// CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
// TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
// SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

module tv80a (/*AUTOARG*/
    // Clock & Reset
    input logic clk, cen, reset,
    // Control Outputs
    output logic m1_n,
    output logic mreq_n, iorq_n, rd_n, wr_n, 
    // Bus exchange
    output logic [15:0] A,
    output logic [7:0] dout,
    input logic [7:0] di,
    // State Info outputs 
    output logic rfsh_n, halt_n, busak_n, 
    // Control Inputs
    input logic wait_n, int_n, nmi_n, busrq_n
  );

    wire rst_n = ~reset;
	initial begin
		mreq_n = 1'b1; iorq_n = 1'b1; rd_n = 1'b1; wr_n = 1'b1; 
	end
  // 0 => Z80
  // wr_n active in T2
  // Std I/O cycle

  logic          intcycle_n;        // 0-INT/NMI Acknowledge Cycle, 1-Standard Cycle
  logic          no_read;           // 0-read enabled, 1-do not execute Read 
  logic          write;             // 0-read, 1-write
  logic          iorq;              // 0-read/write memory (MREQ), 1-read/write I/O (IORQ)
  logic [7:0]    di_reg;            // input data latched durning T2
  logic [6:0]    mcycle;            // current M cycle
  logic [6:0]    tstate;            // current T state within M cycle


    tv80_core core (
        .clk(clk), .cen (cen), .rst_n(rst_n),
        // Control Outputs
        .m1_n (m1_n), .iorq (iorq), .no_read (no_read), .write (write),
        // Bus Exchange
        .A(A), .dinst(di), .di(di_reg), .dout(dout),
        // state info
        .rfsh_n (rfsh_n), .halt_n (halt_n), .busak_n(busak_n),
        // Control inputs
        .wait_n (wait_n), .int_n (int_n), .nmi_n (nmi_n), .busrq_n (busrq_n),
        // Cycle state
        .mc (mcycle), .ts (tstate),
        .intcycle_n (intcycle_n)
     );
    
    always_comb begin
        if (!rst_n) begin
            rd_n   = 1'b1; wr_n   = 1'b1;  iorq_n = 1'b1; mreq_n = 1'b1;
        end else if(cen) begin
            rd_n = 1'b1;         // default
            wr_n = 1'b1;         // default
            iorq_n = 1'b1;       // default
            mreq_n = 1'b1;       // default
            if (mcycle[0]) begin
                // During M1 (T1 and T2), 
                // for Standard Fetch set active RD and MREQ
                // for INT/NMI Acknowledge Cycle set active IORQ (and M1)
                if (tstate[1] || tstate[2]) begin
                    rd_n = ~ intcycle_n;
                    mreq_n = ~ intcycle_n;
                    iorq_n = intcycle_n;
                end
                // During M1 (T3 and T4), refresh state - set active MREQ w/o RD
                if (tstate[3] || tstate[4]) mreq_n = 1'b0;
            end // if (mcycle[0])
            else begin
                // Durning M2,M3,etc (T1 and T2), if Read (not write & not read blocked)
                // Standard Read cycle - set active RD and IORQ or MREQ respectively
                if ((tstate[1] || tstate[2]) && no_read == 1'b0 && write == 1'b0) begin
                    rd_n = 1'b0;
                    iorq_n = ~ iorq;
                    mreq_n = iorq;
                end
                // Durning M2,M3,etc (T1 and T2), if Write 
                // Standard Write cycle - set active WR and IORQ or MREQ respectively
                if ((tstate[1] || tstate[2]) && write == 1'b1) begin
                    wr_n = 1'b0;
                    iorq_n = ~ iorq;
                    mreq_n = iorq;
                end
            end // else: !if(mcycle[0])

        end // else: !if(!rst_n)
    end // always @ (posedge clk or negedge rst_n)

    // Latch data input during T2 if Wait not active (not in a wait state)
    always_ff@(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            di_reg <= 'd0;
        end else if (cen) begin
            if (tstate[2] && wait_n == 1'b1)
                di_reg <= di;
        end
    end

endmodule // t80s

