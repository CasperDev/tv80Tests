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

module tv80s (/*AUTOARG*/
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

	initial begin
		mreq_n = 1'b1; iorq_n = 1'b1; rd_n = 1'b1; wr_n = 1'b1; 
	end
  // 0 => Z80
  // wr_n active in T2
  // Std I/O cycle

  logic          intcycle_n;
  logic          no_read;        // 0-reqd or write, 1-internal cycle (??) 
  logic          write;          // wr
  logic          iorq;           // when rd or wr: 1-IORQ r/w, 0- MREQ r/w
  logic [7:0]    di_reg;
  logic [6:0]    mcycle;
  logic [6:0]    tstate;


    tv80_core core (
        .clk(clk), .cen (cen), .reset(reset),
        // Control Outputs
        .m1_n (m1_n), .iorq (iorq), .no_read (no_read), .write (write),
        // Bus Exchange
        .A(A), .dinst(di), .di(di_reg), .dout(dout),
        // state info
        .rfsh_n (rfsh_n), .halt_n (halt_n), .busak_n(busak_n),
        // Control inputs
        .wait_n (wait_n), .int_n (int_n), .nmi_n (nmi_n), .busrq_n (busrq_n),
        // Extra State
        .IntE (), .stop (),
        // Cycle state
        .mc (mcycle), .ts (tstate),
        .intcycle_n (intcycle_n)
     );
    
    always_ff@(posedge clk or posedge reset) begin
        if (reset) begin
            rd_n   <= 1'b1; wr_n   <= 1'b1;  iorq_n <= 1'b1; mreq_n <= 1'b1;
            di_reg <= 'd0;
        end else if(cen) begin
            rd_n <= 1'b1;         // default
            wr_n <= 1'b1;         // default
            iorq_n <= 1'b1;       // default
            mreq_n <= 1'b1;       // default
            if (mcycle[0]) begin
                if (tstate[1] || (tstate[2] && wait_n == 1'b0)) begin
                    rd_n <= ~ intcycle_n;
                    mreq_n <= ~ intcycle_n;
                    iorq_n <= intcycle_n;
                end
                if (tstate[3]) mreq_n <= 1'b0;
            end // if (mcycle[0])
            else begin
                if ((tstate[1] || (tstate[2] && wait_n == 1'b0)) && no_read == 1'b0 && write == 1'b0) begin
                    rd_n <= 1'b0;
                    iorq_n <= ~ iorq;
                    mreq_n <= iorq;
                end
                if ((tstate[1] || (tstate[2] && wait_n == 1'b0)) && write == 1'b1) begin
                    wr_n <= 1'b0;
                    iorq_n <= ~ iorq;
                    mreq_n <= iorq;
                end

            end // else: !if(mcycle[0])

            if (tstate[2] && wait_n == 1'b1)
                di_reg <= di;
        end // else: !if(reset)
    end // always @ (posedge clk or posedge reset)

endmodule // t80s

