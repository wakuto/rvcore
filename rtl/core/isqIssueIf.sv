`default_nettype none

`include "common.sv"
`include "parameters.sv"
interface isqIssueIf;
  import parameters::*;
  logic                            valid    [0:DISPATCH_WIDTH-1];
  common::alu_cmd_t                alu_cmd  [0:DISPATCH_WIDTH-1];
  logic [31:0]                     op1      [0:DISPATCH_WIDTH-1];
  common::op_type_t                op2_type [0:DISPATCH_WIDTH-1];
  logic [31:0]                     op2      [0:DISPATCH_WIDTH-1];
  logic [PHYS_REGS_ADDR_WIDTH-1:0] phys_rd  [0:DISPATCH_WIDTH-1];

  // Issue queue ->
  modport out (
    output valid,
    output alu_cmd,
    output op1,
    output op2_type,
    output op2,
    output phys_rd
  );
  // -> Executer
  modport in (
    input valid,
    input alu_cmd,
    input op1,
    input op2_type,
    input op2,
    input phys_rd
  );
endinterface

`default_nettype wire

