`default_nettype none

`include "parameters.sv"

interface freelistIf;
  import parameters::*;

  logic [PHYS_REGS_ADDR_WIDTH-1:0] push_reg [0:DISPATCH_WIDTH-1];
  logic [DISPATCH_WIDTH-1:0]       push_en;
  logic [PHYS_REGS_ADDR_WIDTH-1:0] pop_reg  [0:DISPATCH_WIDTH-1];
  logic [DISPATCH_WIDTH-1:0]       pop_en;
  logic [PHYS_REGS_ADDR_WIDTH:0]   num_free;

  modport push(
    output push_reg,
    output push_en
  );

  modport pop(
    input  pop_reg,
    output pop_en,
    input  num_free
  );

  modport freelist(
    input  push_reg,
    input  push_en,
    output pop_reg,
    input  pop_en,
    output num_free
  );
endinterface

`default_nettype wire
