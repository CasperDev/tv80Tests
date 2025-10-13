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



module tv80_reg (/*AUTOARG*/
	input wire clk, CEN,
	input wire WEH, WEL,
	input wire[7:0] DIL, DIH,
	input wire [2:0] AddrA, AddrB, AddrC, 
	output wire [7:0] DOAL, DOAH,
	output wire [7:0] DOBL, DOBH,
	output wire [7:0] DOCL, DOCH
  );

  reg [7:0] RegsH [0:7];
  reg [7:0] RegsL [0:7];

  always @(posedge clk)
    begin
      if (CEN)
        begin
          if (WEH) RegsH[AddrA] <= DIH;
          if (WEL) RegsL[AddrA] <= DIL;
        end
    end

  assign DOAH = RegsH[AddrA];
  assign DOAL = RegsL[AddrA];
  assign DOBH = RegsH[AddrB];
  assign DOBL = RegsL[AddrB];
  assign DOCH = RegsH[AddrC];
  assign DOCL = RegsL[AddrC];

  // break out ram bits for waveform debug
// synopsys translate_off
  wire [7:0] B = RegsH[0];
  wire [7:0] C = RegsL[0];
  wire [7:0] D = RegsH[1];
  wire [7:0] E = RegsL[1];
  wire [7:0] H = RegsH[2];
  wire [7:0] L = RegsL[2];

  wire [15:0] IX = { RegsH[3], RegsL[3] };
  wire [15:0] IY = { RegsH[7], RegsL[7] };

  wire [15:0] BC = { RegsH[0], RegsL[0] };
  wire [15:0] DE = { RegsH[1], RegsL[1] };
  wire [15:0] HL = { RegsH[2], RegsL[2] };
  // alteranate register set
  wire [15:0] BCp = { RegsH[4], RegsL[4] };
  wire [15:0] DEp = { RegsH[5], RegsL[5] };
  wire [15:0] HLp = { RegsH[6], RegsL[6] };
//
// synopsys translate_on

endmodule

