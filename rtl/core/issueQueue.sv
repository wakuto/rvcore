`default_nettype none

`include "common.sv"
`include "parameters.sv"

typedef struct packed {
  logic             entry_valid;
  logic [3:0]       tag;
  common::alu_cmd_t alu_cmd;
  logic [31:0]      op1_data, op2_data;
  common::op_type_t op2_type;
  logic             op1_valid, op2_valid;
  logic [parameters::PHYS_REGS_ADDR_WIDTH-1:0]       phys_rd;
} issue_queue_entry_t;


module issueQueue #(
  parameter ISSUE_QUEUE_SIZE = 8
) (
  input wire clk,
  input wire rst,
  isqDispatchIf.in dispatch_if,
  isqWbIf.in wb_if,
  isqIssueIf.out issue_if
);
  import parameters::*;
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
  issue_queue_entry_t issue_entry[0:DISPATCH_WIDTH-1];
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
    for(int bank = 0; bank < DISPATCH_WIDTH; bank++) begin
      issue_entry[bank] = search_tree[ISSUE_QUEUE_SIZE - 2 - bank];
      issue_if.valid[bank] = entry_valid(issue_entry[bank]);
      issue_if.alu_cmd[bank] = issue_entry[bank].alu_cmd;
      issue_if.op1[bank] = issue_entry[bank].op1_data;
      issue_if.op2_type[bank] = issue_entry[bank].op2_type;
      issue_if.op2[bank] = issue_entry[bank].op2_data;
      issue_if.phys_rd[bank] = issue_entry[bank].phys_rd;
    end
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
  logic [ISSUE_QUEUE_ADDR_WIDTH-1:0] free_entry_idx [0:DISPATCH_WIDTH-1];
  int free_offset [0:ISSUE_QUEUE_ADDR_WIDTH];
  logic [DISPATCH_ADDR_WIDTH:0] dispatch_enable_count;
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

    dispatch_enable_count = 0;
    for (int bank = 0; bank < DISPATCH_WIDTH; bank++) begin
      dispatch_enable_count = dispatch_enable_count + dispatch_if.en[bank];
      free_entry_idx[bank] = get_idx(free_search_tree[ISSUE_QUEUE_SIZE - 2 - bank]);
    end
  end

  assign dispatch_if.full = !get_free(free_search_tree[ISSUE_QUEUE_SIZE - 2]);

  always_ff @(posedge clk) begin
    if (rst) begin
      for (int i = 0; i < ISSUE_QUEUE_SIZE; i++) begin
        issue_queue[i].entry_valid <= 1'b0;
        tag_counter <= 4'b0;
      end
      if (DEBUG) $display("[verilog] reset now");
    end else begin
      // Debug
      if (DEBUG) $display("din: %0x, v = %x, op1 = %x, op2 = %x, phys_rd = %x", dispatch_if, dispatch_if.en, dispatch_if.op1, dispatch_if.op2, dispatch_if.phys_rd);
      for (int i = 0; i < ISSUE_QUEUE_SIZE; i++) begin
        if (DEBUG) $write("issue_queue[%0x]: %0x, v = %x, tag = %x alu_cmd = %x, op1_v = %x, op2_v = %x\n", i, issue_queue[i], issue_queue[i].entry_valid, issue_queue[i].tag, issue_queue[i].alu_cmd, issue_queue[i].op1_valid, issue_queue[i].op2_valid);
      end
      // Invalidate issued entry
      for (int bank = 0; bank < DISPATCH_WIDTH; bank++) begin
        if (issue_entry[bank].entry_valid) begin
          if (DEBUG) $display("[invalidate] issue_queue[%0x]: %0x", addr_search_tree[ISSUE_QUEUE_SIZE - 2 - bank], issue_entry[bank]);
          if (DEBUG) $display("[issue] v=%x, tag=%x, alu_cmd=%x, op1_v=%x, op2_v=%x", issue_entry[bank].entry_valid, issue_entry[bank].tag, issue_entry[bank].alu_cmd, issue_entry[bank].op1_valid, issue_entry[bank].op2_valid);
          issue_queue[addr_search_tree[ISSUE_QUEUE_SIZE - 2 - bank]].entry_valid <= 1'b0;
        end
        if (DEBUG) $display("");
      end

      // Dispatch
      for(int bank = 0; bank < DISPATCH_WIDTH; bank++) begin
        if (dispatch_if.en[bank]) begin
          tag_counter <= tag_counter + 4'(dispatch_enable_count);
          // 空いている領域を探してそこに書き込む
          issue_queue[free_entry_idx[bank]].entry_valid <= dispatch_if.en[bank];
          issue_queue[free_entry_idx[bank]].tag <= tag_counter + 4'(dispatch_enable_count == 2 && bank == 1);
          issue_queue[free_entry_idx[bank]].alu_cmd <= dispatch_if.alu_cmd[bank];
          issue_queue[free_entry_idx[bank]].op1_data <= dispatch_if.op1[bank];
          issue_queue[free_entry_idx[bank]].op2_type <= dispatch_if.op2_type[bank];
          issue_queue[free_entry_idx[bank]].op2_data <= dispatch_if.op2[bank];
          issue_queue[free_entry_idx[bank]].op1_valid <= dispatch_if.op1_valid[bank];
          issue_queue[free_entry_idx[bank]].op2_valid <= dispatch_if.op2_valid[bank];
          issue_queue[free_entry_idx[bank]].phys_rd <= dispatch_if.phys_rd[bank];
        end
      end

      // op1/op2 tag writeback
      for(int bank = 0; bank < DISPATCH_WIDTH; bank++) begin
        for(int i = 0; i < ISSUE_QUEUE_SIZE; i++) begin
          if (wb_if.valid[bank]) begin
            if (issue_queue[i].entry_valid && !issue_queue[i].op1_valid && issue_queue[i].op1_data[PHYS_REGS_ADDR_WIDTH-1:0] == wb_if.phys_rd[bank]) begin
              issue_queue[i].op1_valid <= 1'b1;
              issue_queue[i].op1_data <= wb_if.data[bank];
            end
            if (issue_queue[i].entry_valid && !issue_queue[i].op2_valid && issue_queue[i].op2_data[PHYS_REGS_ADDR_WIDTH-1:0] == wb_if.phys_rd[bank]) begin
              issue_queue[i].op2_valid <= 1'b1;
              issue_queue[i].op2_data <= wb_if.data[bank];
            end
          end
        end
      end
    end
  end

endmodule

`default_nettype wire

