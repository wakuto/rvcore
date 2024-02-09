#include "../../obj_dir/Vcore.h" // From Verilating "../rtl/core.sv"
#include "../../obj_dir/Vcore_robCommitIf.h"
#include "../../obj_dir/Vcore___024root.h"
#include <fstream>
#include <iostream>
#include <format>
#include <vector>
#include <filesystem>
#include <verilated.h>       // Defines common routines
#include <verilated_vcd_c.h> // VCD output
#include "../common/model_tester.hpp"

#define UART0_BASE 0x10000000
#define UART0_SIZE 0x100
#define DRAM_BASE  0x80000000
#define DRAM_SIZE  0x40000

class CoreTester : public ModelTester<Vcore> {
private:
  const uint32_t MEMORY_SIZE = DRAM_SIZE;
  // uint8_t *program = new uint8_t[MEMORY_SIZE]; // 4kB instruction memory
  uint8_t *memory = new uint8_t[MEMORY_SIZE];  // 4kB data memory

  // ログファイルのファイルポインタ
  std::ofstream log_file;

public:
  CoreTester(std::string dump_filename) : ModelTester("rvcore_vcd", dump_filename) {}
  
  ~CoreTester() {
    delete[] this->memory;
    this->log_file.close();
  }
  
  void clock(uint32_t signal) {
    this->top->clk = signal;
  }

  void reset(uint32_t signal) {
    this->top->rst = signal;
  }

