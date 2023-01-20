`default_nettype none

module direct_map #(
  parameter LINE_SIZE = 4,
  parameter CACHE_SIZE = 1024
)(
  input  logic        clk,
  input  logic [31:0] addr,
  output logic        hit,
  output logic        dirty,
  output logic [31:0] data,

  input  logic [31:0] write_data,
  input  logic [3:0]  write_strb,
  input  logic        write_valid,
  output logic [31:0] invalidate_addr,
  // 書き込みアクセスの場合アサート
  input  logic        write_access
);
  parameter LINE_NUM = CACHE_SIZE/LINE_SIZE;
  parameter LINE_OFFSET_WIDTH = $clog2(LINE_SIZE);
  parameter SET_ADDR_WIDTH = $clog2(LINE_NUM);
  parameter TAG_WIDTH = 32 - SET_ADDR_WIDTH - LINE_OFFSET_WIDTH;

  logic [LINE_OFFSET_WIDTH-1:0] line_offset;
  logic [SET_ADDR_WIDTH-1:0]    set_addr;
  logic [TAG_WIDTH-1:0]    tag;

  assign line_offset = addr[0 +: LINE_OFFSET_WIDTH];
  assign set_addr    = addr[LINE_OFFSET_WIDTH +: SET_ADDR_WIDTH];
  assign tag         = addr[LINE_OFFSET_WIDTH + SET_ADDR_WIDTH +: TAG_WIDTH];

  logic [(LINE_SIZE << 3)-1:0] data_out;
  logic [31:0] write_mask;

  always_comb begin
    for (int i = 0; i < 4; i = i + 1) begin
      write_mask[(i << 3) +: 8] = {8{write_strb[i]}};
    end
  end

  bram #(
    .DATA_WIDTH(LINE_SIZE << 3),
    .CAPACITY(CACHE_SIZE)
  ) cached_data (
    .clk,
    .addr(set_addr),
    .wen(write_valid),
    .din(write_access ? (data_out & ~write_mask) | (write_data & write_mask) : write_data),
    .dout(data_out)
  );

  // ホントの容量は(TAG_WIDTH+2)*LINE_NUM bit だけど、
  // XLEN*LINE_NUM bit にしちゃおう
  logic [31:0] tag_out;

  bram #(
    .DATA_WIDTH(32),
    .CAPACITY(LINE_NUM*4)
  ) valid_and_tag (
    .clk,
    .addr(set_addr),
    .wen(write_valid),
    .din(32'({write_access, 1'b1, tag})),
    .dout(tag_out)
  );

  // tag_out[TAG_WIDTH]  : line valid flag
  // tag_out[TAG_WIDTH+1]: dirty flag
  assign dirty = tag_out[TAG_WIDTH+1];
  wire valid = tag_out[TAG_WIDTH];
  assign hit = valid & (tag_out[TAG_WIDTH-1:0] == tag);
  assign data = data_out;
  assign invalidate_addr = {tag_out[TAG_WIDTH-1:0], set_addr, line_offset};

  wire _unused = &{1'b0,
                   line_offset,
                   1'b0};
endmodule
`default_nettype wire
