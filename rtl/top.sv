`default_nettype none
parameter [31:0] BUBBLE = 31'h00000013; // addi x0, x0, 0
module top(
  input  logic        reset,
  input  logic        clk
);
  axi_memory axi_memory (
    // 読み出し用ポート
    .aclk(clk),
    .areset(reset),
    .arvalid,
    .arready,
    .araddr,
    .arprot,

    .rvalid,
    .rready,
    .rdata,
    .rresp,

    
    .awaddr,
    .awprot,
    .awvalid,
    .awready,

    .wdata,
    .wstrb,
    .wvalid,
    .wready,

    .bresp,
    .bvalid,
    .bready
  );

  logic [31:0] pc;
  logic [31:0] instruction;
  logic inst_valid;

  i_cache i_cache(
    .reset,
    // cpu側
    .clk,
    .addr(pc),
    .data(instruction),
    .data_ready(inst_valid),

    // memory側 axi4 lite(read)
    .axi_aclk,
    .axi_areset,
    .axi_arvalid,
    .axi_arready,
    .axi_araddr,
    .axi_arprot,

    .axi_rvalid,
    .axi_rready,
    .axi_rdata,
    .axi_rresp
  );
  
  cpu cpu(
    .clock(clk),
    .reset,

    // instruction data
    .pc,
    .instruction(inst_valid ? instruction : BUBBLE,

    // memory data
    .address,
    .read_data,
    .read_enable,     // データを読むときにアサート
    .read_valid,  // メモリ出力の有効フラグ
    .write_data,
    .write_enable,    // データを書くときにアサート->request signal
    .write_wstrb,  // 書き込むデータの幅

    .debug_ebreak,
    .debug_reg[0:31],
    .illegal_instr,
    .timer_int,
    .soft_int,
    .ext_int
  );

endmodule
`default_nettype wire

