`default_nettype none
`include "./memory_map.sv"

module d_cache (
  input  logic        reset,

  // cpu側
  input  logic        clk,
  input  logic [31:0] addr,
  input  logic        mem_wen,
  input  logic        mem_ren,
  output logic [31:0] data_out,
  output logic        data_read_valid,
  input  logic [31:0] data_in,
  input  logic [3:0]  strb,
  output logic        data_write_ready,

  // memory側 axi4 lite
  // 読み出し用ポート
  input  logic        aclk,
  input  logic        areset,
  output logic        arvalid,
  input  logic        arready,
  output logic [31:0] araddr,
  output logic [2:0]  arprot,

  input  logic        rvalid,
  output logic        rready,
  input  logic [31:0] rdata,
  input  logic [1:0]  rresp,

  // 書き込み用ポート
  output logic [31:0] awaddr,
  output logic [2:0]  awprot,
  output logic        awvalid,
  input  logic        awready,

  output logic [31:0] wdata,
  output logic [3:0]  wstrb,
  output logic        wvalid,
  input  logic        wready,

  input  logic [1:0]  bresp,
  input  logic        bvalid,
  output logic        bready
);
  // data & secure & unprivileged
  assign arprot = 3'b000;
  assign awprot = 3'b000;

  enum logic [2:0] {HIT_CMP, SEND_ADDR, WAIT_DATA, END_ACCESS, SEND_DATA, WAIT_WRITING} state;

  logic hit, dirty, cache_wen;
  logic [31:0] invalidate_addr;

  import memory_map::*;
  logic cacheable;
  always_comb begin
    /* verilator lint_off UNSIGNED */
    cacheable = DRAM_BASE <= addr & addr < DRAM_BASE + DRAM_SIZE;
  end


  localparam LINE_SIZE = 4;
  localparam LINE_OFFSET = $clog2(LINE_SIZE);
  localparam CACHE_SIZE = 1024;
  wire [LINE_OFFSET-1:0] addr_offset = addr[LINE_OFFSET-1:0] & {LINE_OFFSET{1'b1}};
  wire [31:0] current_line = addr & ~32'({LINE_OFFSET{1'B1}});
  wire [31:0] next_line = current_line + LINE_SIZE;
  wire [2:0] access_size = (strb == 4'b0001) ? 3'h1 :
                            (strb == 4'b0011) ? 3'h2 :
                            (strb == 4'b1111) ? 3'h4 : 3'h4;
  wire double_access = (LINE_SIZE - access_size) < addr_offset;
  logic [31:0] read_data1;
  logic [31:0] read_data2;
  logic data2_ready;
  logic [31:0] cache_addr;
  logic [31:0] cache_dout;
  logic [31:0] cache_din;

  direct_map #(
    .LINE_SIZE(LINE_SIZE),
    .CACHE_SIZE(CACHE_SIZE)
  ) direct_map (
  .clk(~clk),
  .addr(cache_addr),
  .hit,
  .dirty,
  .data(cache_dout),

  .write_data(cache_din),
  .write_valid(cache_wen),
  .invalidate_addr,
  // 書き込みアクセスの場合アサート
  .write_access(mem_wen)
  );
  wire [31:0] shift_amount = 32'(addr_offset) << 3;
  wire [31:0] read_lower = (cache_dout >> shift_amount);
  wire [31:0] read_higher = (read_data2 >> ((LINE_OFFSET-32'(addr_offset))<<3));
  wire [31:0] write_higher_mask = ~(32'h0) << (32'(addr_offset) << 32'h3);
  wire [31:0] strb_32bit = {{8{strb[3]}}, {8{strb[2]}}, {8{strb[1]}}, {8{strb[0]}}};
  wire [31:0] write_orig = cache_dout & ~(strb_32bit << (32'(addr_offset) << 3));
  wire [31:0] write_new = (data_in & strb_32bit) << (32'(addr_offset) << 3);

  always_comb begin
    // data_out = (readdata2 >> ((clog2(line_size)-addr_offset)<<3)) | (readdata >> (addr_offset<<3))

    // 常にアラインされたアドレスを供給
    if (double_access & !data2_ready) begin
      cache_addr = next_line;
    end else begin
      cache_addr = current_line;
    end

    if (state == END_ACCESS & mem_wen) begin
      cache_din = rdata;
    end else if (mem_wen & double_access & !data2_ready) begin
      cache_din = (cache_dout & write_higher_mask) | (data_in & ~write_higher_mask);
    end else if (mem_wen) begin
      cache_din = (write_orig) | (write_new);
    end else begin
      cache_din = rdata;
    end

    cache_wen = 1'b0;
    if (cacheable & state == HIT_CMP & mem_wen & 
      (hit | (!dirty & strb == 4'b1111 & addr_offset == 0))) begin
      cache_wen = 1'b1;
    end else if (cacheable & state == END_ACCESS & mem_wen) begin
      cache_wen = 1'b1;
    end else if (cacheable & state == WAIT_WRITING & bvalid) begin
      cache_wen = 1'b1;
    end else if (cacheable & state == END_ACCESS & mem_ren) begin
      cache_wen = 1'b1;
    end
  end

  // state machine
  always_ff @(negedge clk) begin
    if (reset) begin
      state <= HIT_CMP;
      data_read_valid <= 1'b0;
      data_write_ready <= 1'b0;
    end else begin
      case(state)
        HIT_CMP: begin
          if (cacheable & (mem_ren | mem_wen)) begin
            // READ
            // hit
            if (hit & mem_ren) begin
              state <= HIT_CMP;
              data_write_ready <= 1'b0;
              if (double_access & !data2_ready) begin
                read_data2 <= cache_dout;
                data2_ready <= 1'b1;
                data_read_valid <= 1'b0;
              end else begin
                // あやしい
                data2_ready <= 1'b0;
                data_read_valid <= 1'b1;
                data_out <= (read_higher | read_lower);
              end
            // miss
            end else if (!hit & mem_ren & !dirty) begin
              state <= SEND_ADDR;
              data_read_valid <= 1'b0;
              data_write_ready <= 1'b0;
              arvalid <= 1'b1;
              araddr <= cache_addr;
            // WRITE
            // hit
            // ヒットするか，すべてを上書きするならそのまま書き込む
            end else if (mem_wen & (hit | (!dirty & strb == 4'b1111 & addr_offset == 0))) begin
              state <= HIT_CMP;
              data_read_valid <= 1'b0;
              if (double_access & !data2_ready) begin
                data2_ready <= 1'b1;
              end else begin
                data2_ready <= 1'b0;
                data_write_ready <= 1'b1;
              end
            // ヒットしなかったけどdirtyじゃない
            // すべてを上書きしないので，
            // 書き込まない部分のデータを取得
            end else if (mem_wen & !dirty) begin
              state <= SEND_ADDR;
              data_read_valid <= 1'b0;
              data_write_ready <= 1'b0;
              arvalid <= 1'b1;
              if (double_access & !data2_ready) begin
                araddr <= next_line;
              end else begin
                araddr <= current_line;
              end
            // miss キャッシュから掃き出す
            end else if (mem_wen & !hit & dirty) begin
              state <= SEND_DATA;
              data_read_valid <= 1'b0;
              data_write_ready <= 1'b0;
              awvalid <= 1'b1;
              wvalid <= 1'b1;
              awaddr <= invalidate_addr;
              // data_out: invalidate_data
              wdata <= data_out;
              wstrb <= strb;
              bready <= 1'b1;
            end else begin
              state <= HIT_CMP;
              data_read_valid <= 1'b0;
              data_write_ready <= 1'b0;
            end
          end else if (mem_ren | mem_wen) begin
            // キャッシュしないアドレスたちの処理
            if (mem_wen) begin
              state <= SEND_DATA;
              data_read_valid <= 1'b0;
              data_write_ready <= 1'b0;
              awvalid <= 1'b1;
              wvalid <= 1'b1;
              awaddr <= addr;
              wdata <= data_in;
              wstrb <= strb;
              bready <= 1'b1;
            end else if(mem_ren) begin
              state <= SEND_ADDR;
              data_read_valid <= 1'b0;
              data_write_ready <= 1'b0;
              arvalid <= 1'b1;
              araddr <= addr;
            end
          end else begin
            data_read_valid <= 1'b0;
            data_write_ready <= 1'b0;
            state <= HIT_CMP;
          end
        end
        SEND_ADDR: begin
          if (arready) begin
            state <= WAIT_DATA;
            arvalid <= 1'b0;
          end
        end
        WAIT_DATA: begin
          if (rvalid) begin
            state <= END_ACCESS;
            rready <= 1'b1;
          end
        end
        END_ACCESS: begin
          //if (hit & read) begin
            // $display("AXI read:  %h\t->%h", araddr, rdata);
            state <= HIT_CMP;
            rready <= 1'b0;
            if (mem_ren) begin
              if (double_access & !data2_ready) begin
                data2_ready <= 1'b1;
                read_data2 <= rdata;
                data_read_valid <= 1'b0;
              end else begin
                data_out <= rdata;
                data_read_valid <= 1'b1;
              end
            end else if(mem_wen) begin
              // 怪しい
              if (double_access & !data2_ready) begin
                data2_ready <= 1'b1;
                data_read_valid <= 1'b0;
              end else begin
                data_read_valid <= 1'b1;
              end
            end
          //end
        end
        SEND_DATA: begin
          if (awready & wready) begin
            // $display("AXI write: %h\t->%h", awaddr, wdata);
            state <= WAIT_WRITING;
            awvalid <= 1'b0;
            wvalid <= 1'b0;
          end
        end
        WAIT_WRITING: begin
          if (bvalid) begin
            if (mem_wen) begin
              bready <= 1'b0;
              state <= HIT_CMP;
              if (double_access & !data2_ready) begin
                data2_ready <= 1'b1;
              end else begin
                data2_ready <= 1'b0;
                data_write_ready <= 1'b1;
              end
            end else if (mem_ren) begin
              bready <= 1'b0;
              state <= SEND_ADDR;
              arvalid <= 1'b1;
            end
          end
        end
        default: begin
          state <= HIT_CMP;
        end
      endcase
    end
  end

  wire _unused = &{
    1'b0,
    aclk,
    areset,
    rresp,
    bresp,
    1'b0
  };

endmodule

`default_nettype wire
