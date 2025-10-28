// Only for ADD -> AluOp == 0000
module alu_add(
    input logic [7:0] BusA, BusB,
    input logic [7:0] F_in,
    output logic [7:0] F_Out, Q_t
);

    parameter		Flag_C = 0;
    parameter		Flag_N = 1;
    parameter		Flag_P = 2;
    parameter		Flag_X = 3;
    parameter		Flag_H = 4;
    parameter		Flag_Y = 5;
    parameter		Flag_Z = 6;
    parameter		Flag_S = 7;

  
    logic HalfCarry_v, OverFlow_v, Carry_v, Carry7_v;

always@(*) begin
    { HalfCarry_v, Q_t[3:0] } = {1'b0, BusA[3:0]} + {1'b0, BusB[3:0]};
    { Carry7_v, Q_t[6:4] } = {1'b0, BusA[6:4]} + {1'b0, BusB[6:4]} + {3'h0, HalfCarry_v};
    { Carry_v, Q_t[7] } = { 1'b0, BusA[7]} + {1'b0, BusB[7]} + {1'h0, Carry7_v};
    OverFlow_v = Carry_v ^ Carry7_v;
end

always@(*) begin
    F_Out[Flag_C] <= Carry_v;
    F_Out[Flag_N] <= 1'b0;
    F_Out[Flag_H] <= HalfCarry_v;
    F_Out[Flag_P] <= OverFlow_v;
    F_Out[Flag_X] <= Q_t[3];
    F_Out[Flag_Y] <= Q_t[5];
    F_Out[Flag_Z] <= &(~Q_t);
    F_Out[Flag_S] <= Q_t[7];
end

endmodule
