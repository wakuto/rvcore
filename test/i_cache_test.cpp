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
  static int arready_prev = 0;

  if (is_first) {
    for (int i = 0; i < 0x1000; i++) {
      mem[i] = i >> 2;
    }
    is_first = false;
  }


  // アドレス転送処理
  if (top->axi_arvalid) {
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

  // アドレス転送完了
  if (top->axi_arvalid && top->axi_arready)
    top->axi_arready = 0;

  // データ転送完了
  if (top->axi_rvalid && top->axi_rready) {
    top->axi_rvalid = 0;
    delay_counter = 0;
    arvalid = false;
  }
  arready_prev = top->axi_arready;
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

int main(int argc, char **argv) {

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

  int state_count = 0;
  while (!Verilated::gotFinish()) {
    top->clk = !top->clk;
    top->axi_aclk = !top->axi_aclk;

    if (posedge(top)) {
      axi_memory(top);
      if (!top->reset) {
        if (!top->addr_valid) {
          top->addr = state_count;
          top->addr_valid = 1;
        }
        if (top->addr_valid && top->data_ready) {
          top->addr_valid = 0;
          std::cout << "data: " << top->addr << " = " << top->data << std::endl;
          state_count = (state_count + 4) % 16;
        }
      }
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
