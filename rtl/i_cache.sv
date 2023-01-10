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

  // 4 word = 16Byte = 1Line = 4bit
  // 512Byte = 32Line = 5bit
  logic        valid [31:0];
  logic [22:0] tag [31:0];        // 32bit - 5bit(line addr) - 4bit(line offset)
  logic [32*4-1:0]  cache [31:0]; // 4word * 32Line(=5bit addr)

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
  // instruction fetch!!!
  // valid = 0;
  // do_cache_search()
  // if (is_cache_hit) {
  //   valid = 1;
  //   return instruction;
  // } else {
  //   data_fetch_from_memory();
  //   memory_write_to_fifo();
  //   cache_append_from_fifo();
  //   valid = 1;
  //   return instruction;
  // }

endmodule

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
  parameter ADDR_WIDTH = $clog2(CAPACITY/DATA_WIDTH);

  (* ram_style = "block" *)
  logic [DATA_WIDTH-1:0] ram [(1 << ADDR_WIDTH)-1:0];

  always_ff @(posedge clk) begin
    if (wen) ram[addr] <= din;
    dout <= ram[addr];
  end
  
endmodule

module direct_map #(
  parameter LINE_SIZE = 16,
  parameter CACHE_SIZE = 1024
)(
  input  logic clk,
  input  logic req_addr,
  output logic valid,
  output logic hit,
  output logic [31:0] data
);
  parameter LINE_NUM = CACHE_SIZE/LINE_SIZE;
  parameter LINE_OFFSET_WIDTH = $clog2(LINE_SIZE);
  parameter SET_ADDR_WIDTH = $clog2(LINE_NUM);
  parameter TAG_WIDTH = 32 - SET_ADDR_WIDTH - LINE_OFFSET_WIDTH;

  logic [LINE_OFFSET_WIDTH-1:0] line_offset;
  logic [SET_ADDR_WIDTH-1:0]    set_addr;
  logic [TAG_WIDTH-1:0]    tag;

  assign line_offset = req_addr[0 +: LINE_OFFSET_WIDTH];
  assign set_addr    = req_addr[LINE_OFFSET_WIDTH +: SET_ADDR_WIDTH];
  assign tag         = req_addr[LINE_OFFSET_WIDTH + SET_ADDR_WIDTH +: TAG_WIDTH];

  logic [(LINE_SIZE << 3)-1:0] data_out;

  bram #(
    .DATA_WIDTH(LINE_SIZE << 3),
    .CAPACITY(CACHE_SIZE)
  ) cached_data (
    .clk,
    .addr(set_addr),
    .wen(1'b0),
    .din(0),
    .dout(data_out)
  );

  // ホントの容量は(TAG_WIDTH+1)*LINE_NUM bit だけど、
  // XLEN*LINE_NUM bit にしちゃおう
  logic [31:0] tag_out;

  bram #(
    .DATA_WIDTH(32),
    .CAPACITY(LINE_NUM*4)
  ) valid_and_tag (
    .clk,
    .addr(set_addr),
    .wen(1'b0),
    .din(0),
    .dout(tag_out)
  );

  assign hit = tag_out[TAG_WIDTH] & (tag_out[TAG_WIDTH-1:0] == tag);
  assign data = data_out;

  always_ff @(posedge clk) begin
  end

endmodule
`default_nettype wire
