`default_nettype none
`ifndef PARAMETER_H
`define PARAMETER_H

package parameter;
  parameter integer DISPATCH_WIDTH = 2;
  parameter integer ROB_SIZE = 16;
  parameter integer ROB_ADDR_WIDTH = $clog2(ROB_SIZE);
  parameter integer PHYS_REGS = 128;
  parameter integer PHYS_REGS_ADDR_WIDTH = $clog2(PHYS_REGS);
endpackage

`endif
`default_nettype wire

