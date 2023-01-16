/* @@@@@@@@@@@@ Simulation only @@@@@@@@@@@@ */
`default_nettype none

module axi_memory(
  // 読み出し用ポート
  input  logic        aclk,
  input  logic        areset,
  input  logic        arvalid,
  output logic        arready,
  input  logic [31:0] araddr,
  input  logic [2:0]  arprot,

  output logic        rvalid,
  input  logic        rready,
  output logic [31:0] rdata,
  output logic [1:0]  rresp

  // 書き込み用ポート
  input  logic [31:0] awaddr,
  input  logic [2:0]  awprot,
  input  logic        awvalid,
  output logic        awready,

  input  logic [31:0] wdata,
  input  logic [3:0]  wstrb,
  input  logic        wvalid,
  output logic        wready,

  output logic [1:0]  bresp,
  output logic        bvalid,
  input  logic        bready,
);
  assign rresp = 2'b00; // OK

  logic [31:0] memory[4095:0];

  logic [31:0] counter;
  
  initial begin
    counter <= 0;
    int i = 0;
    for (i = 0; i < 4096; i++) begin
      memory[i] = 0;
    end
  end

  // 読み出し部
  logic next_arready, next_rvalid;
  logic [31:0] next_rdata;
  logic [31:0] addr;

  always_comb begin
    if (arvalid & arready) begin
      next_arready = 1'b0;
    end else if (arvalid) begin
      next_arready = 1'b1;
    end

    if (counter >= 30) begin
      next_rvalid = 1'b1;
    end

    if (rvalid & rready) begin
      next_rvalid = 1'b0;
    end
  end

  always_ff @(posedge aclk) begin
    if (areset) begin
      rvalid <= 1'b0;
      arready <= 1'b0;
      addr <= 32'b0;
      rdata <= 32'b0;
    end else begin
      rvalid <= next_rvalid;
      arready <= next_arready;

      if (arvalid) begin
        addr <= araddr;
      end
      if (next_rvalid) begin
        rdata <= memory[addr];
      end
    end
  end

  // 書き込み部
  logic next_wready, next_awready, next_bvalid;
  logic [1:0]  next_bresp;
endmodule
`default_nettype wire
/* @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ */
