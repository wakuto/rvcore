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
          rob->dispatch_is_branch_instr[i] = 0;

          rob->writeback_bank_addr[i] = 0;
          rob->writeback_rob_addr[i] = 0;
          rob->writeback_en[i] = 0;
          rob->writeback_is_branch_instr[i] = 0;
          rob->writeback_taken[i] = 0;
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
    if (!rob->dispatch_full) {
      rob->dispatch_phys_rd[0] = 32;
      rob->dispatch_arch_rd[0] = 0;
      rob->dispatch_en[0] = 1;
    }
  });

  // bank0にdispatchした内容をテスト
  instr_bank_addr.push_back(dut->top->dispatch_bank_addr[0]);
  instr_rob_addr.push_back(dut->top->dispatch_rob_addr[0]);
  EXPECT_EQ(dut->top->dispatch_bank_addr[0], 0);
  EXPECT_EQ(dut->top->dispatch_rob_addr[0], 0);

  // バンク1にdispatch
  dut->do_posedge([](Vrob *rob) {
    for(auto i = 0; i < 2; i++) {
      rob->dispatch_en[i] = 0;
    }
    if (!rob->dispatch_full) {
      rob->dispatch_phys_rd[1] = 33;
      rob->dispatch_arch_rd[1] = 1;
      rob->dispatch_en[1] = 1;
    }
  });

  // bank1にdispatchした内容をテスト
  instr_bank_addr.push_back(dut->top->dispatch_bank_addr[1]);
  instr_rob_addr.push_back(dut->top->dispatch_rob_addr[1]);

  EXPECT_EQ(dut->top->dispatch_bank_addr[1], 1);
  EXPECT_EQ(dut->top->dispatch_rob_addr[1], 1);

  // バンク0, 1に同時にdispatch
  dut->do_posedge([](Vrob *rob) {
    for(auto i = 0; i < 2; i++) {
      rob->dispatch_en[i] = 0;
    }
    if (!rob->dispatch_full) {
      rob->dispatch_phys_rd[0] = 34;
      rob->dispatch_arch_rd[0] = 2;
      rob->dispatch_en[0] = 1;
      rob->dispatch_phys_rd[1] = 35;
      rob->dispatch_arch_rd[1] = 3;
      rob->dispatch_en[1] = 1;
    }
  });

  // bank0, bank1にdispatchした内容をテスト
  instr_bank_addr.push_back(dut->top->dispatch_bank_addr[0]);
  instr_bank_addr.push_back(dut->top->dispatch_bank_addr[1]);
  instr_rob_addr.push_back(dut->top->dispatch_rob_addr[0]);
  instr_rob_addr.push_back(dut->top->dispatch_rob_addr[1]);

  EXPECT_EQ(dut->top->dispatch_bank_addr[0], 0);
  EXPECT_EQ(dut->top->dispatch_bank_addr[1], 1);
  EXPECT_EQ(dut->top->dispatch_rob_addr[0], 2);
  EXPECT_EQ(dut->top->dispatch_rob_addr[1], 2);

  dut->do_posedge([](Vrob *rob) {
    for(auto i = 0; i < 2; i++) {
      rob->dispatch_en[i] = 0;
    }
  });

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
    if (!rob->dispatch_full) {
      rob->dispatch_phys_rd[0] = 32;
      rob->dispatch_arch_rd[0] = 0;
      rob->dispatch_en[0] = 1;
    }
  });

  // bank0 にdispatchした内容をテスト
  instr_bank_addr.push_back(dut->top->dispatch_bank_addr[0]);
  instr_rob_addr.push_back(dut->top->dispatch_rob_addr[0]);
  EXPECT_EQ(dut->top->dispatch_bank_addr[0], 0);
  EXPECT_EQ(dut->top->dispatch_rob_addr[0], 0);

  // バンク1にdispatch
  dut->do_posedge([](Vrob *rob) {
    for(auto i = 0; i < 2; i++) {
      rob->dispatch_en[i] = 0;
    }
    if (!rob->dispatch_full) {
      rob->dispatch_phys_rd[1] = 33;
      rob->dispatch_arch_rd[1] = 1;
      rob->dispatch_en[1] = 1;
    }
  });

  // bank1 にdispatchした内容をテスト
  instr_bank_addr.push_back(dut->top->dispatch_bank_addr[1]);
  instr_rob_addr.push_back(dut->top->dispatch_rob_addr[1]);

  EXPECT_EQ(dut->top->dispatch_bank_addr[1], 1);
  EXPECT_EQ(dut->top->dispatch_rob_addr[1], 1);

  // バンク0, 1に同時にdispatch
  dut->do_posedge([](Vrob *rob) {
    for(auto i = 0; i < 2; i++) {
      rob->dispatch_en[i] = 0;
    }
    if (!rob->dispatch_full) {
      rob->dispatch_phys_rd[0] = 34;
      rob->dispatch_arch_rd[0] = 2;
      rob->dispatch_en[0] = 1;
      rob->dispatch_phys_rd[1] = 35;
      rob->dispatch_arch_rd[1] = 3;
      rob->dispatch_en[1] = 1;
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

  dut->do_posedge([](Vrob *rob) {
    for(auto i = 0; i < 2; i++) {
      rob->dispatch_en[i] = 0;
    }
  });

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


TEST (ROBTest, OperandFetchTest) {
  auto dut = std::make_unique<ROBTester>("rob_operand_fetch_test.vcd");
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
    if (!rob->dispatch_full) {
      rob->dispatch_phys_rd[0] = 32;
      rob->dispatch_arch_rd[0] = 0;
      rob->dispatch_en[0] = 1;
    }
  });

  // +---------------------------+---------------------------+
  // |           bank0           |           bank1           |
  // +---------+---------+-------+---------+---------+-------+
  // | phys_rd | arch_rd | valid | phys_rd | arch_rd | valid |
  // +=========+=========+=======+=========+=========+=======+
  // |       32|        0|      1|        0|        0|      0|
  // +---------+---------+-------+---------+---------+-------+
  // バンク1にdispatch
  dut->do_posedge([](Vrob *rob) {
    for(auto i = 0; i < 2; i++) {
      rob->dispatch_en[i] = 0;
    }
    if (!rob->dispatch_full) {
      rob->dispatch_phys_rd[1] = 33;
      rob->dispatch_arch_rd[1] = 1;
      rob->dispatch_en[1] = 1;
    }
  });

  // +---------------------------+---------------------------+
  // |           bank0           |           bank1           |
  // +---------+---------+-------+---------+---------+-------+
  // | phys_rd | arch_rd | valid | phys_rd | arch_rd | valid |
  // +=========+=========+=======+=========+=========+=======+
  // |       32|        0|      1|        0|        0|      0|
  // +---------+---------+-------+---------+---------+-------+
  // |        0|        0|      0|       33|        1|      1|
  // +---------+---------+-------+---------+---------+-------+
  // バンク0, 1に同時にdispatch
  dut->do_posedge([](Vrob *rob) {
    for(auto i = 0; i < 2; i++) {
      rob->dispatch_en[i] = 0;
    }
    if (!rob->dispatch_full) {
      rob->dispatch_phys_rd[0] = 34;
      rob->dispatch_arch_rd[0] = 2;
      rob->dispatch_en[0] = 1;
      rob->dispatch_phys_rd[1] = 35;
      rob->dispatch_arch_rd[1] = 3;
      rob->dispatch_en[1] = 1;
    }
  });

  // +---------------------------+---------------------------+
  // |           bank0           |           bank1           |
  // +---------+---------+-------+---------+---------+-------+
  // | phys_rd | arch_rd | valid | phys_rd | arch_rd | valid |
  // +=========+=========+=======+=========+=========+=======+
  // |       32|        0|      1|        0|        0|      0| <- tail
  // +---------+---------+-------+---------+---------+-------+
  // |        0|        0|      0|       33|        1|      1|
  // +---------+---------+-------+---------+---------+-------+
  // |       34|        2|      1|       35|        3|      1|
  // +---------+---------+-------+---------+---------+-------+
  // |         |         |       |         |         |       | <- head
  // +---------+---------+-------+---------+---------+-------+
  // バンク0, 1に同時にdispatch
  dut->do_posedge([](Vrob *rob) {
    for(auto i = 0; i < 2; i++) {
      rob->dispatch_en[i] = 0;
    }
    if (!rob->dispatch_full) {
      rob->dispatch_phys_rd[0] = 36;
      rob->dispatch_arch_rd[0] = 2;
      rob->dispatch_en[0] = 1;
      rob->dispatch_phys_rd[1] = 37;
      rob->dispatch_arch_rd[1] = 3;
      rob->dispatch_en[1] = 1;
    }
  });

  dut->do_posedge([](Vrob *rob) {
    for(auto i = 0; i < 2; i++) {
      rob->dispatch_en[i] = 0;
    }
  });

  dut->next_clock();
  dut->next_clock();

  // operand fetch test
  // +--------------------------------------+--------------------------------------+
  // |           bank0                      |           bank1                      |
  // +---------+---------+---+--------------+---------+---------+---+--------------+
  // | phys_rd | arch_rd | v | commit_ready | phys_rd | arch_rd | v | commit_ready |
  // +=========+=========+===+--------------+=========+=========+===+--------------+
  // |       32|        0|  1|             0|        0|        0|  0|             0| <  tail
  // +---------+---------+---+--------------+---------+---------+---+--------------+
  // |        0|        0|  0|             0|       33|        1|  1|             0|
  // +---------+---------+---+--------------+---------+---------+---+--------------+
  // |       34|        2|  1|             0|       35|        3|  1|             0|
  // +---------+---------+---+--------------+---------+---------+---+--------------+
  // |       36|        2|  1|             0|       37|        3|  1|             0|
  // +---------+---------+---+--------------+---------+---------+---+--------------+
  // |         |         |   |              |         |         |   |              | <- head
  // +---------+---------+---+--------------+---------+---------+---+--------------+
  // bank0でrs1(=x1)をfetch
  dut->do_posedge([](Vrob *rob) {
    rob->op_fetch_phys_rs1[0] = 33;
  });

  EXPECT_FALSE(dut->top->op_fetch_rs1_valid[0]); // not writebacked yet

  // bank1でrs2(=x2)をfetch
  dut->do_posedge([](Vrob *rob) {
    rob->op_fetch_phys_rs1[1] = 34;
  });

  EXPECT_FALSE(dut->top->op_fetch_rs1_valid[1]); // not writebacked yet

  // ----------------------------
  // writeback
  // ----------------------------
  // +--------------------------------------+--------------------------------------+
  // |           bank0                      |           bank1                      |
  // +---------+---------+---+--------------+---------+---------+---+--------------+
  // | phys_rd | arch_rd | v | commit_ready | phys_rd | arch_rd | v | commit_ready |
  // +=========+=========+===+--------------+=========+=========+===+--------------+
  // |       32|        0|  1|             0|        0|        0|  0|             0| <  tail
  // +---------+---------+---+--------------+---------+---------+---+--------------+
  // |        0|        0|  0|             0|       33|        1|  1|             0|
  // +---------+---------+---+--------------+---------+---------+---+--------------+
  // |       34|        2|  1|             0|       35|        3|  1|             0| <- writeback
  // +---------+---------+---+--------------+---------+---------+---+--------------+
  // |       36|        2|  1|             0|       37|        3|  1|             0|
  // +---------+---------+---+--------------+---------+---------+---+--------------+
  // |         |         |   |              |         |         |   |              | <- head
  // +---------+---------+---+--------------+---------+---------+---+--------------+
  // (bank_addr, rob_addr) = (0, 2), (1, 2)をwriteback
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

  // bank0でrs1(=x2), rs2(=x3)をfetch
  dut->do_posedge([](Vrob *rob) {
    rob->op_fetch_phys_rs1[0] = 34;
    rob->op_fetch_phys_rs2[0] = 35;
  });

  EXPECT_TRUE(dut->top->op_fetch_rs1_valid[0]); // not writebacked yet
  EXPECT_TRUE(dut->top->op_fetch_rs2_valid[0]); // not writebacked yet

  // +--------------------------------------+--------------------------------------+
  // |           bank0                      |           bank1                      |
  // +---------+---------+---+--------------+---------+---------+---+--------------+
  // | phys_rd | arch_rd | v | commit_ready | phys_rd | arch_rd | v | commit_ready |
  // +=========+=========+===+--------------+=========+=========+===+--------------+
  // |       32|        0|  1|             0|        0|        0|  0|             0| <  tail
  // +---------+---------+---+--------------+---------+---------+---+--------------+
  // |        0|        0|  0|             0|       33|        1|  1|             0|
  // +---------+---------+---+--------------+---------+---------+---+--------------+
  // |       34|        2|  1|             0|       35|        3|  1|             0| <- writeback
  // +---------+---------+---+--------------+---------+---------+---+--------------+
  // |       36|        2|  1|             0|       37|        3|  1|             0|
  // +---------+---------+---+--------------+---------+---------+---+--------------+
  // |         |         |   |              |         |         |   |              | <- head
  // +---------+---------+---+--------------+---------+---------+---+--------------+
  // (bank_addr, rob_addr) = (0, 3), (1, 3)をwriteback
  dut->do_posedge([](Vrob *rob) {
    for(auto i = 0; i < 2; i++) {
      rob->writeback_en[i] = 0;
    }
    rob->writeback_bank_addr[0] = 0;
    rob->writeback_rob_addr[0] = 3;
    rob->writeback_en[0] = 1;
    rob->writeback_bank_addr[1] = 1;
    rob->writeback_rob_addr[1] = 3;
    rob->writeback_en[1] = 1;
  });

  // bank1でrs1(=x2), rs2(=x3)をfetch
  dut->do_posedge([](Vrob *rob) {
    for(auto i = 0; i < 2; i++) {
      rob->writeback_en[i] = 0;
    }
    rob->op_fetch_phys_rs1[1] = 36;
    rob->op_fetch_phys_rs2[1] = 37;
  });

  EXPECT_TRUE(dut->top->op_fetch_rs1_valid[1]); // not writebacked yet
  EXPECT_TRUE(dut->top->op_fetch_rs2_valid[1]); // not writebacked yet


  dut->next_clock();

  dut->next_clock();
  dut->next_clock();
}

struct RobOutput {
  bool disp0_en;
  uint32_t disp0_bank_addr;
  uint32_t disp0_rob_addr;
  bool commit0_en;
  uint32_t commit0_phys_rd;
  uint32_t commit0_arch_rd;

  bool disp1_en;
  uint32_t disp1_bank_addr;
  uint32_t disp1_rob_addr;
  bool commit1_en;
  uint32_t commit1_phys_rd;
  uint32_t commit1_arch_rd;
};

#define test_roboutput(i, output, expected) do { \
  if ((expected)->disp0_en) { \
    EXPECT_EQ((output)->disp0_bank_addr, (expected)->disp0_bank_addr) << "@" << (i) << std::endl; \
    EXPECT_EQ((output)->disp0_rob_addr, (expected)->disp0_rob_addr) << "@" << (i) << std::endl; \
  } \
  EXPECT_EQ((output)->commit0_en, (expected)->commit0_en) << "@" << (i) << std::endl; \
  if((output)->commit0_en) { \
    EXPECT_EQ((output)->commit0_phys_rd, (expected)->commit0_phys_rd) << "@" << (i) << std::endl; \
    EXPECT_EQ((output)->commit0_arch_rd, (expected)->commit0_arch_rd) << "@" << (i) << std::endl; \
  } \
  if ((expected)->disp1_en) { \
    EXPECT_EQ((output)->disp1_bank_addr, (expected)->disp1_bank_addr) << "@" << (i) << std::endl; \
    EXPECT_EQ((output)->disp1_rob_addr, (expected)->disp1_rob_addr) << "@" << (i) << std::endl; \
  } \
  EXPECT_EQ((output)->commit1_en, (expected)->commit1_en) << "@" << (i) << std::endl; \
  if((output)->commit1_en) { \
    EXPECT_EQ((output)->commit1_phys_rd, (expected)->commit1_phys_rd) << "@" << (i) << std::endl; \
    EXPECT_EQ((output)->commit1_arch_rd, (expected)->commit1_arch_rd) << "@" << (i) << std::endl; \
  } \
} while(0);

