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
    output common::instr_field field,
    // other
    // regfile
    input logic [31:0] regfile[0:31],
    input logic [31:0] pc,
    output logic [31:0] pc_plus_4,
    output logic [31:0] pc_branch,
    output logic is_jump_instr,
    input logic [31:0] csr_data,
    // error
    output logic illegal_instruction

);
  // instruction fields
  assign field.opcode = instruction[6:0];
  assign field.rd = instruction[11:7];
  assign field.rs1 = instruction[19:15];
  assign field.rs2 = instruction[24:20];
  assign field.shamt = instruction[24:20];
  assign field.funct3 = instruction[14:12];
  assign field.funct7 = instruction[31:25];
  assign field.imm_i = instruction[31:20];
  assign field.imm_s = {instruction[31:25], instruction[11:7]};
  assign field.imm_b = {
    instruction[31], instruction[7], instruction[30:25], instruction[11:8], 1'b0
  };
  assign field.imm_u = {instruction[31:12], 12'h0};
  assign field.imm_j = {
    instruction[31], instruction[19:12], instruction[20], instruction[30:21], 1'b0
  };

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
      ADD, ADDI, AUIPC, LB, LBU, LH, LHU, LW, LUI, SW, SH, SB, JAL, JALR, CSRRW, CSRRWI:
      _alu_ops = common::ADD;
      SUB: _alu_ops = common::SUB;
      XOR, XORI: _alu_ops = common::XOR;
      OR, ORI, CSRRS, CSRRSI: _alu_ops = common::OR;
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
      CSRRC, CSRRCI: _access_type = common::BIT_C;
      default: _alu_ops = common::ILL;
    endcase
    illegal_instruction = _alu_ops == common::ILL;
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

    // operand fetch
    case (field.opcode)
      // R-Type
      7'b0110011: begin
        op1 = regfile[field.rs1];
        op2 = regfile[field.rs2];
      end
      // I-Type
      7'b0010011, 7'b0000011: begin
        op1 = regfile[field.rs1];
        op2 = 32'(signed'(field.imm_i));
      end
      // S-Type
      7'b0100011: begin
        op1 = regfile[field.rs1];
        op2 = 32'(signed'(field.imm_s));
      end
      // B-Type
      7'b1100011: begin
        op1 = regfile[field.rs1];
        op2 = regfile[field.rs2];
      end
      // U-Type(lui)
      7'b0110111: begin
        op1 = field.imm_u;
        op2 = 32'h00000000;
      end
      // U-Type(auipc)
      7'b0010111: begin
        op1 = field.imm_u;
        op2 = pc;
      end
      // J-Type, jalr
      7'b1101111, 7'b1100111: begin
        op1 = 32'h1;
        op2 = 32'h0;
      end
      // Zicsr
      7'b1110011: begin
        op1 = csr_data;
        case (field.funct3)
          // csrrw, csrrwi
          3'b001, 3'b101: op2 = 32'h0;
          // csrrsi, csrrci
          3'b110, 3'b111: op2 = 32'(unsigned'(field.imm_i));
          // csrrc, csrrs
          default: op2 = regfile[field.rs1];
        endcase
      end
      // other
      default: begin
        op1 = 32'h0;
        op2 = 32'h0;
      end
    endcase
    // calc jump addr
    pc_plus_4 = pc + 32'h4;
    case (field.opcode)
      7'b1100011: pc_branch = pc + 32'(signed'(field.imm_b));  // branch
      7'b1100111: pc_branch = regfile[field.rs1] + 32'(signed'(field.imm_i));  // jal
      7'b1101111: pc_branch = pc + 32'(signed'(field.imm_j));  // jalr
      default: pc_branch = 32'h0;
    endcase
    case (field.opcode)
      7'b1100011, 7'b1100111, 7'b1101111: is_jump_instr = 1'b1;
      default: is_jump_instr = 1'b0;
    endcase
    $display("op1 %h:", op1);
    $display("op2 %h:", op2);
  end
endmodule
