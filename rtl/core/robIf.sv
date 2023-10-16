`default_nettype none

`include "common.sv"
`include "paramter.sv"

interface robIf();
  import parameter::*;
  // dispatch port
  logic [PHYS_REGS_ADDR_WIDTH-1: 0] dispatch_phys_rd   [0:DISPATCH_WIDTH-1];
  logic [ 4: 0]                     dispatch_arch_rd   [0:DISPATCH_WIDTH-1];
  logic                             dispatch_en        [0:DISPATCH_WIDTH-1];
  logic [DISPATCH_WIDTH-1: 0]       dispatch_bank_addr [0:DISPATCH_WIDTH-1];
  logic [ROB_ADDR_WIDTH-1: 0]       dispatch_rob_addr  [0:DISPATCH_WIDTH-1];
  logic                             full;

  // writeback port
  logic [DISPATCH_WIDTH-1: 0] writeback_bank_addr [0:DISPATCH_WIDTH-1];
  logic [ROB_ADDR_WIDTH-1: 0] writeback_rob_addr  [0:DISPATCH_WIDTH-1];
  logic                       writeback_en        [0:DISPATCH_WIDTH-1];

  // commit port
  logic [PHYS_REGS_ADDR_WIDTH-1: 0] commit_phys_rd    [0:DISPATCH_WIDTH-1];
  logic [ 4: 0]                     commit_arch_rd    [0:DISPATCH_WIDTH-1];
  logic                             commit_en         [0:DISPATCH_WIDTH-1];

  modport rob (
    // dispatch
    input  dispatch_phys_rd,
    input  dispatch_arch_rd,
    input  dispatch_en,
    output dispatch_bank_addr,
    output dispatch_rob_addr,
    output full,

    // writeback
    input  writeback_bank_addr,
    input  writeback_rob_addr,
    input  writeback_en,

    // commit
    input  commit_phys_rd,
    input  commit_arch_rd,
    input  commit_en
  );

  modport dispatch (
    output dispatch_phys_rd,
    output dispatch_arch_rd,
    output dispatch_en,
    input  dispatch_bank_addr,
    input  dispatch_rob_addr,
    input  full
  );

  modport writeback (
    output writeback_bank_addr,
    output writeback_rob_addr,
    output writeback_en
  );

  modport commit (
    output commit_phys_rd,
    output commit_arch_rd,
    output commit_en
  );
endinterface

`default_nettype wire
