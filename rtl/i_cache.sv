`default_nettype none

module i_cache (
  input  logic        reset,
  // cpu側
  input  logic        clk,
  input  logic [31:0] addr,
  output logic [31:0] data,
  output logic        valid,

  // memory側 axi4 lite(read)
  input  logic        axi_aclk,
  input  logic        axi_areset,
  output logic        axi_arvalid,
  input  logic        axi_arready,
  output logic [31:0] axi_araddr,
  output logic [2:0]  axi_arprot,

  input  logic        axi_rvalid,
  output logic        axi_rready,
  input  logic [31:0] axi_rdata,
  input  logic [1:0]  axi_rresp
);
  assign axi_arprot = 3'b101; // instruction & secure & privileged

  logic cache_miss;

  // cpu側転送
  always_ff @(posedge clk) begin
    if (reset) begin
    end else begin
    end
  end


  logic next_arvalid, next_rready;

  // メモリ読み込み制御
  always_comb begin
    if (cache_miss & ~axi_arvalid)
      next_arvalid = 1'b1;

    if (axi_arready)
      next_arvalid = 1'b0;

    if (axi_rvalid)
      next_rready = 1'b1;
    
    if (axi_rready)
      next_rready = 1'b0;
  end

  always_ff @(posedge axi_aclk) begin
    if (axi_areset) begin
      axi_arvalid <= 1'b0;
      axi_araddr <= 1'b0;
      axi_rready <= 1'b0;
    end else begin
      axi_arvalid <= next_arvalid;
      axi_rready <= next_rready;
    end
  end

endmodule
`default_nettype wire
