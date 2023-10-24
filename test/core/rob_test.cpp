#include <iostream>
#include <format>
#include <gtest/gtest.h>
#include <sys/types.h>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include <vector>
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

TEST (ROBTest, OrderdWriteback) {
  auto dut = std::make_unique<ROBTester>("rob_ordered_test.vcd");
  auto instr_bank_addr = std::vector<typeof(dut->top->dispatch_bank_addr[0])>();
  auto instr_rob_addr = std::vector<typeof(dut->top->dispatch_rob_addr[0])>();

  dut->init();

  // ----------------------------
  // dispatch
  // ----------------------------
  // バンク0にdispatch
  dut->do_posedge([](Vrob *rob) {
    for(auto i = 0; i < 2; i++) {
      rob->dispatch_en[i] = 0;
    }
    if (!rob->full) {
      rob->dispatch_phys_rd[0] = 32;
      rob->dispatch_arch_rd[0] = 0;
      rob->dispatch_en[0] = 1;
    }
  });

  // バンク1にdispatch
  dut->do_posedge([](Vrob *rob) {
    for(auto i = 0; i < 2; i++) {
      rob->dispatch_en[i] = 0;
    }
    if (!rob->full) {
      rob->dispatch_phys_rd[1] = 33;
      rob->dispatch_arch_rd[1] = 1;
      rob->dispatch_en[1] = 1;
    }
  });

  // 1クロック遅れてbank0にdispatchした内容をテスト
  instr_bank_addr.push_back(dut->top->dispatch_bank_addr[0]);
  instr_rob_addr.push_back(dut->top->dispatch_rob_addr[0]);
  EXPECT_EQ(dut->top->dispatch_bank_addr[0], 0);
  EXPECT_EQ(dut->top->dispatch_rob_addr[0], 0);


  // バンク0, 1に同時にdispatch
  dut->do_posedge([](Vrob *rob) {
    for(auto i = 0; i < 2; i++) {
      rob->dispatch_en[i] = 0;
    }
    if (!rob->full) {
      rob->dispatch_phys_rd[0] = 34;
      rob->dispatch_arch_rd[0] = 2;
      rob->dispatch_en[0] = 1;
      rob->dispatch_phys_rd[1] = 35;
      rob->dispatch_arch_rd[1] = 3;
      rob->dispatch_en[1] = 1;
    }
  });

  instr_bank_addr.push_back(dut->top->dispatch_bank_addr[1]);
  instr_rob_addr.push_back(dut->top->dispatch_rob_addr[1]);

  EXPECT_EQ(dut->top->dispatch_bank_addr[1], 1);
  EXPECT_EQ(dut->top->dispatch_rob_addr[1], 1);

  dut->do_posedge([](Vrob *rob) {
    for(auto i = 0; i < 2; i++) {
      rob->dispatch_en[i] = 0;
    }
  });

  instr_bank_addr.push_back(dut->top->dispatch_bank_addr[0]);
  instr_bank_addr.push_back(dut->top->dispatch_bank_addr[1]);
  instr_rob_addr.push_back(dut->top->dispatch_rob_addr[0]);
  instr_rob_addr.push_back(dut->top->dispatch_rob_addr[1]);

  EXPECT_EQ(dut->top->dispatch_bank_addr[0], 0);
  EXPECT_EQ(dut->top->dispatch_bank_addr[1], 1);
  EXPECT_EQ(dut->top->dispatch_rob_addr[0], 2);
  EXPECT_EQ(dut->top->dispatch_rob_addr[1], 2);

  dut->next_clock();
  dut->next_clock();

  // ----------------------------
  // writeback
  // ----------------------------
  // (bank_addr, rob_addr) = (0, 0)をwriteback
  dut->do_posedge([](Vrob *rob) {
    for(auto i = 0; i < 2; i++) {
      rob->writeback_en[i] = 0;
    }
    rob->writeback_bank_addr[0] = 0;
    rob->writeback_rob_addr[0] = 0;
    rob->writeback_en[0] = 1;
  });

  // (1, 1)をwriteback
  dut->do_posedge([](Vrob *rob) {
    for(auto i = 0; i < 2; i++) {
      rob->writeback_en[i] = 0;
    }
    rob->writeback_bank_addr[1] = 1;
    rob->writeback_rob_addr[1] = 1;
    rob->writeback_en[1] = 1;
  });

  // (0, 2), (1, 2)を同時にwriteback
  dut->do_posedge([](Vrob *rob) {
    for(auto i = 0; i < 2; i++) {
      rob->writeback_en[i] = 0;
    }
    rob->writeback_bank_addr[0] = 0;
    rob->writeback_rob_addr[0] = 2;
    rob->writeback_en[0] = 1;
    rob->writeback_bank_addr[1] = 1;
    rob->writeback_rob_addr[1] = 2;
    rob->writeback_en[1] = 1;
  });

  // 2クロック遅れてコミットされるかをテスト
  EXPECT_EQ(dut->top->commit_phys_rd[0], 32);
  EXPECT_EQ(dut->top->commit_arch_rd[0], 0);
  EXPECT_EQ(dut->top->commit_en[0], 1);
  EXPECT_EQ(dut->top->commit_en[1], 0);

  dut->do_posedge([](Vrob *rob) {
    for(auto i = 0; i < 2; i++) {
      rob->writeback_en[i] = 0;
    }
  });

  EXPECT_EQ(dut->top->commit_phys_rd[1], 33);
  EXPECT_EQ(dut->top->commit_arch_rd[1], 1);
  EXPECT_EQ(dut->top->commit_en[0], 0);
  EXPECT_EQ(dut->top->commit_en[1], 1);

  dut->next_clock();

  EXPECT_EQ(dut->top->commit_phys_rd[0], 34);
  EXPECT_EQ(dut->top->commit_arch_rd[0], 2);
  EXPECT_EQ(dut->top->commit_en[0], 1);
  EXPECT_EQ(dut->top->commit_phys_rd[1], 35);
  EXPECT_EQ(dut->top->commit_arch_rd[1], 3);
  EXPECT_EQ(dut->top->commit_en[1], 1);

  dut->next_clock();
  dut->next_clock();
}

