#include "../obj_dir/Vi_cache.h"
#include <fstream>
#include <iostream>
#include <verilated.h>       // Defines common routines
#include <verilated_vcd_c.h> // VCD output
                             //
unsigned int main_time = 0;  // Current simulation time

double sc_time_stamp() { // Called by $time in Verilog
  return main_time;
}

void axi_memory(Vi_cache *top) {
  static uint32_t addr = 0;
  static uint8_t mem[0x1000];
  static bool is_first = true;
  const uint32_t delay_num = 5;
  static uint32_t delay_counter = 0;
  static bool arvalid = false;

  if (is_first) {
    for (int i = 0; i < 0x1000; i++) {
      mem[i] = i % 16;
    }
    is_first = false;
  }

  // データ転送完了
  if (top->axi_rvalid && top->axi_rready) {
    top->axi_rvalid = 0;
    delay_counter = 0;
    arvalid = false;
  }

  // アドレス転送完了
  if (top->axi_arvalid && top->axi_arready)
    top->axi_arready = 0;
  // アドレス転送処理
  else if (top->axi_arvalid) {
    addr = top->axi_araddr;
    top->axi_arready = 1;
    arvalid = true;
  }
  // アドレス受理後、データ読み出し処理
  if (arvalid) {
    if (delay_counter >= delay_num) {
      uint32_t data = 0;
      for (int i = 3; i >= 0; i--) {
        data |= mem[addr + i] << (8 * i);
      }
      top->axi_rdata = data;
      top->axi_rvalid = 1;
    }
    delay_counter++;
  }
}

bool posedge(Vi_cache *top) {
  static int prev_clk = 0;
  bool res = prev_clk != top->clk && top->clk == 1;
  prev_clk = top->clk;
  return res;
}

bool negedge(Vi_cache *top) {
  static int prev_clk = 0;
  bool res = prev_clk != top->clk && top->clk == 0;
  prev_clk = top->clk;
  return res;
}

void copy_input_data(Vi_cache *src, Vi_cache *dest) {
  dest->reset = src->reset;
  dest->clk = src->clk;
  dest->addr = src->addr;
  dest->addr_valid = src->addr_valid;

  dest->axi_aclk = src->axi_aclk;
  dest->axi_areset = src->axi_areset;
  dest->axi_arready = src->axi_arready;

  dest->axi_rvalid = src->axi_rvalid;
  dest->axi_rdata = src->axi_rdata;
  dest->axi_rresp = src->axi_rresp;
}

void copy_output_data(Vi_cache *src, Vi_cache *dest) {
  dest->data = src->data;
  dest->data_ready = src->data_ready;

  dest->axi_arvalid = src->axi_arvalid;
  dest->axi_araddr = src->axi_araddr;
  dest->axi_arprot = src->axi_arprot;
  dest->axi_rready = src->axi_rready;
}

void do_posedge(Vi_cache *top, void (*func)(Vi_cache *)) {
  Vi_cache *tmp = new Vi_cache;
  copy_input_data(top, tmp);
  copy_output_data(top, tmp);

  func(tmp);

  top->clk = 1;
  top->axi_aclk = 1;

  top->eval();
  
  copy_input_data(tmp, top);
}

void processing(Vi_cache *top) {
  static int state_count = 0;
  if (!top->reset) {
    axi_memory(top);

    top->addr = state_count;
    top->addr_valid = 1;

    if (top->data_ready) {
      state_count = (state_count + 4) % 16;
    }
  }
}

int main(int argc, char **argv) {
  std::cout << std::showbase << std::hex;

  Verilated::commandArgs(argc, argv); // Remember args

  Vi_cache *top = new Vi_cache(); // Create instance

  // Trace DUMP ON
  Verilated::traceEverOn(true);
  VerilatedVcdC *tfp = new VerilatedVcdC;

  // initialize
  top->trace(tfp, 100);
  tfp->open("i_cache_sim.vcd");

  top->clk = 0;
  top->reset = 1;
  top->addr = 0;
  top->addr_valid = 0;

  top->axi_aclk = 0;
  top->axi_areset = 0;
  top->axi_arready = 0;

  top->axi_rvalid = 0;
  top->axi_rdata = 0;
  top->axi_rresp = 0;

  while (!Verilated::gotFinish()) {
    top->clk = !top->clk;
    top->axi_aclk = !top->axi_aclk;

    if (posedge(top)) {
      top->clk = !top->clk;
      top->axi_aclk = !top->axi_aclk;

      do_posedge(top, processing);

      top->clk = !top->clk;
      top->axi_aclk = !top->axi_aclk;
      if (top->data_ready)
        std::cout << "data: " << top->addr << " = " << top->data << std::endl;
    }

    // top->clk = !top->clk;
    // top->axi_aclk = !top->axi_aclk;
    // top->eval();
    // top->clk = !top->clk;
    // top->axi_aclk = !top->axi_aclk;
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
