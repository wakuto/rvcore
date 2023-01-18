`default_nettype none

module d_cache (
  input  logic        reset,

  // cpu側
  input  logic        clk,
  input  logic [31:0] addr,
  input  logic        mem_wen,
  output logic [31:0] data_out,
  output logic        data_read_valid,
  input  logic [31:0] data_in,
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

  enum logic [2:0] {HIT_CMP, SEND_ADDR, WAIT_DATA, END_ACCESS, SEND_DATA, WAIT_WRITING} state;

  logic hit, read, dirty, cache_wen;
  assign read = !mem_wen;

  direct_map direct_map (
  .clk,
  .addr,
  .hit,
  .dirty,
  .data,

  .write_data(mem_wen ? data_in : rdata),
  .write_valid(cache_wen),
  // 書き込みアクセスの場合アサート
  .write_access(mem_wen)
  );

  always_comb begin
    cache_wen = 1'b0;

    if (state == HIT_CMP & !read & (hit | !dirty)) begin
      cache_wen = 1'b1;
    end else if (state == SEND_DATA & awready & wready) begin
      cache_wen = mem_wen;
    end else if (state == END_ACCESS & hit & read) begin
      cache_wen = 1'b1;
    end
  end

  // state machine
  always_ff @(negedge clk) begin
    if (!reset) begin
      state <= HIT_CMP;
      data_read_valid <= 1'b0;
      data_write_ready <= 1'b0;
    end else begin
      if (cache_wen) begin
        data_write_ready <= 1'b1;
      end else begin
        data_write_ready <= 1'b0;
      end
      case(state) begin
        HIT_CMP: begin
          // READ
          // hit
          if (hit & read) begin
            state <= HIT_CMP;
            data_read_valid <= 1'b1;
          // miss
          end else if (!hit & read & !dirty) begin
            state <= SEND_ADDR;
            data_read_valid <= 1'b0;
            arvalid <= 1'b1;
          // WRITE
          // hit
          end else if (!read & (hit | !dirty)) begin
            state <= HIT_CMP;
            data_read_valid <= 1'b0;
          // miss (write back)
          end else if (!hit & dirty) begin
            state <= SEND_DATA;
            data_read_valid <= 1'b0;
            awvalid <= 1'b1;
            wvalid <= 1'b1;
            bready <= 1'b1;
            awaddr <= 
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
          if (hit & read) begin
            state <= HIT_CMP;
            rready <= 1'b0;
            data_valid <= 1'b1;
          end
        end
        SEND_DATA: begin
          if (awready & wready) begin
            state <= WAIT_WRITING;
            awvalid <= 1'b0;
            wvalid <= 1'b0;
          end
        end
        WAIT_WRITING: begin
          if (bvalid) begin
            bready <= 1'b0;
            if (!read) begin
              state <= HIT_CMP;
            end else if (read) begin
              state <= SEND_ADDR;
              arvalid <= 1'b1;
            end
          end
        end
        default: begin
        end
      end
    end
  end

endmodule

`default_nettype wire
