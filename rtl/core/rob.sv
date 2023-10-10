`default_nettype none

`include "common.sv"

typedef struct packed {
  logic             entry_valid;
  logic [3:0]       tag;
  logic [7:0]       phys_rd;
  logic [4:0]       arch_rd;
  logic             commit_ready;
} rob_entry_t;

module robEntry #(
) (
  robIf.rob rob_if
);

  rob_entry_t rob_entry [0:ROB_SIZE-1];
  logic [3:0] tag_counter;
  logic [3:0] head;
  logic [3:0] tail;

  // 同時に２命令をFIFOに追加したい．
  // - 1エントリに２命令分格納する
  // - FIFOを１から実装して，enの立っている数によってheadをずらす数を変える
  // 前者のほうが実装は楽だけど，後者のほうがFIFOのサイズが小さくて済む．
  // ただ，後者はロジックが複雑になってクリティカルパスが伸びる可能性がある．
  fifoIf fifo_if#(
    .DATA_WIDTH($bits(rob_entry_t) * 2),
    .DEPTH(16)
  ) (
    .clk(rob_if.clk),
    .rst(rob_if.rst)
  );

  fifo fifo #(
  ) (
    .fifo_if (fifo_if.fifo)
  );
  
  // Append

  // Commit

endmodule
