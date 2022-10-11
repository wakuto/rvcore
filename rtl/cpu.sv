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
    output logic [31:0] debug_reg[0:31],
    output logic illegal_instruction
);
  // regfile
  logic [31:0] reg_pc;
  logic [31:0] regfile[0:31];

  // decoded data
  common::alu_cmd operation_type;
  common::mem_access_type access_type;
  common::instr_field field;
  logic [31:0] op1;
  logic [31:0] op2;
  logic [31:0] alu_out;
  logic [31:0] pc_plus_4;
  logic [31:0] pc_branch;
  logic is_jump_instr;
  decoder decoder (
      .instruction,
      .alu_ops(operation_type),
      .access_type,
      .op1,
      .op2,
      .field,
      .regfile,
      .pc(reg_pc),
      .pc_plus_4,
      .pc_branch,
      .is_jump_instr,
      .illegal_instruction
  );

  execute execute (
      .op1,
      .op2,
      .alu_ops(operation_type),
      .alu_out
  );

  // memory access
  logic [31:0] wb_mask;
  memory_access memory_access (
      .access_type,
      .write_wstrb,
      .write_enable,
      .read_enable,
      .wb_mask
  );

  logic [31:0] pc_next;
  logic [31:0] reg_next;
  logic wb_en;
  write_back write_back (
      .pc_plus_4,
      .pc_branch,
      .is_jump_instr,
      .pc_next,
      .field,
      .read_data,
      .wb_mask,
      .alu_result(alu_out),
      .reg_next,
      .wb_en
  );

  // <= だとwarning出るけどなんで？
  initial begin
    reg_pc  = 32'h0;
    address = 32'h0;
    for (int i = 0; i < 32; i++) regfile[i] = 32'h0;
  end

  always_comb begin
    // debug output
    debug_ebreak = instruction == riscv_instr::EBREAK;
    for (int i = 0; i < 32; i++) debug_reg[i] = regfile[i];
    pc = reg_pc;
    address = alu_out;
    write_data = regfile[field.rs2];
  end

  always_ff @(posedge clock or posedge reset) begin
    if (reset) begin
      reg_pc <= 32'h0;
    end else begin
      reg_pc <= pc_next;
      if (wb_en) regfile[field.rd] <= reg_next;
      else regfile[field.rd] <= regfile[field.rd];
    end
  end
endmodule
