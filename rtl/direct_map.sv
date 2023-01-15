`default_nettype none

module direct_map #(
  parameter LINE_SIZE = 4,
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
  parameter LINE_OFFSET_WIDTH = $clog2(LINE_SIZE);
  parameter SET_ADDR_WIDTH = $clog2(LINE_NUM);
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
  logic [31:0] tag_out;
  logic [TAG_WIDTH-1:0] req_tag_buf;
  always_ff @(posedge clk) begin
    req_tag_buf <= req_tag;
  end

  bram #(
    .DATA_WIDTH(32),
    .CAPACITY(LINE_NUM*4)
  ) valid_and_tag (
    .clk(clk),
    .addr(write_valid ? write_set_addr : req_set_addr),
    .wen(write_valid),
    .din(32'({1'b1, write_tag})),
    .dout(tag_out)
  );

  // tag_out[TAG_WIDTH]: line valid flag
  assign hit = tag_out[TAG_WIDTH] & (tag_out[TAG_WIDTH-1:0] == req_tag_buf);
  assign data = data_out;

  wire _unused = &{1'b0,
                   req_line_offset,
                   write_line_offset,
                   1'b0};
endmodule
`default_nettype wire