struct RobOutput step(Vrob *rob, bool disp0_en, int disp0_phys_rd, int disp0_arch_rd, bool disp0_is_branch_instr, bool disp0_pred_taken, bool wb0_en, int wb0_bank_addr, int wb0_rob_addr, bool wb0_is_branch_instr, bool wb0_taken,
                     bool disp1_en, int disp1_phys_rd, int disp1_arch_rd, bool disp1_is_branch_instr, bool wb1_en, int wb1_bank_addr, int wb1_rob_addr, bool wb1_is_branch_instr, bool wb1_taken) {
  rob->dispatch_en[0] = disp0_en;
  rob->dispatch_phys_rd[0] = disp0_phys_rd;
  rob->dispatch_arch_rd[0] = disp0_arch_rd;
  rob->dispatch_is_branch_instr[0] = disp0_is_branch_instr;
  rob->dispatch_pred_taken[0] = disp0_pred_taken;
  rob->writeback_en[0] = wb0_en;
  rob->writeback_bank_addr[0] = wb0_bank_addr;
  rob->writeback_rob_addr[0] = wb0_rob_addr;
  rob->writeback_is_branch_instr[0] = wb0_is_branch_instr;
  rob->writeback_taken[0] = wb0_taken;

  rob->dispatch_en[1] = disp1_en;
  rob->dispatch_phys_rd[1] = disp1_phys_rd;
  rob->dispatch_arch_rd[1] = disp1_arch_rd;
  rob->dispatch_is_branch_instr[1] = disp1_is_branch_instr;
  rob->dispatch_pred_taken[1] = false;
  rob->writeback_en[1] = wb1_en;
  rob->writeback_bank_addr[1] = wb1_bank_addr;
  rob->writeback_rob_addr[1] = wb1_rob_addr;
  rob->writeback_is_branch_instr[1] = wb1_is_branch_instr;
  rob->writeback_taken[1] = wb1_taken;
  
  struct RobOutput output;
  output.disp0_en = disp0_en;
  output.disp0_bank_addr = rob->dispatch_bank_addr[0];
  output.disp0_rob_addr = rob->dispatch_rob_addr[0];
  output.commit0_en = rob->commit_en[0];
  output.commit0_phys_rd = rob->commit_phys_rd[0];
  output.commit0_arch_rd = rob->commit_arch_rd[0];
  output.disp1_en = disp1_en;
  output.disp1_bank_addr = rob->dispatch_bank_addr[1];
  output.disp1_rob_addr = rob->dispatch_rob_addr[1];
  output.commit1_en = rob->commit_en[1];
  output.commit1_phys_rd = rob->commit_phys_rd[1];
  output.commit1_arch_rd = rob->commit_arch_rd[1];
  return output;
}

