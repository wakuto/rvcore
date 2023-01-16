`default_nettype none

module i_cache (
  input  logic        reset,
  // cpu側
  input  logic        clk,
  input  logic [31:0] addr,
  output logic [31:0] data,
  output logic        data_ready,

  // memory側 axi4 lite(read)
  input  logic        axi_aclk,
  input  logic        axi_areset,
  output logic        axi_arvalid,
  input  logic        axi_arready,
  output logic [31:0] axi_araddr,
  output logic [2:0]  axi_arprot,

  input  logic        axi_rvalid,
  output logic        axi_rready,
  input  logic [31:0] axi_rdata,
  input  logic [1:0]  axi_rresp
);
  assign axi_arprot = 3'b101; // instruction & secure & privileged

  logic hit;
  logic [31:0] cache_data;
  direct_map direct_map (
    .clk(~clk),
    .req_addr(addr),
    .hit,
    .data(cache_data),

    .write_addr(addr),
    .write_data(axi_rdata),
    .write_valid(axi_rready)
  );

  enum logic [1:0] {HIT_CMP, ADDR_SEND, WAIT_DATA, END_ACCESS} _state;
  initial begin
    $display(HIT_CMP, ADDR_SEND, WAIT_DATA, END_ACCESS);
  end

  task hit_or_req();
    data_ready <= hit;
    if (hit) begin
      _state <= HIT_CMP;
      data <= cache_data;
    end else begin
      _state <= ADDR_SEND;
      axi_arvalid <= 1'b1;
      axi_araddr <= addr;
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
          if (axi_arready) begin
            _state <= WAIT_DATA;
            axi_arvalid <= 1'b0;
          end
        end
        WAIT_DATA: begin
          if (axi_rvalid) begin
            _state <= END_ACCESS;
            axi_rready <= 1'b1;
            data_ready <= 1'b1;
            data <= axi_rdata;
          end
        end
        END_ACCESS: begin
          axi_rready <= 1'b0;
          hit_or_req();
        end
        default: begin
          _state <= _state;
        end
      endcase
    end
  end




  wire _unused = &{1'b0,
                   axi_aclk,
                   axi_areset,
                   axi_rresp,
                   1'b0};
endmodule

`default_nettype wire
