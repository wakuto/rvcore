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
  robDispatchIf.in dispatch_if,
  robWbIf.in wb_if,
  robCommitIf.out commit_if,
  robOpFetchIf.in op_fetch_if
);
  import parameters::*;
  rob_entry_t rob_entry [0:ROB_SIZE-1][0:DISPATCH_WIDTH-1];
  logic [ROB_ADDR_WIDTH-1:0] head; // 次にdispatchするアドレス
  logic [ROB_ADDR_WIDTH-1:0] tail; // 次にcommitするアドレス
  logic [ROB_ADDR_WIDTH-1:0] num_entry; // 現在のエントリ数

  // dispatch_width個のバンク*rob_size個の中からrs1 == arch_rdとなるエントリを探す
  // rs2 についても同様
  // dispatch_width分だけ繰り返す
  logic [1:0][DISPATH_WIDTH-1:0][ROB_SIZE-1:0] hit [0:DISPATCH_WIDTH-1];

  always_comb begin
    // hit テーブルの作成
    for (int i = 0; i < DISPATCH_WIDTH; i++) begin
      for (int bank = 0; bank < DISPATCH_WIDTH; bank++) begin
        for (int j = 0; j < ROB_SIZE; j++) begin
          hit[0][bank][j][i] = rob_entry[j][bank].entry_valid && (rob_entry[j][bank].arch_rd == op_fetch_if.rs1[i]);
          hit[1][bank][j][i] = rob_entry[j][bank].entry_valid && (rob_entry[j][bank].arch_rd == op_fetch_if.rs2[i]);
        end
      end
    end
    // 2次元 priority encoder... ってコト！？
    // １次元目：ROBの各エントリ、２次元目：各バンク
    // each column
    // if (hit[bank0] && hit[bank1]) phys_rd = rob_entry[bank0].phys_rd
    // else if (hit[bank0]) phys_rd = rob_entry[bank0].phys_rd
    // else if (hit[bank1]) phys_rd = rob_entry[bank1].phys_rd
    // else phys_rd = 0
    for (int j = 0; j < ROB_SIZE; j++) begin
      if (hit[j][bank0] | hit[j][bank1]) begin
        // ともにhitの場合はbank0を優先
        if (hit[j][bank0]) begin
          phys_rd = rob_entry[j][bank0].phys_rd;
          op_fetch_if.valid = rob_entry[j][bank0].commit_ready;
        end else if (hit[j][bank1]) begin
          phys_rd = rob_entry[j][bank1].phys_rd;
          op_fetch_if.valid = rob_entry[j][bank1].commit_ready;
        end else begin
          phys_rd = 0;
        end
        break;
      end
    end
  end


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
      dispatch_en |= dispatch_if.en[w];
    end

    // TODO: 条件があっているかの確認
    dispatch_if.full = num_entry == ROB_ADDR_WIDTH'(ROB_SIZE-1);
  end
  // いずれかのバンクにdispatchされたら head を進める
  always_ff @(posedge clk) begin
    if (dispatch_en) begin
      head <= head + 1;
    end
  end

  always_ff @(posedge clk) begin
    for (int w = 0; w < DISPATCH_WIDTH; w++) begin
      if (dispatch_if.en[w]) begin
        rob_entry[head][w].entry_valid <= 1;
        rob_entry[head][w].phys_rd     <= dispatch_if.phys_rd[w];
        rob_entry[head][w].arch_rd     <= dispatch_if.arch_rd[w];
        rob_entry[head][w].commit_ready<= 0;
        dispatch_if.bank_addr[w]   <= DISPATCH_ADDR_WIDTH'(w);
        dispatch_if.rob_addr[w]    <= head;
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
      if (wb_if.en[w]) begin
        rob_entry[wb_if.rob_addr[w]][wb_if.bank_addr[w]].commit_ready <= 1;
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
          commit_if.phys_rd[w] <= rob_entry[tail][w].phys_rd;
          commit_if.arch_rd[w] <= rob_entry[tail][w].arch_rd;
          commit_if.en[w] <= 1;
          rob_entry[tail][w].entry_valid <= 0;
          rob_entry[tail][w].commit_ready<= 0;
        end else begin
          commit_if.en[w] <= 0;
        end
        tail <= tail + 1;
      end else begin
        commit_if.en[w] <= 0;
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
