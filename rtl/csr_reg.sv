`default_nettype none
`include "./riscv_instr.sv"
`include "./common.sv"

module csr_reg (
  input logic clock,
  input logic [11:0] csr_addr,
  input logic [31:0] csr_write_data,
  input logic csr_write_enable,
  output logic [31:0] csr_output
);
  import riscv_instr::*;
  logic [31:0] reg_csr [0:31];

// TODO: csrレジスタと割り込みの実装
  always_comb begin
    case(csr_addr)
      CSR_MSTATUS: csr_output = reg_csr[0];
      CSR_MISA: csr_output = reg_csr[1];
      CSR_MIE: csr_output = reg_csr[2];
      CSR_MTVEC: csr_output = reg_csr[3];
    endcase
  end
endmodule
