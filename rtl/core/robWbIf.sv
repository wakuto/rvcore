`default_nettype none

`include "common.sv"
`include "parameters.sv"

interface robWbIf;
  import parameters::*;
  logic [DISPATCH_ADDR_WIDTH-1: 0]  bank_addr [0:DISPATCH_WIDTH-1];
  logic [ROB_ADDR_WIDTH-1: 0]       rob_addr  [0:DISPATCH_WIDTH-1];
  logic                             en        [0:DISPATCH_WIDTH-1];
  logic [PHYS_REGS_ADDR_WIDTH-1: 0] phys_rd   [0:DISPATCH_WIDTH-1];

  modport out (
    output phys_rd,
    output bank_addr,
    output rob_addr,
    output en
  );

  modport in (
    input  phys_rd,
    input  bank_addr,
    input  rob_addr,
    input  en
  );
endinterface

`default_nettype wire

