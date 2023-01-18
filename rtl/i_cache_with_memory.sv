`default_nettype none

module i_cache_with_memory (
  input  logic        reset,

  // cpu側
  input  logic        clk,
  input  logic [31:0] addr,
  output logic [31:0] data,
  output logic        data_valid
);
  // memory側 axi4 lite
  // 読み出し用ポート
  logic        aclk;
  logic        areset;

  assign aclk = clk;
  assign areset = reset;

  logic        arvalid;
  logic        arready;
  logic [31:0] araddr;
  logic [2:0]  arprot;

  logic        rvalid;
  logic        rready;
  logic [31:0] rdata;
  logic [1:0]  rresp;

  i_cache i_cache (
    .reset,
    .clk(clk),
    .addr,
    .data,
    .data_valid,

    .aclk(aclk),
    .areset,
    .arvalid,
    .arready,
    .araddr,
    .arprot,

    .rvalid,
    .rready,
    .rdata,
    .rresp
  );

  logic awready, wready, bvalid;
  logic [1:0] bresp;

  axi_memory axi_memory (
    .aclk(~aclk),
    .areset,
    .arvalid,
    .arready,
    .araddr,
    .arprot,

    .rvalid,
    .rready,
    .rdata,
    .rresp,

    .awaddr(0),
    .awprot(0),
    .awvalid(0),
    .awready,

    .wdata(0),
    .wstrb(0),
    .wvalid(0),
    .wready,

    .bresp,
    .bvalid,
    .bready(0)
  );

  wire _unused = &{
    1'b0,
    awready,
    wready,
    bresp,
    bvalid,
    1'b0
  };

endmodule

`default_nettype wire


