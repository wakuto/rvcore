`default_nettype none

`include "parameters.sv"
`include "common.sv"

module issueQueueWrapper #(
  parameter ISSUE_QUEUE_SIZE = 8
) (
  input wire clk,
  input wire rst,

  input  wire                            dispatch_en        [0:DISPATCH_WIDTH-1],
  output logic                           full,
  input  common::alu_cmd_t               dispatch_alu_cmd   [0:DISPATCH_WIDTH-1],
  input  wire                            dispatch_op1_valid [0:DISPATCH_WIDTH-1],
  input  wire                            dispatch_op2_valid [0:DISPATCH_WIDTH-1],
  input  wire [PHYS_REGS_ADDR_WIDTH-1:0] dispatch_op1       [0:DISPATCH_WIDTH-1],
  input  wire [31:0]                     dispatch_op2       [0:DISPATCH_WIDTH-1],
  input  common::op_type_t               dispatch_op2_type  [0:DISPATCH_WIDTH-1],
  input  wire [PHYS_REGS_ADDR_WIDTH-1:0] dispatch_phys_rd   [0:DISPATCH_WIDTH-1],
  input  wire [DISPATCH_ADDR_WIDTH-1: 0] dispatch_bank_addr [0:DISPATCH_WIDTH-1],
  input  wire [ROB_ADDR_WIDTH-1: 0]      dispatch_rob_addr  [0:DISPATCH_WIDTH-1],
  input  wire [31:0]                     dispatch_pc        [0:DISPATCH_WIDTH-1],
  input  wire [31:0]                     dispatch_instr     [0:DISPATCH_WIDTH-1],

// 他の命令の結果の適用
  input  wire                             wb_valid        [0:DISPATCH_WIDTH-1],
  input  wire [PHYS_REGS_ADDR_WIDTH-1:0]  wb_phys_rd      [0:DISPATCH_WIDTH-1],

  output logic                            issue_valid     [0:DISPATCH_WIDTH-1],
  output common::alu_cmd_t                issue_alu_cmd   [0:DISPATCH_WIDTH-1],
  output logic [PHYS_REGS_ADDR_WIDTH-1:0] issue_op1       [0:DISPATCH_WIDTH-1],
  output common::op_type_t                issue_op2_type  [0:DISPATCH_WIDTH-1],
  output logic [31:0]                     issue_op2       [0:DISPATCH_WIDTH-1],
  output logic [PHYS_REGS_ADDR_WIDTH-1:0] issue_phys_rd   [0:DISPATCH_WIDTH-1],
  output logic [DISPATCH_ADDR_WIDTH-1: 0] issue_bank_addr [0:DISPATCH_WIDTH-1],
  output logic [ROB_ADDR_WIDTH-1: 0]      issue_rob_addr  [0:DISPATCH_WIDTH-1],
  output logic [31:0]                     issue_pc        [0:DISPATCH_WIDTH-1],
  output logic [31:0]                     issue_instr     [0:DISPATCH_WIDTH-1]
);
  import parameters::*;

  isqDispatchIf dispatch_if();
  isqWbIf wb_if();
  isqIssueIf issue_if();

  issueQueue #(
    .ISSUE_QUEUE_SIZE(ISSUE_QUEUE_SIZE)
  ) issue_queue_1 (
    .clk,
    .rst,
    .dispatch_if(dispatch_if.in),
    .wb_if(wb_if.in),
    .issue_if(issue_if.out)
  );

  always_comb begin
    full = dispatch_if.full;
    for (int bank = 0; bank < DISPATCH_WIDTH; bank++) begin
      dispatch_if.en[bank]        = dispatch_en[bank];
      dispatch_if.alu_cmd[bank]   = dispatch_alu_cmd[bank];
      dispatch_if.op1[bank]       = dispatch_op1[bank];
      dispatch_if.op2[bank]       = dispatch_op2[bank];
      dispatch_if.op1_valid[bank] = dispatch_op1_valid[bank];
      dispatch_if.op2_valid[bank] = dispatch_op2_valid[bank];
      dispatch_if.op2_type[bank]  = dispatch_op2_type[bank];
      dispatch_if.phys_rd[bank]   = dispatch_phys_rd[bank];
      dispatch_if.bank_addr[bank] = dispatch_bank_addr[bank];
      dispatch_if.rob_addr[bank]  = dispatch_rob_addr[bank];
      dispatch_if.pc[bank]        = dispatch_pc[bank];
      dispatch_if.instr[bank]     = dispatch_instr[bank];
    end

    wb_if.valid = wb_valid;
    wb_if.phys_rd = wb_phys_rd;

    for (int bank = 0; bank < DISPATCH_WIDTH; bank++) begin
      issue_valid[bank]     = issue_if.valid[bank];
      issue_alu_cmd[bank]   = issue_if.alu_cmd[bank];
      issue_op1[bank]       = issue_if.op1[bank];
      issue_op2_type[bank]  = issue_if.op2_type[bank];
      issue_op2[bank]       = issue_if.op2[bank];
      issue_phys_rd[bank]   = issue_if.phys_rd[bank];
      issue_bank_addr[bank] = issue_if.bank_addr[bank];
      issue_rob_addr[bank]  = issue_if.rob_addr[bank];
      issue_pc[bank]        = issue_if.pc[bank];
      issue_instr[bank]     = issue_if.instr[bank];
    end
  end
endmodule

`default_nettype wire
