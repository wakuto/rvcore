`default_nettype none
`include "riscv_instr.sv"
`include "common.sv"
`include "parameters.sv"
`include "memory_map.sv"

module core (
  input wire logic        clk,
  input wire logic        rst,

  // instruction data
  output     logic [31:0] pc,
  input wire logic [31:0] instruction,
  input wire logic        instr_valid,

  // memory data
  output     logic [31:0] address,
  input wire logic [31:0] read_data,
  output     logic        read_enable,     // データを読むときにアサート
  input wire logic        read_valid,  // メモリ出力の有効フラグ
  output     logic [31:0] write_data,
  output     logic        write_enable,    // データを書くときにアサート->request signal
  output     logic [3:0]  strb,  // 書き込むデータの幅
  input wire logic        write_ready,  // 書き込むデータの幅

  output     logic        debug_ebreak,
  output     logic        debug_ecall,
  output     logic [31:0] debug_reg[0:31],
  output     logic        illegal_instr,
  input wire logic        timer_int,
  input wire logic        soft_int,
  input wire logic        ext_int
);
  import parameters::*;

  // ID stage
  logic             valid_id    [0:DISPATCH_WIDTH-1];
  logic [4:0]       rs1_id      [0:DISPATCH_WIDTH-1];
  logic [4:0]       rs2_id      [0:DISPATCH_WIDTH-1];
  logic [4:0]       rd_id       [0:DISPATCH_WIDTH-1];
  common::alu_cmd_t alu_cmd_id  [0:DISPATCH_WIDTH-1];
  logic [31:0]      imm_id      [0:DISPATCH_WIDTH-1];
  common::op_type_t op2_type_id [0:DISPATCH_WIDTH-1];

  // ID/REN regs
  logic             valid_rn    [0:DISPATCH_WIDTH-1];
  logic [4:0]       rs1_rn      [0:DISPATCH_WIDTH-1];
  logic [4:0]       rs2_rn      [0:DISPATCH_WIDTH-1];
  logic [4:0]       rd_rn       [0:DISPATCH_WIDTH-1];
  common::alu_cmd_t alu_cmd_rn  [0:DISPATCH_WIDTH-1];
  logic [31:0]      imm_rn      [0:DISPATCH_WIDTH-1];
  common::op_type_t op2_type_rn [0:DISPATCH_WIDTH-1];

  // REN stage
  logic [31:0]                     rs1_data_rn [0:DISPATCH_WIDTH-1];
  logic [31:0]                     rs2_data_rn [0:DISPATCH_WIDTH-1];
  logic [PHYS_REGS_ADDR_WIDTH-1:0] pop_reg_rn  [0:DISPATCH_WIDTH-1];
  freelistIf freelist_if_rn();

  // REN/DISP regs
  logic                            valid_disp    [0:DISPATCH_WIDTH-1];
  common::alu_cmd_t                alu_cmd_disp  [0:DISPATCH_WIDTH-1];
  logic [4:0]                      rs1_disp      [0:DISPATCH_WIDTH-1];
  common::op_type_t                op2_type_disp [0:DISPATCH_WIDTH-1];
  logic [4:0]                      rs2_disp      [0:DISPATCH_WIDTH-1];
  logic [31:0]                     imm_disp      [0:DISPATCH_WIDTH-1];
  logic [PHYS_REGS_ADDR_WIDTH-1:0] phys_rd_disp  [0:DISPATCH_WIDTH-1];
  logic [4:0]                      arch_rd_disp  [0:DISPATCH_WIDTH-1];

  // DISP stage
  logic [DISPATCH_WIDTH-1:0]       bank_addr_disp      [0:DISPATCH_WIDTH-1];
  logic [ROB_ADDR_WIDTH-1:0]       rob_addr_disp       [0:DISPATCH_WIDTH-1];
  logic [PHYS_REGS_ADDR_WIDTH-1:0] phys_rs1_disp       [0:DISPATCH_WIDTH-1];
  logic                            phys_rs1_valid_disp [0:DISPATCH_WIDTH-1];
  logic [PHYS_REGS_ADDR_WIDTH-1:0] phys_rs2_disp       [0:DISPATCH_WIDTH-1];
  logic                            phys_rs2_valid_disp [0:DISPATCH_WIDTH-1];
  robDispatchIf dispatch_if_disp();
  robWbIf       wb_if_disp();
  robCommitIf   commit_if_disp();
  robOpFetchIf  op_fetch_if_disp();

  // DISP/ISSUE regs
  logic                            valid_issue     [0:DISPATCH_WIDTH-1];
  common::alu_cmd_t                alu_cmd_issue   [0:DISPATCH_WIDTH-1];
  logic [PHYS_REGS_ADDR_WIDTH-1:0] rs1_issue       [0:DISPATCH_WIDTH-1];
  logic                            rs1_valid_issue [0:DISPATCH_WIDTH-1];
  common::op_type_t                op2_type_issue  [0:DISPATCH_WIDTH-1];
  logic [PHYS_REGS_ADDR_WIDTH-1:0] rs2_issue       [0:DISPATCH_WIDTH-1];
  logic                            rs2_valid_issue [0:DISPATCH_WIDTH-1];
  logic [31:0]                     imm_issue       [0:DISPATCH_WIDTH-1];
  logic [PHYS_REGS_ADDR_WIDTH-1:0] phys_rd_issue   [0:DISPATCH_WIDTH-1];
  logic [DISPATCH_WIDTH-1:0]       bank_addr_issue [0:DISPATCH_WIDTH-1];
  logic [ROB_ADDR_WIDTH-1:0]       rob_addr_issue  [0:DISPATCH_WIDTH-1];

  // ISSUE stage
  logic [31:0]                     op2_issue            [0:DISPATCH_WIDTH-1];
  logic                            op2_valid_issue      [0:DISPATCH_WIDTH-1];
  logic                            issue_valid_issue    [0:DISPATCH_WIDTH-1];
  common::alu_cmd_t                issue_alu_cmd_issue  [0:DISPATCH_WIDTH-1];
  logic [31:0]                     issue_op1_issue      [0:DISPATCH_WIDTH-1];
  logic [31:0]                     issue_op2_issue      [0:DISPATCH_WIDTH-1];
  common::op_type_t                issue_op2_type_issue [0:DISPATCH_WIDTH-1];
  logic [PHYS_REGS_ADDR_WIDTH-1:0] issue_phys_rd_issue  [0:DISPATCH_WIDTH-1];
  isqDispatchIf                    dispatch_if_issue();
  isqWbIf                          wb_if_issue();
  isqIssueIf                       issue_if_issue();

  // ISSUE/REGREAD regs
  logic                            valid_rread     [0:DISPATCH_WIDTH-1];
  common::alu_cmd_t                alu_cmd_rread   [0:DISPATCH_WIDTH-1];
  logic [PHYS_REGS_ADDR_WIDTH-1:0] op1_rread       [0:DISPATCH_WIDTH-1];
  common::op_type_t                op2_type_rread  [0:DISPATCH_WIDTH-1];
  logic [PHYS_REGS_ADDR_WIDTH-1:0] op2_rread       [0:DISPATCH_WIDTH-1];
  logic [PHYS_REGS_ADDR_WIDTH-1:0] phys_rd_rread   [0:DISPATCH_WIDTH-1];
  logic [DISPATCH_WIDTH-1:0]       bank_addr_rread [0:DISPATCH_WIDTH-1];
  logic [ROB_ADDR_WIDTH-1:0]       rob_addr_rread  [0:DISPATCH_WIDTH-1];

  // REGREAD stage
  logic [31:0]               rs1_data_rread  [0:DISPATCH_WIDTH-1];
  logic [31:0]               rs2_data_rread  [0:DISPATCH_WIDTH-1];

  // REGREAD/EX regs
  logic                            valid_ex     [0:DISPATCH_WIDTH-1];
  common::alu_cmd_t                alu_cmd_ex   [0:DISPATCH_WIDTH-1];
  logic [31:0]                     op1_ex       [0:DISPATCH_WIDTH-1];
  logic [31:0]                     op2_ex       [0:DISPATCH_WIDTH-1];
  logic [PHYS_REGS_ADDR_WIDTH-1:0] phys_rd_ex   [0:DISPATCH_WIDTH-1];
  logic [DISPATCH_WIDTH-1:0]       bank_addr_ex [0:DISPATCH_WIDTH-1];
  logic [ROB_ADDR_WIDTH-1:0]       rob_addr_ex  [0:DISPATCH_WIDTH-1];

  // EX stage
  logic [31:0]               alu_out_ex   [0:DISPATCH_WIDTH-1];

  // EX/WB regs
  logic                            valid_wb     [0:DISPATCH_WIDTH-1];
  logic [31:0]                     result_wb    [0:DISPATCH_WIDTH-1];
  logic [PHYS_REGS_ADDR_WIDTH-1:0] phys_rd_wb   [0:DISPATCH_WIDTH-1];
  logic [DISPATCH_WIDTH-1:0]       bank_addr_wb [0:DISPATCH_WIDTH-1];
  logic [ROB_ADDR_WIDTH-1:0]       rob_addr_wb  [0:DISPATCH_WIDTH-1];

  // COMMIT stage
  logic [PHYS_REGS_ADDR_WIDTH-1:0] phys_rd_commit [0:DISPATCH_WIDTH-1];
  logic [31:0]                     arch_rd_commit [0:DISPATCH_WIDTH-1];
  logic                            en_commit      [0:DISPATCH_WIDTH-1];

  always_ff @(posedge clk) begin
    if (rst) begin
      pc <= 0;
    end else begin
      if (instr_valid) begin
        pc <= pc + 4;
      end
    end
  end

  decoder decoder0(
    .instruction,
    .instr_valid,
    .rs1(rs1_id),
    .rs2(rs2_id),
    .rd(rd_id),
    .alu_cmd(alu_cmd_id),
    .imm(imm_id),
    .op2_type(op2_type_id)
  );

  // ID/REN regs
  always_ff @(posedge clk) begin
    if (rst) begin
      valid_rn    <= 0;
      rs1_rn      <= 0;
      rs2_rn      <= 0;
      rd_rn       <= 0;
      alu_cmd_rn  <= 0;
      imm_rn      <= 0;
      op2_type_rn <= 0;
    end else begin
      valid_rn    <= valid_id;
      rs1_rn      <= rs1_id;
      rs2_rn      <= rs2_id;
      rd_rn       <= rd_id;
      alu_cmd_rn  <= alu_cmd_id;
      imm_rn      <= imm_id;
      op2_type_rn <= op2_type_id;
    end
  end

  regfile #(
    .NUM_REGS(32),
    .REG_WIDTH(PHYS_REGS_ADDR_WIDTH)
  )
  rename_map_table(
    .clk,
    .rst,
    .addr_rs1(rs1_rn),
    .addr_rs2(rs2_rn),
    .addr_rd(rd_rn),
    .rd_data(pop_reg_rn),
    .rd_wen(valid_rn),
    .rs1_data(rs1_data_rn),
    .rs2_data(rs2_data_rn)
  );

  freelist freelist(
    .clk,
    .rst,
    .freelist_if(freelist_if_rn)
  );

  always_comb begin
    freelist_if_rn.push_reg = phys_rd_commit;
    freelist_if_rn.push_en  = en_commit;

    freelist_if_rn.pop_en   = valid_rn;
    pop_reg_rn = freelist_if_rn.pop_reg;
  end

  // REN/DISP regs
  always_ff @(posedge clk) begin
    if (rst) begin
      valid_disp    <= 0;
      alu_cmd_disp  <= 0;
      rs1_disp      <= 0;
      op2_type_disp <= 0;
      rs2_disp      <= 0;
      imm_disp      <= 0;
      phys_rd_disp  <= 0;
      arch_rd_disp  <= 0;
    end else begin
      valid_disp    <= valid_rn;
      alu_cmd_disp  <= alu_cmd_rn;
      rs1_disp      <= rs1_data_rn;
      op2_type_disp <= op2_type_rn;
      rs2_disp      <= rs2_data_rn;
      imm_disp      <= imm_rn;
      phys_rd_disp  <= pop_reg_rn;
      arch_rd_disp  <= rd_rn;
    end
  end

  rob #() rob (
    .clk,
    .rst,
    .dispatch_if(dispatch_if_disp),
    .wb_if(wb_if_disp),
    .commit_if(commit_if_disp),
    .op_fetch_if(op_fetch_if_disp)
  );

  always_comb begin
    dispatch_if_disp.en      = valid_disp;
    dispatch_if_disp.phys_rd = phys_rd_disp;
    dispatch_if_disp.arch_rd = arch_rd_disp;
    bank_addr_disp = dispatch_if_disp.bank_addr;
    rob_addr_disp  = dispatch_if_disp.rob_addr;

    wb_if_disp.en        = valid_wb;
    wb_if_disp.bank_addr = bank_addr_wb;
    wb_if_disp.rob_addr  = rob_addr_wb;

    arch_rd_commit = commit_if_disp.arch_rd;
    phys_rd_commit = commit_if_disp.phys_rd;
    en_commit      = commit_if_disp.en;

    op_fetch_if_disp.arch_rs1 = rs1_disp;
    op_fetch_if_disp.arch_rs2 = rs2_disp;

    phys_rs1_disp       = op_fetch_if_disp.phys_rs1;
    phys_rs1_valid_disp = op_fetch_if_disp.rs1_valid;
    phys_rs2_disp       = op_fetch_if_disp.phys_rs2;
    phys_rs2_valid_disp = op_fetch_if_disp.rs2_valid;
  end

  // DISP/ISSUE regs
  always_ff @(posedge clk) begin
    if (rst) begin
      valid_issue     <= 0;
      alu_cmd_issue   <= 0;
      rs1_issue       <= 0;
      rs1_valid_issue <= 0;
      op2_type_issue  <= 0;
      rs2_issue       <= 0;
      rs2_valid_issue <= 0;
      imm_issue       <= 0;
      phys_rd_issue   <= 0;
      bank_addr_issue <= 0;
      rob_addr_issue  <= 0;
    end else begin
      valid_issue     <= valid_disp;
      alu_cmd_issue   <= alu_cmd_disp;
      rs1_issue       <= phys_rs1_disp;
      rs1_valid_issue <= phys_rs1_valid_disp;
      op2_type_issue  <= op2_type_disp;
      rs2_issue       <= phys_rs2_disp;
      rs2_valid_issue <= phys_rs2_valid_disp;
      imm_issue       <= imm_disp;
      phys_rd_issue   <= phys_rd_disp;
      bank_addr_issue <= bank_addr_disp;
      rob_addr_issue  <= rob_addr_disp;
    end
  end

  op2ValidLogic op2_valid_logic(
    .op2_type(op2_type_issue),
    .rs2(rs2_issue),
    .rs2_valid(rs2_valid_issue),
    .imm(imm_issue),
    .op2(op2_issue),
    .op2_valid(op2_valid_issue)
  );

  issueQueue #(
    .ISSUE_QUEUE_SIZE(8)
  ) issue_queue (
    .clk,
    .rst,
    .dispatch_if(dispatch_if_issue.in),
    .wb_if(wb_if_issue.in),
    .issue_if(issue_if_issue.out)
  );

  always_comb begin
    dispatch_if_issue.en        = valid_issue;
    dispatch_if_issue.alu_cmd   = alu_cmd_issue;
    dispatch_if_issue.op1       = rs1_issue;
    dispatch_if_issue.op1_valid = rs1_valid_issue;
    dispatch_if_issue.op2       = op2_issue;
    dispatch_if_issue.op2_valid = op2_valid_issue;
    dispatch_if_issue.phys_rd   = phys_rd_issue;

    wb_if_issue.valid = valid_wb;
    wb_if_issue.phys_rd = phys_rd_wb;
    wb_if_issue.data = result_wb;

    issue_valid_issue   = issue_if_issue.valid;
    issue_alu_cmd_issue = issue_if_issue.alu_cmd;
    issue_op1_issue     = issue_if_issue.op1;
    issue_op2_issue     = issue_if_issue.op2;
    issue_phys_rd_issue = issue_if_issue.phys_rd;
  end

  // ISSUE/RREAD regs
  always_ff @(posedge clk) begin
    if(rst) begin
      valid_rread     <= 0;
      alu_cmd_rread   <= 0;
      op1_rread       <= 0;
      op2_type_rread  <= 0;
      op2_rread       <= 0;
      phys_rd_rread   <= 0;
      bank_addr_rread <= 0;
      rob_addr_rread  <= 0;
    end else begin
      valid_rread     <= issue_valid_issue;
      alu_cmd_rread   <= issue_alu_cmd_issue;
      op1_rread       <= issue_op1_issue;
      op2_type_rread  <= issue_op2_type_issue;
      op2_rread       <= issue_op2_issue;
      phys_rd_rread   <= issue_phys_rd_issue;
      bank_addr_rread <= bank_addr_issue;
      rob_addr_rread  <= rob_addr_issue;
    end
  end

  regfile #(
    .NUM_REGS(PHYS_REGS),
    .REG_WIDTH(PHYS_REGS_ADDR_WIDTH)
  ) phys_regfile(
    .clk,
    .rst,
    .addr_rs1(op1_rread),
    .addr_rs2(op2_rread),
    .addr_rd(phys_rd_wb),
    .rd_data(result_wb),
    .rd_wen(valid_wb),
    .rs1_data(rs1_data_rread),
    .rs2_data(rs2_data_rread)
  );

  // RREAD/EX regs
  always_ff @(posedge clk) begin
    if (rst) begin
      valid_ex     <= 0;
      alu_cmd_ex   <= 0;
      op1_ex       <= 0;
      op2_ex       <= 0;
      phys_rd_ex   <= 0;
      bank_addr_ex <= 0;
      rob_addr_ex  <= 0;
    end else begin
      valid_ex     <= valid_rread;
      alu_cmd_ex   <= alu_cmd_rread;
      op1_ex       <= rs1_data_rread;
      for (int bank = 0; bank < DISPATCH_WIDTH; bank++) begin
        case(op2_type_rread[bank])
          common::IMM: op2_ex[bank] <= op2_rread[bank];
          common::REG: op2_ex[bank] <= rs2_data_rread[bank];
          default: op2_ex[bank] <= 0;
        endcase
      end
      phys_rd_ex   <= phys_rd_rread;
      bank_addr_ex <= bank_addr_rread;
      rob_addr_ex  <= rob_addr_rread;
    end
  end

  generate
    genvar bank;
    for(bank = 0; bank < DISPATCH_WIDTH; bank++) begin
      alu alu(
        .op1(op1_ex[bank]),
        .op2(op2_ex[bank]),
        .alu_ops(alu_cmd_ex[bank]),
        .alu_out(alu_out_ex[bank])
      );
    end
  endgenerate

  always_ff @(posedge clk) begin
    if (rst) begin
      valid_wb     <= 0;
      result_wb    <= 0;
      phys_rd_wb   <= 0;
      bank_addr_wb <= 0;
      rob_addr_wb  <= 0;
    end else begin
      valid_wb     <= valid_ex;
      result_wb    <= alu_out_ex;
      phys_rd_wb   <= phys_rd_ex;
      bank_addr_wb <= bank_addr_ex;
      rob_addr_wb  <= rob_addr_ex;
    end
  end

  regfile #(
    .NUM_REGS(32),
    .REG_WIDTH(PHYS_REGS_ADDR_WIDTH)
  ) bank_regfile(
    .clk,
    .rst,
    .addr_rs1(),
    .addr_rs2(),
    .addr_rd(arch_rd_commit),
    .rd_data(phys_rd_commit),
    .rd_wen(en_commit),
    .rs1_data(),
    .rs2_data()
  );

endmodule
`default_nettype wire
