`default_nettype none

`include "common.sv"

typedef struct packed {
  logic             entry_valid;
  logic [3:0]       tag;
  common::alu_cmd_t alu_cmd;
  logic [31:0]      op1_data, op2_data;
  logic             op1_valid, op2_valid;
  logic [7:0]       phys_rd;
} issue_queue_entry_t;


module issueQueue #(
  parameter ISSUE_QUEUE_SIZE = 8
) (
  input wire clk,
  input wire rst,
  issueQueueIf.issue_din ru_issue_if,
  issueQueueIf.issue issue_ex_if
);
  localparam DEBUG = 0;
  logic [3:0] tag_counter;
  localparam ISSUE_QUEUE_ADDR_WIDTH = $clog2(ISSUE_QUEUE_SIZE);
  issue_queue_entry_t issue_queue [0:ISSUE_QUEUE_SIZE-1];

  // verilator lint_off UNUSEDSIGNAL
  function entry_valid (input issue_queue_entry_t entry);
    entry_valid = entry.entry_valid && entry.op1_valid && entry.op2_valid;
  endfunction
  // verilator lint_on UNUSEDSIGNAL

  // Issue
  // validなentryのうちtagが小さい方を選ぶ
  // 両方invalidなら0を返す
  // アドレスと issue_queue_entry_t を結合して返す
  function logic [ISSUE_QUEUE_ADDR_WIDTH + $bits(issue_queue_entry_t) - 1:0] chose_entry (
    input issue_queue_entry_t entry_1,
    input issue_queue_entry_t entry_2,
    input logic [ISSUE_QUEUE_ADDR_WIDTH-1:0] addr_1,
    input logic [ISSUE_QUEUE_ADDR_WIDTH-1:0] addr_2
  );
    if (entry_valid(entry_1) && entry_valid(entry_2)) begin
      if (entry_1.tag[3] == entry_2.tag[3]) begin
        if (entry_1.tag < entry_2.tag) begin
          chose_entry[0 +: $bits(issue_queue_entry_t)] = entry_1;
          chose_entry[$bits(issue_queue_entry_t) +: ISSUE_QUEUE_ADDR_WIDTH] = addr_1;
        end else begin
          chose_entry[0 +: $bits(issue_queue_entry_t)] = entry_2;
          chose_entry[$bits(issue_queue_entry_t) +: ISSUE_QUEUE_ADDR_WIDTH] = addr_2;
        end
      end else begin
        if (entry_1.tag < entry_2.tag) begin
          chose_entry[0 +: $bits(issue_queue_entry_t)] = entry_2;
          chose_entry[$bits(issue_queue_entry_t) +: ISSUE_QUEUE_ADDR_WIDTH] = addr_2;
        end else begin
          chose_entry[0 +: $bits(issue_queue_entry_t)] = entry_1;
          chose_entry[$bits(issue_queue_entry_t) +: ISSUE_QUEUE_ADDR_WIDTH] = addr_1;
        end
      end
    end else if (entry_valid(entry_1)) begin
      chose_entry[0 +: $bits(issue_queue_entry_t)] = entry_1;
      chose_entry[$bits(issue_queue_entry_t) +: ISSUE_QUEUE_ADDR_WIDTH] = addr_1;
    end else if (entry_valid(entry_2)) begin
      chose_entry[0 +: $bits(issue_queue_entry_t)] = entry_2;
      chose_entry[$bits(issue_queue_entry_t) +: ISSUE_QUEUE_ADDR_WIDTH] = addr_2;
    end else begin
      chose_entry[0 +: $bits(issue_queue_entry_t)] = 0;
      chose_entry[$bits(issue_queue_entry_t) +: ISSUE_QUEUE_ADDR_WIDTH] = addr_2;
    end
  endfunction


  // 発行する命令の決定
  // 検索のための比較回路をツリーで構成
  issue_queue_entry_t search_tree [ 0 : ISSUE_QUEUE_SIZE - 2 ];
  logic [ISSUE_QUEUE_ADDR_WIDTH-1:0] addr_search_tree [ 0 : ISSUE_QUEUE_SIZE - 2 ];
  // verilator lint_off UNUSEDSIGNAL
  issue_queue_entry_t issue_entry;
  // verilator lint_on UNUSEDSIGNAL
  localparam half = ISSUE_QUEUE_SIZE >> 1;
  int offset [0:ISSUE_QUEUE_ADDR_WIDTH];
  always_comb begin
    for (int _i = 0; _i < half; _i++) begin
      {addr_search_tree[_i], search_tree[_i]} = chose_entry(
        issue_queue[(_i << 1)],
        issue_queue[(_i << 1) + 1],
        ISSUE_QUEUE_ADDR_WIDTH'(_i << 1),
        ISSUE_QUEUE_ADDR_WIDTH'(_i << 1) + 1
      );
    end
    offset[1] = half;
    for (int _j = 2; _j < ISSUE_QUEUE_ADDR_WIDTH+1; _j++) begin
      for (int _i = offset[_j-1]; _i < offset[_j-1] + (ISSUE_QUEUE_SIZE >> _j); _i++) begin
        {addr_search_tree[_i], search_tree[_i]} = chose_entry(
          search_tree[((_i-half) << 1)],
          search_tree[((_i-half) << 1) + 1],
          addr_search_tree[((_i-half) << 1)],
          addr_search_tree[((_i-half) << 1) + 1]
        );
      end
      offset[_j] = offset[_j-1] + (ISSUE_QUEUE_SIZE >> _j);
    end
  end

