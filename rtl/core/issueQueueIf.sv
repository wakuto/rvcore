`default_nettype none

`include "common.sv"

interface issueQueueIf;
  logic             write_enable;
  logic             full;
  logic             alu_cmd_valid;
  common::alu_cmd_t alu_cmd;
  common::alu_cmd_t issue_alu_cmd;
  logic             op1_valid, op2_valid;
  logic [31:0]      op1, op2;
  logic [31:0]      issue_op1, issue_op2;
  // verilator lint_off UNUSEDSIGNAL
  logic [7:0]       phys_rd;
  // verilator lint_on UNUSEDSIGNAL
  logic             phys_result_valid;
  logic [7:0]       phys_result_tag;
  logic [31:0]      phys_result_data;

  // Rename unit -> 
  modport rename_unit (
    output write_enable,
    input  full,
    output alu_cmd,
    output op1_valid, op2_valid,
    output op1, op2,
    output phys_rd
  );

  // -> Issue queue
  modport issue_din (
    input  write_enable,
    output full,
    input  alu_cmd,
    input  op1_valid, op2_valid,
    input  op1, op2,
    input  phys_rd,
    output phys_result_valid,
    output phys_result_tag,
    output phys_result_data
  );

  // Issue queue ->
  modport issue (
    output alu_cmd_valid,
    output issue_alu_cmd,
    output issue_op1,
    output issue_op2,
    output phys_rd
  );
  // -> Executer
  modport executer (
    input alu_cmd_valid,
    input issue_alu_cmd,
    input issue_op1,
    input issue_op2,
    input phys_rd
  );

endinterface

`default_nettype wire
