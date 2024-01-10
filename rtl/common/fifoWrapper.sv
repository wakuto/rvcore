`default_nettype none
module fifoWrapper(
  input  wire         clk, rst,
  input  wire         wr_en, rd_en,
  input  wire  [31:0] wr_data,
  output logic [31:0] rd_data,
  output logic        empty, full
);

  fifoIf #(.DATA_WIDTH(32), .DEPTH(16)) fifo_if();

  fifo fifo (.clk, .rst,.fifo_if(fifo_if.fifo));

  always_comb begin
    fifo_if.wr_en = wr_en;
    fifo_if.rd_en = rd_en;
    fifo_if.wr_data = wr_data;
    rd_data = fifo_if.rd_data;
    empty = fifo_if.empty;
    full = fifo_if.full;
  end

endmodule
`default_nettype wire
