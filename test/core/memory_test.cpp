#include "../../obj_dir/Vmemory.h"
#include <fstream>
#include <iostream>
#include <string>
#include <format>
#include <verilated.h>       // Defines common routines
#include <verilated_vcd_c.h> // VCD output
#include <gtest/gtest.h>
#include "model_tester.hpp"

#define UART0_BASE 0x10000000
#define UART0_SIZE 0x100
#define DRAM_BASE  0x80000000
#define DRAM_SIZE  0x40000

// メモリ操作用クラス
class MemoryTester : public ModelTester<Vmemory> {
public:
  MemoryTester(std::string dump_filename) : ModelTester("memory_test_vcd", dump_filename) {}
  
  void clock(uint32_t signal) {
    this->top->clk = signal;
  }

  void reset(uint32_t signal) {
    this->top->reset = signal;
  }

  void init() {
    this->reset(1);
    this->change_signal([](Vmemory *vmem){
      vmem->read_enable = 0;
      vmem->write_data = 0;
      vmem->write_wstrb = 0;
      vmem->write_enable = 0;
    });

    this->next_clock();
    this->reset(0);
  }
  
  // signalがvalid(=1)になるまで待機
  // クロックの立ち上がりまで解析を続ける
  void wait_for_signal(CData *signal) {
    do {
      this->next_clock();
    } while(!*signal);
  }
  
  uint32_t readmem(uint32_t addr) {
    this->do_posedge([=](Vmemory *vmem) {
      vmem->address = addr+DRAM_BASE;
      vmem->read_enable = 1;
      vmem->write_enable = 0;
    });
    this->wait_for_signal(&this->top->read_valid);
    return this->top->read_data;
  }
  
  void writemem(uint32_t addr, uint8_t data) {
    this->do_posedge([=](Vmemory *vmem) {
      vmem->address = addr+DRAM_BASE;
      vmem->read_enable = 0;
      vmem->write_enable = 1;
      vmem->write_data = data;
      vmem->write_wstrb = 0x01;
    });
    this->wait_for_signal(&this->top->write_ready);
  }

  void writemem(uint32_t addr, uint16_t data) {
    this->do_posedge([=](Vmemory *vmem) {
      vmem->address = addr+DRAM_BASE;
      vmem->read_enable = 0;
      vmem->write_enable = 1;
      vmem->write_data = data;
      vmem->write_wstrb = 0x03;
    });
    this->wait_for_signal(&this->top->write_ready);
  }

  void writemem(uint32_t addr, uint32_t data) {
    this->do_posedge([=](Vmemory *vmem) {
      vmem->address = addr+DRAM_BASE;
      vmem->read_enable = 0;
      vmem->write_enable = 1;
      vmem->write_data = data;
      vmem->write_wstrb = 0x0F;
    });
    this->wait_for_signal(&this->top->write_ready);
  }
};

size_t load_program(std::string program_file, uint32_t *program, size_t size) {
  std::ifstream program_stream(program_file, std::ios::binary);
  if (program_stream.fail()) {
    throw std::runtime_error("failed to load memory initialization file: ../sample_src/program.bin");
  }

  auto i = 0;
  uint8_t buffer[4];
  while (i < size && program_stream.read(reinterpret_cast<char*>(buffer), 4)) {
    program[i++] = static_cast<uint32_t>(buffer[0]) |
                        (static_cast<uint32_t>(buffer[1]) << 8) |
                        (static_cast<uint32_t>(buffer[2]) << 16) |
                        (static_cast<uint32_t>(buffer[3]) << 24);
  }
  // 読み込めたサイズを返却
  // size分読めたときを場合分け
  return i+1 < size ? i+1 : size;
}

TEST (memory_test, read_test) {
  uint32_t program[32];
  auto test_num = 0;
  ASSERT_NO_THROW(test_num = load_program("../sample_src/program.bin", program, 32));

  auto dut = new MemoryTester("read_test.vcd");
  dut->init();
  
  for(int i = 0; i < test_num; i++) {
    uint32_t tmp;
    ASSERT_EQ(program[i], tmp = dut->readmem(0x04*i))
      << std::format("memory data is different at {:#x}: expect:{:#x}, actually:{:#x}", 0x4*i, program[0x4*i], tmp);
  }
}

TEST (memory_test, write_1byte_test) {
  uint32_t program[32];
  auto test_num = 0;
  ASSERT_NO_THROW(test_num = load_program("../sample_src/program.bin", program, 32));

  auto dut = new MemoryTester("write_1byte_test.vcd");
  dut->init();

  for(int i = 0; i < test_num; i++) {
    dut->writemem(0x4*i, (uint8_t)i);
    program[i] &= 0xFFFFFF00;
    program[i] |= (uint8_t)i;
  }
  
  for(int i = 0; i < test_num; i++) {
    uint32_t tmp;
    ASSERT_EQ(program[i], tmp = dut->readmem(0x04*i))
      << std::format("memory data is different at {:#x}: expect:{:#x}, actually:{:#x}", 0x4*i, program[0x4*i], tmp);
  }
}

TEST (memory_test, write_2byte_test) {
  uint32_t program[32];
  auto test_num = 0;
  ASSERT_NO_THROW(test_num = load_program("../sample_src/program.bin", program, 32));

  auto dut = new MemoryTester("write_2byte_test.vcd");
  dut->init();

  for(int i = 0; i < test_num; i++) {
    dut->writemem(0x4*i, (uint16_t)i);
    program[i] &= 0xFFFF0000;
    program[i] |= (uint16_t)i;
  }
  
  for(int i = 0; i < test_num; i++) {
    uint32_t tmp;
    ASSERT_EQ(program[i], tmp = dut->readmem(0x04*i))
      << std::format("memory data is different at {:#x}: expect:{:#x}, actually:{:#x}", 0x4*i, program[0x4*i], tmp);
  }
}

TEST (memory_test, write_4byte_test) {
  uint32_t program[32];
  auto test_num = 0;
  ASSERT_NO_THROW(test_num = load_program("../sample_src/program.bin", program, 32));

  auto dut = new MemoryTester("write_4byte_test.vcd");
  dut->init();

  for(int i = 0; i < test_num; i++) {
    dut->writemem(0x4*i, (uint32_t)(1 << i));
    program[i] = (uint32_t)(1 << i);
  }
  
  for(int i = 0; i < test_num; i++) {
    uint32_t tmp;
    ASSERT_EQ(program[i], tmp = dut->readmem(0x04*i))
      << std::format("memory data is different at {:#x}: expect:{:#x}, actually:{:#x}", 0x4*i, program[0x4*i], tmp);
  }
}
