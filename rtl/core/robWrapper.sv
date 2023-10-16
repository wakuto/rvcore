`default_nettype none
`include "parameters.sv"

module robWrapper(
  input wire clk, rst,
  // dispatch
  input  wire  [PHYS_REGS_ADDR_WIDTH-1: 0] dispatch_phys_rd   [0:DISPATCH_WIDTH-1],
  input  wire  [ 4: 0]                     dispatch_arch_rd   [0:DISPATCH_WIDTH-1],
  input  wire                              dispatch_en        [0:DISPATCH_WIDTH-1],
  output logic [DISPATCH_ADDR_WIDTH-1: 0]       dispatch_bank_addr [0:DISPATCH_WIDTH-1],
  output logic [ROB_ADDR_WIDTH-1: 0]       dispatch_rob_addr  [0:DISPATCH_WIDTH-1],
  output logic                             full,

  // writeback port
  input  wire  [DISPATCH_ADDR_WIDTH-1: 0] writeback_bank_addr [0:DISPATCH_WIDTH-1],
  input  wire  [ROB_ADDR_WIDTH-1: 0] writeback_rob_addr  [0:DISPATCH_WIDTH-1],
  input  wire                        writeback_en        [0:DISPATCH_WIDTH-1],

  // commit port
  output logic [PHYS_REGS_ADDR_WIDTH-1: 0] commit_phys_rd    [0:DISPATCH_WIDTH-1],
  output logic [ 4: 0]                     commit_arch_rd    [0:DISPATCH_WIDTH-1],
  output logic                             commit_en         [0:DISPATCH_WIDTH-1]
);
  import parameters::*;


  robIf rob_if;

  rob rob (.clk, .rst, .rob_if);

  always_comb begin
    // dispatch
    rob_if.dispatch_phys_rd = dispatch_phys_rd;
    rob_if.dispatch_arch_rd = dispatch_arch_rd;
    rob_if.dispatch_en = dispatch_en;
    dispatch_bank_addr = rob_if.dispatch_bank_addr;
    dispatch_rob_addr = rob_if.dispatch_rob_addr;
    full = rob_if.full;

    // writeback
    rob_if.writeback_bank_addr = writeback_bank_addr;
    rob_if.writeback_rob_addr = writeback_rob_addr;
    rob_if.writeback_en = writeback_en;

    // commit
    commit_phys_rd = rob_if.commit_phys_rd;
    commit_arch_rd = rob_if.commit_arch_rd;
    commit_en = rob_if.commit_en;
  end
endmodule

`default_nettype wire

