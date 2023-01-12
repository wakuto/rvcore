`default_nettype none

module bram #(
  parameter DATA_WIDTH = 32,
  parameter CAPACITY = 1024
)(
  input  logic                  clk,
  input  logic [ADDR_WIDTH-1:0] addr,
  input  logic                  wen,
  input  logic [DATA_WIDTH-1:0] din,
  output logic [DATA_WIDTH-1:0] dout
);
  parameter ADDR_WIDTH = $clog2((CAPACITY << 3)/DATA_WIDTH);

  (* ram_style = "block" *)
  logic [DATA_WIDTH-1:0] ram [(1 << ADDR_WIDTH)-1:0];

  always_ff @(posedge clk) begin
    if (wen) ram[addr] <= din;
    dout <= ram[addr];
  end
endmodule

`default_nettype wire

