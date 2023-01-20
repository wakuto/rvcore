#include "../obj_dir/Vtop.h"
#include <fstream>
#include <iostream>
#include <verilated.h>       // Defines common routines
#include <verilated_vcd_c.h> // VCD output
                             //
unsigned int main_time = 0;  // Current simulation time

double sc_time_stamp() { // Called by $time in Verilog
  return main_time;
}

bool posedge(Vtop *top) {
  static int prev_clk = 0;
  bool res = prev_clk != top->clk && top->clk == 1;
  prev_clk = top->clk;
  return res;
}

void copy_input_data(Vtop *src, Vtop *dest) {
  dest->reset = src->reset;
  dest->clk = src->clk;
  dest->timer_int = src->timer_int;
  dest->soft_int = src->soft_int;
  dest->ext_int = src->ext_int;
}

void copy_output_data(Vtop *src, Vtop *dest) {
  dest->debug_ebreak = src->debug_ebreak;
  for (int i = 0; i < 32; i++) {
    dest->debug_reg[i] = src->debug_reg[i];
  }
  dest->illegal_instr = src->illegal_instr;
}

void do_posedge(Vtop *top, void (*func)(Vtop *)) {
  Vtop *tmp = new Vtop;
  copy_input_data(top, tmp);
  copy_output_data(top, tmp);

  func(tmp);

  top->clk = 1;

  top->eval();
  
  copy_input_data(tmp, top);
}

void do_negedge(Vtop *top, void (*func)(Vtop *)) {
  Vtop *tmp = new Vtop;
  copy_input_data(top, tmp);
  copy_output_data(top, tmp);

  func(tmp);

  top->clk = 0;

  top->eval();
  
  copy_input_data(tmp, top);
}

enum {
} write_state;

void processing(Vtop *top) {
  static int state_count = 0;
  if (!top->reset) {
  }
}

// write 1-100
// read 1-100
int main(int argc, char **argv) {
  std::cout << std::showbase << std::hex;

  Verilated::commandArgs(argc, argv); // Remember args

  Vtop *top = new Vtop(); // Create instance

  // Trace DUMP ON
  Verilated::traceEverOn(true);
  VerilatedVcdC *tfp = new VerilatedVcdC;

  // initialize
  top->trace(tfp, 100);
  tfp->open("top_test.vcd");

  top->clk = 0;
  top->reset = 1;
  top->timer_int = 0;
  top->soft_int = 0;
  top->ext_int = 0;

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
    if (top->debug_ebreak)
      break;
  }

  top->final(); // Done simulating
  tfp->close();
}


