#include <iostream>
#include <fstream>
#include <format>
#include <vector>
#include <gtest/gtest.h>
#include <sys/types.h>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "VbranchPredictor.h"
#include "VbranchPredictor___024root.h"
#include "../common/model_tester.hpp"

#define DRAM_BASE  0x80000000
#define DRAM_SIZE  0x40000

class BranchPredictorTester : public ModelTester<VbranchPredictor> {
private:
  const uint32_t MEMORY_SIZE = DRAM_SIZE;
  uint8_t *memory = new uint8_t[MEMORY_SIZE];

public:
  BranchPredictorTester(std::string dump_filename) : ModelTester("branch_predictor_test_vcd", dump_filename) {}
  
  void clock(uint32_t signal) {
    this->top->clk = signal;
  }

  void reset(uint32_t signal) {
    this->top->rst = signal;
  }

  void init() {
    std::vector<uint32_t> mem = {
      0x02009463,
      0x00000013,
      0x00100093,
      0x00000013,
      0x00000013,
      0x00000013,
      0x00000013,
      0x00000013,
      0x00000013,
      0xfc009ee3,
      0x00100113,
      0x00000013,
      0x00000013
    };
    for(uint32_t i = 0; i < mem.size(); i++) {
      this->memory[i * 4 + 0] = (mem[i] >> 0) & 0xff;
      this->memory[i * 4 + 1] = (mem[i] >> 8) & 0xff;
      this->memory[i * 4 + 2] = (mem[i] >> 16) & 0xff;
      this->memory[i * 4 + 3] = (mem[i] >> 24) & 0xff;
    }
    this->reset(1);
    this->top->eval();
    this->do_posedge([](VbranchPredictor *brp) {
      for(int i = 0; i < 2; i++) {
        brp->pc[i] = 0;
        brp->instr[i] = 0;
      }
      brp->fetch_valid = 0;
      brp->branch_result_valid = 0;
      brp->branch_correct = 0;
    });

    this->next_clock();
    this->next_clock();
    this->reset(0);
  }
  
  void read_program(std::string filename) {
    std::ifstream hexfile(filename, std::ios::binary);
    hexfile.seekg(0, std::ios::end);
    size_t size = hexfile.tellg();

    if (size > this->MEMORY_SIZE)
      throw std::runtime_error(
        std::format("failed to load program (too long!) {}. \
        max size = {} bytes!", filename, this->MEMORY_SIZE)
      );

    hexfile.seekg(0);
    hexfile.read((char *)this->memory, size);
  }
  
  uint32_t read_imem(uint32_t addr) {
    if (DRAM_BASE <= addr && addr < DRAM_BASE + DRAM_SIZE) {
      addr -= DRAM_BASE;
      if (addr + 3 > this->MEMORY_SIZE) {
        throw std::out_of_range(std::format("Address out of memory(fetch): {:#x}/{:#x}", addr+3, this->MEMORY_SIZE));
      }
      auto data_word = (this->memory[addr + 3] << 3 * 8) | (this->memory[addr + 2] << 2 * 8) |
                       (this->memory[addr + 1] << 1 * 8) | this->memory[addr];
      return data_word;
    }
    return 0xdeadbeef;
  }

  void fetch(uint32_t pc_0, uint32_t pc_1) {
    this->top->instr_valid[0] = DRAM_BASE <= pc_0 && pc_0 < DRAM_BASE + DRAM_SIZE;
    this->top->pc[0] = pc_0;
    this->top->instr[0] = this->read_imem(pc_0);

    this->top->instr_valid[1] = DRAM_BASE <= pc_1 && pc_1 < DRAM_BASE + DRAM_SIZE;
    this->top->pc[1] = pc_1;
    this->top->instr[1] = this->read_imem(pc_1);
    
    this->top->fetch_valid = 1;
    
    // this->top->eval();
  }
};

typedef enum {
  STRONG_NOT_TAKEN,
  WEAK_NOT_TAKEN,
  WEAK_TAKEN,
  STRONG_TAKEN
} branch_state_t;

