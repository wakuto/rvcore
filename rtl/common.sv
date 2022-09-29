`ifndef COMMON_H
`define COMMON_H

package common;
  typedef enum logic [3:0] {ADD, SUB, XOR, OR, AND, SRL, SRA, SLL, EQ, NE, LT, GE, LTU, GEU} alu_cmd;
  typedef enum logic [2:0] {R_TYPE, I_TYPE, S_TYPE, B_TYPE, U_TYPE, J_TYPE} instr_type;
  typedef enum logic [3:0] {LB, LH, LW, LBU, LHU, SB, SH, SW, NONE} mem_access_type;
endpackage

`endif
