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
  output logic [1:0]  rresp,

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
  input  logic        bready
);
  assign rresp = 2'b00; // OK
  assign bresp = 2'b00;

  logic [31:0] memory[4095:0];

  logic [31:0] counter;
  
  initial begin
    counter = 32'd0;
    for (int i = 0; i < 4096; i++) begin
      memory[i] = 0;
    end
  end

  // 読み出し部
  logic next_arready, next_rvalid;
  logic [31:0] addr;
  logic addr_ready_flag;

  always_comb begin
    // set default value
    next_arready = 1'b0;
    next_rvalid = 1'b0;

    if (arvalid & arready) begin
      next_arready = 1'b0;
    end else if (arvalid) begin
      next_arready = 1'b1;
    end

    if (counter >= 30) begin
      next_rvalid = 1'b1;
    end else begin
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

      // レイテンシ再現
      if (arvalid) begin
        addr_ready_flag <= 1'b1;
      end
      if (addr_ready_flag) begin
        counter <= counter + 32'd1;
      end
      if (rvalid & rready) begin
        addr_ready_flag <= 1'b0;
        counter <= 32'd0;
      end
    end
  end

  // 書き込み部
  logic next_wready, next_awready, next_bvalid;

  always_comb begin
    // set default value
    next_awready = 1'b0;
    next_wready = 1'b0;
    next_bvalid = 1'b0;

    if (awvalid & awready) begin
      next_awready = 1'b0;
    end else if (awvalid) begin
      next_awready = 1'b1;
    end

    if (wvalid & wready) begin
      next_wready = 1'b0;
      next_bvalid = 1'b0;
    end else if (wvalid) begin
      next_wready = 1'b1;
    end

    if (bvalid & bready) begin
      next_bvalid = 1'b0;
    end
  end

  logic [31:0] write_addr;
  always_ff @(posedge aclk) begin
    if (areset) begin
      awready <= 1'b0;
      wready <= 1'b0;
      bvalid <= 1'b0;
    end else begin
      awready <= next_awready;
      wready <= next_wready;
      bvalid <= next_bvalid;

      if (awvalid) begin
        write_addr <= awaddr;
      end

      if (wvalid) begin
        memory[write_addr] <= wdata;
      end
    end
  end

  wire _unused = &{1'b0,
                   wstrb,
                   write_addr,
                   addr,
                   arprot,
                   awprot,
                   1'b0};
endmodule
`default_nettype wire
/* @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ */
