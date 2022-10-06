`default_nettype none
`include "./riscv_instr.sv"
`include "./common.sv"

module decoder (
    // if/id
    input logic [31:0] instruction,
    // id/ex
    // output _alu_ops
    output logic [3:0] alu_ops,
    // output instruction type
    //output logic [2:0] inst_type,
    output [3:0] access_type,
    // output wb_type
    // output op1, op2
    output logic [31:0] op1,
    output logic [31:0] op2,
    // other
    // regfile
    input logic [31:0] regfile[0:31],
    input logic [31:0] pc

);
  // instruction fields
  logic [6:0] opcode;
  logic [4:0] rd, rs1, rs2, shamt;
  logic [ 2:0] funct3;
  logic [ 6:0] funct7;
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
  assign access_type = _access_type;

  always_comb begin
    // chose _alu_ops
    import riscv_instr::*;
    casez (instruction)
      ADD, ADDI, AUIPC, LB, LBU, LH, LHU, LW, LUI, SW, SH, SB: _alu_ops = common::ADD;
      SUB: _alu_ops = common::SUB;
      XOR, XORI: _alu_ops = common::XOR;
      OR, ORI: _alu_ops = common::OR;
      AND, ANDI: _alu_ops = common::AND;
      SRL, SRLI: _alu_ops = common::SRL;
      SRA, SRAI: _alu_ops = common::SRA;
      SLL, SLLI: _alu_ops = common::SLL;
      BEQ: _alu_ops = common::EQ;
      BNE: _alu_ops = common::NE;
      BLT: _alu_ops = common::LT;
      BGE: _alu_ops = common::GE;
      BLTU: _alu_ops = common::LTU;
      BGEU: _alu_ops = common::GEU;
      default: _alu_ops = common::ADD;
    endcase
    // memory access type
    casez (instruction)
      LB: _access_type = common::LB;
      LH: _access_type = common::LH;
      LW: _access_type = common::LW;
      LBU: _access_type = common::LBU;
      LHU: _access_type = common::LHU;
      SB: _access_type = common::SB;
      SH: _access_type = common::SH;
      SW: _access_type = common::SW;
      default: _access_type = common::NONE;
    endcase

    // chose op1, op2
    case (opcode)
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
