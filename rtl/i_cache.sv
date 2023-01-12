`default_nettype none

module i_cache (
  input  logic        reset,
  // cpu側
  input  logic        clk,
  input  logic [31:0] addr,
  output logic [31:0] data,
  input  logic        addr_valid,
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

  enum logic [1:0] {WAIT, TAG_COMP, ADDR_REQ, DATA_RECV} state;
  logic cache_hit;

  logic [31:0] cache_dout;
  direct_map direct_map (
    .clk,
    .req_addr(addr),
    .hit(cache_hit),
    .data(cache_dout),

    .write_addr(addr),
    .write_data(axi_rdata),
    .write_valid(axi_rvalid)
  );

  always_ff @(posedge clk) begin
    if (reset) begin
      state <= WAIT;
    end else begin
      case(state)
        WAIT: begin
          if (addr_valid) begin
            state <= TAG_COMP;
            // data output
            // cache decision
            data <= cache_dout;
            data_ready <= cache_hit;
          end
        end
        TAG_COMP: begin
          if (cache_hit) begin // hit
            state <= WAIT;
          end else begin // miss
            state <= ADDR_REQ;
            // addr request
            data_ready <= 1'b0;
            axi_arvalid <= 1'b1;
            axi_araddr <= addr;
          end
        end
        ADDR_REQ: begin
          if (axi_arvalid & axi_arready) begin
            axi_arvalid <= 1'b0;
          end
          // raise data_ready
          if (axi_rvalid) begin
            state <= DATA_RECV;
            axi_rready <= 1'b1;
            data_ready <= 1'b1;
            data <= axi_rdata;
            // store data to cache
          end
        end
        DATA_RECV: begin
          state <= WAIT;
          axi_rready <= 1'b0;
          data_ready <= 1'b0;
          data <= 32'b0;
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
