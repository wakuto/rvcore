`default_nettype none
`include "./riscv_instr.sv"

module cpu(
  input  logic clock,
  input  logic reset,
  // instruction data
  output logic [31:0] pc,
  input  logic [31:0] instruction,
  // memory data
  output logic [31:0] address,
  input  logic [31:0] read_data,
  input  logic read_enable,
  output logic [31:0] write_data,
  output logic write_enable,
  output logic debug_ebreak,
  output logic [31:0] debug_reg [0:31]
);
  // registers
  logic [31:0] reg_pc;
  logic [31:0] registers [0:31];

  // data_output
  logic [31:0] data_out;
  logic data_out_enable;
  assign write_data = data_out;
  assign write_enable = data_out_enable;

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

  logic [31:0] op1;
  logic [31:0] op2;
  logic [31:0] alu_out;

  // decoded data
  enum logic [3:0] {ADD, SUB, XOR, OR, AND, SRL, SRA, SLL, EQ, NE, LT, GE, LTU, GEU} operation_type;
  enum logic [3:0] {LB, LH, LW, LBU, LHU, SB, SH, SW, NONE} access_type;
  // enum logic [] {

  // <= だとwarning出るけどなんで？
  initial begin
    reg_pc = 32'h0;
    address = 32'h0;
    data_out = 32'h0;
    data_out_enable = 1'b0;
    for(int i = 0; i < 32; i++)
      registers[i] = 32'h0;
  end


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

  // 演算の種類の決定
  // 演算に使うデータの取得
  // メモリアクセスの有無
  // ライトバックの有無
  always_comb begin
    // debug output
    debug_ebreak = instruction == riscv_instr::EBREAK;
    for(int i = 0; i < 32; i++)
      debug_reg[i] = registers[i];
    pc = reg_pc;

    // chose operation_type
    casez(instruction)
      riscv_instr::ADD, riscv_instr::ADDI, riscv_instr::AUIPC,
        riscv_instr::LB, riscv_instr::LBU, riscv_instr::LH, 
        riscv_instr::LHU, riscv_instr::LW: operation_type = ADD;
      riscv_instr::SUB: operation_type = SUB;
      riscv_instr::XOR, riscv_instr::XORI: operation_type = XOR;
      riscv_instr::OR, riscv_instr::ORI: operation_type = OR;
      riscv_instr::AND, riscv_instr::ANDI: operation_type = AND;
      riscv_instr::SRL, riscv_instr::SRLI: operation_type = SRL;
      riscv_instr::SRA, riscv_instr::SRAI: operation_type = SRA;
      riscv_instr::SLL, riscv_instr::SLLI: operation_type = SLL;
      riscv_instr::BEQ: operation_type = EQ;
      default: operation_type = ADD;
    endcase

    // chose op1, op2
    case(opcode)
      // R-Type
      7'b0110011: begin
        op1 = registers[rs1];
        op2 = registers[rs2];
      end
      // I-Type
      7'b0010011: begin
        op1 = registers[rs1];
        op2 = 32'(signed'(imm_i));
      end
      // other
      default: begin
        op1 = 32'h0;
        op2 = 32'h0;
      end
    endcase

    case(operation_type)
      ADD: alu_out = op1 + op2;
      SUB: alu_out = op1 - op2;
      XOR: alu_out = op1 ^ op2;
      OR:  alu_out = op1 | op2;
      AND: alu_out = op1 & op2;
      SRL: alu_out = op1 >> op2;
      SRA: alu_out = op1 >>> op2;
      SLL: alu_out = op1 << op2;
      EQ:  alu_out = {31'h0, op1 == op2};
      default: alu_out = 32'h0;
    endcase
  end

  always_ff @(posedge clock or posedge reset) begin
    if(reset) begin
      reg_pc <= 32'h0;
      address <= 32'h0;
      write_data <= 32'h0;
      write_enable <= 1'b0;
    end
    else begin
      reg_pc <= reg_pc + 32'h4;
      // write back
      case(opcode)
        // R-Type, I-Type(not load instruction)
        7'b0110011, 7'b0010011: begin
          registers[rd] <= alu_out;
        end
        // other
        default:;
      endcase
    end
    // instruction fetch -> instruction
    // ------
    // instruction decode
  end

  // if

  // id
  // ex
  // mem
  // wb

endmodule
