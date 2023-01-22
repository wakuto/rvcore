`default_nettype none

module i_cache (
  input  logic        reset,
  // cpu側
  input  logic        clk,
  input  logic [31:0] addr,
  output logic [31:0] data,
  output logic        data_valid,

  // memory側 axi4 lite(read)
  input  logic        aclk,
  input  logic        areset,
  output logic        arvalid,
  input  logic        arready,
  output logic [31:0] araddr,
  output logic [2:0]  arprot,

  input  logic        rvalid,
  output logic        rready,
  input  logic [31:0] rdata,
  input  logic [1:0]  rresp
);
  assign arprot = 3'b101; // instruction & secure & privileged

  logic hit, dirty, cache_wen, data_valid_sync;
  logic [31:0] cache_data;
  logic [31:0] invalidate_addr;

  always_comb begin
    cache_wen = (state == END_ACCESS);
    data_valid = data_valid_sync & hit;
  end

  direct_map direct_map (
    .clk(~clk),
    .addr(addr),
    .hit,
    .dirty,
    .data(data),

    .write_data(rdata),
    .write_valid(cache_wen),
    .invalidate_addr,
    .write_access(1'b0)
  );

  enum logic [1:0] {HIT_CMP, SEND_ADDR, WAIT_DATA, END_ACCESS} state;

  task hit_or_req();
    if (hit) begin
      state <= HIT_CMP;
      data <= cache_data;
    end else begin
      state <= SEND_ADDR;
      arvalid <= 1'b1;
      araddr <= addr;
    end
  endtask

  always_ff @(negedge clk) begin
    if (reset) begin
      state <= HIT_CMP;
      data_valid_sync <= 1'b0;
    end else begin
      case(state)
        HIT_CMP: begin
          // READ
          // hit
          if (hit) begin
            state <= HIT_CMP;
            data_valid_sync <= 1'b1;
          // miss
          end else begin
            state <= SEND_ADDR;
            data_valid_sync <= 1'b0;
            arvalid <= 1'b1;
            araddr <= addr;
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
            // $display("AXI read:  ", araddr, "\t->", rdata);
            state <= HIT_CMP;
            rready <= 1'b0;
            data_valid_sync <= 1'b1;
          //end
        end
        /*
        HIT_CMP: begin
          data_valid <= hit;
          hit_or_req();
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
            data_valid <= 1'b1;
            data <= rdata;
          end
        end
        END_ACCESS: begin
          rready <= 1'b0;
          data_valid <= 1'b1;
          state <= HIT_CMP;
          // hit_or_req();
        end
        */
        default: begin
          state <= state;
        end
      endcase
    end
  end




  wire _unused = &{1'b0,
                   dirty,
                   invalidate_addr,
                   aclk,
                   areset,
                   rresp,
                   1'b0};
endmodule

`default_nettype wire
