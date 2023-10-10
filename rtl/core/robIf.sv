`default_nettype none

`include "common.sv"

interface robIf(input clk, input rst);
  // 2命令同時実行なので2つのポートを持つ
  logic [ 7: 0] phys_rd [0:1];;
  logic [ 4: 0] arch_rd [0:1];;
  logic         rd_en [0:1];
  logic         full;
  logic [ 4: 0] commit_target_tag [0:1];
  logic         commit_target_en [0:1];

  modport rob (
    input clk, rst,
    input phys_rd,
    input arch_rd,
    input rd_en,
    output full,
    input commit_target_tag,
    input commit_target_en
  );

  modport append (
    output phys_rd,
    output arch_rd,
    output rd_en,
    input  full
  );

  modport commit (
    output commit_target_tag,
    output commit_target_en
  );
endinterface

`default_nettype wire
