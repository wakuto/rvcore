`default_nettype none
module top(
  input  logic        reset,
  input  logic        clk,
  output logic        debug_ebreak,
  output logic [31:0] debug_reg[0:31],
  output logic        illegal_instr,
  input  logic        timer_int,
  input  logic        soft_int,
  input  logic        ext_int
);
  logic        aclk;
  logic        areset;

  assign aclk = clk;
  assign areset = reset;

  logic a_arvalid;
  logic a_arready;
  logic [31:0] a_araddr;
  logic [2:0] a_arprot;

  logic a_rvalid;
  logic a_rready;
  logic [31:0] a_rdata;
  logic [1:0] a_rresp;

  logic b_arvalid;
  logic b_arready;
  logic [31:0] b_araddr;
  logic [2:0] b_arprot;

  logic b_rvalid;
  logic b_rready;
  logic [31:0] b_rdata;
  logic [1:0] b_rresp;

  logic [31:0] awaddr;
  logic [2:0] awprot;
  logic awvalid;
  logic awready;

  logic [31:0] wdata;
  logic [3:0] wstrb;
  logic wvalid;
  logic wready;

  logic [1:0] bresp;
  logic bvalid;
  logic bready;

  axi_memory axi_memory (
    .aclk(!clk),
    .areset(reset),

    // 読み出し用ポート
    .a_arvalid,
    .a_arready,
    .a_araddr,
    .a_arprot,

    .a_rvalid,
    .a_rready,
    .a_rdata,
    .a_rresp,

    .b_arvalid,
    .b_arready,
    .b_araddr,
    .b_arprot,

    .b_rvalid,
    .b_rready,
    .b_rdata,
    .b_rresp,
    
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
  logic instr_valid;

  i_cache i_cache(
    .reset,
    // cpu側
    .clk,
    .addr(pc),
    .data(instruction),
    .data_valid(instr_valid),

    // memory側 axi4 lite(read)
    .aclk(clk),
    .areset(reset),
    .arvalid(a_arvalid),
    .arready(a_arready),
    .araddr(a_araddr),
    .arprot(a_arprot),

    .rvalid(a_rvalid),
    .rready(a_rready),
    .rdata(a_rdata),
    .rresp(a_rresp)
  );

  logic [31:0] address;
  logic read_enable;
  logic [31:0] read_data;
  logic read_valid;
  logic [31:0] write_data;
  logic write_enable;
  logic [3:0] write_wstrb;
  logic write_ready;

  d_cache d_cache (
    .reset,

    // cpu側
    .clk,
    .addr(address),
    .mem_wen(write_enable),
    .mem_ren(read_enable),
    .data_out(read_data),
    .data_read_valid(read_valid),
    .data_in(write_data),
    .data_in_strb(write_wstrb),
    .data_write_ready(write_ready),

    // memory側 axi4 lite
    // 読み出し用ポート
    .aclk,
    .areset,
    .arvalid(b_arvalid),
    .arready(b_arready),
    .araddr(b_araddr),
    .arprot(b_arprot),

    .rvalid(b_rvalid),
    .rready(b_rready),
    .rdata(b_rdata),
    .rresp(b_rresp),

    // 書き込み用ポート
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

  always_ff @(posedge clk) begin
    if (read_enable & read_valid) begin
      // $display("mem read:\t%h\t->%h", address, read_data);
    end
    if (write_enable & write_ready) begin
      // $display("mem write:\t%h\t<-%h", address, write_data);
    end
    if (instr_valid) begin
      // $display("execute :\t%h\t%h", pc, instruction);
    end
  end
  
  cpu cpu(
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
    .write_wstrb,  // 書き込むデータの幅
    .write_ready,

    .debug_ebreak,
    .debug_reg,
    .illegal_instr,
    .timer_int,
    .soft_int,
    .ext_int
  );

endmodule
`default_nettype wire

