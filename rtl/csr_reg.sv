`default_nettype none
`include "./riscv_instr.sv"
`include "./common.sv"

module csr_reg (
    input logic clock,
    input logic reset,
    input logic [11:0] csr_addr,
    input logic [31:0] csr_write_data,
    input logic csr_write_enable,
    output logic [31:0] csr_output
);
  import riscv_instr::*;
  logic [31:0] reg_csr [0:4095];
  logic [11:0] csr_sel;

  // TODO: csrレジスタと割り込みの実装
  always_comb begin
    casez (csr_addr)
      // unprivileged and user-level
      12'b11000???????, 12'b110010??????: read_only = 1'b1;
      // machine-level
      12'b11110???????, 12'b111110??????: read_only = 1'b1;
      default: read_only = 1'b0;
    endcase
    csr_output = reg_csr[csr_addr];
  end

  always_ff @(posedge clock or posedge reset) begin
    if (reset) begin
      for (int i = 0; i < 4096; i++) reg_csr <= 32'h0;
    end else begin
      if (csr_write_enable && !read_only) begin
        reg_csr[csr_addr] <= csr_write_data;
      end
      {reg_csr[CSR_CYCLEH], reg_csr[CSR_CYCLE]} <= {reg_csr[CSR_CYCLEH], reg_csr[CSR_CYCLE]} + 64'h1;
    end
  end
endmodule
