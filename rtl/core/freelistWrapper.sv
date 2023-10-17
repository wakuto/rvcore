`default_nettype none

`include "parameters.sv"

module freelistWrapper(
  input  wire  clk, rst,
  input  wire  [PHYS_REGS_ADDR_WIDTH-1:0] push_reg [0:DISPATCH_WIDTH-1],
  input  wire                             push_en  [0:DISPATCH_WIDTH-1],
  output logic full,
  output logic [PHYS_REGS_ADDR_WIDTH-1:0] pop_reg  [0:DISPATCH_WIDTH-1],
  input  wire                             pop_en   [0:DISPATCH_WIDTH-1],
  output logic empty
);
  import parameters::*;

  freelistIf freelist_if;

  freelist freelist(
    .clk,
    .rst,
    .freelist_if
  );

  always_comb begin
    freelist_if.push_reg = push_reg;
    freelist_if.push_en  = push_en;
    full                = freelist_if.full;

    pop_reg             = freelist_if.pop_reg;
    freelist_if.pop_en  = pop_en;
    empty               = freelist_if.empty;
  end

endmodule
`default_nettype wire

