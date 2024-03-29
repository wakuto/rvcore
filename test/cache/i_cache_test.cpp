#include "../obj_dir/Vi_cache_with_memory.h"
#include <fstream>
#include <iostream>
#include <verilated.h>       // Defines common routines
#include <verilated_vcd_c.h> // VCD output
                             //
unsigned int main_time = 0;  // Current simulation time

double sc_time_stamp() { // Called by $time in Verilog
  return main_time;
}

uint32_t access_pattern[] = {0, 4, 8, 12, 0, 4, 8, 12, 16, 0, 4, 20, 16, 24, 8, 12};

bool posedge(Vi_cache_with_memory *top) {
  static int prev_clk = 0;
  bool res = prev_clk != top->clk && top->clk == 1;
  prev_clk = top->clk;
  return res;
}

bool negedge(Vi_cache_with_memory *top) {
  static int prev_clk = 0;
  bool res = prev_clk != top->clk && top->clk == 0;
  prev_clk = top->clk;
  return res;
}

void copy_input_data(Vi_cache_with_memory *src, Vi_cache_with_memory *dest) {
  dest->reset = src->reset;
  dest->clk = src->clk;
  dest->addr = src->addr;

/*
  dest->axi_aclk = src->axi_aclk;
  dest->axi_areset = src->axi_areset;
  dest->axi_arready = src->axi_arready;

  dest->axi_rvalid = src->axi_rvalid;
  dest->axi_rdata = src->axi_rdata;
  dest->axi_rresp = src->axi_rresp;
  */
}

void copy_output_data(Vi_cache_with_memory *src, Vi_cache_with_memory *dest) {
  dest->data = src->data;
  dest->data_valid = src->data_valid;

/*
  dest->axi_arvalid = src->axi_arvalid;
  dest->axi_araddr = src->axi_araddr;
  dest->axi_arprot = src->axi_arprot;
  dest->axi_rready = src->axi_rready;
  */
}

void do_posedge(Vi_cache_with_memory *top, void (*func)(Vi_cache_with_memory *)) {
  Vi_cache_with_memory *tmp = new Vi_cache_with_memory;
  copy_input_data(top, tmp);
  copy_output_data(top, tmp);

  func(tmp);

  top->clk = 1;
  /*
  top->axi_aclk = 1;
  */

  top->eval();
  
  copy_input_data(tmp, top);
}

void do_negedge(Vi_cache_with_memory *top, void (*func)(Vi_cache_with_memory *)) {
  Vi_cache_with_memory *tmp = new Vi_cache_with_memory;
  copy_input_data(top, tmp);
  copy_output_data(top, tmp);

  func(tmp);

  top->clk = 0;
  // top->axi_aclk = 0;

  top->eval();
  
  copy_input_data(tmp, top);
}

void processing(Vi_cache_with_memory *top) {
  static int state_count = 0;
  if (!top->reset) {
    if (top->data_valid) {
      state_count = (state_count + 1) % 16;
      std::cout << "data: " << top->addr << " = " << top->data << std::endl;
    }
    top->addr = access_pattern[state_count];

  }
}

int main(int argc, char **argv) {
  std::cout << std::showbase << std::hex;

  Verilated::commandArgs(argc, argv); // Remember args

  Vi_cache_with_memory *top = new Vi_cache_with_memory(); // Create instance

  // Trace DUMP ON
  Verilated::traceEverOn(true);
  VerilatedVcdC *tfp = new VerilatedVcdC;

  // initialize
  top->trace(tfp, 100);
  tfp->open("i_cache_sim.vcd");

  top->clk = 0;
  top->reset = 1;
  top->addr = 0;

/*
  top->axi_aclk = 0;
  top->axi_areset = 0;
  top->axi_arready = 0;

  top->axi_rvalid = 0;
  top->axi_rdata = 0;
  top->axi_rresp = 0;
  */

  while (!Verilated::gotFinish()) {
    top->clk = !top->clk;
    // top->axi_aclk = !top->axi_aclk;

    if (posedge(top)) {
      top->clk = !top->clk;
      // top->axi_aclk = !top->axi_aclk;

      do_posedge(top, processing);

      top->clk = !top->clk;
      // top->axi_aclk = !top->axi_aclk;
    }
    /*
    if (negedge(top)) {
      top->clk = !top->clk;
      top->axi_aclk = !top->axi_aclk;

      do_negedge(top, axi_memory);

      top->clk = !top->clk;
      top->axi_aclk = !top->axi_aclk;
    }
    */

    // top->clk = !top->clk;
    // top->axi_aclk = !top->axi_aclk;
    // top->eval();
    // top->clk = !top->clk;
    // top->axi_aclk = !top->axi_aclk;
    top->eval();
    tfp->dump(main_time);

    main_time++;
    top->reset = main_time < 10;
    if (main_time > 2000)
      break;
  }

  top->final(); // Done simulating
  tfp->close();
}
