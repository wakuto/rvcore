#include "../obj_dir/Vdirect_map.h"
#include <fstream>
#include <iostream>
#include <verilated.h>       // Defines common routines
#include <verilated_vcd_c.h> // VCD output
                             //
unsigned int main_time = 0;  // Current simulation time

double sc_time_stamp() { // Called by $time in Verilog
  return main_time;
}

bool posedge(Vdirect_map *top) {
  static int prev_clk = 0;
  bool res = prev_clk != top->clk && top->clk == 1;
  prev_clk = top->clk;
  return res;
}

bool negedge(Vdirect_map *top) {
  static int prev_clk = 0;
  bool res = prev_clk != top->clk && top->clk == 0;
  prev_clk = top->clk;
  return res;
}

enum state { Wait, TagComp, AddrReq, DataRecv };
int main(int argc, char **argv) {

  Verilated::commandArgs(argc, argv); // Remember args

  Vdirect_map *top = new Vdirect_map(); // Create instance

  // Trace DUMP ON
  Verilated::traceEverOn(true);
  VerilatedVcdC *tfp = new VerilatedVcdC;

  // initialize
  top->trace(tfp, 100);
  tfp->open("direct_map_sim.vcd");

  top->clk = 0;
  top->req_addr = 0;
  top->hit = 0;
  top->data = 0;

  top->write_addr = 0;
  top->write_data = 0;
  top->write_valid = 0;

  int state_count = 0;
  enum state current = Wait;
  while (!Verilated::gotFinish()) {
    top->clk = !top->clk;

    if (posedge(top)) {
      switch (current) {
        case Wait: {
          break;
        }
        case TagComp: {
          break;
        }
        case AddrReq: {
          break;
        }
        case DataRecv: {
          break;
        }
      }
      top->req_addr = state_count;
      if (top->hit) {
      } else {
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
    if (main_time > 1000)
      break;
  }

  top->final(); // Done simulating
  tfp->close();
}
