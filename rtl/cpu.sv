`default_nettype none
`include "./riscv_instr.sv"
`include "./common.sv"

module cpu (
    input wire logic clock,
    input wire logic reset,
    // instruction data
    output logic [31:0] pc,
    input wire logic [31:0] instruction,
    // memory data
    output logic [31:0] address,
    input wire logic [31:0] read_data,
    output logic read_enable,  // データを読むときにアサート
    //input wire logic mem_valid,  // response signal
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
  logic [31:0] csr_regfile[0:4095];
  logic [31:0] csr_next;
  logic [31:0] csr_data;
  logic [11:0] csr_rd;
  logic csr_wb_en;
    input logic clock,
    input logic reset,
    input logic [11:0] csr_addr,
    input logic [31:0] csr_write_data,
    input logic csr_wen,
    output logic [31:0] csr_output
  csr_reg csr_reg(.clock, .reset, .csr_addr(), .csr_write_data(), .csr_wen(), .csr_output());

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
      .alu_ops(operation_type),
      .access_type,
      .wb_sel,
      .op1,
      .op2,
      .field,
      .csr_rd,
      .reg_rs1(regfile[field.rs1]),
      .reg_rs2(regfile[field.rs2]),
      .pc(reg_pc),
      .pc_plus_4,
      .pc_branch,
      .is_jump_instr,
      .pc_sel,
      .csr_data,
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
      .pc_mepc(csr_regfile[CSR_MEPC]),
      .is_jump_instr,
      .pc_sel,
      .pc_next,
      .wb_sel,
      .read_data,
      .wb_mask,
      .alu_result(alu_out),
      .reg_next,
      .wb_en,
      .csr_data,
      .csr_next,
      .csr_wb_en
  );

  // <= だとwarning出るけどなんで？
  initial begin
    reg_pc  = 32'h0;
    address = 32'h0;
    for (int i = 0; i < 32; i++) regfile[i] = 32'h0;
    for (int i = 0; i < 4096; i++) csr_regfile[i] = 32'h0;
  end

  logic interrupt;
  logic mstatus_mie, mie_msie, mip_msip;

  always_comb begin
    import riscv_instr::*;
    // debug output
    debug_ebreak = instruction == riscv_instr::EBREAK;
    for (int i = 0; i < 32; i++) debug_reg[i] = regfile[i];
    pc = reg_pc;
    address = alu_out;
    write_data = regfile[field.rs2];
    csr_data = csr_regfile[field.imm_i];
    interrupt = csr_regfile[CSR_MSTATUS][3] & csr_regfile[CSR_MIE][3] & csr_regfile[CSR_MIP][3];
    mstatus_mie = csr_regfile[CSR_MSTATUS][3];
    mie_msie = csr_regfile[CSR_MIE][3];
    mip_msip = csr_regfile[CSR_MIP][3];
  end

  always_ff @(posedge clock or posedge reset) begin
    if (reset) begin
      reg_pc <= 32'h0;
    end else begin
      import riscv_instr::*;
      int unsigned mstatus = csr_regfile[CSR_MSTATUS];
      int unsigned mie = csr_regfile[CSR_MIE];
      int unsigned mip = csr_regfile[CSR_MIP];
      int unsigned mtvec = csr_regfile[CSR_MTVEC];
      if (mstatus[3]) begin  // mstatus.mie
        // software interrupt
        if (mie[3] & mip[3]) begin  // mie.msie & mip.msip
          // mpie = mie
          // mie = 0
          //csr_regfile[CSR_MSTATUS] <= {mstatus[31:8], 1'b1, mstatus[6:4], 1'b0, mstatus[2:0]};
          csr_regfile[CSR_MSTATUS] <= mstatus ^ 32'b10001000;
          csr_regfile[CSR_MIP][3]  <= 1'b0;
          if (csr_regfile[CSR_MCAUSE][31]) csr_regfile[CSR_MEPC] <= reg_pc;
          else
            // FIXME: incorrect jump address...
            // implement reg_prev
            csr_regfile[CSR_MEPC] <= reg_pc;
          // jump to trap vector
          reg_pc <= mtvec;
        end else begin
          reg_pc <= pc_next;
          if (wb_en) regfile[field.rd] <= reg_next;
          if (csr_wb_en) csr_regfile[csr_rd] <= csr_next;
        end
      end else begin
        reg_pc <= pc_next;
        if (wb_en) regfile[field.rd] <= reg_next;
        if (csr_wb_en) csr_regfile[csr_rd] <= csr_next;
      end
    end
  end
endmodule
`default_nettype wire
