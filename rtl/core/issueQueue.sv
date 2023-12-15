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
  logic [1:0] dispatch_enable_count;
  
  // Issue signals
  logic [1:0] issue_ready_count;
  logic [ISSUE_QUEUE_ADDR_WIDTH-1:0] issue_idx [0:DISPATCH_WIDTH-1];
  

  // Dispatch
  always_comb begin
    dispatch_enable_count = 0;
    for (int bank = 0; bank < DISPATCH_WIDTH; bank++) begin
      dispatch_enable_count = dispatch_enable_count + dispatch_if.en[bank];
    end
    
    disp_tail_next = disp_tail - issue_ready_count + dispatch_enable_count;
  end

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
        issue_queue[disp_tail_next - 2].op1_valid   <= dispatch_if.op1_valid[0];
        case(dispatch_if.op2_type[0])
          common::REG: issue_queue[disp_tail_next - 2].op2_valid <= dispatch_if.op2_valid[0];
          common::IMM: issue_queue[disp_tail_next - 2].op2_valid <= 1'b1;
          default: issue_queue[disp_tail_next - 2].op2_valid <= 1'b0;
        endcase
        issue_queue[disp_tail_next - 2].phys_rd     <= dispatch_if.phys_rd[0];
        issue_queue[disp_tail_next - 2].bank_addr   <= dispatch_if.bank_addr[0];
        issue_queue[disp_tail_next - 2].rob_addr    <= dispatch_if.rob_addr[0];

        issue_queue[disp_tail_next - 1].entry_valid <= dispatch_if.en[1];
        issue_queue[disp_tail_next - 1].alu_cmd     <= dispatch_if.alu_cmd[1];
        issue_queue[disp_tail_next - 1].op1_data    <= dispatch_if.op1[1];
        issue_queue[disp_tail_next - 1].op2_type    <= dispatch_if.op2_type[1];
        issue_queue[disp_tail_next - 1].op2_data    <= dispatch_if.op2[1];
        issue_queue[disp_tail_next - 1].op1_valid   <= dispatch_if.op1_valid[1];
        case(dispatch_if.op2_type[1])
          common::REG: issue_queue[disp_tail_next - 1].op2_valid <= dispatch_if.op2_valid[1];
          common::IMM: issue_queue[disp_tail_next - 1].op2_valid <= 1'b1;
          default: issue_queue[disp_tail_next - 1].op2_valid <= 1'b0;
        endcase
        issue_queue[disp_tail_next - 1].phys_rd     <= dispatch_if.phys_rd[1];
        issue_queue[disp_tail_next - 1].bank_addr   <= dispatch_if.bank_addr[1];
        issue_queue[disp_tail_next - 1].rob_addr    <= dispatch_if.rob_addr[1];
      end else if(dispatch_enable_count == 1) begin
        issue_queue[disp_tail_next - 1].entry_valid <= dispatch_if.en[0];
        issue_queue[disp_tail_next - 1].alu_cmd     <= dispatch_if.alu_cmd[0];
        issue_queue[disp_tail_next - 1].op1_data    <= dispatch_if.op1[0];
        issue_queue[disp_tail_next - 1].op2_type    <= dispatch_if.op2_type[0];
        issue_queue[disp_tail_next - 1].op2_data    <= dispatch_if.op2[0];
        issue_queue[disp_tail_next - 1].op1_valid   <= dispatch_if.op1_valid[0];
        case(dispatch_if.op2_type[0])
          common::REG: issue_queue[disp_tail_next - 1].op2_valid <= dispatch_if.op2_valid[0];
          common::IMM: issue_queue[disp_tail_next - 1].op2_valid <= 1'b1;
          default: issue_queue[disp_tail_next - 1].op2_valid <= 1'b0;
        endcase
        issue_queue[disp_tail_next - 1].phys_rd     <= dispatch_if.phys_rd[0];
        issue_queue[disp_tail_next - 1].bank_addr   <= dispatch_if.bank_addr[0];
        issue_queue[disp_tail_next - 1].rob_addr    <= dispatch_if.rob_addr[0];
        if (issue_ready_count == 2) begin
          issue_queue[disp_tail_next].entry_valid <= 0;
          issue_queue[disp_tail_next].alu_cmd     <= common::alu_cmd_t'(0);
          issue_queue[disp_tail_next].op1_valid   <= 0;
          issue_queue[disp_tail_next].op2_valid   <= 0;
        end
      end else begin
        if (issue_ready_count == 2) begin
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
        if (issue_ready_count == 2) begin
          if (issue_idx[0] <= ISSUE_QUEUE_ADDR_WIDTH'(i) && ISSUE_QUEUE_ADDR_WIDTH'(i) < issue_idx[1] - 1) begin
            issue_queue[i] <= issue_queue[i+1];
          end else if (issue_idx[1] - 1 <= ISSUE_QUEUE_ADDR_WIDTH'(i) && ISSUE_QUEUE_ADDR_WIDTH'(i) < disp_tail - 2) begin
            issue_queue[i] <= issue_queue[i+2];
          end
        end else if (issue_ready_count == 1) begin
          if (issue_idx[0] <= ISSUE_QUEUE_ADDR_WIDTH'(i) && ISSUE_QUEUE_ADDR_WIDTH'(i) < disp_tail - 1) begin
            issue_queue[i] <= issue_queue[i+1];
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
    if (issue_ready_count == 2) begin
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
      issue_if.phys_rd[0]   <= issue_queue[issue_idx[0]].phys_rd;
      issue_if.bank_addr[0] <= issue_queue[issue_idx[0]].bank_addr;
      issue_if.rob_addr[0]  <= issue_queue[issue_idx[0]].rob_addr;

      issue_if.valid[1]     <= issue_queue[issue_idx[1]].entry_valid & issue_ready_count == 2;
      issue_if.alu_cmd[1]   <= issue_queue[issue_idx[1]].alu_cmd;
      issue_if.op1[1]       <= issue_queue[issue_idx[1]].op1_data;
      issue_if.op2_type[1]  <= issue_queue[issue_idx[1]].op2_type;
      issue_if.op2[1]       <= issue_queue[issue_idx[1]].op2_data;
      issue_if.phys_rd[1]   <= issue_queue[issue_idx[1]].phys_rd;
      issue_if.bank_addr[1] <= issue_queue[issue_idx[1]].bank_addr;
      issue_if.rob_addr[1]  <= issue_queue[issue_idx[1]].rob_addr;
    end
  end

  assign dispatch_if.full = 32'(disp_tail) + 32'(dispatch_enable_count) > ISSUE_QUEUE_SIZE;

  always_ff @(posedge clk) begin
    if (rst) begin
      for (int i = 0; i < ISSUE_QUEUE_SIZE; i++) begin
        issue_queue[i].entry_valid <= 1'b0;
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

