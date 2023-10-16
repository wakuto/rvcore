#include <iostream>
#include <format>
#include <gtest/gtest.h>
#include <sys/types.h>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vrob.h"
#include "../common/model_tester.hpp"

class ROBTester : public ModelTester<Vrob> {
public:
  ROBTester(std::string dump_filename) : ModelTester("rob_test_vcd", dump_filename) {}
  
  void clock(uint32_t signal) {
    this->top->clk = signal;
  }

  void reset(uint32_t signal) {
    this->top->rst = signal;
  }

  void init() {
    this->reset(1);
    this->top->eval();
    this->do_posedge([](Vrob *rob){
      for (auto i = 0; i < 2; i++) {
        rob->dispatch_phys_rd[i] = 0;
        rob->dispatch_arch_rd[i] = 0;
        rob->dispatch_en[i] = 0;

        rob->writeback_bank_addr[i] = 0;
        rob->writeback_rob_addr[i] = 0;
        rob->writeback_en[i] = 0;
      }
    });

    this->next_clock();
    this->next_clock();
    this->reset(0);
  }
};

TEST (ROBTest, Basic) {
  auto dut = std::make_unique<ROBTester>("rob_test.vcd");

  ASSERT_EQ(0, 1);
}
