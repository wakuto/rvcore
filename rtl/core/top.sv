`default_nettype none
module top(
  input  wire logic        reset,
  input  wire logic        clk,
  output      logic        debug_ebreak,
  output      logic        debug_ecall,
  output      logic [31:0] debug_reg[0:31],
  output      logic        illegal_instr,
  input  wire logic        timer_int,
  input  wire logic        soft_int,
  input  wire logic        ext_int
);

  logic [31:0] pc;
  logic [31:0] instruction;
  logic instr_valid;

  memory imem(
    .clk,
    .reset,
    .address(pc),
    .read_data(instruction),
    .read_enable(1'b1),
    .read_valid(instr_valid),
    .write_data(32'd0),
    .write_enable(1'b0),
    .write_wstrb(4'b0),
    .write_ready()
  );

  logic [31:0] address;
  logic [31:0] read_data;
  logic        read_enable;
  logic        read_valid;
  logic [31:0] write_data;
  logic        write_enable;
  logic [ 3:0] strb;
  logic        write_ready;

  memory dmem(
    .clk,
    .reset,
    .address,
    .read_data,
    .read_enable,
    .read_valid,
    .write_data,
    .write_enable,
    .write_wstrb(strb),
    .write_ready
  );
  
  core core(
    .clock(clk),
    .reset,

    // instruction data
    .pc,
    .instruction,
    .instr_valid,

    // memory data
    .address,
    .read_data,
    .read_enable,     // データを読むときにアサート
    .read_valid,  // メモリ出力の有効フラグ
    .write_data,
    .write_enable,    // データを書くときにアサート->request signal
    .strb,  // 書き込むデータの幅
    .write_ready,

    .debug_ebreak,
    .debug_ecall,
    .debug_reg,
    .illegal_instr,
    .timer_int,
    .soft_int,
    .ext_int
  );

endmodule
`default_nettype wire

