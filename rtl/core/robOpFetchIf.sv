`default_nettype none

`include "common.sv"
`include "parameters.sv"

interface robOpFetchIf;
  import parameters::*;
  logic [PHYS_REGS_ADDR_WIDTH-1: 0] phys_rs1  [0:DISPATCH_WIDTH-1];
  logic                             rs1_valid [0:DISPATCH_WIDTH-1];
  logic [PHYS_REGS_ADDR_WIDTH-1: 0] phys_rs2  [0:DISPATCH_WIDTH-1];
  logic                             rs2_valid [0:DISPATCH_WIDTH-1];

  modport out (
    output phys_rs1,
    input  rs1_valid,
    output phys_rs2,
    input  rs2_valid
  );

  modport in (
    input  phys_rs1,
    output rs1_valid,
    input  phys_rs2,
    output rs2_valid
  );
endinterface

`default_nettype wire



