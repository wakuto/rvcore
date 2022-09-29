`default_nettype none
`include "./riscv_instr.sv"
`include "./common.sv"

module execute(
  input logic [31:0] op1,
  input logic [31:0] op2,
  input logic [3:0] alu_ops,
  output logic [31:0] alu_out
);

  always_comb begin
    case(alu_ops)
      common::ADD: alu_out = op1 + op2;
      common::SUB: alu_out = op1 - op2;
      common::XOR: alu_out = op1 ^ op2;
      common::OR:  alu_out = op1 | op2;
      common::AND: alu_out = op1 & op2;
      common::SRL: alu_out = op1 >> op2;
      common::SRA: alu_out = op1 >>> op2;
      common::SLL: alu_out = op1 << op2;
      common::EQ:  alu_out = {31'h0, op1 == op2};
      default: alu_out = 32'h0;
    endcase
  end
endmodule
