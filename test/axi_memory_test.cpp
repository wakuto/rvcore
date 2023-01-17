#include "../obj_dir/Vaxi_memory.h"
#include <fstream>
#include <iostream>
#include <verilated.h>       // Defines common routines
#include <verilated_vcd_c.h> // VCD output
                             //
unsigned int main_time = 0;  // Current simulation time

double sc_time_stamp() { // Called by $time in Verilog
  return main_time;
}

bool posedge(Vaxi_memory *top) {
  static int prev_clk = 0;
  bool res = prev_clk != top->aclk && top->aclk == 1;
  prev_clk = top->aclk;
  return res;
}

bool negedge(Vaxi_memory *top) {
  static int prev_clk = 0;
  bool res = prev_clk != top->aclk && top->aclk == 0;
  prev_clk = top->aclk;
  return res;
}

void copy_input_data(Vaxi_memory *src, Vaxi_memory *dest) {
  dest->aclk = src->aclk;
  dest->areset = src->areset;
  dest->arvalid = src->arvalid;
  dest->araddr = src->araddr;
  dest->arprot = src->arprot;

  dest->rready = src->rready;

  // 書き込み用ポート
  dest->awaddr = src->awaddr;
  dest->awprot = src->awprot;
  dest->awvalid = src->awvalid;

  dest->wdata = src->wdata;
  dest->wstrb = src->wstrb;
  dest->wvalid = src->wvalid;

  dest->bready = src->bready;
}

void copy_output_data(Vaxi_memory *src, Vaxi_memory *dest) {
  dest->arready = src->arready;
  dest->rvalid = src->rvalid;
  dest->rdata = src->rdata;
  dest->rresp = src->rresp;
  dest->awready = src->awready;
  dest->wready = src->wready;
  dest->bresp = src->bresp;
  dest->bvalid = src->bvalid;
}

void do_posedge(Vaxi_memory *top, void (*func)(Vaxi_memory *)) {
  Vaxi_memory *tmp = new Vaxi_memory;
  copy_input_data(top, tmp);
  copy_output_data(top, tmp);

  func(tmp);

  top->aclk = 1;

  top->eval();
  
  copy_input_data(tmp, top);
}

void do_negedge(Vaxi_memory *top, void (*func)(Vaxi_memory *)) {
  Vaxi_memory *tmp = new Vaxi_memory;
  copy_input_data(top, tmp);
  copy_output_data(top, tmp);

  func(tmp);

  top->aclk = 0;

  top->eval();
  
  copy_input_data(tmp, top);
}

void processing(Vaxi_memory *top) {
  static int state_count = 0;
  if (!top->areset) {

  }
}

// write 1-100
// read 1-100
int main(int argc, char **argv) {
  std::cout << std::showbase << std::hex;

  Verilated::commandArgs(argc, argv); // Remember args

  Vaxi_memory *top = new Vaxi_memory(); // Create instance

  // Trace DUMP ON
  Verilated::traceEverOn(true);
  VerilatedVcdC *tfp = new VerilatedVcdC;

  // initialize
  top->trace(tfp, 100);
  tfp->open("axi_memory_sim.vcd");

  // 読み出し用ポート
  top->aclk = 0;
  top->areset = 0;
  top->arvalid = 0;
  top->araddr = 0;
  top->arprot = 0;

  top->rready = 0;

  // 書き込み用ポート
  top->awaddr = 0;
  top->awprot = 0;
  top->awvalid = 0;

  top->wdata = 0;
  top->wstrb = 0;
  top->wvalid = 0;

  top->bready = 0;

  while (!Verilated::gotFinish()) {
    top->aclk = !top->aclk;

    if (posedge(top)) {
      top->aclk = !top->aclk;

      do_posedge(top, processing);

      top->aclk = !top->aclk;
    }
    if (negedge(top)) {
      top->aclk = !top->aclk;

      // do_negedge(top, memory);

      top->aclk = !top->aclk;
    }

    // top->clk = !top->clk;
    // top->axi_aclk = !top->axi_aclk;
    // top->eval();
    // top->clk = !top->clk;
    // top->axi_aclk = !top->axi_aclk;
    top->eval();
    tfp->dump(main_time);

    main_time++;
    top->areset = main_time < 10;
    if (main_time > 2000)
      break;
  }

  top->final(); // Done simulating
  tfp->close();
}

