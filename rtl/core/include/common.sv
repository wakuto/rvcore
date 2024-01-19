`default_nettype none
`ifndef COMMON_H
`define COMMON_H

package common;
  typedef enum logic [1:0] {
    PC_JMP,     // jal
    COND_BR,    // beq, bne, b**
    REG_JMP,    // jalr
    NOT_BRANCH  // not a branch instruction
  } branch_type_t;
  typedef struct packed {
    logic [6:0] opcode;
    logic [4:0] rd, rs1, rs2, shamt;
    logic [2:0] funct3;
    logic [6:0] funct7;
    logic [11:0] imm_i;
    logic [11:0] imm_s;
    logic [12:0] imm_b;
    logic [31:0] imm_u;
    logic [20:0] imm_j;
  } instr_field;
  typedef enum logic {
    REG,
    IMM
  } op_type_t;
  typedef enum logic [4:0] {
    ADD,
    SUB,
    XOR,
    OR,
    AND,
    SRL,
    SRA,
    SLL,
    EQ,
    NE,
    LT,
    GE,
    LTU,
    GEU,
    BIT_C,
    SLT,
    SLTU,
    ILL
  } alu_cmd_t;
  typedef enum logic [2:0] {
    R_TYPE,
    I_TYPE,
    S_TYPE,
    B_TYPE,
    U_TYPE,
    J_TYPE
  } instr_type_t;
  typedef enum logic [3:0] {
    LB,
    LH,
    LW,
    LBU,
    LHU,
    SB,
    SH,
    SW,
    MEM_NONE
  } mem_access_type;
  typedef enum logic [2:0] {
    RI_TYPE_LUI,
    LOAD,
    JUMP,
    ZICSR,
    WB_MRET,
    WB_NONE
  } wb_sel_t;
  typedef enum logic [1:0] {
    PC_BRANCH,
    PC_MRET,
    PC_NEXT
  } pc_sel_t;
  // nop(addi x0, x0, 0)
  // verilator lint_off UNUSEDPARAM
  localparam [31:0] BUBBLE = 32'b000000000000_00000_000_00000_0010011;
  // verilator lint_on UNUSEDPARAM
endpackage

`endif
`default_nettype wire
