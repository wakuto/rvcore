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
      fifoIf #(.DATA_WIDTH(PHYS_REGS_ADDR_WIDTH), .DEPTH(DISPATCH_WIDTH)) fifo_if;
      fifo fifo(
        .clk,
        .rst,
        .fifo_if(fifo_if.fifo)
      );
    end
  endgenerate
  // TODO: FreeListってdispatchのレーン別に作っちゃうと、
  // 各レーン間でフリーなレジスタの共有ができないからリソースに無駄が出そう
  // （レーン0だけfreeListが空で、他のレーンは開いてるレジスタがたくさんあったりする状況が出そう）
  generate
    for (i = 0; i < DISPATCH_WIDTH; i++) begin
      always_comb begin
        genfifo[i].fifo_if.wr_en = freelist_if.push_en[i];
        genfifo[i].fifo_if.wr_data = freelist_if.push_reg[i];
        freelist_if.full[i] = genfifo[i].fifo_if.full;

        genfifo[i].fifo_if.rd_en = freelist_if.pop_en[i];
        freelist_if.pop_reg[i] = genfifo[i].fifo_if.rd_data;
        freelist_if.empty[i] = genfifo[i].fifo_if.empty;
      end
    end
  endgenerate
endmodule


`default_nettype wire

