`default_nettype none

`include "common.sv"
`include "parameters.sv"
interface isqDispatchIf;
  import parameters::*;
  logic                            full;
  logic                            en       [0:DISPATCH_WIDTH-1];
  common::alu_cmd_t                alu_cmd  [0:DISPATCH_WIDTH-1];
  logic                            op1_valid[0:DISPATCH_WIDTH-1];
  logic                            op2_valid[0:DISPATCH_WIDTH-1];
  logic [31:0]                     op1      [0:DISPATCH_WIDTH-1];
  logic [31:0]                     op2      [0:DISPATCH_WIDTH-1];
  logic [PHYS_REGS_ADDR_WIDTH-1:0] phys_rd  [0:DISPATCH_WIDTH-1];

  // Rename unit -> 
  modport out (
    output en,
    input  full,
    output alu_cmd,
    output op1_valid, op2_valid,
    output op1, op2,
    output phys_rd
  );

  // -> Issue queue
  modport in (
    input  en,
    output full,
    input  alu_cmd,
    input  op1_valid, op2_valid,
    input  op1, op2,
    input  phys_rd
  );
endinterface

`default_nettype wire

