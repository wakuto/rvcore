`default_nettype none

module memory (
  input wire logic        clk,
  input wire logic        reset,
  input wire logic [31:0] address,
  output     logic [31:0] read_data,
  input wire logic        read_enable,  // データを読むときにアサート
  output     logic        read_valid,   // メモリ出力の有効フラグ
  input wire logic [31:0] write_data,
  input wire logic        write_enable, // データを書くときにアサート->request signal
  input wire logic [3:0]  write_wstrb,  // 書き込むデータの幅
  output     logic        write_ready   // 書き込むデータの幅
);

  logic [7:0] mem [0:4095];

  initial begin
    int fd = $fopen("../sample_src/program.txt", "r");
    int i = 0;
    logic [31:0] tmp = 0;
    while($feof(fd) == 0 && i < 4096) begin
      $fscanf(fd, "%h\n", tmp);
      mem[i+0] = tmp[7:0];
      mem[i+1] = tmp[15:8];
      mem[i+2] = tmp[23:16];
      mem[i+3] = tmp[31:24];
      i += 4;
    end
  end

  always_ff @(posedge clk) begin
    if (reset) begin
      read_valid <= 1'b0;
      write_ready <= 1'b0;
    end else begin
      if (read_enable & ~read_valid) begin
        read_data[7+0*8:0*8] <= mem[address+0];
        read_data[7+1*8:1*8] <= mem[address+1];
        read_data[7+2*8:2*8] <= mem[address+2];
        read_data[7+3*8:3*8] <= mem[address+3];
        read_valid <= 1'b1;
      end else begin
        read_valid <= 1'b0;
      end
      if (write_enable & ~write_ready) begin
        case(write_wstrb)
          4'b0001: begin
            mem[address] <= write_data[7:0];
          end
          4'b0011: begin
            mem[address+0] <= write_data[7:0];
            mem[address+1] <= write_data[15:8];
          end
          default: begin
            mem[address+0] <= write_data[7:0];
            mem[address+1] <= write_data[15:8];
            mem[address+2] <= write_data[23:16];
            mem[address+3] <= write_data[31:24];
          end
        endcase
        write_ready <= 1'b1;
      end else begin
        write_ready <= 1'b0;
      end
    end
  end

endmodule

`default_nettype wire