TEST (ROBTest, BranchPrediction) {
  auto dut = std::make_unique<ROBTester>("rob_branch_prediction.vcd");
  auto instr_bank_addr = std::vector<typeof(dut->top->dispatch_bank_addr[0])>();
  auto instr_rob_addr = std::vector<typeof(dut->top->dispatch_rob_addr[0])>();

  dut->init();

  // ----------------------------
  // test pattern
  // https://docs.google.com/spreadsheets/d/1SOGVN360lOAwjHmHtGCsKo4hk-SpMqlmGtNFAquVBb0/edit?usp=sharing
  // ----------------------------
  std::vector<std::vector<uint32_t>> test_vector = {
    {  1,  1,  2,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  1,  2,  3,  1,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0},
    {  1,  3,  4,  0,  1,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  1,  4,  5,  1,  1,  0,  0,  0,  0,  0,  0,  0,  0,  0},
    {  1,  5,  2,  0,  2,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  1,  6,  3,  1,  2,  0,  0,  0,  0,  0,  0,  0,  0,  0},
    {  1,  7,  4,  0,  3,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  1,  8,  5,  1,  3,  0,  0,  0,  0,  0,  0,  0,  0,  0},
    {  1,  0,  0,  0,  4,  1,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0},
    {  1,  9,  6,  0,  5,  0,  0,  1,  0,  0,  0,  0,  0,  0,  0,  1, 10,  6,  1,  5,  0,  1,  1,  0,  0,  0,  0,  0,  0},
    {  1, 11,  7,  0,  6,  0,  0,  1,  0,  1,  0,  0,  1,  1,  2,  1, 12,  7,  1,  6,  0,  1,  1,  1,  0,  0,  1,  2,  3},
    {  1, 13,  8,  0,  7,  0,  0,  1,  0,  2,  0,  0,  1,  3,  4,  1, 14,  8,  1,  7,  0,  1,  1,  2,  0,  0,  1,  4,  5},
    {  1, 15,  9,  0,  8,  0,  0,  1,  0,  3,  0,  0,  1,  5,  2,  1, 16,  9,  1,  8,  0,  1,  1,  3,  0,  0,  1,  6,  3},
    {  1, 17, 10,  0,  9,  0,  0,  1,  0,  4,  1,  1,  1,  7,  4,  1, 18, 10,  1,  9,  0,  0,  0,  0,  0,  0,  1,  8,  5},
    {  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  1,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0},
    {  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0},
    {  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0},
    {  1, 19,  2,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  1, 20,  3,  1,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0},
    {  1, 21,  4,  0,  1,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  1, 22,  5,  1,  1,  0,  0,  0,  0,  0,  0,  0,  0,  0},
    {  1,  0,  0,  0,  2,  1,  1,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0},
    {  1, 23,  2,  0,  3,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  1, 24,  3,  1,  3,  0,  0,  0,  0,  0,  0,  0,  0,  0},
    {  1, 25,  4,  0,  4,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  1, 26,  5,  1,  4,  0,  0,  0,  0,  0,  0,  0,  0,  0},
    {  0,  0,  0,  0,  0,  0,  0,  1,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  1,  1,  0,  0,  0,  0,  0,  0},
    {  0,  0,  0,  0,  0,  0,  0,  1,  0,  1,  0,  0,  1, 19,  2,  0,  0,  0,  0,  0,  0,  1,  1,  1,  0,  0,  1, 20,  3},
    {  0,  0,  0,  0,  0,  0,  0,  1,  0,  2,  1,  1,  1, 21,  4,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  1, 22,  5},
    {  1,  0,  0,  0,  5,  1,  1,  1,  0,  3,  0,  0,  1,  0,  0,  0,  0,  0,  0,  0,  0,  1,  1,  3,  0,  0,  0,  0,  0},
    {  1, 27,  2,  0,  6,  0,  0,  1,  0,  4,  0,  0,  1, 23,  2,  1, 28,  3,  1,  6,  0,  1,  1,  4,  0,  0,  1, 24,  3},
    {  1, 29,  4,  0,  7,  0,  0,  0,  0,  0,  0,  0,  1, 25,  4,  1, 30,  5,  1,  7,  0,  0,  0,  0,  0,  0,  1, 26,  5}
  };
  int i = 0;
  struct RobOutput expected, output, buf;
  // なんかcommit0,1 の出力が1サイクル遅れて出てくるのでバッファを噛ませる
  // 多分svでテストを書けば直る（posedgeが再現できてない）
  buf.commit0_en = 0;
  buf.commit1_en = 0;
  for (auto v: test_vector) {
    dut->do_posedge([&](Vrob *rob) {
      output = step(rob,
        v[0], v[1], v[2], v[5], v[6],  // dispatch0
        v[7], v[8], v[9], v[10], v[11],// writeback0
        v[15], v[16], v[17], v[20],    // dispatch1
        v[21], v[22], v[23], v[24], v[25] // writeback1
      );

      expected.disp0_en = v[0];
      expected.disp0_bank_addr = v[3];
      expected.disp0_rob_addr = v[4];
      expected.commit0_en = buf.commit0_en;
      expected.commit0_phys_rd = buf.commit0_phys_rd;
      expected.commit0_arch_rd = buf.commit0_arch_rd;
      expected.disp1_en = v[15];
      expected.disp1_bank_addr = v[18];
      expected.disp1_rob_addr = v[19];
      expected.commit1_en = buf.commit1_en;
      expected.commit1_phys_rd = buf.commit1_phys_rd;
      expected.commit1_arch_rd = buf.commit1_arch_rd;

      buf.commit0_en = v[12];
      buf.commit0_phys_rd = v[13];
      buf.commit0_arch_rd = v[14];
      buf.commit1_en = v[26];
      buf.commit1_phys_rd = v[27];
      buf.commit1_arch_rd = v[28];
    });
    test_roboutput(i, &output, &expected);
    i++;
  }

  dut->next_clock();
  dut->next_clock();
}

