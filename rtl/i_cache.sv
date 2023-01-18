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

  logic hit, dirty;
  logic [31:0] cache_data;
  logic [31:0] invalidate_addr;
  direct_map direct_map (
    .clk(~clk),
    .addr(addr),
    .hit,
    .dirty,
    .data(cache_data),

    .write_data(rdata),
    .write_strb(4'b1111),
    .write_valid(rready),
    .invalidate_addr,
    .write_access(1'b0)
  );

  enum logic [1:0] {HIT_CMP, ADDR_SEND, WAIT_DATA, END_ACCESS} _state;
  initial begin
    $display(HIT_CMP, ADDR_SEND, WAIT_DATA, END_ACCESS);
  end

  task hit_or_req();
    data_valid <= hit;
    if (hit) begin
      _state <= HIT_CMP;
      data <= cache_data;
    end else begin
      _state <= ADDR_SEND;
      arvalid <= 1'b1;
      araddr <= addr;
    end
  endtask

  always_ff @(negedge clk) begin
    if (reset) begin
      _state <= HIT_CMP;
    end else begin
      case(_state)
        HIT_CMP: begin
          hit_or_req();
        end
        ADDR_SEND: begin
          if (arready) begin
            _state <= WAIT_DATA;
            arvalid <= 1'b0;
          end
        end
        WAIT_DATA: begin
          if (rvalid) begin
            _state <= END_ACCESS;
            rready <= 1'b1;
            data_valid <= 1'b1;
            data <= rdata;
          end
        end
        END_ACCESS: begin
          rready <= 1'b0;
          hit_or_req();
        end
        default: begin
          _state <= _state;
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
