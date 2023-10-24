`default_nettype none

module fifo #(
) (
  input clk, rst,
  fifoIf.fifo fifo_if
);
  localparam DATA_WIDTH = fifo_if.DATA_WIDTH;
  localparam DEPTH = fifo_if.DEPTH;
  localparam ADDR_WIDTH = $clog2(DEPTH);
  logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];
  logic [ADDR_WIDTH:0] count;
  logic [ADDR_WIDTH-1:0] wr_ptr;
  logic [ADDR_WIDTH-1:0] rd_ptr;

  assign fifo_if.empty = (count == 0);
  assign fifo_if.full =  (count == (ADDR_WIDTH+1)'(DEPTH));

  always_ff @(posedge clk) begin
    if (rst) begin
      wr_ptr <= 0;
      rd_ptr <= 0;
    end else begin
      if (fifo_if.wr_en && !fifo_if.full) begin
        mem[wr_ptr] <= fifo_if.wr_data;
        wr_ptr <= wr_ptr + ADDR_WIDTH'(1);
        if (!fifo_if.rd_en) begin
          count <= count + ADDR_WIDTH'(1);
        end
      end

      if (fifo_if.rd_en && !fifo_if.empty) begin
        fifo_if.rd_data <= mem[rd_ptr];
        rd_ptr <= rd_ptr + ADDR_WIDTH'(1);
        if (!fifo_if.wr_en) begin
          count <= count - ADDR_WIDTH'(1);
        end
      end
    end
  end

endmodule

`default_nettype wire
