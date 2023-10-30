`default_nettype none

`include "common.sv"
interface isqDispatchIf;
  logic             full;
  logic             en;
  common::alu_cmd_t alu_cmd;
  logic             op1_valid, op2_valid;
  logic [31:0]      op1, op2;
  logic [7:0]       phys_rd;

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

