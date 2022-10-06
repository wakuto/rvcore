`default_nettype none
`include "./riscv_instr.sv"
`include "./common.sv"

module execute (
    input  logic [31:0] op1,
    input  logic [31:0] op2,
    input  logic [ 3:0] alu_ops,
    output logic [31:0] alu_out
);

  always_comb begin
    import common::*;
    case (alu_ops)
      ADD: alu_out = op1 + op2;
      SUB: alu_out = op1 - op2;
      XOR: alu_out = op1 ^ op2;
      OR: alu_out = op1 | op2;
      AND: alu_out = op1 & op2;
      SRL: alu_out = op1 >> op2;
      SRA: alu_out = op1 >>> op2;
      SLL: alu_out = op1 << op2;
      EQ: alu_out = {31'h0, op1 == op2};
      NE: alu_out = {31'h0, op1 != op2};
      LT: alu_out = {31'h0, signed'(op1) < signed'(op2)};
      GE: alu_out = {31'h0, signed'(op1) >= signed'(op2)};
      LTU: alu_out = {31'h0, op1 < op2};
      GEU: alu_out = {31'h0, op1 >= op2};
      default: alu_out = 32'h0;
    endcase
  end
endmodule
