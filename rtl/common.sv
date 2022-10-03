`ifndef COMMON_H
`define COMMON_H

package common;
  typedef enum logic [3:0] {
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
    GEU
  } alu_cmd;
  typedef enum logic [2:0] {
    R_TYPE,
    I_TYPE,
    S_TYPE,
    B_TYPE,
    U_TYPE,
    J_TYPE
  } instr_type;
  typedef enum logic [3:0] {
    LB,
    LH,
    LW,
    LBU,
    LHU,
    SB,
    SH,
    SW,
    NONE
  } mem_access_type;
  // nop(addi x0, x0, 0)
  localparam [31:0] BUBBLE = 32'b000000000000_00000_000_00000_0010011;
endpackage

`endif
