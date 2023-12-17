`default_nettype none

`include "common.sv"
`include "parameters.sv"

typedef struct packed {
  logic             entry_valid;
  common::alu_cmd_t alu_cmd;
  logic [parameters::PHYS_REGS_ADDR_WIDTH-1:0] op1_data;
  logic [31:0]      op2_data;
  common::op_type_t op2_type;
  logic             op1_valid, op2_valid;
  logic [parameters::PHYS_REGS_ADDR_WIDTH-1:0] phys_rd;
  logic [parameters::DISPATCH_ADDR_WIDTH -1:0] bank_addr;
  logic [parameters::ROB_ADDR_WIDTH-1: 0]      rob_addr;
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
  localparam ISSUE_QUEUE_ADDR_WIDTH = $clog2(ISSUE_QUEUE_SIZE);
  issue_queue_entry_t issue_queue [0:ISSUE_QUEUE_SIZE-1];
  
  // Dispatch signals
  logic [ISSUE_QUEUE_ADDR_WIDTH-1:0] disp_tail_next;
  logic [ISSUE_QUEUE_ADDR_WIDTH-1:0] disp_tail; 
  logic [DISPATCH_ADDR_WIDTH:0] dispatch_enable_count;
  
  // Issue signals
  logic [ISSUE_QUEUE_ADDR_WIDTH:0] issue_ready_count;
  logic [ISSUE_QUEUE_ADDR_WIDTH-1:0] issue_idx [0:DISPATCH_WIDTH-1];
  
  logic [DISPATCH_WIDTH-1:0] op1_valid;
  logic [DISPATCH_WIDTH-1:0] op2_valid;
  
  function logic forwarding_check(logic valid [0:DISPATCH_WIDTH-1], logic [PHYS_REGS_ADDR_WIDTH-1:0] phys_rd [0:DISPATCH_WIDTH-1], logic [PHYS_REGS_ADDR_WIDTH-1:0] rs);
    forwarding_check = 0;
    for (int i = 0; i < DISPATCH_WIDTH; i++) begin
      forwarding_check = forwarding_check || (valid[i] && (phys_rd[i] == rs));
    end
  endfunction

  // Dispatch
  always_comb begin
    dispatch_enable_count = 0;
    for (int bank = 0; bank < DISPATCH_WIDTH; bank++) begin
      dispatch_enable_count = dispatch_enable_count + dispatch_if.en[bank];
    end
    
    if (issue_ready_count <= 2) begin
      disp_tail_next = disp_tail - ISSUE_QUEUE_ADDR_WIDTH'(issue_ready_count) + ISSUE_QUEUE_ADDR_WIDTH'(dispatch_enable_count);
    end else begin
      disp_tail_next = disp_tail - 2 + ISSUE_QUEUE_ADDR_WIDTH'(dispatch_enable_count);
    end
    
    for (int i = 0; i < DISPATCH_WIDTH; i++) begin
      op1_valid[i] = forwarding_check(wb_if.valid, wb_if.phys_rd, dispatch_if.op1[i]) || dispatch_if.op1_valid[i];
      case(dispatch_if.op2_type[i])
        common::REG: op2_valid[i] = forwarding_check(wb_if.valid, wb_if.phys_rd, PHYS_REGS_ADDR_WIDTH'(dispatch_if.op2[i])) || dispatch_if.op2_valid[i];
        common::IMM: op2_valid[i] = 1'b1;
        default: op2_valid[i] = 0;
      endcase
    end
  end

  /* verilator lint_off UNUSED */
  function issue_queue_entry_t replace_entry(issue_queue_entry_t entry, logic new_op1_valid, logic new_op2_valid);
    replace_entry.entry_valid = entry.entry_valid;
    replace_entry.alu_cmd     = entry.alu_cmd;
    replace_entry.op1_data    = entry.op1_data;
    replace_entry.op2_type    = entry.op2_type;
    replace_entry.op2_data    = entry.op2_data;
    replace_entry.op1_valid   = new_op1_valid;
    case(entry.op2_type)
      common::REG: replace_entry.op2_valid = new_op2_valid;
      common::IMM: replace_entry.op2_valid = 1'b1;
      default: replace_entry.op2_valid = 0;
    endcase
    replace_entry.phys_rd     = entry.phys_rd;
    replace_entry.bank_addr   = entry.bank_addr;
    replace_entry.rob_addr    = entry.rob_addr;
  endfunction
  /* verilator lint_on UNUSED */
  always_ff @(posedge clk) begin
    if (rst) begin
      disp_tail <= 0;
    end else begin
      disp_tail <= disp_tail_next;
      // TODO: function とか使って簡略化したい
      if (dispatch_enable_count == 2) begin
        issue_queue[disp_tail_next - 2].entry_valid <= dispatch_if.en[0];
        issue_queue[disp_tail_next - 2].alu_cmd     <= dispatch_if.alu_cmd[0];
        issue_queue[disp_tail_next - 2].op1_data    <= dispatch_if.op1[0];
        issue_queue[disp_tail_next - 2].op2_type    <= dispatch_if.op2_type[0];
        issue_queue[disp_tail_next - 2].op2_data    <= dispatch_if.op2[0];
        issue_queue[disp_tail_next - 2].op1_valid   <= op1_valid[0];
        issue_queue[disp_tail_next - 2].op2_valid   <= op2_valid[0];
        issue_queue[disp_tail_next - 2].phys_rd     <= dispatch_if.phys_rd[0];
        issue_queue[disp_tail_next - 2].bank_addr   <= dispatch_if.bank_addr[0];
        issue_queue[disp_tail_next - 2].rob_addr    <= dispatch_if.rob_addr[0];

        issue_queue[disp_tail_next - 1].entry_valid <= dispatch_if.en[1];
        issue_queue[disp_tail_next - 1].alu_cmd     <= dispatch_if.alu_cmd[1];
        issue_queue[disp_tail_next - 1].op1_data    <= dispatch_if.op1[1];
        issue_queue[disp_tail_next - 1].op2_type    <= dispatch_if.op2_type[1];
        issue_queue[disp_tail_next - 1].op2_data    <= dispatch_if.op2[1];
        issue_queue[disp_tail_next - 1].op1_valid   <= op1_valid[1];
        issue_queue[disp_tail_next - 1].op2_valid   <= op2_valid[1];
        issue_queue[disp_tail_next - 1].phys_rd     <= dispatch_if.phys_rd[1];
        issue_queue[disp_tail_next - 1].bank_addr   <= dispatch_if.bank_addr[1];
        issue_queue[disp_tail_next - 1].rob_addr    <= dispatch_if.rob_addr[1];
      end else if(dispatch_enable_count == 1) begin
        issue_queue[disp_tail_next - 1].entry_valid <= dispatch_if.en[0];
        issue_queue[disp_tail_next - 1].alu_cmd     <= dispatch_if.alu_cmd[0];
        issue_queue[disp_tail_next - 1].op1_data    <= dispatch_if.op1[0];
        issue_queue[disp_tail_next - 1].op2_type    <= dispatch_if.op2_type[0];
        issue_queue[disp_tail_next - 1].op2_data    <= dispatch_if.op2[0];
        issue_queue[disp_tail_next - 1].op1_valid   <= op1_valid[0];
        issue_queue[disp_tail_next - 1].op2_valid   <= op2_valid[0];
        issue_queue[disp_tail_next - 1].phys_rd     <= dispatch_if.phys_rd[0];
        issue_queue[disp_tail_next - 1].bank_addr   <= dispatch_if.bank_addr[0];
        issue_queue[disp_tail_next - 1].rob_addr    <= dispatch_if.rob_addr[0];
        if (issue_ready_count >= 2) begin
          issue_queue[disp_tail_next].entry_valid <= 0;
          issue_queue[disp_tail_next].alu_cmd     <= common::alu_cmd_t'(0);
          issue_queue[disp_tail_next].op1_valid   <= 0;
          issue_queue[disp_tail_next].op2_valid   <= 0;
        end
      end else begin
        if (issue_ready_count >= 2) begin
          issue_queue[disp_tail - 2].entry_valid <= 0;
          issue_queue[disp_tail - 2].alu_cmd     <= common::alu_cmd_t'(0);
          issue_queue[disp_tail - 2].op1_valid   <= 0;
          issue_queue[disp_tail - 2].op2_valid   <= 0;
        end
        if (issue_ready_count >= 1) begin
          issue_queue[disp_tail - 1].entry_valid <= 0;
          issue_queue[disp_tail - 1].alu_cmd     <= common::alu_cmd_t'(0);
          issue_queue[disp_tail - 1].op1_valid   <= 0;
          issue_queue[disp_tail - 1].op2_valid   <= 0;
        end
      end
      
      // issue_queue の詰め直し
      for(int i = 0; i < ISSUE_QUEUE_SIZE - 1; i++) begin
        if (issue_ready_count >= 2) begin
          if (issue_idx[0] <= ISSUE_QUEUE_ADDR_WIDTH'(i) && ISSUE_QUEUE_ADDR_WIDTH'(i) < issue_idx[1] - 1) begin
            issue_queue[i] <= replace_entry(issue_queue[i+1], 
                                            forwarding_check(wb_if.valid, wb_if.phys_rd, PHYS_REGS_ADDR_WIDTH'(issue_queue[i+1].op1_data)) || issue_queue[i+1].op1_valid,
                                            forwarding_check(wb_if.valid, wb_if.phys_rd, PHYS_REGS_ADDR_WIDTH'(issue_queue[i+1].op2_data)) || issue_queue[i+1].op2_valid);
          end else if (issue_idx[1] - 1 <= ISSUE_QUEUE_ADDR_WIDTH'(i) && ISSUE_QUEUE_ADDR_WIDTH'(i) < disp_tail - 2) begin
            issue_queue[i] <= replace_entry(issue_queue[i+2], 
                                            forwarding_check(wb_if.valid, wb_if.phys_rd, PHYS_REGS_ADDR_WIDTH'(issue_queue[i+2].op1_data)) || issue_queue[i+2].op1_valid,
                                            forwarding_check(wb_if.valid, wb_if.phys_rd, PHYS_REGS_ADDR_WIDTH'(issue_queue[i+2].op2_data)) || issue_queue[i+2].op2_valid);
          end
        end else if (issue_ready_count == 1) begin
          if (issue_idx[0] <= ISSUE_QUEUE_ADDR_WIDTH'(i) && ISSUE_QUEUE_ADDR_WIDTH'(i) < disp_tail - 1) begin
            issue_queue[i] <= replace_entry(issue_queue[i+1], 
                                            forwarding_check(wb_if.valid, wb_if.phys_rd, PHYS_REGS_ADDR_WIDTH'(issue_queue[i+1].op1_data)) || issue_queue[i+1].op1_valid,
                                            forwarding_check(wb_if.valid, wb_if.phys_rd, PHYS_REGS_ADDR_WIDTH'(issue_queue[i+1].op2_data)) || issue_queue[i+2].op1_valid);
          end
        end
      end
    end
  end
  
  // Issue
  always_comb begin
    issue_ready_count = 0;
    for(int i = 0; i < ISSUE_QUEUE_SIZE; i++) begin
      if (issue_queue[i].entry_valid && issue_queue[i].op1_valid && issue_queue[i].op2_valid) begin
        issue_ready_count = issue_ready_count + 1;
      end
    end
    
    issue_idx[0] = 0;
    issue_idx[1] = 0;
    if (issue_ready_count >= 2) begin
      for(int i = 0; i < ISSUE_QUEUE_SIZE; i++) begin
        if (issue_queue[i].entry_valid && issue_queue[i].op1_valid && issue_queue[i].op2_valid) begin
          issue_idx[0] = ISSUE_QUEUE_ADDR_WIDTH'(i);
          break;
        end
      end
      for(int i = 32'(issue_idx[0]) + 1; i < ISSUE_QUEUE_SIZE; i++) begin
        if (issue_queue[i].entry_valid && issue_queue[i].op1_valid && issue_queue[i].op2_valid) begin
          issue_idx[1] = ISSUE_QUEUE_ADDR_WIDTH'(i);
          break;
        end
      end
    end else if (issue_ready_count == 1) begin
      for(int i = 0; i < ISSUE_QUEUE_SIZE; i++) begin
        if (issue_queue[i].entry_valid && issue_queue[i].op1_valid && issue_queue[i].op2_valid) begin
          issue_idx[0] = ISSUE_QUEUE_ADDR_WIDTH'(i);
          break;
        end
      end
    end
  end
  
  always_ff @(posedge clk) begin
    if (rst) begin
    end else begin
      issue_if.valid[0]     <= issue_queue[issue_idx[0]].entry_valid && issue_ready_count != 0;
      issue_if.alu_cmd[0]   <= issue_queue[issue_idx[0]].alu_cmd;
      issue_if.op1[0]       <= issue_queue[issue_idx[0]].op1_data;
      issue_if.op2_type[0]  <= issue_queue[issue_idx[0]].op2_type;
      issue_if.op2[0]       <= issue_queue[issue_idx[0]].op2_data;
      issue_if.phys_rd[0]   <= issue_ready_count >= 1 ? issue_queue[issue_idx[0]].phys_rd : 0;
      issue_if.bank_addr[0] <= issue_queue[issue_idx[0]].bank_addr;
      issue_if.rob_addr[0]  <= issue_queue[issue_idx[0]].rob_addr;

      issue_if.valid[1]     <= issue_queue[issue_idx[1]].entry_valid & issue_ready_count >= 2;
      issue_if.alu_cmd[1]   <= issue_queue[issue_idx[1]].alu_cmd;
      issue_if.op1[1]       <= issue_queue[issue_idx[1]].op1_data;
      issue_if.op2_type[1]  <= issue_queue[issue_idx[1]].op2_type;
      issue_if.op2[1]       <= issue_queue[issue_idx[1]].op2_data;
      issue_if.phys_rd[1]   <= issue_ready_count >= 2 ? issue_queue[issue_idx[1]].phys_rd : 0;
      issue_if.bank_addr[1] <= issue_queue[issue_idx[1]].bank_addr;
      issue_if.rob_addr[1]  <= issue_queue[issue_idx[1]].rob_addr;
    end
  end

  assign dispatch_if.full = 32'(disp_tail) + 32'(dispatch_enable_count) >= ISSUE_QUEUE_SIZE;

  always_ff @(posedge clk) begin
    if (rst) begin
      for (int i = 0; i < ISSUE_QUEUE_SIZE; i++) begin
        issue_queue[i] <= issue_queue_entry_t'(0);
      end
    end else begin
      // op1/op2 writeback
      for(int bank = 0; bank < DISPATCH_WIDTH; bank++) begin
        for(int i = 0; i < ISSUE_QUEUE_SIZE; i++) begin
          if (wb_if.valid[bank]) begin
            if (issue_queue[i].entry_valid && !issue_queue[i].op1_valid && issue_queue[i].op1_data[PHYS_REGS_ADDR_WIDTH-1:0] == wb_if.phys_rd[bank]) begin
              if (issue_ready_count == 2) begin
                if (ISSUE_QUEUE_ADDR_WIDTH'(i) < issue_idx[0]) begin
                  issue_queue[i].op1_valid <= 1'b1;
                end else if (issue_idx[0] <= ISSUE_QUEUE_ADDR_WIDTH'(i) && ISSUE_QUEUE_ADDR_WIDTH'(i) < issue_idx[1]) begin
                  issue_queue[i-1].op1_valid <= 1'b1;
                end else if (issue_idx[1] <= ISSUE_QUEUE_ADDR_WIDTH'(i) && ISSUE_QUEUE_ADDR_WIDTH'(i) < disp_tail) begin
                  issue_queue[i-2].op1_valid <= 1'b1;
                end
              end else if (issue_ready_count == 1) begin
                if (ISSUE_QUEUE_ADDR_WIDTH'(i) < issue_idx[0]) begin
                  issue_queue[i].op1_valid <= 1'b1;
                end else if (issue_idx[1] <= ISSUE_QUEUE_ADDR_WIDTH'(i) && ISSUE_QUEUE_ADDR_WIDTH'(i) < disp_tail) begin
                  issue_queue[i-1].op1_valid <= 1'b1;
                end
              end else begin
                issue_queue[i].op1_valid <= 1'b1;
              end
            end
            if (issue_queue[i].entry_valid && issue_queue[i].op2_type == common::REG && !issue_queue[i].op2_valid && issue_queue[i].op2_data[PHYS_REGS_ADDR_WIDTH-1:0] == wb_if.phys_rd[bank]) begin
              if (issue_ready_count == 2) begin
                if (ISSUE_QUEUE_ADDR_WIDTH'(i) < issue_idx[0]) begin
                  issue_queue[i].op2_valid <= 1'b1;
                end else if (issue_idx[0] <= ISSUE_QUEUE_ADDR_WIDTH'(i) && ISSUE_QUEUE_ADDR_WIDTH'(i) < issue_idx[1]) begin
                  issue_queue[i-1].op2_valid <= 1'b1;
                end else if (issue_idx[1] <= ISSUE_QUEUE_ADDR_WIDTH'(i) && ISSUE_QUEUE_ADDR_WIDTH'(i) < disp_tail) begin
                  issue_queue[i-2].op2_valid <= 1'b1;
                end
              end else if (issue_ready_count == 1) begin
                if (ISSUE_QUEUE_ADDR_WIDTH'(i) < issue_idx[0]) begin
                  issue_queue[i].op2_valid <= 1'b1;
                end else if (issue_idx[0] <= ISSUE_QUEUE_ADDR_WIDTH'(i) && ISSUE_QUEUE_ADDR_WIDTH'(i) < disp_tail) begin
                  issue_queue[i-1].op2_valid <= 1'b1;
                end
              end else begin
                issue_queue[i].op2_valid <= 1'b1;
              end
            end
          end
        end
      end
    end
  end

endmodule

`default_nettype wire

