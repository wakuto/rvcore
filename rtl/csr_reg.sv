`default_nettype none
`include "./riscv_instr.sv"
`include "./common.sv"

module csr_reg (
    input logic clock,
    input logic reset,
    input logic [11:0] csr_addr,
    input logic [31:0] csr_write_data,
    input logic csr_wen,
    output logic [31:0] csr_output
);
  import riscv_instr::*;
  enum logic [3:0] {
    MSTATUS,
    MIE,
    MTVEC,
    MEPC,
    MCAUSE,
    MIP,
    CYCLE,
    CYCLEH,
    OTHER
  } csr_sel;
  logic [31:0] reg_csr[0:csr_sel.num()-1];

  // TODO: csrレジスタと割り込みの実装
  always_comb begin
    casez (csr_addr)
      // unprivileged and user-level
      12'b11000???????, 12'b110010??????: read_only = 1'b1;
      // machine-level
      12'b11110???????, 12'b111110??????: read_only = 1'b1;
      default: read_only = 1'b0;
    endcase
    casez (csr_addr)
      CSR_MSTATUS: csr_sel = MSTATUS;
      CSR_MIE: csr_sel = MIE;
      CSR_MTVEC: csr_sel = MTVEC;
      CSR_MEPC: csr_sel = MEPC;
      CSR_MCAUSE: csr_sel = MCAUSE;
      CSR_MIP: csr_sel = MIP;
      CSR_CYCLE: csr_sel = CYCLE;
      CSR_CYCLEH: csr_sel = CYCLEH;
      default: csr_sel = OTHER;
    endcase
    if (csr_sel != OTHER) csr_output = csr_reg[csr_sel];
    else csr_output = 32'h0;
  end

  always_ff @(posedge clock or posedge reset) begin
    if (reset) begin
      for (int i = 0; i < csr_sel.num(); i++) reg_csr[i] <= 32'h0;
    end else begin
      if (csr_wen && !read_only && csr_sel != OTHER) begin
        reg_csr[csr_sel] <= csr_write_data;
      end
      {reg_csr[CYCLEH], reg_csr[CYCLE]} <= {reg_csr[CYCLEH], reg_csr[CYCLE]} + 64'h1;
    end
  end
endmodule
`default_nettype wire
