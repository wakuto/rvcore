`default_nettype none

interface fifoIf #(
// データ幅
  parameter DATA_WIDTH = 32,
// データ数
  parameter DEPTH = 16
)(input wire clk, rst);
  logic                  wr_en;
  logic                  rd_en;
  logic [DATA_WIDTH-1:0] wr_data;
  logic [DATA_WIDTH-1:0] rd_data;
  logic                  empty;
  logic                  full;

  modport reader (
    input  clk, rst,
    output rd_en,
    input  rd_data,
    input  empty
  );

  modport writer(
    input clk, rst,
    output wr_en, wr_data,
    input  full
  );

  modport fifo (
    input  clk, rst,
    input  wr_en, wr_data,
    input  rd_en,
    output rd_data,
    output empty, full
  );
endinterface

`default_nettype wire
