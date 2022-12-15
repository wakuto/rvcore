`default_nettype none
`include "./riscv_instr.sv"
`include "./common.sv"

module csr_reg (
    input logic clock,
    input logic reset,

    input logic csr_instr,
    input logic [11:0] csr_addr,
    input logic [31:0] csr_instr_src,
    output logic [31:0] csr_instr_dst,

    input logic mret_instr,

    // interrupt flags
    input logic illegal_instr,
    input logic env_call,
    input logic load_access,
    input logic break_point,
    input logic timer_int,
    input logic soft_int,
    input logic ext_int,

    // interrupt data
    input logic [31:0] pc,
    output logic [31:0] mtvec,
    output logic [31:0] mepc,
    output logic csr_pc_sel
);
  import riscv_instr::*;

  enum logic [3:0] {
    MSTATUS,
    MIE,
    MTVEC,
    MEPC,
    MCAUSE,
    MIP,
    CYCLE,
    CYCLEH,
    OTHER
  } csr_sel;
  logic [31:0] reg_csr[0:csr_sel.num()-1];
  assign mtvec = reg_csr[MTVEC];

  logic [6:0] flags;

  localparam BIT_ENV = 0;
  localparam BIT_ILL = 1;
  localparam BIT_LOAD = 2;
  localparam BIT_BRK = 3;
  localparam BIT_EXT = 4;
  localparam BIT_SOFT = 5;
  localparam BIT_TIM = 6;

  always_comb begin
    flags[BIT_ENV]  = env_call;
    flags[BIT_ILL]  = illegal_instr;
    flags[BIT_LOAD] = load_access;
    flags[BIT_BRK]  = break_point;
    flags[BIT_EXT]  = ext_int;
    flags[BIT_SOFT] = soft_int;
    flags[BIT_TIM]  = timer_int;

    csr_pc_sel =
      ((|flags & reg_csr[MSTATUS][B_MIE])  & 
        ((flags[BIT_EXT] & reg_csr[MIE][B_MEIE]) |
         (flags[BIT_TIM] & reg_csr[MIE][B_MTIE]) |
         (flags[BIT_SOFT] & reg_csr[MIE][B_MSIE])))
      | mret_instr;

    mepc = reg_csr[MEPC];

    casez (csr_addr)
      CSR_MSTATUS: csr_sel = MSTATUS;
      CSR_MIE: csr_sel = MIE;
      CSR_MTVEC: csr_sel = MTVEC;
      CSR_MEPC: csr_sel = MEPC;
      CSR_MCAUSE: csr_sel = MCAUSE;
      CSR_MIP: csr_sel = MIP;
      CSR_CYCLE: csr_sel = CYCLE;
      CSR_CYCLEH: csr_sel = CYCLEH;
      default: csr_sel = OTHER;
    endcase

    csr_instr_dst = reg_csr[csr_sel];
  end

  localparam B_MIE = 3;
  localparam B_MPIE = 7;
  localparam B_MSIE = 3;
  localparam B_MTIE = 7;
  localparam B_MEIE = 11;

  task set_inter_regs();
    reg_csr[MEPC] <= pc;
    reg_csr[MSTATUS][B_MIE] <= 1'b0;
    reg_csr[MSTATUS][B_MPIE] <= 1'b1;
  endtask

  always_ff @(posedge clock or posedge reset) begin
    if (reset) begin
      for (int i = 0; i < csr_sel.num(); i++) reg_csr[i] <= 32'h0;
    end else begin

      // no interrupt && is csr instruction
      if (~|flags & csr_instr) begin
        reg_csr[csr_sel] <= csr_instr_src;
      end
      // interrupt && interrupt enable
      else if (|flags && reg_csr[MSTATUS][B_MIE]) begin
        if (csr_pc_sel) begin
          reg_csr[MEPC] <= pc;
          reg_csr[MSTATUS][B_MIE] <= 1'b0;
          reg_csr[MSTATUS][B_MPIE] <= 1'b1;
        end
        if (flags[BIT_TIM] & reg_csr[MIE][B_MTIE]) begin
          reg_csr[MCAUSE] <= 32'h80000000 | 32'd7;
        end
        else if (flags[BIT_SOFT] & reg_csr[MIE][B_MSIE]) begin
          reg_csr[MCAUSE] <= 32'h80000000 | 32'd3;
        end
        else if (flags[BIT_EXT] & reg_csr[MIE][B_MEIE]) begin
          reg_csr[MCAUSE] <= 32'h80000000 | 32'd11;
        end
        // no (timer, software, external) interrupt && has exception
        else if (~|flags[6:4] & |flags[3:0]) begin
          if (flags[BIT_BRK])
            reg_csr[MCAUSE] <= 32'h3;
          else if (flags[BIT_LOAD])
            reg_csr[MCAUSE] <= 32'h5;
          else if (flags[BIT_ILL])
            reg_csr[MCAUSE] <= 32'h2;
          else if (flags[BIT_ENV])
            reg_csr[MCAUSE] <= 32'h11;
        end
      end
      else if (mret_instr) begin
        reg_csr[MSTATUS][B_MIE] <= 1'b1;
        reg_csr[MSTATUS][B_MPIE] <= 1'b0;
      end

      {reg_csr[CYCLEH], reg_csr[CYCLE]} <= {reg_csr[CYCLEH], reg_csr[CYCLE]} + 64'h1;

    end
  end
endmodule
`default_nettype wire
