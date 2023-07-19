`default_nettype none
`include "./riscv_instr.sv"
`include "./common.sv"

module decoder (
    // if/id
    input wire logic [31:0] instruction,
    input wire logic        instr_valid,
    // id/ex
    // output _alu_ops
    output logic [3:0] alu_ops,
    // output instruction type
    //output logic [2:0] inst_type,
    output logic [3:0] access_type,
    // output wb_type
    output common::wb_sel_t wb_sel,
    // output op1, op2
    output logic [31:0] op1,
    output logic [31:0] op2,
    output common::instr_field field,
    output logic [11:0] csr_rd,
    // other
    // regfile
    input wire logic [31:0] reg_rs1,
    input wire logic [31:0] reg_rs2,
    //input wire logic [31:0] regfile[0:31],
    input wire logic [31:0] pc,
    output logic [31:0] pc_plus_4,
    output logic [31:0] pc_branch,
    output logic is_jump_instr,
    output common::pc_sel_t pc_sel,
    input wire logic [31:0] csr_data,
    // error
    
    output logic mret_instr,
    
    output logic illegal_instr,
    output logic env_call,
    output logic break_point,
    output logic csr_instr

);
  logic [31:0] instr;
  assign instr = instr_valid ? instruction : common::BUBBLE;
  // instruction fields
  assign field.opcode = instr[6:0];
  assign field.rd = instr[11:7];
  assign field.rs1 = instr[19:15];
  assign field.rs2 = instr[24:20];
  assign field.shamt = instr[24:20];
  assign field.funct3 = instr[14:12];
  assign field.funct7 = instr[31:25];
  assign field.imm_i = instr[31:20];
  assign field.imm_s = {instr[31:25], instr[11:7]};
  assign field.imm_b = {
    instr[31], instr[7], instr[30:25], instr[11:8], 1'b0
  };
  assign field.imm_u = {instr[31:12], 12'h0};
  assign field.imm_j = {
    instr[31], instr[19:12], instr[20], instr[30:21], 1'b0
  };

  common::alu_cmd _alu_ops;
  assign alu_ops = _alu_ops;
  common::instr_type instruction_type;
  //assign inst_type = instruction_type;
  common::mem_access_type _access_type;
  assign access_type = _access_type;

  assign csr_instr = wb_sel == common::ZICSR;

  always_comb begin
    // chose _alu_ops
    import riscv_instr::*;
    casez (instr)
      ADD, ADDI, AUIPC, LB, LBU, LH, LHU, LW, LUI, SW, SH, SB, JAL, JALR, CSRRW, CSRRWI, EBREAK:
      _alu_ops = common::ADD;
      SUB: _alu_ops = common::SUB;
      XOR, XORI, MRET: _alu_ops = common::XOR;
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
      CSRRC, CSRRCI: _alu_ops = common::BIT_C;
      default: _alu_ops = common::ILL;
    endcase

    illegal_instr = instr_valid & _alu_ops == common::ILL;
    casez (instr) 
      ECALL: begin
        env_call = 1'b1;
        break_point = 1'b0;
        mret_instr = 1'b0;
      end
      EBREAK: begin
        env_call = 1'b0;
        break_point = 1'b1;
        mret_instr = 1'b0;
      end
      MRET: begin
        env_call = 1'b0;
        break_point = 1'b0;
        mret_instr = 1'b1;
      end
      default: begin
        env_call = 1'b0;
        break_point = 1'b0;
        mret_instr = 1'b0;
      end
    endcase
    // memory access type
    casez (instr)
      LB: _access_type = common::LB;
      LH: _access_type = common::LH;
      LW: _access_type = common::LW;
      LBU: _access_type = common::LBU;
      LHU: _access_type = common::LHU;
      SB: _access_type = common::SB;
      SH: _access_type = common::SH;
      SW: _access_type = common::SW;
      default: _access_type = common::MEM_NONE;
    endcase

    // operand fetch
    case (field.opcode)
      // R-Type
      7'b0110011: begin
        op1 = reg_rs1;
        op2 = reg_rs2;
      end
      // I-Type
      7'b0010011, 7'b0000011: begin
        op1 = reg_rs1;
        op2 = 32'(signed'(field.imm_i));
      end
      // S-Type
      7'b0100011: begin
        op1 = reg_rs1;
        op2 = 32'(signed'(field.imm_s));
      end
      // B-Type
      7'b1100011: begin
        op1 = reg_rs1;
        op2 = reg_rs2;
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
        casez(instr)
          CSRRW, CSRRWI: begin
            op1 = reg_rs1;
            op2 = 32'h0;
          end
          CSRRSI, CSRRCI: begin
            op1 = csr_data;
            op2 = 32'(unsigned'(field.rs1));  // uimm
          end
          CSRRS, CSRRC: begin
            op1 = csr_data;
            op2 = reg_rs1;
          end
          MRET: begin
            op1 = csr_data;
            op2 = 32'b10001000;
          end
          EBREAK: begin
            op1 = 32'h0;
            op2 = 32'h0;
          end
          default: begin
            op1 = csr_data;
            op2 = reg_rs1;
          end
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
      7'b1100111: pc_branch = reg_rs1 + 32'(signed'(field.imm_i));  // jal
      7'b1101111: pc_branch = pc + 32'(signed'(field.imm_j));  // jalr
      default: pc_branch = 32'h0;
    endcase
    case (field.opcode)
      7'b1100011, 7'b1100111, 7'b1101111: is_jump_instr = 1'b1;
      default: is_jump_instr = 1'b0;
    endcase

    // set wb_sel
    if (field.rd != 5'h0) begin
      case (field.opcode)
        // R-Type, I-Type, lui, auipc
        7'b0110011, 7'b0010011, 7'b0110111, 7'b0010111: wb_sel = common::RI_TYPE_LUI;
        // load instruction
        7'b0000011: wb_sel = common::LOAD;
        // JAL, JALR
        7'b1100111, 7'b1101111: wb_sel = common::JUMP;
        7'b1110011: begin
          casez(instr)
            // zicsr
            CSRRW, CSRRWI, CSRRS, CSRRSI, CSRRC, CSRRCI: wb_sel = common::ZICSR;
            MRET: wb_sel = common::WB_MRET;
            default: wb_sel = common::WB_NONE;
          endcase
        end
        // other
        default: wb_sel = common::WB_NONE;
      endcase
    end
    else begin
      casez(instr)
        MRET: wb_sel = common::WB_MRET;
        default: wb_sel = common::WB_NONE;
      endcase
    end

    // set pc_sel
    casez(instr)
      JAL, JALR, BEQ, BNE, BLT, BGE, BLTU, BGEU: pc_sel = common::PC_BRANCH;
      MRET: pc_sel = common::PC_MRET;
      default: pc_sel = common::PC_NEXT;
    endcase

    // set csr_rd
    casez(instr)
      CSRRW, CSRRWI, CSRRS, CSRRSI, CSRRC, CSRRCI: csr_rd = field.imm_i;
      MRET: csr_rd = 12'h300;
      default: csr_rd = 12'h0;
    endcase
  end
endmodule
`default_nettype wire
