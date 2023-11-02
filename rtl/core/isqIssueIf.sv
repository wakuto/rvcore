`default_nettype none

`include "common.sv"
`include "parameters.sv"
interface isqIssueIf;
  import parameters::*;
  logic                            valid;
  common::alu_cmd_t                alu_cmd;
  logic [31:0]                     op1, op2;
  logic [PHYS_REGS_ADDR_WIDTH-1:0] phys_rd;

  // Issue queue ->
  modport out (
    output valid,
    output alu_cmd,
    output op1,
    output op2,
    output phys_rd
  );
  // -> Executer
  modport in (
    input valid,
    input alu_cmd,
    input op1,
    input op2,
    input phys_rd
  );
endinterface

`default_nettype wire

