#include "../obj_dir/Vfifo.h"
#include <fstream>
#include <iostream>
#include <verilated.h>       // Defines common routines
#include <verilated_vcd_c.h> // VCD output
                             //
unsigned int main_time = 0; // Current simulation time
int r_clk_prev, w_clk_prev;
                            //
double sc_time_stamp() { // Called by $time in Verilog
  return main_time;
}

int write(Vfifo* top, int x) {
  int res = 0;
  // positive edge
  if (w_clk_prev == 0 && top->w_clk == 1) {
    top->wen = 1;
    top->din = x;
    res = 1;
  }
  w_clk_prev = top->w_clk;
  return res;
}

int w_posedge(Vfifo* top) {
  return w_clk_prev == 0 && top->w_clk == 1;
}

int r_posedge(Vfifo* top) {
  return r_clk_prev == 0 && top->r_clk == 1;
}

int read(Vfifo* top) {
  int res = 0;
  // positive edge
  if (r_clk_prev == 0 && top->r_clk == 1) {
    top->ren = 1;
    res = 1;
  }
  return res;
}

int main(int argc, char **argv) {

  Verilated::commandArgs(argc, argv); // Remember args

  Vfifo *top = new Vfifo(); // Create instance

  // Trace DUMP ON
  Verilated::traceEverOn(true);
  VerilatedVcdC *tfp = new VerilatedVcdC;

  // initialize
  top->trace(tfp, 100);
  tfp->open("fifo_sim.vcd");

  // 2
  top->r_clk = 0;
  top->ren = 0;

  // 3
  top->w_clk = 0;
  top->wen = 0;
  top->din = 0;

  int state_count = 0;
  // 1,2,3の順番で書き込んで順番に読み出す
  while (!Verilated::gotFinish()) {
    int write_flag = main_time % 3 == 0;
    int read_flag  = main_time % 2 == 0;
    if (main_time < 10) {
      write_flag = 0;
      read_flag = 0;
    }
    if (write_flag) top->w_clk = !top->w_clk;
    if (read_flag)  top->r_clk = !top->r_clk;

    // 書き込みステート
    if (state_count < 3) {
      if (w_posedge(top)) {
        top->wen = 1;
        top->din = state_count + 1;
        state_count++;
      }
    } else if (state_count == 3) {
      if (w_posedge(top)) {
        top->wen = 0;
        state_count++;
      }
    }
    // 読み出しステート
    if (4 <= state_count && state_count < 7) {
      if (r_posedge(top)) {
        top->ren = 1;
        state_count++;
      }
    } else if (state_count == 7) {
      if (r_posedge(top)) {
        top->ren = 0;
        state_count++;
      }
    }

    int w_clk_tmp = top->w_clk;
    int r_clk_tmp = top->r_clk;
    // クロックの更新前に一度eval()
    top->w_clk = w_clk_prev;
    top->r_clk = r_clk_prev;
    top->eval();
    // クロックの更新後にもう一度eval()
    top->w_clk = w_clk_tmp;
    top->r_clk = r_clk_tmp;
    top->eval();
    tfp->dump(main_time);

    if (top->wen) {
      std::cout << "WRITE: " << top->din << std::endl;
    }

    if (top->ren) {
      std::cout << "READ: " << top->dout << std::endl;
    }

    if (20 > state_count && state_count >= 8) {
      state_count++;
    } else if (state_count >= 20) {
      break;
    }
    main_time++;
    w_clk_prev = top->w_clk;
    r_clk_prev = top->r_clk;
  }

  top->final(); // Done simulating
  tfp->close();
}