TEST (ROBTest, UnOrderedWriteback) {
  auto dut = std::make_unique<ROBTester>("rob_unordered_test.vcd");
  auto instr_bank_addr = std::vector<typeof(dut->top->dispatch_bank_addr[0])>();
  auto instr_rob_addr = std::vector<typeof(dut->top->dispatch_rob_addr[0])>();

  dut->init();

  // ----------------------------
  // dispatch
  // ----------------------------
  // バンク0にdispatch
  dut->do_posedge([](Vrob *rob) {
    for(auto i = 0; i < 2; i++) {
      rob->dispatch_en[i] = 0;
    }
    if (!rob->full) {
      rob->dispatch_phys_rd[0] = 32;
      rob->dispatch_arch_rd[0] = 0;
      rob->dispatch_en[0] = 1;
    }
  });

  // バンク1にdispatch
  dut->do_posedge([](Vrob *rob) {
    for(auto i = 0; i < 2; i++) {
      rob->dispatch_en[i] = 0;
    }
    if (!rob->full) {
      rob->dispatch_phys_rd[1] = 33;
      rob->dispatch_arch_rd[1] = 1;
      rob->dispatch_en[1] = 1;
    }
  });

  // 1クロック遅れてbank0にdispatchした内容をテスト
  instr_bank_addr.push_back(dut->top->dispatch_bank_addr[0]);
  instr_rob_addr.push_back(dut->top->dispatch_rob_addr[0]);
  EXPECT_EQ(dut->top->dispatch_bank_addr[0], 0);
  EXPECT_EQ(dut->top->dispatch_rob_addr[0], 0);


  // バンク0, 1に同時にdispatch
  dut->do_posedge([](Vrob *rob) {
    for(auto i = 0; i < 2; i++) {
      rob->dispatch_en[i] = 0;
    }
    if (!rob->full) {
      rob->dispatch_phys_rd[0] = 34;
      rob->dispatch_arch_rd[0] = 2;
      rob->dispatch_en[0] = 1;
      rob->dispatch_phys_rd[1] = 35;
      rob->dispatch_arch_rd[1] = 3;
      rob->dispatch_en[1] = 1;
    }
  });

  instr_bank_addr.push_back(dut->top->dispatch_bank_addr[1]);
  instr_rob_addr.push_back(dut->top->dispatch_rob_addr[1]);

  EXPECT_EQ(dut->top->dispatch_bank_addr[1], 1);
  EXPECT_EQ(dut->top->dispatch_rob_addr[1], 1);

  dut->do_posedge([](Vrob *rob) {
    for(auto i = 0; i < 2; i++) {
      rob->dispatch_en[i] = 0;
    }
  });

  instr_bank_addr.push_back(dut->top->dispatch_bank_addr[0]);
  instr_bank_addr.push_back(dut->top->dispatch_bank_addr[1]);
  instr_rob_addr.push_back(dut->top->dispatch_rob_addr[0]);
  instr_rob_addr.push_back(dut->top->dispatch_rob_addr[1]);

  EXPECT_EQ(dut->top->dispatch_bank_addr[0], 0);
  EXPECT_EQ(dut->top->dispatch_bank_addr[1], 1);
  EXPECT_EQ(dut->top->dispatch_rob_addr[0], 2);
  EXPECT_EQ(dut->top->dispatch_rob_addr[1], 2);

  dut->next_clock();
  dut->next_clock();

  // ----------------------------
  // writeback
  // ----------------------------
  // (0, 2), (1, 2)を同時にwriteback
  dut->do_posedge([](Vrob *rob) {
    for(auto i = 0; i < 2; i++) {
      rob->writeback_en[i] = 0;
    }
    rob->writeback_bank_addr[0] = 0;
    rob->writeback_rob_addr[0] = 2;
    rob->writeback_en[0] = 1;
    rob->writeback_bank_addr[1] = 1;
    rob->writeback_rob_addr[1] = 2;
    rob->writeback_en[1] = 1;
  });

  // (1, 1)をwriteback
  dut->do_posedge([](Vrob *rob) {
    for(auto i = 0; i < 2; i++) {
      rob->writeback_en[i] = 0;
    }
    rob->writeback_bank_addr[1] = 1;
    rob->writeback_rob_addr[1] = 1;
    rob->writeback_en[1] = 1;
  });

  // (bank_addr, rob_addr) = (0, 0)をwriteback
  dut->do_posedge([](Vrob *rob) {
    for(auto i = 0; i < 2; i++) {
      rob->writeback_en[i] = 0;
    }
    rob->writeback_bank_addr[0] = 0;
    rob->writeback_rob_addr[0] = 0;
    rob->writeback_en[0] = 1;
  });

  dut->do_posedge([](Vrob *rob) {
    for(auto i = 0; i < 2; i++) {
      rob->writeback_en[i] = 0;
    }
  });
  dut->next_clock();

  // 2クロック遅れてコミットされるかをテスト
  EXPECT_EQ(dut->top->commit_phys_rd[0], 32);
  EXPECT_EQ(dut->top->commit_arch_rd[0], 0);
  EXPECT_EQ(dut->top->commit_en[0], 1);
  EXPECT_EQ(dut->top->commit_en[1], 0);

  dut->next_clock();

  EXPECT_EQ(dut->top->commit_phys_rd[1], 33);
  EXPECT_EQ(dut->top->commit_arch_rd[1], 1);
  EXPECT_EQ(dut->top->commit_en[0], 0);
  EXPECT_EQ(dut->top->commit_en[1], 1);

  dut->next_clock();

  EXPECT_EQ(dut->top->commit_phys_rd[0], 34);
  EXPECT_EQ(dut->top->commit_arch_rd[0], 2);
  EXPECT_EQ(dut->top->commit_en[0], 1);
  EXPECT_EQ(dut->top->commit_phys_rd[1], 35);
  EXPECT_EQ(dut->top->commit_arch_rd[1], 3);
  EXPECT_EQ(dut->top->commit_en[1], 1);

  dut->next_clock();
  dut->next_clock();
}
