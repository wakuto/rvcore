#include "../../obj_dir/Vtop.h"
#include <fstream>
#include <iostream>
#include <format>
#include <verilated.h>       // Defines common routines
#include <verilated_vcd_c.h> // VCD output
#include <gtest/gtest.h>
#include "model_tester.hpp"

class TopTester : public ModelTester<Vtop> {
public:
  TopTester(std::string dump_filename) : ModelTester("top_test_vcd", dump_filename) { }
  
  void clock(uint32_t signal) {
    this->top->clk = signal;
  }

  void reset(uint32_t signal) {
    this->top->reset = signal;
  }

  void init() {
    this->reset(1);
    this->change_signal([](Vtop *top){
      top->timer_int = 0;
      top->soft_int = 0;
      top->ext_int = 0;
    });

    this->next_clock();
    this->next_clock();
    this->reset(0);
  }
};

TEST (top_test, run_sample_program) {
  uint32_t cycle = 0;
  auto dut = new TopTester("run_sample_program.vcd");
  dut->init();

  while (1) {
    dut->do_posedge([](Vtop *top) {});
    cycle += 1;
    
    EXPECT_FALSE(cycle > 5000);
    if (cycle > 5000 || dut->top->debug_ebreak) break;
  }
}
