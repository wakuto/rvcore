/* @@@@@@@@@@@@ Simulation only @@@@@@@@@@@@ */
`default_nettype none

module axi_memory(
  input  logic        aclk,
  input  logic        areset,

  // 読み出し用ポート1
  input  logic        a_arvalid,
  output logic        a_arready,
  input  logic [31:0] a_araddr,
  input  logic [2:0]  a_arprot,

  output logic        a_rvalid,
  input  logic        a_rready,
  output logic [31:0] a_rdata,
  output logic [1:0]  a_rresp,

  // 読み出し用ポート2
  input  logic        b_arvalid,
  output logic        b_arready,
  input  logic [31:0] b_araddr,
  input  logic [2:0]  b_arprot,

  output logic        b_rvalid,
  input  logic        b_rready,
  output logic [31:0] b_rdata,
  output logic [1:0]  b_rresp,

  // 書き込み用ポート
  input  logic [31:0] awaddr,
  input  logic [2:0]  awprot,
  input  logic        awvalid,
  output logic        awready,

  input  logic [31:0] wdata,
  input  logic [3:0]  wstrb,
  input  logic        wvalid,
  output logic        wready,

  output logic [1:0]  bresp,
  output logic        bvalid,
  input  logic        bready
);
  assign a_rresp = 2'b00; // OK
  assign b_rresp = 2'b00; // OK
  assign bresp = 2'b00;

  logic [7:0] memory[4096*4-1:0];

  logic [31:0] a_counter, b_counter;
  int fd; //, i;
  
  initial begin
    a_counter = 32'd0;
    b_counter = 32'd0;
    fd = $fopen("../sample_src/program.bin", "rb");
    $fread(memory, fd);
    /*
    i = 0;
    // $readmemh("../sample_src/program.bin", memory, 0, 4*4096);
    begin:FILE_LOOP
      forever begin                   
        if ($feof(fd) != 0 | i > 4095*4-1) begin
            disable FILE_LOOP;
        end
        if ($fread(memory[i], fd, i, 1) == 0) begin
          $display("OMG");
        end
        i = i + 1;
      end
    end
    */

  end

  parameter MEM_DELAY = 5;

  // 読み出し部1
  logic next_a_arready, next_a_rvalid;
  logic [31:0] a_addr;
  logic a_addr_ready_flag;

  always_comb begin
    // set default value
    next_a_arready = 1'b0;

    if (a_arvalid & a_arready) begin
      next_a_arready = 1'b0;
    end else if (a_arvalid) begin
      next_a_arready = 1'b1;
    end

    if (a_counter >= MEM_DELAY) begin
      next_a_rvalid = 1'b1;
    end else begin
      next_a_rvalid = 1'b0;
    end
  end

  always_ff @(posedge aclk) begin
    if (areset) begin
      a_rvalid <= 1'b0;
      a_arready <= 1'b0;
      a_addr <= 32'b0;
      a_rdata <= 32'b0;
    end else begin
      a_arready <= next_a_arready;

      if (a_arvalid) begin
        a_addr <= a_araddr;
      end
      if (next_a_rvalid) begin
        for (int i_read = 0; i_read < 4; i_read = i_read+1) begin
          a_rdata[8*i_read+:8] <= memory[a_addr+i_read];
        end
      end

      // レイテンシ再現
      if (a_arvalid) begin
        a_addr_ready_flag <= 1'b1;
      end
      if (a_addr_ready_flag) begin
        a_counter <= a_counter + 32'd1;
      end
      if (a_rvalid & a_rready) begin
        a_addr_ready_flag <= 1'b0;
        a_counter <= 32'd0;
        a_rvalid <= 1'b0;
      end else begin
        a_rvalid <= next_a_rvalid;
      end
    end
  end

  // 読み出し部2
  logic next_b_arready, next_b_rvalid;
  logic [31:0] b_addr;
  logic b_addr_ready_flag;

  always_comb begin
    // set default value
    next_b_arready = 1'b0;

    if (b_arvalid & b_arready) begin
      next_b_arready = 1'b0;
    end else if (b_arvalid) begin
      next_b_arready = 1'b1;
    end

    if (b_counter >= MEM_DELAY) begin
      next_b_rvalid = 1'b1;
    end else begin
      next_b_rvalid = 1'b0;
    end
  end

  always_ff @(posedge aclk) begin
    if (areset) begin
      b_rvalid <= 1'b0;
      b_arready <= 1'b0;
      b_addr <= 32'b0;
      b_rdata <= 32'b0;
    end else begin
      b_arready <= next_b_arready;

      if (b_arvalid) begin
        b_addr <= b_araddr;
      end
      if (next_b_rvalid) begin
        for (int i_read = 0; i_read < 4; i_read = i_read+1) begin
          b_rdata[8*i_read+:8] <= memory[b_addr+i_read];
        end
      end

      // レイテンシ再現
      if (b_arvalid) begin
        b_addr_ready_flag <= 1'b1;
      end
      if (b_addr_ready_flag) begin
        b_counter <= b_counter + 32'd1;
      end
      if (b_rvalid & b_rready) begin
        b_addr_ready_flag <= 1'b0;
        b_counter <= 32'd0;
        b_rvalid <= 1'b0;
      end else begin
        b_rvalid <= next_b_rvalid;
      end
    end
  end

  // 書き込み部
  logic next_wready, next_awready;
  logic [31:0] wcounter;
  logic [31:0] write_addr;
  logic [31:0] write_data;
  logic waddr_ready, wdata_ready;

  always_comb begin
    // set default value
    next_awready = 1'b0;
    next_wready = 1'b0;

    if (awvalid & awready) begin
      next_awready = 1'b0;
    end else if (awvalid) begin
      next_awready = 1'b1;
    end

    if (wvalid & wready) begin
      next_wready = 1'b0;
    end else if (wvalid) begin
      next_wready = 1'b1;
    end
  end

  always_ff @(posedge aclk) begin
    if (areset) begin
      awready <= 1'b0;
      wready <= 1'b0;
      bvalid <= 1'b0;
    end else begin
      awready <= next_awready;
      wready <= next_wready;

      if (awvalid & awready) begin
        write_addr <= awaddr;
        waddr_ready <= 1'b1;
      end
      if (wvalid & wready) begin
        write_data <= wdata;
        wdata_ready <= 1'b1;
      end

      if (wdata_ready & waddr_ready) begin
        wcounter <= wcounter + 32'd1;
      end

      if (wcounter >= MEM_DELAY) begin
        for(int i_write = 0; i_write < 4; i_write = i_write + 1) begin
          memory[write_addr+i_write] <= write_data[8*i_write+:8];
        end
        bvalid <= 1'b1;
      end

      if (bvalid & bready) begin
        wdata_ready <= 1'b0;
        waddr_ready <= 1'b0;
        bvalid <= 1'b0;
        wcounter <= 32'd0;
      end
    end
  end

  wire _unused = &{1'b0,
                   wstrb,
                   a_arprot,
                   b_arprot,
                   awprot,
                   1'b0};
endmodule
`default_nettype wire
/* @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ */
