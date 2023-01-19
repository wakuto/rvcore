#include "../obj_dir/Vd_cache_with_memory.h"
#include <fstream>
#include <iostream>
#include <iomanip>
#include <verilated.h>       // Defines common routines
#include <verilated_vcd_c.h> // VCD output
                             //
unsigned int main_time = 0;  // Current simulation time

double sc_time_stamp() { // Called by $time in Verilog
  return main_time;
}

// ↓のアクセスパターンで書き込み→読み込みの順番でテスト
// 書き込むデータは書き込み回数
uint32_t access_pattern_data[] = {0, 0, 0, 1024, 1024, 0, 4, 4};
uint32_t access_pattern_wen[]  = {1, 1, 0,    1,    0, 0, 1, 0};

bool posedge(Vd_cache_with_memory *top) {
  static int prev_clk = 0;
  bool res = prev_clk != top->clk && top->clk == 1;
  prev_clk = top->clk;
  return res;
}

bool negedge(Vd_cache_with_memory *top) {
  static int prev_clk = 0;
  bool res = prev_clk != top->clk && top->clk == 0;
  prev_clk = top->clk;
  return res;
}

void copy_input_data(Vd_cache_with_memory *src, Vd_cache_with_memory *dest) {
  dest->reset = src->reset;
  dest->clk = src->clk;
  dest->addr = src->addr;
  dest->mem_wen = src->mem_wen;
  dest->data_in = src->data_in;
  dest->data_in_strb = src->data_in_strb;
}

void copy_output_data(Vd_cache_with_memory *src, Vd_cache_with_memory *dest) {
  dest->data_out = src->data_out;
  dest->data_read_valid = src->data_read_valid;
  dest->data_write_ready = src->data_write_ready;
}

void do_posedge(Vd_cache_with_memory *top, void (*func)(Vd_cache_with_memory *)) {
  Vd_cache_with_memory *tmp = new Vd_cache_with_memory;
  copy_input_data(top, tmp);
  copy_output_data(top, tmp);

  func(tmp);

  top->clk = 1;

  top->eval();
  
  copy_input_data(tmp, top);
}

void do_negedge(Vd_cache_with_memory *top, void (*func)(Vd_cache_with_memory *)) {
  Vd_cache_with_memory *tmp = new Vd_cache_with_memory;
  copy_input_data(top, tmp);
  copy_output_data(top, tmp);

  func(tmp);

  top->clk = 0;

  top->eval();
  
  copy_input_data(tmp, top);
}

void processing(Vd_cache_with_memory *top) {
  static int state_count = 0;
  static int write_count = 0;
  if (!top->reset) {
    // 現在の情報をもとに結果を出力
    if (top->data_read_valid) {
      std::cout << "read  data:" << std::setw(10) << top->addr << "\t -> " << top->data_out << std::endl;
      state_count = (state_count + 1) % 8;
    }
    if (top->data_write_ready) {
      std::cout << "write data:" << std::setw(10) << top->addr << "\t <- " << top->data_in << std::endl;
      state_count = (state_count + 1) % 8;
      write_count++;
    }
    // 次の値を計算

    top->addr = access_pattern_data[state_count];
    top->mem_wen = access_pattern_wen[state_count];
    if (top->mem_wen) {
      top->data_in = write_count;
      top->data_in_strb = 0xF;
    }
  }
}

int main(int argc, char **argv) {
  std::cout << std::showbase << std::hex;

  Verilated::commandArgs(argc, argv); // Remember args

  Vd_cache_with_memory *top = new Vd_cache_with_memory(); // Create instance

  // Trace DUMP ON
  Verilated::traceEverOn(true);
  VerilatedVcdC *tfp = new VerilatedVcdC;

  // initialize
  top->trace(tfp, 100);
  tfp->open("d_cache_sim.vcd");

  top->clk = 0;
  top->reset = 1;
  top->addr = 0;

  while (!Verilated::gotFinish()) {
    top->clk = !top->clk;

    if (posedge(top)) {
      top->clk = !top->clk;

      do_posedge(top, processing);

      top->clk = !top->clk;
    }

    top->eval();
    tfp->dump(main_time);

    main_time++;
    top->reset = main_time < 10;
    if (main_time > 1000)
      break;
  }

  top->final(); // Done simulating
  tfp->close();
}

