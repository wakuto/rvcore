`default_nettype none
module issueQueueWrapper #(
  parameter ISSUE_QUEUE_SIZE = 8
) (
  input wire clk,
  input wire rst,

  input  wire              in_write_enable,
  output logic             out_full,
  input  common::alu_cmd_t in_alu_cmd,
  input                    in_op1_valid, in_op2_valid,
  input  wire [31:0]       in_op1, in_op2,
  input  wire [ 7:0]       in_phys_rd,

// 他の命令の結果の適用
  input  wire              phys_result_valid,
  input  wire [ 7:0]       phys_result_tag,
  input  wire [31:0]       phys_result_data,

  output logic             alu_cmd_valid,
  output common::alu_cmd_t issue_alu_cmd,
  output logic [31:0]      issue_op1,
  output logic [31:0]      issue_op2,
  output logic [ 7:0]      phys_rd
);

  issueQueueIf iq_if;

  issueQueue #(
    .ISSUE_QUEUE_SIZE(ISSUE_QUEUE_SIZE)
  ) issue_queue_1 (
    .clk,
    .rst,
    .ru_issue_if(iq_if.issue_din),
    .issue_ex_if(iq_if.issue)
  );

  always_comb begin
    iq_if.write_enable = in_write_enable;
    out_full = iq_if.full;
    iq_if.alu_cmd = in_alu_cmd;
    iq_if.op1     = in_op1;
    iq_if.op2     = in_op2;
    iq_if.op1_valid = in_op1_valid;
    iq_if.op2_valid = in_op2_valid;
    iq_if.phys_rd = in_phys_rd;
    iq_if.phys_result_valid = phys_result_valid;
    iq_if.phys_result_tag = phys_result_tag;
    iq_if.phys_result_data = phys_result_data;

    alu_cmd_valid = iq_if.alu_cmd_valid;
    issue_alu_cmd   = iq_if.issue_alu_cmd;
    issue_op1       = iq_if.issue_op1;
    issue_op2       = iq_if.issue_op2;
    phys_rd   = iq_if.phys_rd;
  end
endmodule

`default_nettype wire
