`default_nettype none

`include "common.sv"
`include "parameters.sv"

interface robCommitIf;
  import parameters::*;
  logic [PHYS_REGS_ADDR_WIDTH-1: 0] phys_rd [0:DISPATCH_WIDTH-1];
  logic [ 4: 0]                     arch_rd [0:DISPATCH_WIDTH-1];
  logic                             en      [0:DISPATCH_WIDTH-1];
  logic [31:0]                      pc      [0:DISPATCH_WIDTH-1];
  logic [31:0]                      instr   [0:DISPATCH_WIDTH-1];
  logic                             is_branch_instr [0:DISPATCH_WIDTH-1];
  logic                             branch_correct  [0:DISPATCH_WIDTH-1];
  logic                             branch_taken    [0:DISPATCH_WIDTH-1];
  logic [12:0]                      br_offset [0:DISPATCH_WIDTH-1];

  modport out (
    output phys_rd,
    output arch_rd,
    output en,
    output pc,
    output instr,
    output is_branch_instr,
    output branch_correct,
    output branch_taken,
    output br_offset
  );

  modport in (
    input  phys_rd,
    input  arch_rd,
    input  en,
    input  pc,
    input  instr,
    input  is_branch_instr,
    input  branch_correct,
    input  branch_taken,
    input  br_offset
  );
endinterface

`default_nettype wire


