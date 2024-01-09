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
  input wire logic [31:0] instruction[0:DISPATCH_WIDTH-1],
  input wire logic        instr_valid[0:DISPATCH_WIDTH-1],

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
  
  // performance counter
  logic [63:0] clock_counter;
  logic [63:0] instr_counter;
  always_ff @(posedge clk) begin
    clock_counter <= clock_counter + 1;
    if (rst) begin
      instr_counter <= 0;
    end else if (commit_if_disp.en[0] && commit_if_disp.en[1]) begin
      instr_counter <= instr_counter + 2;
    end else if (commit_if_disp.en[0] || commit_if_disp.en[1]) begin
      instr_counter <= instr_counter + 1;
    end
  end

  // IF stage
  
  // IF/ID regs
  logic             instr_valid_id [0:DISPATCH_WIDTH-1];
  logic [31:0]      pc_id          [0:DISPATCH_WIDTH-1];
  logic [31:0]      instr_id       [0:DISPATCH_WIDTH-1];

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
  logic [31:0]      pc_rn       [0:DISPATCH_WIDTH-1];
  logic [31:0]      instr_rn    [0:DISPATCH_WIDTH-1];

  // REN stage
  logic [PHYS_REGS_ADDR_WIDTH-1:0] rs1_data_rn [0:DISPATCH_WIDTH-1];
  logic [PHYS_REGS_ADDR_WIDTH-1:0] rs2_data_rn [0:DISPATCH_WIDTH-1];
  logic [PHYS_REGS_ADDR_WIDTH-1:0] pop_reg_rn  [0:DISPATCH_WIDTH-1];
  freelistIf freelist_if_rn();

  // REN/DISP regs
  logic                            valid_disp    [0:DISPATCH_WIDTH-1];
  common::alu_cmd_t                alu_cmd_disp  [0:DISPATCH_WIDTH-1];
  logic [PHYS_REGS_ADDR_WIDTH-1:0] rs1_disp      [0:DISPATCH_WIDTH-1];
  common::op_type_t                op2_type_disp [0:DISPATCH_WIDTH-1];
  logic [PHYS_REGS_ADDR_WIDTH-1:0] rs2_disp      [0:DISPATCH_WIDTH-1];
  logic [31:0]                     imm_disp      [0:DISPATCH_WIDTH-1];
  logic [PHYS_REGS_ADDR_WIDTH-1:0] phys_rd_disp  [0:DISPATCH_WIDTH-1];
  logic [4:0]                      arch_rd_disp  [0:DISPATCH_WIDTH-1];
  logic [31:0]                     pc_disp       [0:DISPATCH_WIDTH-1];
  logic [31:0]                     instr_disp    [0:DISPATCH_WIDTH-1];

  // DISP stage
  logic [DISPATCH_ADDR_WIDTH-1:0]  bank_addr_disp      [0:DISPATCH_WIDTH-1];
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
  logic [DISPATCH_ADDR_WIDTH-1:0]  bank_addr_issue [0:DISPATCH_WIDTH-1];
  logic [ROB_ADDR_WIDTH-1:0]       rob_addr_issue  [0:DISPATCH_WIDTH-1];
  logic [31:0]                     pc_issue        [0:DISPATCH_WIDTH-1];
  logic [31:0]                     instr_issue     [0:DISPATCH_WIDTH-1];

  // ISSUE stage
  logic [31:0]                     op2_issue            [0:DISPATCH_WIDTH-1];
  logic                            op2_valid_issue      [0:DISPATCH_WIDTH-1];
  isqDispatchIf                    dispatch_if_issue();
  isqWbIf                          wb_if_issue();
  isqIssueIf                       issue_if_issue();

  // REGREAD stage
  logic                            valid_rread     [0:DISPATCH_WIDTH-1];
  common::alu_cmd_t                alu_cmd_rread   [0:DISPATCH_WIDTH-1];
  logic [PHYS_REGS_ADDR_WIDTH-1:0] op1_rread       [0:DISPATCH_WIDTH-1];
  common::op_type_t                op2_type_rread  [0:DISPATCH_WIDTH-1];
  logic [31:0]                     op2_rread       [0:DISPATCH_WIDTH-1];
  logic [PHYS_REGS_ADDR_WIDTH-1:0] phys_rd_rread   [0:DISPATCH_WIDTH-1];
  logic [DISPATCH_ADDR_WIDTH-1:0]  bank_addr_rread [0:DISPATCH_WIDTH-1];
  logic [ROB_ADDR_WIDTH-1:0]       rob_addr_rread  [0:DISPATCH_WIDTH-1];
  logic [31:0]                     rs1_data_rread  [0:DISPATCH_WIDTH-1];
  logic [31:0]                     rs2_data_rread  [0:DISPATCH_WIDTH-1];
  logic [31:0]                     pc_rread        [0:DISPATCH_WIDTH-1];
  logic [31:0]                     instr_rread     [0:DISPATCH_WIDTH-1];

  // REGREAD/EX regs
  logic                            valid_ex     [0:DISPATCH_WIDTH-1];
  common::alu_cmd_t                alu_cmd_ex   [0:DISPATCH_WIDTH-1];
  logic [31:0]                     op1_ex       [0:DISPATCH_WIDTH-1];
  logic [31:0]                     op2_ex       [0:DISPATCH_WIDTH-1];
  logic [PHYS_REGS_ADDR_WIDTH-1:0] phys_rd_ex   [0:DISPATCH_WIDTH-1];
  logic [DISPATCH_ADDR_WIDTH-1:0]  bank_addr_ex [0:DISPATCH_WIDTH-1];
  logic [ROB_ADDR_WIDTH-1:0]       rob_addr_ex  [0:DISPATCH_WIDTH-1];
  logic [31:0]                     pc_ex        [0:DISPATCH_WIDTH-1];
  logic [31:0]                     instr_ex     [0:DISPATCH_WIDTH-1];

  // EX stage
  logic [31:0]               alu_out_ex   [0:DISPATCH_WIDTH-1];

  // EX/WB regs
  logic                            valid_wb     [0:DISPATCH_WIDTH-1];
  logic [31:0]                     result_wb    [0:DISPATCH_WIDTH-1];
  logic [PHYS_REGS_ADDR_WIDTH-1:0] phys_rd_wb   [0:DISPATCH_WIDTH-1];
  logic [DISPATCH_ADDR_WIDTH-1:0]  bank_addr_wb [0:DISPATCH_WIDTH-1];
  logic [ROB_ADDR_WIDTH-1:0]       rob_addr_wb  [0:DISPATCH_WIDTH-1];
  logic [31:0]                     pc_wb        [0:DISPATCH_WIDTH-1];
  logic [31:0]                     instr_wb     [0:DISPATCH_WIDTH-1];

  // COMMIT stage
  logic [PHYS_REGS_ADDR_WIDTH-1:0] phys_rd_commit [0:DISPATCH_WIDTH-1];
  logic [4:0]                      arch_rd_commit [0:DISPATCH_WIDTH-1];
  logic                            en_commit      [0:DISPATCH_WIDTH-1];
  logic [31:0]                     pc_commit      [0:DISPATCH_WIDTH-1];
  logic [31:0]                     instr_commit   [0:DISPATCH_WIDTH-1];
  
  // hazard logic
  logic stall_if;
  logic stall_rn;
  logic stall_disp;
  logic stall_issue;
  
  // hazard unit
  hazard hazard(
    .freelist_empty(freelist_if_rn.num_free < 2),
    .rob_full(dispatch_if_disp.full),
    .issue_queue_full(dispatch_if_issue.full),
    .stall_if(stall_if),
    .stall_rn(stall_rn),
    .stall_disp(stall_disp),
    .stall_issue(stall_issue)
  );

  always_ff @(posedge clk) begin
    if (rst) begin
      pc <= 32'h80000000;
    end else begin
      if (!stall_if) begin
        if (&instr_valid) begin
          pc <= pc + 8;
        end else if (|instr_valid) begin
          pc <= pc + 4;
        end
      end
    end
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      for(int i = 0; i < DISPATCH_WIDTH; i++) begin
        instr_id[i]       <= 0;
        instr_valid_id[i] <= 0;
        pc_id[i]          <= 0;
      end
    end else begin
      if (!stall_if) begin
        // bank 0 に優先的に投入
        case({instr_valid[1], instr_valid[0]})
          2'b11: begin
            instr_id <= instruction;
            instr_valid_id <= instr_valid;
            pc_id[0] <= pc;
            pc_id[1] <= pc + 4;
          end
          2'b10: begin
            instr_id[0] <= instruction[1];
            instr_valid_id[0] <= instr_valid[1];
            pc_id[0] <= pc;
            instr_id[1] <= 0;
            instr_valid_id[1] <= 0;
            pc_id[1] <= 0;
          end
          2'b01: begin
            instr_id[0] <= instruction[0];
            instr_valid_id[0] <= instr_valid[0];
            pc_id[0] <= pc;
            instr_id[1] <= 0;
            instr_valid_id[1] <= 0;
            pc_id[1] <= 0;
          end
          default: begin
            instr_valid_id[0] <= 0;
            instr_valid_id[1] <= 0;
            instr_id[0] <= 0;
            instr_id[1] <= 0;
            pc_id[0] <= 0;
            pc_id[1] <= 0;
          end
        endcase
      end
    end
  end

  genvar bank;
  generate
    for(bank = 0; bank < DISPATCH_WIDTH; bank++) begin
      decoder decoder(
        .instruction(instr_id[bank]),
        .instr_valid(instr_valid_id[bank]),
        .rs1(rs1_id[bank]),
        .rs2(rs2_id[bank]),
        .rd(rd_id[bank]),
        .alu_cmd(alu_cmd_id[bank]),
        .imm(imm_id[bank]),
        .op2_type(op2_type_id[bank])
      );
    end
  endgenerate

  always_comb begin
    for(int i = 0; i < DISPATCH_WIDTH; i++) begin
      valid_id[i] = instr_valid[i] & (rd_id[i] != 0);
    end
  end

  // ID/REN regs
  always_ff @(posedge clk) begin
    if (rst) begin
      for(int i = 0; i < DISPATCH_WIDTH; i++) begin
        valid_rn[i]    <= 0;
        rs1_rn[i]      <= 0;
        rs2_rn[i]      <= 0;
        rd_rn[i]       <= 0;
        alu_cmd_rn[i]  <= common::alu_cmd_t'(0);
        imm_rn[i]      <= 0;
        op2_type_rn[i] <= common::op_type_t'(0);
        pc_rn[i]       <= 0;
        instr_rn[i]    <= 0;
      end
    end else begin
      if (!stall_rn) begin
        valid_rn    <= valid_id;
        rs1_rn      <= rs1_id;
        rs2_rn      <= rs2_id;
        rd_rn       <= rd_id;
        alu_cmd_rn  <= alu_cmd_id;
        imm_rn      <= imm_id;
        op2_type_rn <= op2_type_id;
        pc_rn       <= pc_id;
        instr_rn    <= instr_id;
      end
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
    for(int i = 0; i < DISPATCH_WIDTH; i++) begin
      freelist_if_rn.push_en[i]  = en_commit[i];
      freelist_if_rn.pop_en[i]   = valid_rn[i] & !stall_rn;
    end

    pop_reg_rn = freelist_if_rn.pop_reg;
  end

  // REN/DISP regs
  always_ff @(posedge clk) begin
    if (rst) begin
      for(int i = 0; i < DISPATCH_WIDTH; i++) begin
        valid_disp[i]    <= 0;
        alu_cmd_disp[i]  <= common::alu_cmd_t'(0);
        rs1_disp[i]      <= 0;
        op2_type_disp[i] <= common::op_type_t'(0);
        rs2_disp[i]      <= 0;
        imm_disp[i]      <= 0;
        phys_rd_disp[i]  <= 0;
        arch_rd_disp[i]  <= 0;
        pc_disp[i]       <= 0;
        instr_disp[i]    <= 0;
      end
    end else begin
      if (!stall_disp) begin
        valid_disp    <= valid_rn;
        alu_cmd_disp  <= alu_cmd_rn;
        rs1_disp[0]   <= rs1_data_rn[0];
        rs1_disp[1]   <= rd_rn[0] == rs1_rn[1] ? pop_reg_rn[0] : rs1_data_rn[1];
        op2_type_disp <= op2_type_rn;
        rs2_disp[0]   <= rs2_data_rn[0];
        rs2_disp[1]   <= rd_rn[0] == rs2_rn[1] ? pop_reg_rn[0] : rs2_data_rn[1];
        imm_disp      <= imm_rn;
        phys_rd_disp  <= pop_reg_rn;
        arch_rd_disp  <= rd_rn;
        pc_disp       <= pc_rn;
        instr_disp    <= instr_rn;
      end
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
    for(int i = 0; i < DISPATCH_WIDTH; i++) begin
      dispatch_if_disp.en[i] = valid_disp[i] & !stall_disp;
    end
    dispatch_if_disp.phys_rd = phys_rd_disp;
    dispatch_if_disp.arch_rd = arch_rd_disp;
    dispatch_if_disp.pc      = pc_disp;
    dispatch_if_disp.instr   = instr_disp;
    bank_addr_disp = dispatch_if_disp.bank_addr;
    rob_addr_disp  = dispatch_if_disp.rob_addr;

    wb_if_disp.en        = valid_wb;
    wb_if_disp.phys_rd   = phys_rd_wb;
    wb_if_disp.bank_addr = bank_addr_wb;
    wb_if_disp.rob_addr  = rob_addr_wb;

    arch_rd_commit = commit_if_disp.arch_rd;
    phys_rd_commit = commit_if_disp.phys_rd;
    en_commit      = commit_if_disp.en;
    pc_commit      = commit_if_disp.pc;
    instr_commit   = commit_if_disp.instr;

    op_fetch_if_disp.phys_rs1 = rs1_disp;
    op_fetch_if_disp.phys_rs2 = rs2_disp;

    phys_rs1_valid_disp = op_fetch_if_disp.rs1_valid;
    phys_rs2_valid_disp = op_fetch_if_disp.rs2_valid;
  end

  // DISP/ISSUE regs
  always_ff @(posedge clk) begin
    if (rst) begin
      for(int i = 0; i < DISPATCH_WIDTH; i++) begin
        valid_issue[i]     <= 0;
        alu_cmd_issue[i]   <= common::alu_cmd_t'(0);
        rs1_issue[i]       <= 0;
        rs1_valid_issue[i] <= 0;
        op2_type_issue[i]  <= common::op_type_t'(0);
        rs2_issue[i]       <= 0;
        rs2_valid_issue[i] <= 0;
        imm_issue[i]       <= 0;
        phys_rd_issue[i]   <= 0;
        bank_addr_issue[i] <= 0;
        rob_addr_issue[i]  <= 0;
        pc_issue[i]        <= 0;
        instr_issue[i]     <= 0;
      end
    end else begin
      if (!stall_issue) begin
        valid_issue     <= valid_disp;
        alu_cmd_issue   <= alu_cmd_disp;
        rs1_issue       <= rs1_disp;
        rs1_valid_issue[0] <= phys_rs1_valid_disp[0];
        rs1_valid_issue[1] <= phys_rd_disp[0] == rs1_disp[1] ? 0 : phys_rs1_valid_disp[1];
        op2_type_issue  <= op2_type_disp;
        rs2_issue       <= rs2_disp;
        rs2_valid_issue[0] <= phys_rs2_valid_disp[0];
        rs2_valid_issue[1] <= phys_rd_disp[0] == rs2_disp[1] ? 0 : phys_rs2_valid_disp[1];
        imm_issue       <= imm_disp;
        phys_rd_issue   <= phys_rd_disp;
        bank_addr_issue <= bank_addr_disp;
        rob_addr_issue  <= rob_addr_disp;
        pc_issue        <= pc_disp;
        instr_issue     <= instr_disp;
      end
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
    .ISSUE_QUEUE_SIZE(32)
  ) issue_queue (
    .clk,
    .rst,
    .dispatch_if(dispatch_if_issue.in),
    .wb_if(wb_if_issue.in),
    .issue_if(issue_if_issue.out)
  );

  always_comb begin
    for(int i = 0; i < DISPATCH_WIDTH; i++) begin
      dispatch_if_issue.en[i]   = valid_issue[i] & !stall_issue;
    end
    dispatch_if_issue.alu_cmd   = alu_cmd_issue;
    dispatch_if_issue.op1       = rs1_issue;
    dispatch_if_issue.op1_valid = rs1_valid_issue;
    dispatch_if_issue.op2       = op2_issue;
    dispatch_if_issue.op2_valid = op2_valid_issue;
    dispatch_if_issue.op2_type  = op2_type_issue;
    dispatch_if_issue.phys_rd   = phys_rd_issue;
    dispatch_if_issue.rob_addr  = rob_addr_issue;
    dispatch_if_issue.bank_addr = bank_addr_issue;
    dispatch_if_issue.pc        = pc_issue;
    dispatch_if_issue.instr     = instr_issue;
    
    wb_if_issue.valid = valid_wb;
    wb_if_issue.phys_rd = phys_rd_wb;

    valid_rread     = issue_if_issue.valid;
    alu_cmd_rread   = issue_if_issue.alu_cmd;
    op1_rread       = issue_if_issue.op1;
    op2_rread       = issue_if_issue.op2;
    op2_type_rread  = issue_if_issue.op2_type;
    phys_rd_rread   = issue_if_issue.phys_rd;
    bank_addr_rread = issue_if_issue.bank_addr;
    rob_addr_rread  = issue_if_issue.rob_addr;
    pc_rread        = issue_if_issue.pc;
    instr_rread     = issue_if_issue.instr;
  end

  logic [PHYS_REGS_ADDR_WIDTH-1:0] op2_rread_bit_cast [0:DISPATCH_WIDTH-1];
  always_comb begin
    for(int i = 0; i < DISPATCH_WIDTH; i++) begin
      op2_rread_bit_cast[i] = PHYS_REGS_ADDR_WIDTH'(op2_rread[i]);
    end
  end

  regfile #(
    .NUM_REGS(PHYS_REGS),
    .REG_WIDTH(32)
  ) phys_regfile(
    .clk,
    .rst,
    .addr_rs1(op1_rread),
    .addr_rs2(op2_rread_bit_cast),
    .addr_rd(phys_rd_wb),
    .rd_data(result_wb),
    .rd_wen(valid_wb),
    .rs1_data(rs1_data_rread),
    .rs2_data(rs2_data_rread)
  );

  // RREAD/EX regs
  always_ff @(posedge clk) begin
    if (rst) begin
      for(int i = 0; i < DISPATCH_WIDTH; i++) begin
        valid_ex[i]     <= 0;
        alu_cmd_ex[i]   <= common::alu_cmd_t'(0);
        op1_ex[i]       <= 0;
        op2_ex[i]       <= 0;
        phys_rd_ex[i]   <= 0;
        bank_addr_ex[i] <= 0;
        rob_addr_ex[i]  <= 0;
        pc_ex[i]        <= 0;
        instr_ex[i]     <= 0;
      end
    end else begin
      valid_ex     <= valid_rread;
      alu_cmd_ex   <= alu_cmd_rread;
      op1_ex       <= rs1_data_rread;
      for (int bank = 0; bank < DISPATCH_WIDTH; bank++) begin
        case(op2_type_rread[bank])
          common::IMM: op2_ex[bank] <= op2_rread[bank];
          common::REG: op2_ex[bank] <= rs2_data_rread[bank];
          default: op2_ex[bank] <= 32'hcafebabe;
        endcase
      end
      phys_rd_ex   <= phys_rd_rread;
      bank_addr_ex <= bank_addr_rread;
      rob_addr_ex  <= rob_addr_rread;
      pc_ex        <= pc_rread;
      instr_ex     <= instr_rread;
    end
  end

  generate
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
      for(int i = 0; i < DISPATCH_WIDTH; i++) begin
        valid_wb[i]     <= 0;
        result_wb[i]    <= 0;
        phys_rd_wb[i]   <= 0;
        bank_addr_wb[i] <= 0;
        rob_addr_wb[i]  <= 0;
        pc_wb[i]        <= 0;
        instr_wb[i]     <= 0;
      end
    end else begin
      valid_wb     <= valid_ex;
      result_wb    <= alu_out_ex;
      phys_rd_wb   <= phys_rd_ex;
      bank_addr_wb <= bank_addr_ex;
      rob_addr_wb  <= rob_addr_ex;
      pc_wb        <= pc_ex;
      instr_wb     <= instr_ex;
    end
  end

  regfile #(
    .NUM_REGS(32),
    .REG_WIDTH(PHYS_REGS_ADDR_WIDTH)
  ) commit_map_table(
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
