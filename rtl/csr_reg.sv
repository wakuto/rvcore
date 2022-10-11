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
    csr_output = reg_csr[csr_addr];
  end

  always_ff @(posedge clock or posedge reset) begin
    if (reset) begin
      for (int i = 0; i < 4096; i++) reg_csr <= 32'h0;
    end else begin
      if (csr_write_enable) begin
        reg_csr[csr_addr] <= csr_write_data;
      end
    end
  end
endmodule