/*
  // unsupported
  function automatic issue_queue_entry_t get_entry (
    input issue_queue_entry_t entry [0:ISSUE_QUEUE_SIZE-1],
    input logic [ISSUE_QUEUE_ADDR_WIDTH-1:0] head,
    input logic [ISSUE_QUEUE_ADDR_WIDTH-1:0] tail
  );
    if (tail - head + 1 > 2) begin
      get_entry = chose_entry(
        get_entry(entry, head, (head + tail) >> 1),
        get_entry(entry, ((head + tail) >> 1) + 1, tail)
      );
    end else begin
      get_entry = chose_entry(entry[head], entry[tail]);
    end
  endfunction
*/

  always_comb begin
    issue_entry = search_tree[ISSUE_QUEUE_SIZE - 2];
    issue_ex_if.alu_cmd_valid = entry_valid(issue_entry);
    issue_ex_if.issue_alu_cmd = issue_entry.alu_cmd;
    // issue_ex_if.alu_cmd = common::alu_cmd_t'(0);
    issue_ex_if.issue_op1 = issue_entry.op1_data;
    issue_ex_if.issue_op2 = issue_entry.op2_data;
    issue_ex_if.phys_rd = issue_entry.phys_rd;
  end

  
  // Issue queueの空いている領域の検索
  // Dispatch
  // return: {free, idx[ISSUE_QUEUE_ADDR_WIDTH-1:0]}
  function logic [ISSUE_QUEUE_ADDR_WIDTH:0] chose_free(
    input logic [ISSUE_QUEUE_ADDR_WIDTH-1:0] addr_1, addr_2,
    input logic                            free_1, free_2
  );
    chose_free[ISSUE_QUEUE_ADDR_WIDTH] = free_1 | free_2;
    chose_free[ISSUE_QUEUE_ADDR_WIDTH-1:0] = free_1 ? addr_1 : addr_2;
  endfunction

  // verilator lint_off UNUSEDSIGNAL
  function logic get_free(input logic [ISSUE_QUEUE_ADDR_WIDTH:0] addr);
    get_free = addr[ISSUE_QUEUE_ADDR_WIDTH];
  endfunction

  function logic [ISSUE_QUEUE_ADDR_WIDTH-1:0] get_idx(
    input logic [ISSUE_QUEUE_ADDR_WIDTH:0] addr
  );
    get_idx = addr[ISSUE_QUEUE_ADDR_WIDTH-1:0];
  endfunction
  // verilator lint_on UNUSEDSIGNAL

  logic [ISSUE_QUEUE_ADDR_WIDTH:0] free_search_tree [ 0 : ISSUE_QUEUE_SIZE - 2 ];
  logic [ISSUE_QUEUE_ADDR_WIDTH-1:0] free_entry_idx;
  int free_offset [0:ISSUE_QUEUE_ADDR_WIDTH];
  always_comb begin
    for (int _i = 0; _i < half; _i++) begin
      free_search_tree[_i] = chose_free(
        ISSUE_QUEUE_ADDR_WIDTH'(_i << 1),
        ISSUE_QUEUE_ADDR_WIDTH'(_i << 1) + 1,
        !issue_queue[(_i << 1)].entry_valid, !issue_queue[(_i << 1) + 1].entry_valid
      );
    end
    free_offset[1] = half;
    for (int _j = 2; _j < ISSUE_QUEUE_ADDR_WIDTH+1; _j++) begin
      for (int _i = free_offset[_j-1]; _i < free_offset[_j-1] + (ISSUE_QUEUE_SIZE >> _j); _i++) begin
        free_search_tree[_i] = chose_free(
          get_idx (free_search_tree[((_i-half) << 1)]),
          get_idx (free_search_tree[((_i-half) << 1) + 1]),
          get_free(free_search_tree[((_i-half) << 1)]),
          get_free(free_search_tree[((_i-half) << 1) + 1])
        );
      end
      free_offset[_j] = free_offset[_j-1] + (ISSUE_QUEUE_SIZE >> _j);
    end
    free_entry_idx = get_idx(free_search_tree[ISSUE_QUEUE_SIZE - 2]);
  end

  assign ru_issue_if.full = !get_free(free_search_tree[ISSUE_QUEUE_SIZE - 2]);

  always_ff @(posedge clk) begin
    if (rst) begin
      for (int i = 0; i < ISSUE_QUEUE_SIZE; i++) begin
        issue_queue[i].entry_valid <= 1'b0;
        tag_counter <= 4'b0;
      end
      if (DEBUG) $display("[verilog] reset now");
    end else begin
      // Debug
      if (DEBUG) $display("din: %0x, v = %x, op1 = %x, op2 = %x, phys_rd = %x", ru_issue_if, ru_issue_if.write_enable, ru_issue_if.op1, ru_issue_if.op2, ru_issue_if.phys_rd);
      for (int i = 0; i < ISSUE_QUEUE_SIZE; i++) begin
        if (DEBUG) $write("issue_queue[%0x]: %0x, v = %x, tag = %x alu_cmd = %x, op1_v = %x, op2_v = %x\n", i, issue_queue[i], issue_queue[i].entry_valid, issue_queue[i].tag, issue_queue[i].alu_cmd, issue_queue[i].op1_valid, issue_queue[i].op2_valid);
      end
      // Invalidate issued entry
      if (issue_entry.entry_valid) begin
        if (DEBUG) $display("[invalidate] issue_queue[%0x]: %0x", addr_search_tree[ISSUE_QUEUE_SIZE - 2], issue_entry);
        if (DEBUG) $display("[issue] v=%x, tag=%x, alu_cmd=%x, op1_v=%x, op2_v=%x", issue_entry.entry_valid, issue_entry.tag, issue_entry.alu_cmd, issue_entry.op1_valid, issue_entry.op2_valid);
        issue_queue[addr_search_tree[ISSUE_QUEUE_SIZE - 2]].entry_valid <= 1'b0;
      end
      if (DEBUG) $display("");

      // Dispatch
      if (ru_issue_if.write_enable) begin
        tag_counter <= tag_counter + 4'b1;
        // 空いている領域を探してそこに書き込む
        issue_queue[free_entry_idx].entry_valid <= 1'b1;
        issue_queue[free_entry_idx].tag <= tag_counter;
        issue_queue[free_entry_idx].alu_cmd <= ru_issue_if.alu_cmd;
        issue_queue[free_entry_idx].op1_data <= ru_issue_if.op1;
        issue_queue[free_entry_idx].op2_data <= ru_issue_if.op2;
        issue_queue[free_entry_idx].op1_valid <= ru_issue_if.op1_valid;
        issue_queue[free_entry_idx].op2_valid <= ru_issue_if.op2_valid;
        issue_queue[free_entry_idx].phys_rd <= ru_issue_if.phys_rd;
      end

      // op1/op2 tag writeback
      for(int i = 0; i < ISSUE_QUEUE_SIZE; i++) begin
        if (ru_issue_if.phys_result_valid) begin
          if (issue_queue[i].entry_valid && !issue_queue[i].op1_valid && issue_queue[i].op1_data[7:0] == ru_issue_if.phys_result_tag) begin
            issue_queue[i].op1_valid <= 1'b1;
            issue_queue[i].op1_data <= ru_issue_if.phys_result_data;
          end
          if (issue_queue[i].entry_valid && !issue_queue[i].op2_valid && issue_queue[i].op2_data[7:0] == ru_issue_if.phys_result_tag) begin
            issue_queue[i].op2_valid <= 1'b1;
            issue_queue[i].op2_data <= ru_issue_if.phys_result_data;
          end
        end
      end
    end
  end

endmodule

`default_nettype wire

