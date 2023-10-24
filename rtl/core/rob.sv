`default_nettype none

`include "common.sv"
`include "parameters.sv"

typedef struct packed {
  logic             entry_valid;
  logic [parameters::PHYS_REGS_ADDR_WIDTH-1:0] phys_rd;
  logic [4:0]       arch_rd;
  logic             commit_ready;
} rob_entry_t;

module rob #(
) (
  input wire clk, rst,
  robIf.rob rob_if
);
  import parameters::*;
  rob_entry_t rob_entry [0:ROB_SIZE-1][0:DISPATCH_WIDTH-1];
  logic [ROB_ADDR_WIDTH-1:0] head; // 次にdispatchするアドレス
  logic [ROB_ADDR_WIDTH-1:0] tail; // 次にcommitするアドレス
  logic [ROB_ADDR_WIDTH-1:0] num_entry; // 現在のエントリ数

  // reset
  always_ff @(posedge clk) begin
    if (rst) begin
      for (int i = 0; i < ROB_SIZE; i++) begin
        for (int j = 0; j < DISPATCH_WIDTH; j++) begin
          rob_entry[i][j] <= 0;
        end
      end
    end
  end

  // ---------------------------------
  // Dispatch
  // DISPATCH_WIDTH 命令ずつdispatchする
  // ---------------------------------
  // 少なくとも１つのバンクにdispatchされるか
  logic dispatch_en;
  always_comb begin
    dispatch_en = 0;
    for (int w = 0; w < DISPATCH_WIDTH; w++) begin
      dispatch_en |= rob_if.dispatch_en[w];
    end

    // TODO: 条件があっているかの確認
    rob_if.full = num_entry == ROB_ADDR_WIDTH'(ROB_SIZE-1);
  end
  // いずれかのバンクにdispatchされたら head を進める
  always_ff @(posedge clk) begin
    if (dispatch_en) begin
      head <= head + 1;
    end
  end

  always_ff @(posedge clk) begin
    for (int w = 0; w < DISPATCH_WIDTH; w++) begin
      if (rob_if.dispatch_en[w]) begin
        rob_entry[head][w].entry_valid <= 1;
        rob_entry[head][w].phys_rd     <= rob_if.dispatch_phys_rd[w];
        rob_entry[head][w].arch_rd     <= rob_if.dispatch_arch_rd[w];
        rob_entry[head][w].commit_ready<= 0;
        rob_if.dispatch_bank_addr[w]   <= DISPATCH_ADDR_WIDTH'(w);
        rob_if.dispatch_rob_addr[w]    <= head;
      end
    end
  end

  // ---------------------------------
  // Writeback
  // 実行が完了した命令から順にcommit_readyを立てる
  // ---------------------------------
  // 検討事項：同時にwritebackされうる命令数の最大値はDISPATCH_WIDTHとは限らなさそう
  always_ff @(posedge clk) begin
    for (int w = 0; w < DISPATCH_WIDTH; w++) begin
      if (rob_if.writeback_en[w]) begin
        rob_entry[rob_if.writeback_rob_addr[w]][rob_if.writeback_bank_addr[w]].commit_ready <= 1;
      end
    end
  end

  // ---------------------------------
  // Commit
  // DISPATCH_WIDTH 命令ずつcommitする
  // ---------------------------------

  // validなエントリが全てcommit_readyになっているかどうか
  logic tail_commit_ready;
  always_comb begin
    tail_commit_ready = 0;
    // 最低1つのエントリがvalidであること
    for(int w = 0; w < DISPATCH_WIDTH; w++) begin
      tail_commit_ready |= rob_entry[tail][w].entry_valid;
    end
    for(int w = 0; w < DISPATCH_WIDTH; w++) begin
      tail_commit_ready &= rob_entry[tail][w].entry_valid ? rob_entry[tail][w].commit_ready : 1;
    end
  end

  // ↑が成立しているとき、validなエントリをcommitして、エントリを削除する
  always_ff @(posedge clk) begin
    for (int w = 0; w < DISPATCH_WIDTH; w++) begin
      if (tail_commit_ready) begin
        if (rob_entry[tail][w].entry_valid) begin
          rob_if.commit_phys_rd[w] <= rob_entry[tail][w].phys_rd;
          rob_if.commit_arch_rd[w] <= rob_entry[tail][w].arch_rd;
          rob_if.commit_en[w] <= 1;
          rob_entry[tail][w].entry_valid <= 0;
          rob_entry[tail][w].commit_ready<= 0;
        end else begin
          rob_if.commit_en[w] <= 0;
        end
        tail <= tail + 1;
      end else begin
        rob_if.commit_en[w] <= 0;
      end
    end
  end

  // num_entry logic
  always_ff @(posedge clk) begin
    if (!tail_commit_ready && dispatch_en) begin
      num_entry <= num_entry + 1;
    end else if (tail_commit_ready && !dispatch_en) begin
      num_entry <= num_entry - 1;
    end
  end

endmodule
