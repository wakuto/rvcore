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

  initial begin 
    int i = 0;
    for (i = 0; i < 1 << ADDR_WIDTH; i = i + 1) begin
      ram[i] = 0;
    end
  end

  (* ram_style = "block" *)
  logic [DATA_WIDTH-1:0] ram [(1 << ADDR_WIDTH)-1:0];

  // logic [ADDR_WIDTH-1:0] addr_buf;
  // logic wen_buf;
  always_ff @(posedge clk) begin
    if (wen) ram[addr] <= din;
    // addr_buf <= addr;
    // dout <= ram[addr];
  end

  // yabasou…
  assign dout = ram[addr];
endmodule

`default_nettype wire

