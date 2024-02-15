`default_nettype none
`include "riscv_instr.sv"
`include "common.sv"

module decoder (
    input  wire  [31:0] instruction,
    input  wire         instr_valid,
    output logic [ 4:0] rs1,
    output logic [ 4:0] rs2,
    output logic [ 4:0] rd,

    output logic [ 4:0] alu_cmd,
    output logic [31:0] imm,
    output logic        op2_type,
    output logic [12:0] br_offset
);
  logic [31:0] instr;
  assign instr = instr_valid ? instruction : common::BUBBLE;

  common::alu_cmd_t _alu_ops;
  assign alu_cmd = _alu_ops;
  common::op_type_t _op2_type;
  assign op2_type = _op2_type;

  // assign field.opcode = instr[6:0];
  // assign field.rd = instr[11:7];
  // assign field.rs1 = instr[19:15];
  // assign field.rs2 = instr[24:20];
  // assign field.shamt = instr[24:20];
  // assign field.funct3 = instr[14:12];
  // assign field.funct7 = instr[31:25];
  // assign field.imm_i = instr[31:20];
  // assign field.imm_s = {instr[31:25], instr[11:7]};
  // assign field.imm_b = {
  //   instr[31], instr[7], instr[30:25], instr[11:8], 1'b0
  // };
  // assign field.imm_u = {instr[31:12], 12'h0};
  // assign field.imm_j = {
  //   instr[31], instr[19:12], instr[20], instr[30:21], 1'b0
  // };
  
  logic [6:0] opcode;
  
  always_comb begin
    opcode = instr[6:0];
    case(opcode)
      // LUI (x0 + (imm_u << 12))
      7'b0110111: rs1 = 0;
      default: rs1 = instr[19:15];
    endcase
    rs2 = instr[24:20];

    case(opcode)
      // I-type instr
      // addi, slti, ..., load, lui
      7'b0010011, 7'b0000011, 7'b0110111: _op2_type = common::IMM;
      // R-type instr
      // add, sub, ...
      7'b0110011: _op2_type = common::REG;
      // B-type instr
      // beq, bne, ...
      7'b1100011: _op2_type = common::REG;
      default: _op2_type = common::REG;
    endcase
    
    case(opcode)
      7'b0010011, 7'b0000011: imm = 32'(signed'(instr[31:20]));
      // LUI
      7'b0110111: imm = {instr[31:12], 12'h0};
      default: imm = 32'hdeadbeef;
    endcase
    
    // 分岐命令は rd = 0
    if (opcode == 7'b1100011) begin
      rd  = 0;
      br_offset = {instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
    end else begin
      rd  = instr[11: 7];
      br_offset = 0;
    end
  end

  always_comb begin
    // chose _alu_ops
    import riscv_instr::*;
    casez (instr)
      ADD, ADDI, AUIPC, LB, LBU, LH, LHU, LW, LUI, SW, SH, SB, JAL, JALR, CSRRW, CSRRWI, EBREAK, FENCE, FENCE_I:
      _alu_ops = common::ADD;
      SUB: _alu_ops = common::SUB;
      XOR, XORI, MRET: _alu_ops = common::XOR;
      OR, ORI, CSRRS, CSRRSI: _alu_ops = common::OR;
      AND, ANDI: _alu_ops = common::AND;
      SRL, SRLI: _alu_ops = common::SRL;
      SRA, SRAI: _alu_ops = common::SRA;
      SLL, SLLI: _alu_ops = common::SLL;
      SLT, SLTI: _alu_ops = common::SLT;
      SLTU, SLTIU: _alu_ops = common::SLTU;
      BEQ: _alu_ops = common::EQ;
      BNE: _alu_ops = common::NE;
      BLT: _alu_ops = common::LT;
      BGE: _alu_ops = common::GE;
      BLTU: _alu_ops = common::LTU;
      BGEU: _alu_ops = common::GEU;
      CSRRC, CSRRCI: _alu_ops = common::BIT_C;
      default: _alu_ops = common::ILL;
    endcase
  end
endmodule
`default_nettype wire
