`default_nettype none

`include "common.sv"
`include "parameters.sv"

interface robOpFetchIf;
  import parameters::*;
  logic [1:0][PHYS_REGS_ADDR_WIDTH-1: 0] phys_reg [0:DISPATCH_WIDTH-1];
  logic [1:0][ 4: 0]                     arch_reg [0:DISPATCH_WIDTH-1];
  logic [1:0]                            valid    [0:DISPATCH_WIDTH-1];

  modport out (
    output arch_reg,
    input  phys_reg,
    input  valid
  );

  modport in (
    input  arch_reg,
    output phys_reg,
    output valid
  );
endinterface

`default_nettype wire



