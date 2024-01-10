`default_nettype none

`include "common.sv"
`include "parameters.sv"

typedef struct packed {
  logic             entry_valid;
  logic [parameters::PHYS_REGS_ADDR_WIDTH-1:0] phys_rd;
  logic [4:0]       arch_rd;
  logic             commit_ready;
  logic [31:0]      pc;
  logic [31:0]      instr;
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
  logic [DISPATCH_WIDTH-1:0][ROB_SIZE-1:0] hit_rs1 [0:DISPATCH_WIDTH-1];
  logic [DISPATCH_WIDTH-1:0][ROB_SIZE-1:0] hit_rs2 [0:DISPATCH_WIDTH-1];
  
  function logic forwarding_check(
    logic valid [0:DISPATCH_WIDTH-1], 
    logic [PHYS_REGS_ADDR_WIDTH-1:0] phys_rd [0:DISPATCH_WIDTH-1],
    logic [PHYS_REGS_ADDR_WIDTH-1:0] phys_rs
  );
    forwarding_check = 0;
    for (int i = 0; i < DISPATCH_WIDTH; i++) begin
      forwarding_check = forwarding_check || (valid[i] && (phys_rd[i] == phys_rs));
    end
  endfunction

  always_comb begin
    // hit テーブルの作成
    for (int i = 0; i < DISPATCH_WIDTH; i++) begin
      for (int bank = 0; bank < DISPATCH_WIDTH; bank++) begin
        for (int j = 0; j < ROB_SIZE; j++) begin
          hit_rs1[i][bank][j] = rob_entry[j][bank].entry_valid && (rob_entry[j][bank].phys_rd == op_fetch_if.phys_rs1[i]);
          hit_rs2[i][bank][j] = rob_entry[j][bank].entry_valid && (rob_entry[j][bank].phys_rd == op_fetch_if.phys_rs2[i]);
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

    for (int bank = 0; bank < DISPATCH_WIDTH; bank++) begin
      // rs1
      for (int j = 0; j < ROB_SIZE; j++) begin
        // ほんとは以下のif文を任意のbank数分だけ作りたいけど
        // 実装面倒なのでbank0とbank1のみ対応
        // if (|hit[j]) begin
        if (hit_rs1[bank][0][tail-(ROB_ADDR_WIDTH)'(j)] | hit_rs1[bank][1][tail-(ROB_ADDR_WIDTH)'(j)]) begin
          // ともにhit_rs1の場合はbank0を優先
          if (hit_rs1[bank][0][tail-(ROB_ADDR_WIDTH)'(j)]) begin
            op_fetch_if.rs1_valid[bank] = forwarding_check(wb_if.en, wb_if.phys_rd, op_fetch_if.phys_rs1[bank]) || rob_entry[tail-(ROB_ADDR_WIDTH)'(j)][0].commit_ready;
          end else if (hit_rs1[bank][1][tail-(ROB_ADDR_WIDTH)'(j)]) begin
            op_fetch_if.rs1_valid[bank] = forwarding_check(wb_if.en, wb_if.phys_rd, op_fetch_if.phys_rs1[bank]) || rob_entry[tail-(ROB_ADDR_WIDTH)'(j)][1].commit_ready;
          end else begin
            op_fetch_if.rs1_valid[bank] = 0;
          end
          break;
        end else begin
          op_fetch_if.rs1_valid[bank] = 1;
        end
      end

      // rs2
      for (int j = 0; j < ROB_SIZE; j++) begin
        // if (|hit[j]) begin
        if (hit_rs2[bank][0][tail-(ROB_ADDR_WIDTH)'(j)] | hit_rs2[bank][1][tail-(ROB_ADDR_WIDTH)'(j)]) begin
          // ともにhit_rs2の場合はbank0を優先
          if (hit_rs2[bank][0][tail-(ROB_ADDR_WIDTH)'(j)]) begin
            op_fetch_if.rs2_valid[bank] = forwarding_check(wb_if.en, wb_if.phys_rd, op_fetch_if.phys_rs2[bank]) || rob_entry[tail-(ROB_ADDR_WIDTH)'(j)][0].commit_ready;
          end else if (hit_rs2[bank][1][tail-(ROB_ADDR_WIDTH)'(j)]) begin
            op_fetch_if.rs2_valid[bank] = forwarding_check(wb_if.en, wb_if.phys_rd, op_fetch_if.phys_rs2[bank]) || rob_entry[tail-(ROB_ADDR_WIDTH)'(j)][1].commit_ready;
          end else begin
            op_fetch_if.rs2_valid[bank] = 0;
          end
          break;
        end else begin
          op_fetch_if.rs2_valid[bank] = 1;
        end
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
    
    for (int w = 0; w < DISPATCH_WIDTH; w++) begin
      dispatch_if.bank_addr[w] = DISPATCH_ADDR_WIDTH'(w);
      dispatch_if.rob_addr[w]  = head;
    end
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
        rob_entry[head][w].pc          <= dispatch_if.pc[w];
        rob_entry[head][w].instr       <= dispatch_if.instr[w];
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
          commit_if.en[w] <= rob_entry[tail][w].commit_ready;
          commit_if.pc[w] <= rob_entry[tail][w].pc;
          commit_if.instr[w] <= rob_entry[tail][w].instr;
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
