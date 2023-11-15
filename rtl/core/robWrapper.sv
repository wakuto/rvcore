`default_nettype none
`include "parameters.sv"

module robWrapper(
  input wire clk, rst,
  // dispatch
  input  wire  [PHYS_REGS_ADDR_WIDTH-1: 0] dispatch_phys_rd    [0:DISPATCH_WIDTH-1],
  input  wire  [ 4: 0]                     dispatch_arch_rd    [0:DISPATCH_WIDTH-1],
  input  wire                              dispatch_en         [0:DISPATCH_WIDTH-1],
  output logic [DISPATCH_ADDR_WIDTH-1: 0]  dispatch_bank_addr  [0:DISPATCH_WIDTH-1],
  output logic [ROB_ADDR_WIDTH-1: 0]       dispatch_rob_addr   [0:DISPATCH_WIDTH-1],
  output logic                             dispatch_full,

  // writeback port
  input  wire  [DISPATCH_ADDR_WIDTH-1: 0]  writeback_bank_addr [0:DISPATCH_WIDTH-1],
  input  wire  [ROB_ADDR_WIDTH-1: 0]       writeback_rob_addr  [0:DISPATCH_WIDTH-1],
  input  wire                              writeback_en        [0:DISPATCH_WIDTH-1],

  // commit port
  output logic [PHYS_REGS_ADDR_WIDTH-1: 0] commit_phys_rd      [0:DISPATCH_WIDTH-1],
  output logic [ 4: 0]                     commit_arch_rd      [0:DISPATCH_WIDTH-1],
  output logic                             commit_en           [0:DISPATCH_WIDTH-1],

  // operand fetch port
  input  logic [ 4: 0]                     op_fetch_arch_rs1  [0:DISPATCH_WIDTH-1],
  output logic [PHYS_REGS_ADDR_WIDTH-1: 0] op_fetch_phys_rs1  [0:DISPATCH_WIDTH-1],
  output logic                             op_fetch_rs1_valid [0:DISPATCH_WIDTH-1],
  input  logic [ 4: 0]                     op_fetch_arch_rs2  [0:DISPATCH_WIDTH-1],
  output logic [PHYS_REGS_ADDR_WIDTH-1: 0] op_fetch_phys_rs2  [0:DISPATCH_WIDTH-1],
  output logic                             op_fetch_rs2_valid [0:DISPATCH_WIDTH-1]
);

  import parameters::*;


  robDispatchIf dispatch_if();
  robWbIf wb_if();
  robCommitIf commit_if();
  robOpFetchIf op_fetch_if();

  rob rob (.clk, .rst, .dispatch_if, .wb_if, .commit_if, .op_fetch_if);

  always_comb begin
    // dispatch
    dispatch_if.phys_rd = dispatch_phys_rd;
    dispatch_if.arch_rd = dispatch_arch_rd;
    dispatch_if.en = dispatch_en;
    dispatch_bank_addr = dispatch_if.bank_addr;
    dispatch_rob_addr =  dispatch_if.rob_addr;
    dispatch_full = dispatch_if.full;

    // writeback
    wb_if.bank_addr = writeback_bank_addr;
    wb_if.rob_addr = writeback_rob_addr;
    wb_if.en = writeback_en;

    // commit
    commit_phys_rd = commit_if.phys_rd;
    commit_arch_rd = commit_if.arch_rd;
    commit_en = commit_if.en;

    // operand fetch
    op_fetch_if.arch_rs1 = op_fetch_arch_rs1;
    op_fetch_phys_rs1 = op_fetch_if.phys_rs1;
    op_fetch_rs1_valid = op_fetch_if.rs1_valid;
    op_fetch_if.arch_rs2 = op_fetch_arch_rs2;
    op_fetch_phys_rs2 = op_fetch_if.phys_rs2;
    op_fetch_rs2_valid = op_fetch_if.rs2_valid;
  end
endmodule

`default_nettype wire