TEST (BranchPredictorTest, WithWriteBack) {
  auto dut =  std::make_unique<BranchPredictorTester>("with_wb.vcd");
  dut->init();
  
  // TODO: テスト用プログラムを追加
  // 全部のステートを経由
  // 投機実行の成功パターン・失敗パターンも経由
  // WEAK_NOT_TAKEN -> STRONG_NOT_TAKEN -> WEAK_NOT_TAKEN -> WEAK_TAKEN -> STRONG_TAKEN -> WEAK_TAKEN
  // Not Taken -> Taken -> Taken -> Taken -> Not Taken

  // 以下は上記パターンを満たさない、簡易的なテストプログラム
  // 0x00: bne x1, x0, 0x28
  // 0x04: nop
  // 0x08: addi x1, x0, 0x1
  // 0x0c: nop
  // 0x10: nop
  // 0x14: nop
  // 0x18: nop
  // 0x1c: nop
  // 0x20: nop
  // 0x24: bne x1, x0, -0x24
  // 0x28: addi x2, x0, 0x1
  // 0x2c: nop
  // 0x30: nop
  
  auto pc = 0x80000000;

  // 0x80000000
  dut->fetch(pc, pc+4);
  dut->do_posedge([](VbranchPredictor *brp) {
    brp->branch_result_valid = 0;
    brp->branch_correct = 0;
  });
  EXPECT_TRUE(dut->top->instr_valid[0]);
  EXPECT_TRUE(dut->top->instr_valid[1]);
  EXPECT_EQ(dut->top->next_pc, pc + 8);
  EXPECT_TRUE(dut->top->is_branch_instr[0]);
  EXPECT_FALSE(dut->top->is_branch_instr[1]);
  EXPECT_EQ(dut->top->rootp->branchPredictor__DOT__branch_state, branch_state_t::WEAK_NOT_TAKEN);
  pc = dut->top->next_pc;
  
  // 0x80000008
  dut->fetch(pc, pc+4);
  dut->do_posedge([](VbranchPredictor *brp) {
    brp->branch_result_valid = 0;
    brp->branch_correct = 0;
  });
  EXPECT_TRUE(dut->top->instr_valid[0]);
  EXPECT_TRUE(dut->top->instr_valid[1]);
  EXPECT_EQ(dut->top->next_pc, pc + 8);
  EXPECT_FALSE(dut->top->is_branch_instr[0]);
  EXPECT_FALSE(dut->top->is_branch_instr[1]);
  EXPECT_EQ(dut->top->rootp->branchPredictor__DOT__branch_state, branch_state_t::WEAK_NOT_TAKEN);
  pc = dut->top->next_pc;

  // 0x80000010
  dut->fetch(pc, pc+4);
  dut->do_posedge([](VbranchPredictor *brp) {
    brp->branch_result_valid = 0;
    brp->branch_correct = 0;
  });
  EXPECT_TRUE(dut->top->instr_valid[0]);
  EXPECT_TRUE(dut->top->instr_valid[1]);
  EXPECT_EQ(dut->top->next_pc, pc + 8);
  EXPECT_FALSE(dut->top->is_branch_instr[0]);
  EXPECT_FALSE(dut->top->is_branch_instr[1]);
  EXPECT_EQ(dut->top->rootp->branchPredictor__DOT__branch_state, branch_state_t::WEAK_NOT_TAKEN);
  pc = dut->top->next_pc;

  // 0x80000018
  dut->fetch(pc, pc+4);
  dut->do_posedge([](VbranchPredictor *brp) {
    brp->branch_result_valid = 1;
    brp->branch_correct = 1;
  });
  EXPECT_TRUE(dut->top->instr_valid[0]);
  EXPECT_TRUE(dut->top->instr_valid[1]);
  EXPECT_EQ(dut->top->next_pc, pc + 8);
  EXPECT_FALSE(dut->top->is_branch_instr[0]);
  EXPECT_FALSE(dut->top->is_branch_instr[1]);
  EXPECT_EQ(dut->top->rootp->branchPredictor__DOT__branch_state, branch_state_t::WEAK_NOT_TAKEN);
  pc = dut->top->next_pc;

  // 0x80000020
  dut->fetch(pc, pc+4);
  dut->do_posedge([](VbranchPredictor *brp) {
    brp->branch_result_valid = 0;
    brp->branch_correct = 0;
  });
  EXPECT_TRUE(dut->top->instr_valid[0]);
  EXPECT_TRUE(dut->top->instr_valid[1]);
  EXPECT_EQ(dut->top->next_pc, pc + 4 - 0x24);
  EXPECT_FALSE(dut->top->is_branch_instr[0]);
  EXPECT_TRUE(dut->top->is_branch_instr[1]);
  EXPECT_EQ(dut->top->rootp->branchPredictor__DOT__branch_state, branch_state_t::WEAK_TAKEN);
  pc = dut->top->next_pc;

  // 0x80000000
  dut->fetch(pc, pc+4);
  dut->do_posedge([](VbranchPredictor *brp) {
    brp->branch_result_valid = 0;
    brp->branch_correct = 0;
  });
  EXPECT_TRUE(dut->top->instr_valid[0]);
  EXPECT_FALSE(dut->top->instr_valid[1]);
  EXPECT_EQ(dut->top->next_pc, pc + 0x28);
  EXPECT_TRUE(dut->top->is_branch_instr[0]);
  EXPECT_FALSE(dut->top->is_branch_instr[1]);
  EXPECT_EQ(dut->top->rootp->branchPredictor__DOT__branch_state, branch_state_t::WEAK_TAKEN);
  pc = dut->top->next_pc;

  dut->next_clock();
  dut->next_clock();
  
  EXPECT_EQ(0, 0);
}