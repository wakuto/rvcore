`default_nettype none

`include "common.sv"
`include "parameters.sv"

interface isqWbIf;
  import parameters::*;
  logic                            valid   [0:DISPATCH_WIDTH-1];
  logic [PHYS_REGS_ADDR_WIDTH-1:0] phys_rd [0:DISPATCH_WIDTH-1];

  modport out (
    output valid,
    output phys_rd
  );

  modport in (
    input  valid,
    input  phys_rd
  );
endinterface

`default_nettype wire

