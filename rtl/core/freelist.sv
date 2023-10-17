`default_nettype none

`include "parameters.sv"

module freelist(
  input clk, rst,
  freelistIf.freelist freelist_if
);
  import parameters::*;

  genvar i;
  generate
    for(i = 0; i < DISPATCH_WIDTH; i++) begin : genfifo
      fifoIf.fifo fifo_if;
      fifo fifo(
        .clk,
        .rst,
        .fifo_if(genfifo[i].fifo_if)
      );
    end
  endgenerate
  always_comb begin
    for (i = 0; i < DISPATCH_WIDTH; i++) begin
      genfifo[i].fifo_if.wr_en = freelist_if.push_en[i];
      genfifo[i].fifo_if.wr_data = freelist_if.push_reg[i];
      freelist_if.full[i] = genfifo[i].fifo_if.full;

      genfifo[i].fifo_if.rd_en = freelist_if.pop_en[i];
      freelist_if.pop_reg[i] = genfifo[i].fifo_if.rd_data;
      freelist_if.empty[i] = genfifo[i].fifo_if.empty;
    end
  end
endmodule


`default_nettype wire

