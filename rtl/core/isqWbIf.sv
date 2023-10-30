`default_nettype none

`include "common.sv"
interface isqWbIf;
  logic             valid;
  logic [7:0]       phys_rd;
  logic [31:0]      data;

  modport out (
    output valid,
    output phys_rd,
    output data
  );

  modport in (
    input  valid,
    input  phys_rd,
    input  data
  );
endinterface

`default_nettype wire

