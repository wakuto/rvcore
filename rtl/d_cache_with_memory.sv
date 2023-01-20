`default_nettype none

module d_cache_with_memory (
  input  logic        reset,

  // cpu側
  input  logic        clk,
  input  logic [31:0] addr,
  input  logic        mem_wen,
  output logic [31:0] data_out,
  output logic        data_read_valid,
  input  logic [31:0] data_in,
  input  logic [3:0]  data_in_strb,
  output logic        data_write_ready
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

  // 書き込み用ポート
  logic [31:0] awaddr;
  logic [2:0]  awprot;
  logic        awvalid;
  logic        awready;

  logic [31:0] wdata;
  logic [3:0]  wstrb;
  logic        wvalid;
  logic        wready;

  logic [1:0]  bresp;
  logic        bvalid;
  logic        bready;

  d_cache d_cache (
    .reset,
    .clk,
    .addr,
    .mem_wen,
    .data_out,
    .data_read_valid,
    .data_in,
    .data_in_strb,
    .data_write_ready,

    .aclk,
    .areset,
    .arvalid,
    .arready,
    .araddr,
    .arprot,

    .rvalid,
    .rready,
    .rdata,
    .rresp,

    .awaddr,
    .awprot,
    .awvalid,
    .awready,

    .wdata,
    .wstrb,
    .wvalid,
    .wready,

    .bresp,
    .bvalid,
    .bready
  );

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

    .awaddr,
    .awprot,
    .awvalid,
    .awready,

    .wdata,
    .wstrb,
    .wvalid,
    .wready,

    .bresp,
    .bvalid,
    .bready
  );

endmodule

`default_nettype wire

