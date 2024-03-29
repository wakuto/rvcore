`ifndef MEMORY_MAP_H
`define MEMORY_MAP_H

package memory_map;

  localparam UART0_BASE = 32'h10000000;
  localparam UART0_SIZE = 32'h100;
  localparam DRAM_BASE  = 32'h80000000;
  localparam DRAM_SIZE  = 32'h4000;

endpackage

`endif
