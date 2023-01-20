`default_nettype none

module set_asiciative #(
  parameter LINE_SIZE = 4,
  parameter WAY_NUM = 2,
  parameter CACHE_SIZE = 1024
)(
  input  logic        clk,
  input  logic [31:0] req_addr,
  output logic        hit,
  output logic [31:0] data,

  input  logic [31:0] write_addr,
  input  logic [31:0] write_data,
  input  logic        write_valid
);
  parameter LINE_NUM = CACHE_SIZE/LINE_SIZE;
  parameter SET_NUM = LINE_NUM/WAY_NUM;
  parameter LINE_OFFSET_WIDTH = $clog2(LINE_SIZE);
  parameter SET_ADDR_WIDTH = $clog2(SET_NUM);
  parameter TAG_WIDTH = 32 - SET_ADDR_WIDTH - LINE_OFFSET_WIDTH;

  logic [LINE_OFFSET_WIDTH-1:0] req_line_offset, write_line_offset;
  logic [SET_ADDR_WIDTH-1:0]    req_set_addr, write_set_addr;
  logic [TAG_WIDTH-1:0]    req_tag, write_tag;

  assign req_line_offset = req_addr[0 +: LINE_OFFSET_WIDTH];
  assign req_set_addr    = req_addr[LINE_OFFSET_WIDTH +: SET_ADDR_WIDTH];
  assign req_tag         = req_addr[LINE_OFFSET_WIDTH + SET_ADDR_WIDTH +: TAG_WIDTH];

  assign write_line_offset = write_addr[0 +: LINE_OFFSET_WIDTH];
  assign write_set_addr    = write_addr[LINE_OFFSET_WIDTH +: SET_ADDR_WIDTH];
  assign write_tag         = write_addr[LINE_OFFSET_WIDTH + SET_ADDR_WIDTH +: TAG_WIDTH];

  logic [(LINE_SIZE << 3)-1:0] data_out;

  bram #(
    .DATA_WIDTH(LINE_SIZE << 3),
    .CAPACITY(CACHE_SIZE)
  ) cached_data (
    .clk(clk),
    .addr(write_valid ? write_set_addr : req_set_addr),
    .wen(write_valid),
    .din(write_data),
    .dout(data_out)
  );

  // ホントの容量は(TAG_WIDTH+1)*LINE_NUM bit だけど、
  // XLEN*LINE_NUM bit にしちゃおう
  logic [31:0] tag_out [WAY_NUM-1:0];
  logic write_valid [WAY_NUM-1:0];

  // 入れ替えるwayの決定
  // if (all valid) lru;
  // else if (all invalid) way0
  // else if (way0) way1
  // else           way0
  // アクセスした方に1, それ以外に0を記入(recentry used)
  always_comb begin
    
  end
  generate
    for (int i = 0; i < WAY_NUM; i = i + 1) begin
      bram #(
        .DATA_WIDTH(32),
        .CAPACITY(SET_NUM*4)
      ) way (
        .clk(clk),
        .addr(write_valid ? write_set_addr : req_set_addr),
        .wen(write_valid),
        .din(32'({1'b1, write_tag})),
        .dout(tag_out[i])
      );
    end
  endgenerate

  // tag_out[TAG_WIDTH]: line valid flag
  wire valid = tag_out[TAG_WIDTH];
  wire [TAG_WIDTH-1:0] tag = tag_out[TAG_WIDTH-1:0];
  assign hit = valid & (tag == req_tag);
  assign data = data_out;

  wire _unused = &{1'b0,
                   req_line_offset,
                   write_line_offset,
                   1'b0};
endmodule
`default_nettype wire

