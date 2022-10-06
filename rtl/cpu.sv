`default_nettype none
`include "./riscv_instr.sv"
`include "./common.sv"

module cpu (
    input logic clock,
    input logic reset,
    // instruction data
    output logic [31:0] pc,
    input logic [31:0] instruction,
    // memory data
    output logic [31:0] address,
    input logic [31:0] read_data,
    output logic read_enable,  // データを読むときにアサート
    //input logic mem_valid,  // response signal
    output logic [31:0] write_data,
    output logic write_enable,  // データを書くときにアサート->request signal
    output logic [1:0] write_wstrb,  // 書き込むデータの幅
    output logic debug_ebreak,
    output logic [31:0] debug_reg[0:31]
);
  // regfile
  logic [31:0] reg_pc;
  enum logic [1:0] {
    BRANCH,
    JAL,
    JALR,
    PCNEXT
  } pc_sel;
  logic [31:0] regfile[0:31];

  // instruction fields
  logic [6:0] opcode;
  logic [4:0] rd;
  logic [4:0] rs1;
  logic [4:0] rs2;
  logic [11:0] imm_i;
  logic [12:0] imm_b;
  logic [20:0] imm_j;

  logic [31:0] op1;
  logic [31:0] op2;
  logic [31:0] alu_out;

  // decoded data
  common::alu_cmd operation_type;
  common::mem_access_type access_type;

  // memory access
  logic [31:0] wb_mask;
  logic mem_stall_flag;

  // <= だとwarning出るけどなんで？
  initial begin
    reg_pc  = 32'h0;
    address = 32'h0;
    for (int i = 0; i < 32; i++) regfile[i] = 32'h0;
    mem_stall_flag = 1'b0;
  end

  decoder decoder (
      .instruction,
      .alu_ops(operation_type),
      .access_type,
      .op1,
      .op2,
      .regfile,
      .pc(reg_pc)
  );

  execute execute (
      .op1,
      .op2,
      .alu_ops(operation_type),
      .alu_out
  );

  memory_access memory_access (
      .access_type,
      .write_wstrb,
      .write_enable,
      .read_enable,
      .wb_mask
  );

  assign opcode = instruction[6:0];
  assign rd = instruction[11:7];
  assign rs1 = instruction[19:15];
  assign rs2 = instruction[24:20];
  assign imm_i = instruction[31:20];
  assign imm_b = {instruction[31], instruction[7], instruction[30:25], instruction[11:8], 1'b0};
  assign imm_j = {instruction[31], instruction[19:12], instruction[20], instruction[30:21], 1'b0};

  always_comb begin
    // debug output
    debug_ebreak = instruction == riscv_instr::EBREAK;
    for (int i = 0; i < 32; i++) debug_reg[i] = regfile[i];
    case (opcode)
      7'b1100011: begin
        if (alu_out[0]) pc_sel = BRANCH;
        else pc_sel = PCNEXT;
      end
      7'b1100111: pc_sel = JAL;
      7'b1101111: pc_sel = JALR;
      default: pc_sel = PCNEXT;
    endcase
    pc = reg_pc;
    address = alu_out;
    write_data = regfile[rs2];
  end

  always_ff @(posedge clock or posedge reset) begin
    $display("alu_out  :%h", alu_out);
    $display("branch   :%h", reg_pc + 32'(signed'(imm_b)));
    if (reset) begin
      reg_pc <= 32'h0;
    end else begin
      case (pc_sel)
        BRANCH: reg_pc <= reg_pc + 32'(signed'(imm_b));
        JAL: reg_pc <= regfile[rs1] + 32'(signed'(imm_i));
        JALR: reg_pc <= reg_pc + 32'(signed'(imm_j));
        PCNEXT: reg_pc <= reg_pc + 32'h4;
      endcase
      // write back
      case (opcode)
        // R-Type, I-Type, lui
        7'b0110011, 7'b0010011, 7'b0110111: regfile[rd] <= alu_out;
        // load instruction
        7'b0000011: regfile[rd] <= read_data & wb_mask;
        // other
        default: ;
      endcase
    end
  end
endmodule
