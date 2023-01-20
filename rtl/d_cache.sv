`default_nettype none

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
  input  logic [3:0]  data_in_strb,
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

  initial begin
    $display(HIT_CMP, SEND_ADDR, WAIT_DATA, END_ACCESS, SEND_DATA, WAIT_WRITING);
  end

  logic hit, dirty, cache_wen;
  logic [31:0] invalidate_addr;

  direct_map direct_map (
  .clk(~clk),
  .addr,
  .hit,
  .dirty,
  .data(data_out),

  .write_data(mem_wen ? data_in : rdata),
  .write_strb(data_in_strb),
  .write_valid(cache_wen),
  .invalidate_addr,
  // 書き込みアクセスの場合アサート
  .write_access(mem_wen)
  );

  always_comb begin
    cache_wen = 1'b0;

    if (state == HIT_CMP & mem_wen & (hit | !dirty)) begin
      cache_wen = 1'b1;
    end else if (state == WAIT_WRITING & bvalid) begin
      cache_wen = 1'b1;
    end else if (state == END_ACCESS & mem_ren) begin
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
          // READ
          // hit
          if (hit & mem_ren) begin
            state <= HIT_CMP;
            data_read_valid <= 1'b1;
            data_write_ready <= 1'b0;
          // miss
          end else if (!hit & mem_ren & !dirty) begin
            state <= SEND_ADDR;
            data_read_valid <= 1'b0;
            data_write_ready <= 1'b0;
            arvalid <= 1'b1;
            araddr <= addr;
          // WRITE
          // hit
          end else if (mem_wen & (hit | !dirty)) begin
            state <= HIT_CMP;
            data_read_valid <= 1'b0;
            data_write_ready <= 1'b1;
          // miss (write back)
          end else if (mem_wen & !hit & dirty) begin
            state <= SEND_DATA;
            data_read_valid <= 1'b0;
            data_write_ready <= 1'b0;
            awvalid <= 1'b1;
            wvalid <= 1'b1;
            awaddr <= invalidate_addr;
            // data_out: invalidate_data
            wdata <= data_out;
            wstrb <= 4'hF;
            bready <= 1'b1;
          end else begin
            state <= HIT_CMP;
            data_read_valid <= 1'b0;
            data_write_ready <= 1'b0;
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
            $display("AXI read:  %h\t->%h", araddr, rdata);
            state <= HIT_CMP;
            rready <= 1'b0;
            data_read_valid <= 1'b1;
          //end
        end
        SEND_DATA: begin
          if (awready & wready) begin
            $display("AXI write: %h\t->%h", awaddr, wdata);
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
              data_write_ready <= 1'b1;
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
