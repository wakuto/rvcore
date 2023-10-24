`default_nettype none
`ifndef PARAMETERS_H
`define PARAMETERS_H

package parameters;
  parameter integer DISPATCH_WIDTH = 2;
  // verilator lint_off UNUSEDPARAM
  parameter integer DISPATCH_ADDR_WIDTH = $clog2(DISPATCH_WIDTH);
  // verilator lint_on UNUSEDPARAM
  parameter integer ROB_SIZE = 16;
  // verilator lint_off UNUSEDPARAM
  parameter integer ROB_ADDR_WIDTH = $clog2(ROB_SIZE);
  // verilator lint_on UNUSEDPARAM
  parameter integer PHYS_REGS = 128;
  parameter integer PHYS_REGS_ADDR_WIDTH = $clog2(PHYS_REGS);
endpackage

`endif
`default_nettype wire

