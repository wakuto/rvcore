`default_nettype none
`include "riscv_instr.sv"
`include "common.sv"
`include "memory_map.sv"

module core (
    input wire logic        clock,
    input wire logic        reset,

    // instruction data
    output     logic [31:0] pc,
    input wire logic [31:0] instruction,
    input wire logic        instr_valid,

    // memory data
    output     logic [31:0] address,
    input wire logic [31:0] read_data,
    output     logic        read_enable,     // データを読むときにアサート
    input wire logic        read_valid,  // メモリ出力の有効フラグ
    output     logic [31:0] write_data,
    output     logic        write_enable,    // データを書くときにアサート->request signal
    output     logic [3:0]  strb,  // 書き込むデータの幅
    input wire logic        write_ready,  // 書き込むデータの幅

    output     logic        debug_ebreak,
    output     logic        debug_ecall,
    output     logic [31:0] debug_reg[0:31],
    output     logic        illegal_instr,
    input wire logic        timer_int,
    input wire logic        soft_int,
    input wire logic        ext_int
);
  // regfile
  logic [31:0] reg_pc;
  logic [31:0] csr_data;
  logic [11:0] csr_rd;

  logic csr_instr;
  logic [11:0] csr_addr;
  logic [31:0] mtvec;
  logic [31:0] mepc;
  logic csr_pc_sel;
  logic mret_instr;
  logic env_call;
  logic break_point;
  logic load_access;

  csr_reg csr_reg (
    .clock,
    .reset,

    .stall(mem_stall | ~instr_valid),
    .csr_instr,
    .csr_addr(csr_rd),
    .csr_instr_src(alu_out),
    .csr_instr_dst(csr_data),

    .mret_instr,

    .illegal_instr, // <-decoder
    .env_call,      // <-decoder
    .load_access,   // <-mem_access
    .break_point,   // <-decoder
    .timer_int,
    .soft_int,
    .ext_int,

    .pc(reg_pc),
    .mtvec,
    .mepc,
    .csr_pc_sel
  );
  
  logic [31:0] rs1;
  logic [31:0] rs2;
  regfile regfile(
    .clock,
    .reset,
    .addr_rs1(field.rs1),
    .addr_rs2(field.rs2),
    .addr_rd(field.rd),
    .rd_data(reg_next),
    .wen(wb_en),
    .rs1,
    .rs2,
    .debug_reg
  );

  // decoded data
  common::alu_cmd operation_type;
  common::mem_access_type access_type;
  common::instr_field field;
  common::pc_sel_t pc_sel;
  common::wb_sel_t wb_sel;
  logic [31:0] op1;
  logic [31:0] op2;
  logic [31:0] alu_out;
  logic [31:0] pc_plus_4;
  logic [31:0] pc_branch;
  logic is_jump_instr;
  decoder decoder (
      .instruction,
      .instr_valid,
      .alu_ops(operation_type),
      .access_type,
      .wb_sel,
      .op1,
      .op2,
      .field,
      .csr_rd,
      .reg_rs1(rs1),
      .reg_rs2(rs2),
      .pc(reg_pc),
      .pc_plus_4,
      .pc_branch,
      .is_jump_instr,
      .pc_sel,
      .csr_data,
      .mret_instr,
      .illegal_instr,
      .env_call,
      .break_point,
      .csr_instr
  );

  execute execute (
      .op1,
      .op2,
      .alu_ops(operation_type),
      .alu_out
  );

  // memory access
  logic [31:0] wb_mask;
  logic [4:0] wb_msb_bit;
  logic mem_stall;
  memory_access memory_access (
      .access_type,
      .strb,
      .write_enable,
      .write_ready,
      .read_enable,
      .read_valid,
      .wb_mask,
      .wb_msb_bit,
      .mem_stall,
      .load_access
  );

  logic [31:0] pc_next;
  logic [31:0] reg_next;
  logic wb_en;
  write_back write_back (
      .pc(reg_pc),
      .pc_plus_4,
      .pc_branch,
      .mem_stall,
      .instr_valid,
      .is_jump_instr,
      .pc_sel,
      .pc_next,
      .wb_sel,
      .read_data,
      .read_valid,
      .wb_mask,
      .wb_msb_bit,
      .alu_result(alu_out),
      .reg_next,
      .wb_en,
      .csr_data
  );

  always_comb begin
    import riscv_instr::*;
    // debug output
    debug_ebreak = instruction == riscv_instr::EBREAK;
    debug_ecall  = instruction == riscv_instr::ECALL;
    pc = reg_pc;
    address = alu_out;
    write_data = rs2;
  end

  always_ff @(posedge clock or posedge reset) begin
    if (reset) begin
      reg_pc <= memory_map::DRAM_BASE;
    end else begin
      import riscv_instr::*;

      // set the next pc from csr
      if (csr_pc_sel) begin
        // mret
        if(mret_instr) 
          reg_pc <= mepc;
        // interrpt
        else
          reg_pc <= mtvec;
      end
      else
        reg_pc <= pc_next;
    end
  end
endmodule
`default_nettype wire