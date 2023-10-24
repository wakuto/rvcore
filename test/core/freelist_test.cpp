#include <iostream>
#include <format>
#include <gtest/gtest.h>
#include <sys/types.h>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include <vector>
#include <algorithm>
#include "Vfreelist.h"
#include "../common/model_tester.hpp"

class FreelistTester : public ModelTester<Vfreelist> {
  public:
    FreelistTester(std::string dump_filename) : ModelTester("freelist_test_vcd", dump_filename) {}

    void clock(uint32_t signal) {
      this->top->clk = signal;
    }

    void reset(uint32_t signal) {
      this->top->rst = signal;
    }

    void init() {
      this->reset(1);
      this->top->eval();
      this->do_posedge([](Vfreelist *freelist){
        for(auto i = 0; i < 2; i++) {
          freelist->push_reg[i] = 0;
          freelist->push_en = 0;
          freelist->pop_en = 0;
        }
      });

      this->next_clock();
      this->next_clock();
      this->reset(0);
    }
};

TEST (FreelistTest, Pop) {
  auto dut = std::make_unique<FreelistTester>("freelist_test.vcd");
  auto inflight = std::vector<uint32_t>();
  auto count = 0;
  dut->init();

  // pop 10 times from bank 0
  dut->do_posedge([](Vfreelist *freelist){
    freelist->pop_en = 1;
  });
  for(auto i = 1; i < 10; i++) {
    dut->do_posedge([&inflight](Vfreelist *freelist){
      inflight.push_back(freelist->pop_reg[0]);
      freelist->pop_en = 1;
    });
    EXPECT_EQ(inflight.back(), count++);
  }

  // pop 10 items from bank 1
  dut->do_posedge([&inflight](Vfreelist *freelist){
    inflight.push_back(freelist->pop_reg[0]);
    freelist->pop_en = 2;
  });
  EXPECT_EQ(inflight.back(), count++);
  for(auto i = 1; i < 10; i++) {
    dut->do_posedge([&inflight](Vfreelist *freelist){
      inflight.push_back(freelist->pop_reg[1]);
      freelist->pop_en = 2;
    });
    EXPECT_EQ(inflight.back(), count++);
  }

  // pop 10 items from bank 0, 1
  dut->do_posedge([&inflight](Vfreelist *freelist){
    inflight.push_back(freelist->pop_reg[1]);
    freelist->pop_en = 3;
  });
  EXPECT_EQ(inflight.back(), count++);
  for(auto i = 1; i < 10; i++) {
    dut->do_posedge([&inflight](Vfreelist *freelist){
      inflight.push_back(freelist->pop_reg[0]);
      inflight.push_back(freelist->pop_reg[1]);
      freelist->pop_en = 3;
    });
    EXPECT_EQ(inflight.rbegin()[1], count++);
    EXPECT_EQ(inflight.rbegin()[0], count++);
  }

  dut->do_posedge([&inflight](Vfreelist *freelist){
    inflight.push_back(freelist->pop_reg[0]);
    inflight.push_back(freelist->pop_reg[1]);
    freelist->pop_en = 0;
  });
  EXPECT_EQ(inflight.rbegin()[1], count++);
  EXPECT_EQ(inflight.rbegin()[0], count++);
}

TEST (FreelistTest, Push) {
  auto dut = std::make_unique<FreelistTester>("freelist_test.vcd");
  auto inflight = std::vector<uint32_t>();
  auto pushed_value = std::vector<uint32_t>();
  dut->init();

  // pop 40 times from bank 0
  dut->do_posedge([](Vfreelist *freelist){
    freelist->pop_en = 1;
  });
  for(auto i = 1; i < 40; i++) {
    dut->do_posedge([&inflight](Vfreelist *freelist){
      inflight.push_back(freelist->pop_reg[0]);
      freelist->pop_en = 1;
    });
  }

  dut->do_posedge([&inflight](Vfreelist *freelist){
    inflight.push_back(freelist->pop_reg[0]);
    freelist->pop_en = 0;
  });
  // ---------- pop done

  for (const auto i: inflight) {
    std::cout << std::format("inflight value: {}\n", i);
  }

  // push 10 times to bank 0
  for (auto i = 0; i < 10; i++) {
    dut->do_posedge([&inflight, &pushed_value](Vfreelist *freelist){
      freelist->pop_reg[0] = inflight.back();
      pushed_value.push_back(inflight.back());
      inflight.pop_back();
      freelist->push_en = 1;
    });
  }

  // push 10 times to bank 1
  for (auto i = 0; i < 10; i++) {
    dut->do_posedge([&inflight, &pushed_value](Vfreelist *freelist){
      freelist->pop_reg[1] = inflight.back();
      pushed_value.push_back(inflight.back());
      inflight.pop_back();
      freelist->push_en = 2;
    });
  }
  
  // push 10 times to bank 0, 1
  for (auto i = 0; i < 10; i++) {
    dut->do_posedge([&inflight, &pushed_value](Vfreelist *freelist){
      freelist->pop_reg[0] = inflight.back();
      pushed_value.push_back(inflight.back());
      inflight.pop_back();
      freelist->pop_reg[1] = inflight.back();
      pushed_value.push_back(inflight.back());
      inflight.pop_back();
      freelist->push_en = 3;
    });
  }
  dut->do_posedge([](Vfreelist *freelist){
    freelist->push_en = 0;
  });

  for (const auto i: pushed_value) {
    std::cout << std::format("pushed value: {}\n", i);
  }

  // pop until pushed value is popped
  auto pop_value = 0;
  dut->do_posedge([](Vfreelist *freelist){
    freelist->pop_en = 1;
  });
  do {
    dut->do_posedge([&pop_value](Vfreelist *freelist){
      pop_value = freelist->pop_reg[0];
      freelist->pop_en = 1;
    });
  } while (std::find(pushed_value.begin(), pushed_value.end(), pop_value) == pushed_value.end());
  EXPECT_EQ(pop_value, pushed_value.back()) << "While の直後";
  pushed_value.pop_back();

  std::cout << std::format("pushed value size: {}\n", pushed_value.size());
  for (int i = pushed_value.size()-1; i >= 0; i--) {
    dut->do_posedge([&pop_value](Vfreelist *freelist){
      pop_value = freelist->pop_reg[0];
      std::cout << std::format("pop value: {}\n", pop_value);
      freelist->pop_en = 1;
    });
    EXPECT_EQ(pop_value, pushed_value[i]);
  }
  /*

  dut->do_posedge([&pop_value](Vfreelist *freelist){
    pop_value = freelist->pop_reg[0];
    freelist->pop_en = 0;
  });
  EXPECT_EQ(pop_value, pushed_value.back());
  pushed_value.pop_back();
  */


}
