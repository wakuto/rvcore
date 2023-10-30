`default_nettype none
module issueQueueWrapper #(
  parameter ISSUE_QUEUE_SIZE = 8
) (
  input wire clk,
  input wire rst,

  input  wire              dispatch_en,
  output logic             full,
  input  common::alu_cmd_t dispatch_alu_cmd,
  input                    dispatch_op1_valid, dispatch_op2_valid,
  input  wire [31:0]       dispatch_op1, dispatch_op2,
  input  wire [ 7:0]       dispatch_phys_rd,

// 他の命令の結果の適用
  input  wire              wb_valid,
  input  wire [ 7:0]       wb_phys_rd,
  input  wire [31:0]       wb_data,

  output logic             issue_valid,
  output common::alu_cmd_t issue_alu_cmd,
  output logic [31:0]      issue_op1,
  output logic [31:0]      issue_op2,
  output logic [ 7:0]      issue_phys_rd
);

  isqDispatchIf dispatch_if;
  isqWbIf wb_if;
  isqIssueIf issue_if;

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
    dispatch_if.en = dispatch_en;
    dispatch_if.alu_cmd = dispatch_alu_cmd;
    dispatch_if.op1     = dispatch_op1;
    dispatch_if.op2     = dispatch_op2;
    dispatch_if.op1_valid = dispatch_op1_valid;
    dispatch_if.op2_valid = dispatch_op2_valid;
    dispatch_if.phys_rd = dispatch_phys_rd;

    wb_if.valid = wb_valid;
    wb_if.phys_rd = wb_phys_rd;
    wb_if.data = wb_data;

    issue_valid = issue_if.valid;
    issue_alu_cmd   = issue_if.alu_cmd;
    issue_op1       = issue_if.op1;
    issue_op2       = issue_if.op2;
    issue_phys_rd   = issue_if.phys_rd;
  end
endmodule

`default_nettype wire
