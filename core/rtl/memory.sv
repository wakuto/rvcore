`default_nettype none
`include "memory_map.sv"

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
    int fd = $fopen("../sample_src/program.bin", "rb");
    int i = 0;
    int res = 1;
    res = $fread(mem, fd, 0, 4096);
    $fclose(fd);
  end
  
  logic is_dram_addr;
  logic [31:0] dram_addr;
  logic is_uart0_addr;
  logic [31:0] prev_addr;
  
  always_comb begin
    is_dram_addr = (memory_map::DRAM_BASE <= address && address < (memory_map::DRAM_BASE + memory_map::DRAM_SIZE));
    dram_addr = address - memory_map::DRAM_BASE;
    is_uart0_addr = (memory_map::UART0_BASE <= address && address < (memory_map::UART0_BASE + memory_map::UART0_SIZE));
    read_valid = (prev_addr == address);
  end

  logic is_prev_newline;

  always_ff @(posedge clk) begin
    if (reset) begin
      prev_addr <= address;
      write_ready <= 1'b0;
      is_prev_newline <= 1'b1;
    end else begin
      if (read_enable & ~read_valid) begin
        read_data[7+0*8:0*8] <= mem[address+0];
        read_data[7+1*8:1*8] <= mem[address+1];
        read_data[7+2*8:2*8] <= mem[address+2];
        read_data[7+3*8:3*8] <= mem[address+3];
        prev_addr <= address;
      end else begin
      end
      if (write_enable & ~write_ready) begin
        if (is_dram_addr) begin
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
        end else if (is_uart0_addr) begin
          if (is_prev_newline) begin
            $write("[UART0 OUTPUT] ");
          end
          $write("%c", write_data[7:0]);
          is_prev_newline <= write_data[7:0] == 8'h0a;
          write_ready <= 1'b1;
        end
      end else begin
        write_ready <= 1'b0;
      end
    end
  end

endmodule

`default_nettype wire

