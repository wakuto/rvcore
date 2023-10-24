`default_nettype none

`include "parameters.sv"

interface freelistIf;
  import parameters::*;

  logic [PHYS_REGS_ADDR_WIDTH-1:0] push_reg [0:DISPATCH_WIDTH-1];
  logic [DISPATCH_WIDTH-1:0]       push_en;
  logic [PHYS_REGS_ADDR_WIDTH-1:0] pop_reg  [0:DISPATCH_WIDTH-1];
  logic [DISPATCH_WIDTH-1:0]       pop_en;
  logic full;
  logic empty;

  modport push(
    output push_reg,
    output push_en,
    input  full
  );

  modport pop(
    input  pop_reg,
    output pop_en,
    input  empty
  );

  modport freelist(
    input  push_reg,
    input  push_en,
    output full,
    output pop_reg,
    input  pop_en,
    output empty
  );
endinterface

`default_nettype wire
