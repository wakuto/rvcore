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

  modport out (
    output phys_rd,
    output arch_rd,
    output en,
    output pc,
    output instr
  );

  modport in (
    input  phys_rd,
    input  arch_rd,
    input  en,
    input  pc,
    input  instr
  );
endinterface

`default_nettype wire