  void init() {
    this->log_file.open("commit_log_rvcore.txt");
    this->reset(1);
    this->change_signal([](Vcore *core){
      // instruction data
      for(auto i = 0; i < 2; i++) {
        core->instruction[i] = 0;
        core->instr_valid[i] = 0;
      }
      
      // memory data
      core->read_data = 0;
      core->read_valid = 0;
      core->write_ready = 0;

      // interrupt
      core->timer_int = 0;
      core->soft_int = 0;
      core->ext_int = 0;
    });

    this->next_clock();
    this->next_clock();
    this->do_posedge([](Vcore *core) {
        core->rst = 0;
    });
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

  uint32_t read_dmem(uint32_t addr) {
    addr -= DRAM_BASE;
    if (addr + 3 > this->MEMORY_SIZE) {
      throw std::out_of_range(std::format("Address out of memory(read): {:#x}/{:#x}", addr+3, this->MEMORY_SIZE));
    }
    auto data_word = (this->memory[addr + 3] << 3 * 8) | (this->memory[addr + 2] << 2 * 8) |
                     (this->memory[addr + 1] << 1 * 8) | this->memory[addr];
    return data_word;
  }
  
  void write_dmem(uint32_t addr, uint32_t data, uint8_t strb) {
    static bool prev_was_newline = true;
    if (UART0_BASE <= addr && addr < UART0_BASE + UART0_SIZE) {
      if (prev_was_newline) {
        std::cout << "[UART0 OUTPUT] ";
        prev_was_newline = false;
      }
      std::cout << (char)this->top->write_data;
      if ((char)this->top->write_data == '\n')
        prev_was_newline = true;
    } else if (DRAM_BASE <= addr && addr < DRAM_BASE + DRAM_SIZE) {
      addr -= DRAM_BASE;
      uint32_t write_size = 0;
      if      (strb == 0b0001) write_size = 1;
      else if (strb == 0b0011) write_size = 2;
      else if (strb == 0b1111) write_size = 4;

      if (addr + write_size >= this->MEMORY_SIZE) {
        throw std::out_of_range(std::format("Address out of memory(write): {:#x}/{:#x}", addr+3, this->MEMORY_SIZE));
      }
      switch (write_size) {
      case 4:
        this->memory[addr + 3] = (data & 0xFF000000) >> 24;
        this->memory[addr + 2] = (data & 0x00FF0000) >> 16;
      case 2:
        this->memory[addr + 1] = (data & 0x0000FF00) >> 8;
      case 1:
        this->memory[addr + 0] = data & 0x000000FF;
      default:
        break;
      }
    }
  }

  void run_one_cycle(uint32_t mem_delay) {
    static uint32_t delay_counter = 0;
    for(auto i = 0; i < 2; i++) {
      this->top->instruction[i] = this->read_imem(this->top->pc + 4*i);
      this->top->instr_valid[i] = this->top->instruction[i] != 0xdeadbeef;
    }
      
    this->do_posedge([&](Vcore *core) {
      // delay_counter = 0 -> read_valid = write_ready = 0
      if (core->read_enable) {
        if (delay_counter < mem_delay) {
          core->read_data = 0xdeadbeef;
          core->read_valid = 0;
          delay_counter++;
        } else {
          core->read_data = this->read_dmem(core->address);
          core->read_valid = 1;
          delay_counter = 0;
        }
      } else if (core->write_enable) {
        if (delay_counter < mem_delay) {
          core->write_ready = 0;
          delay_counter++;
        } else {
          this->write_dmem(core->address, core->write_data, core->strb);
          core->write_ready = 1;
          delay_counter = 0;
        }
      }
    });
    this->dump_commit_log();
  }

  void dump_commit_log(void) {
    auto commit = this->top->__PVT__core__DOT__commit_if_disp->en[0] + this->top->__PVT__core__DOT__commit_if_disp->en[1];

    if (commit > 0) {
      auto pc_0 = this->top->__PVT__core__DOT__commit_if_disp->pc[0];
      auto pc_1 = this->top->__PVT__core__DOT__commit_if_disp->pc[1];
      auto instr_0 = this->top->__PVT__core__DOT__commit_if_disp->instr[0];
      auto instr_1 = this->top->__PVT__core__DOT__commit_if_disp->instr[1];
      auto arch_rd_0 = this->top->__PVT__core__DOT__commit_if_disp->arch_rd[0];
      auto arch_rd_1 = this->top->__PVT__core__DOT__commit_if_disp->arch_rd[1];
      auto phys_rd_0 = this->top->__PVT__core__DOT__commit_if_disp->phys_rd[0];
      auto phys_rd_1 = this->top->__PVT__core__DOT__commit_if_disp->phys_rd[1];
      auto rd_val_0 = this->top->rootp->core__DOT__phys_regfile__DOT__regfile[phys_rd_0];
      auto rd_val_1 = this->top->rootp->core__DOT__phys_regfile__DOT__regfile[phys_rd_1];

      switch(commit) {
      case 1:
        // bank0 のコミットログを表示
        this->log_file << std::format("core{:>4}: {:>1} {:#010x} ({:#010x}) x{:<2} {:#010x}", 0, 3, pc_0, instr_0, arch_rd_0, rd_val_0) << std::endl;
        break;
      case 2:
        this->log_file << std::format("core{:>4}: {:>1} {:#010x} ({:#010x}) x{:<2} {:#010x}", 0, 3, pc_0, instr_0, arch_rd_0, rd_val_0) << std::endl;
        this->log_file << std::format("core{:>4}: {:>1} {:#010x} ({:#010x}) x{:<2} {:#010x}", 0, 3, pc_1, instr_1, arch_rd_1, rd_val_1) << std::endl;
        break;
      }
    }
  }
  
};

int main(int argc, char **argv) {
  // 実行するファイル名を引数から取得
  if (argc < 2) {
    std::cout << "Usage: " << argv[0] << " <program file>" << std::endl;
    return 1;
  }

  auto dut = std::make_unique<CoreTester>("rvcore.vcd");
  dut->read_program(argv[1]);
  dut->init();
  
  uint32_t cycle = 0;
  while (1) {
    cycle++;
    dut->run_one_cycle(4);
    if (cycle > 5000 || dut->top->debug_ebreak) break;
  }
}
