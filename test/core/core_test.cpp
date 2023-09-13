#include "../../obj_dir/Vcore.h" // From Verilating "../rtl/core.sv"
#include <fstream>
#include <iostream>
#include <format>
#include <vector>
#include <filesystem>
#include <verilated.h>       // Defines common routines
#include <verilated_vcd_c.h> // VCD output
#include <gtest/gtest.h>
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

public:
  CoreTester(std::string dump_filename) : ModelTester("core_test_vcd", dump_filename) {}
  
  void clock(uint32_t signal) {
    this->top->clock = signal;
  }

  void reset(uint32_t signal) {
    this->top->reset = signal;
  }

  void init() {
    this->reset(1);
    this->change_signal([](Vcore *core){
      // instruction data
      core->instruction = 0;
      core->instr_valid = 0;
      
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
    this->do_posedge([&](Vcore *core) {
      core->instruction = this->read_imem(core->pc);
      core->instr_valid = 1;
      
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
  }
};

TEST (core_test, run_sample_program) {
  auto dut = new CoreTester("sample_program.vcd");
  dut->read_program("../sample_src/program.bin");
  dut->init();
  
  uint32_t cycle = 0;
  while (1) {
    cycle++;
    dut->run_one_cycle(4);
    if (cycle > 5000 || dut->top->debug_ebreak) break;
  }
  EXPECT_FALSE(cycle > 5000) << std::format("Test is too long. cycle = {}", cycle);
  EXPECT_TRUE(dut->top->debug_ebreak) << "Test wasn't done.";
  delete(dut);
}

// TODO: RISC-V Tests を実行するテストを書く
TEST (core_test, run_riscv_test) {
  std::string riscv_test_path = "../sample_src/riscv-tests/bin/";
  std::vector<std::string> bin_files;

  for (const auto& entry : std::filesystem::directory_iterator(riscv_test_path)) {
    if (entry.is_regular_file() && entry.path().extension() == ".bin") {
      bin_files.push_back(entry.path().filename().stem().string());
    }
  }
  
  for (const auto& bin_file : bin_files) {
    auto dut = new CoreTester(bin_file + ".vcd");
    dut->read_program(riscv_test_path + bin_file + ".bin");
    dut->init();
    
    uint32_t cycle = 0;
    while (1) {
      cycle++;
      dut->run_one_cycle(4);
      if (cycle > 5000 || dut->top->debug_ecall) break;
    }
    EXPECT_FALSE(cycle > 5000) << std::format("[riscv-tests failed] {}, Test is too long. cycle = {}", bin_file, cycle);
    if (dut->top->debug_reg[3] == 1) std::cout << std::format("[riscv-tests pass] {}", bin_file) << std::endl;
    EXPECT_EQ(dut->top->debug_reg[3], 1) << std::format("[riscv-tests failed] {}", bin_file);

    delete(dut);
  }
}
