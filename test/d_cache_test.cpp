#include "../obj_dir/Vd_cache_with_memory.h"
#include <fstream>
#include <iostream>
#include <verilated.h>       // Defines common routines
#include <verilated_vcd_c.h> // VCD output
                             //
unsigned int main_time = 0;  // Current simulation time

double sc_time_stamp() { // Called by $time in Verilog
  return main_time;
}

// ↓のアクセスパターンで書き込み→読み込みの順番でテスト
// 書き込むデータは書き込み回数
uint32_t access_pattern[] = {0, 4, 8, 12, 0, 4, 8, 12, 16, 0, 4, 20, 16, 24, 8, 12};

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
  static bool writing = false;
  static bool reading = false;
  if (!top->reset) {
    if (state_count < 16) {
      if (!writing) {
        writing = true;
        top->addr = access_pattern[state_count];
        top->mem_wen = 1;
        top->data_in = write_count;
        top->data_in_strb = 0xF;
      }
      if (top->data_write_ready) {
        writing = false;
        state_count = (state_count + 1) % 32;
        write_count++;
      }
    } else {
      if (!reading) {
        reading = true;
        top->addr = access_pattern[state_count % 16];
        top->mem_wen = 0;
      }
      if (top->data_read_valid) {
        std::cout << "data: " << top->addr << " = " << top->data_out << std::endl;
        reading = false;
        state_count = (state_count + 1) % 32;
      }
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

