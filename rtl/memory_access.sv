`default_nettype none
`include "./riscv_instr.sv"
`include "./common.sv"

module memory_access(
  input logic [31:0] alu_out,
  input logic [2:0] access_type,
  input logic [31:0] write_data,
  output logic [31:0] read_data
);
endmodule

