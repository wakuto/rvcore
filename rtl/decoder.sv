`default_nettype none
`include "./riscv_instr.sv"
`include "./common.sv"

module decoder(
  input logic clock,
  input logic reset,
// if/id
  input logic [31:0] instruction,
// id/ex
// output _alu_ops
  output logic [3:0] alu_ops,
// output instruction type
  //output logic [2:0] inst_type,
// output mem_access_type
// output wb_type
// output op1, op2
  output logic [31:0] op1,
  output logic [31:0] op2,
// other
// regfile
  input logic [31:0] regfile [0:31],
  input logic [31:0] pc
  
);
  // instruction fields
  logic [6:0] opcode;
  logic [4:0] rd, rs1, rs2, shamt;
  logic [2:0] funct3;
  logic [6:0] funct7;
  logic [11:0] imm_i;
  logic [11:0] imm_s;
  logic [12:0] imm_b;
  logic [31:0] imm_u;
  logic [20:0] imm_j;
  // decode
  assign opcode = instruction[6:0];
  assign rd = instruction[11:7];
  assign rs1 = instruction[19:15];
  assign rs2 = instruction[24:20];
  assign shamt = instruction[24:20];
  assign funct3 = instruction[14:12];
  assign funct7 = instruction[31:25];
  assign imm_i = instruction[31:20];
  assign imm_s = {instruction[31:25], instruction[11:7]};
  assign imm_b = {instruction[31], instruction[7], instruction[30:25], instruction[11:8], 1'b0};
  assign imm_u = {instruction[31:12], 12'h0};
  assign imm_j = {instruction[31], instruction[19:12], instruction[20], instruction[30:21], 1'b0};

  common::alu_cmd _alu_ops;
  assign alu_ops = _alu_ops;
  common::instr_type instruction_type;
  //assign inst_type = instruction_type;
  common::mem_access_type _access_type;
  //assign access_type = _access_type;

  always_comb begin
    // chose _alu_ops
    casez(instruction)
      riscv_instr::ADD, riscv_instr::ADDI, riscv_instr::AUIPC,
        riscv_instr::LB, riscv_instr::LBU, riscv_instr::LH, 
        riscv_instr::LHU, riscv_instr::LW: _alu_ops = common::ADD;
      riscv_instr::SUB: _alu_ops = common::SUB;
      riscv_instr::XOR, riscv_instr::XORI: _alu_ops = common::XOR;
      riscv_instr::OR, riscv_instr::ORI: _alu_ops = common::OR;
      riscv_instr::AND, riscv_instr::ANDI: _alu_ops = common::AND;
      riscv_instr::SRL, riscv_instr::SRLI: _alu_ops = common::SRL;
      riscv_instr::SRA, riscv_instr::SRAI: _alu_ops = common::SRA;
      riscv_instr::SLL, riscv_instr::SLLI: _alu_ops = common::SLL;
      riscv_instr::BEQ: _alu_ops = common::EQ;
      default: _alu_ops = common::ADD;
    endcase

    // chose op1, op2
    case(opcode)
      // R-Type
      7'b0110011: begin
        op1 = regfile[rs1];
        op2 = regfile[rs2];
      end
      // I-Type
      7'b0010011, 7'b0000011: begin
        op1 = regfile[rs1];
        op2 = 32'(signed'(imm_i));
      end
      // S-Type
      7'b0100011: begin
        op1 = regfile[rs1];
        op2 = 32'(signed'(imm_s));
      end
      // B-Type
      7'b1100011: begin
        op1 = regfile[rs1];
        op2 = regfile[rs2];
      end
      // U-Type(lui)
      7'b0110111: begin
        op1 = imm_u;
        op2 = 32'h00000000;
      end
      // U-Type(auipc)
      7'b0010111: begin
        op1 = imm_u;
        op2 = pc;
      end
      // J-Type
      7'b1101111: begin
        op1 = 32'(signed'(imm_j));
        op2 = pc;
      end
      // other
      default: begin
        op1 = 32'h0;
        op2 = 32'h0;
      end
    endcase
  end
endmodule
