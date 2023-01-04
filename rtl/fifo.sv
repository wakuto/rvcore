`default_nettype none

// 読み込み・書き込みポートが別
module simple_dual_port_ram(
  input  logic        wr_clk,
  input  logic [5:0]  wr_addr,
  input  logic [31:0] wr_din,
  input  logic        wr_en,
  input  logic        rd_clk,
  input  logic [5:0]  rd_addr,
  output logic [31:0] rd_dout,
  input  logic        rd_en
);
  logic [31:0] mem[63:0];

  always_ff @(posedge wr_clk) begin
    if (wr_en) mem[wr_addr] <= wr_din;
  end
  always_ff @(posedge rd_clk) begin
    if (rd_en) rd_dout <= mem[rd_addr];
  end
  
endmodule

// バイナリ・グレイコードの両形式で出力するカウンタ
module bin_gray_counter #(
  parameter ADDR_WIDTH = 6
)(
  input  logic                  clk,
  input  logic                  reset,
  input  logic                  en,
  output logic [ADDR_WIDTH-1:0] bin,
  output logic [ADDR_WIDTH-1:0] gray
);
  
  logic [ADDR_WIDTH-1:0] gray_next;
  logic [ADDR_WIDTH-1:0] bin_next;

  always_comb begin
    gray_next = bin ^ {ADDR_WIDTH{bin >> 1}};
    bin_next = bin + {ADDR_WIDTH{1'b1}};
  end

  always_ff @(posedge clk) begin
    if (reset) begin
      bin  <= 0;
      gray <= 0;
    end
    else if (en) begin
      bin  <= bin_next;
      gray <= gray_next;
    end
  end
endmodule

// 非同期のFIFO
module async_fifo(
  input  logic        w_clk,
  input  logic        wen,
  input  logic [31:0] din,
  output logic        full,

  input  logic        r_clk,
  input  logic        ren,
  output logic [31:0] dout,
  output logic        empty
);
  parameter FULL_THRS = 60;
  parameter EMPTY_THRS = 4;

  logic [5:0] w_addr, r_addr;
  logic [5:0] w_addr_gray, r_addr_gray;

  simple_dual_port_ram ram(
    .wr_clk(w_clk),
    .wr_addr(w_addr),
    .wr_din(din),
    .wr_en(wen),
    .rd_clk(r_clk),
    .rd_addr(r_addr),
    .rd_dout(dout),
    .rd_en(ren)
  );

  bin_gray_counter #(
    .ADDR_WIDTH(6)
  ) r_bgc (
    .clk(r_clk),
    .reset(0),
    .en(ren),
    .bin(r_addr),
    .gray(r_addr_gray)
  );

  bin_gray_counter #(
    .ADDR_WIDTH(6)
  ) w_bgc (
    .clk(w_clk),
    .reset(0),
    .en(wen),
    .bin(w_addr),
    .gray(w_addr_gray)
  );

  function [5:0] gray2bin(
    input logic [5:0] gray
  );
    int i;
    gray2bin[5] = gray[5];
    for (i = 5; i > 0; i = i - 1) begin
      gray2bin[i-1] = gray2bin[i] ^ gray[i-1];
    end
  endfunction

  logic [5:0] w_gray_buff1, w_gray_buff2;
  logic [5:0] r_gray_buff1, r_gray_buff2;

  // write -> read への受け渡し
  always_ff @(posedge r_clk) begin
    w_gray_buff1 <= w_addr_gray;
    w_gray_buff2 <= w_gray_buff1;
  end

  // read -> write への受け渡し
  always_ff @(posedge w_clk) begin
    r_gray_buff1 <= r_addr_gray;
    r_gray_buff2 <= r_gray_buff1;
  end

  logic [6:0] w_addr_diff, r_addr_diff;

  assign w_addr_diff = w_addr - gray2bin(r_gray_buff2);
  assign r_addr_diff = gray2bin(w_gray_buff2) - r_addr;

  assign full  = w_addr_diff > FULL_THRS;
  assign empty = r_addr_diff < EMPTY_THRS;

endmodule
`default_nettype wire
