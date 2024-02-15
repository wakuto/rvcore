`default_nettype none

`include "common.sv"
`include "parameters.sv"
interface isqDispatchIf;
  import parameters::*;
  logic                            full;
  logic                            en        [0:DISPATCH_WIDTH-1];
  common::alu_cmd_t                alu_cmd   [0:DISPATCH_WIDTH-1];
  logic                            op1_valid [0:DISPATCH_WIDTH-1];
  logic                            op2_valid [0:DISPATCH_WIDTH-1];
  logic [PHYS_REGS_ADDR_WIDTH-1:0] op1       [0:DISPATCH_WIDTH-1];
  logic [31:0]                     op2       [0:DISPATCH_WIDTH-1];
  common::op_type_t                op2_type  [0:DISPATCH_WIDTH-1];
  logic [PHYS_REGS_ADDR_WIDTH-1:0] phys_rd   [0:DISPATCH_WIDTH-1];
  logic [DISPATCH_ADDR_WIDTH-1: 0] bank_addr [0:DISPATCH_WIDTH-1];
  logic [ROB_ADDR_WIDTH-1: 0]      rob_addr  [0:DISPATCH_WIDTH-1];
  logic [31:0]                     pc        [0:DISPATCH_WIDTH-1];
  logic [31:0]                     instr     [0:DISPATCH_WIDTH-1];
  logic                            is_branch_instr [0:DISPATCH_WIDTH-1];

  // Rename unit -> 
  modport out (
    output en,
    input  full,
    output alu_cmd,
    output op1_valid, op2_valid,
    output op1, op2,
    output op2_type,
    output phys_rd,
    output bank_addr,
    output rob_addr,
    output pc,
    output instr,
    output is_branch_instr
  );

  // -> Issue queue
  modport in (
    input  en,
    output full,
    input  alu_cmd,
    input  op1_valid, op2_valid,
    input  op1, op2,
    input  op2_type,
    input  phys_rd,
    input  bank_addr,
    input  rob_addr,
    input  pc,
    input  instr,
    input  is_branch_instr
  );
endinterface

`default_nettype wire

