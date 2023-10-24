`default_nettype none

`include "parameters.sv"

module freelistWrapper(
  input  wire  clk, rst,
  input  wire  [PHYS_REGS_ADDR_WIDTH-1:0] push_reg [0:DISPATCH_WIDTH-1],
  input  wire  [DISPATCH_WIDTH-1:0]       push_en,
  output logic [PHYS_REGS_ADDR_WIDTH-1:0] pop_reg  [0:DISPATCH_WIDTH-1],
  input  wire  [DISPATCH_WIDTH-1:0]       pop_en,
  output logic [PHYS_REGS_ADDR_WIDTH:0]   num_free
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

    pop_reg             = freelist_if.pop_reg;
    freelist_if.pop_en  = pop_en;
    num_free            = freelist_if.num_free;
  end

endmodule
`default_nettype wire

