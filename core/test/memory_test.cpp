#include "../obj_dir/Vmemory.h"
#include <fstream>
#include <iostream>
#include <string>
#include <format>
#include <functional>
#include <verilated.h>       // Defines common routines
#include <verilated_vcd_c.h> // VCD output
#include <gtest/gtest.h>

// Verilatorモデルを操作するクラス
template <typename V>
class Model {
public:
  V *top;
  VerilatedVcdC *tfp;
  uint32_t main_time;

  Model(const char* dump_filename) {
    this->top = new V();
    Verilated::traceEverOn(true);
    this->tfp = new VerilatedVcdC;

    this->top->trace(this->tfp, 100);
    this->tfp->open(dump_filename);
  }
  
  void init() {
    this->change_signal([](Vmemory *vmem){
      vmem->reset = 1;
      vmem->read_enable = 0;
      vmem->write_data = 0;
      vmem->write_wstrb = 0;
      vmem->write_enable = 0;
    });

    this->next_clock();
    this->do_posedge([](Vmemory *vmem){
      vmem->reset = 0;
    });
  }

  void dump() {
    this->tfp->dump(this->main_time++);
  }
  void eval_dump() {
    this->top->eval();
    this->dump();
  }

  // signalがvalid(=1)になるまで待機
  // クロックの立ち上がりまで解析を続ける
  void wait_for_signal(CData *signal) {
    do {
      this->next_clock();
    } while(!*signal);
  }
  
  void next_clock() {
    this->top->clk = 1;
    this->eval_dump();
    this->top->clk = 0;
    this->eval_dump();
  }
  
  void change_signal(std::function<void(V*)> func) {
    func(top);
  }
  
  void do_posedge(std::function<void(V*)> func) {
    // クロックの立ち上げ
    this->top->clk = 1;
    this->top->eval();

    // 立ち上がったクロックに反応して信号を操作
    func(this->top);
    this->eval_dump();

    this->top->clk = 0;
    this->eval_dump();
  }
  
  uint32_t readmem(uint32_t addr) {
    this->do_posedge([=](Vmemory *vmem) {
      vmem->address = addr;
      vmem->read_enable = 1;
      vmem->write_enable = 0;
    });
    this->wait_for_signal(&this->top->read_valid);
    return this->top->read_data;
  }
  
  void writemem(uint32_t addr, uint8_t data) {
    this->do_posedge([=](Vmemory *vmem) {
      vmem->address = addr;
      vmem->read_enable = 0;
      vmem->write_enable = 1;
      vmem->write_data = data;
      vmem->write_wstrb = 0x01;
    });
    this->wait_for_signal(&this->top->write_ready);
  }

  void writemem(uint32_t addr, uint16_t data) {
    this->do_posedge([=](Vmemory *vmem) {
      vmem->address = addr;
      vmem->read_enable = 0;
      vmem->write_enable = 1;
      vmem->write_data = data;
      vmem->write_wstrb = 0x03;
    });
    this->wait_for_signal(&this->top->write_ready);
  }

  void writemem(uint32_t addr, uint32_t data) {
    this->do_posedge([=](Vmemory *vmem) {
      vmem->address = addr;
      vmem->read_enable = 0;
      vmem->write_enable = 1;
      vmem->write_data = data;
      vmem->write_wstrb = 0x0F;
    });
    this->wait_for_signal(&this->top->write_ready);
  }
};

size_t load_program(std::string program_file, uint32_t *program, size_t size) {
  std::ifstream program_stream(program_file);
  if (program_stream.fail()) {
    throw std::runtime_error("failed to load memory initialization file: ../sample_src/program.txt");
  }

  auto i = 0;
  std::string str_4byte;
  for(i = 0; (i < size) && std::getline(program_stream, str_4byte); i++) {
    program[i] = std::stoul(str_4byte, nullptr, 16);
  }
  // 読み込めたサイズを返却
  // size分読めたときを場合分け
  return i+1 < size ? i+1 : size;
}

TEST (memory_test, read_test) {
  uint32_t program[32];
  auto test_num = 0;
  ASSERT_NO_THROW(test_num = load_program("../sample_src/program.txt", program, 32));

  auto dut = new Model<Vmemory>("read_test.vcd");
  dut->init();
  
  for(int i = 0; i < test_num; i++) {
    uint32_t tmp;
    EXPECT_EQ(program[i], tmp = dut->readmem(0x04*i))
      << std::format("memory data is different at {:#x}: expect:{:#x}, actually:{:#x}", 0x4*i, program[0x4*i], tmp);
  }
  dut->next_clock();
  dut->top->final();
  dut->tfp->close();
}

TEST (memory_test, write_1byte_test) {
  uint32_t program[32];
  auto test_num = 0;
  ASSERT_NO_THROW(test_num = load_program("../sample_src/program.txt", program, 32));

  auto dut = new Model<Vmemory>("write_1byte_test.vcd");
  dut->init();

  for(int i = 0; i < test_num; i++) {
    dut->writemem(0x4*i, (uint8_t)i);
    program[i] &= 0xFFFFFF00;
    program[i] |= (uint8_t)i;
  }
  
  for(int i = 0; i < test_num; i++) {
    uint32_t tmp;
    EXPECT_EQ(program[i], tmp = dut->readmem(0x04*i))
      << std::format("memory data is different at {:#x}: expect:{:#x}, actually:{:#x}", 0x4*i, program[0x4*i], tmp);
  }
  dut->next_clock();
  dut->top->final();
  dut->tfp->close();
}

TEST (memory_test, write_2byte_test) {
  uint32_t program[32];
  auto test_num = 0;
  ASSERT_NO_THROW(test_num = load_program("../sample_src/program.txt", program, 32));

  auto dut = new Model<Vmemory>("write_2byte_test.vcd");
  dut->init();

  for(int i = 0; i < test_num; i++) {
    dut->writemem(0x4*i, (uint16_t)i);
    program[i] &= 0xFFFF0000;
    program[i] |= (uint16_t)i;
  }
  
  for(int i = 0; i < test_num; i++) {
    uint32_t tmp;
    EXPECT_EQ(program[i], tmp = dut->readmem(0x04*i))
      << std::format("memory data is different at {:#x}: expect:{:#x}, actually:{:#x}", 0x4*i, program[0x4*i], tmp);
  }
  dut->next_clock();
  dut->top->final();
  dut->tfp->close();
}

TEST (memory_test, write_4byte_test) {
  uint32_t program[32];
  auto test_num = 0;
  ASSERT_NO_THROW(test_num = load_program("../sample_src/program.txt", program, 32));

  auto dut = new Model<Vmemory>("write_4byte_test.vcd");
  dut->init();

  for(int i = 0; i < test_num; i++) {
    dut->writemem(0x4*i, (uint32_t)(1 << i));
    program[i] = (uint32_t)(1 << i);
  }
  
  for(int i = 0; i < test_num; i++) {
    uint32_t tmp;
    EXPECT_EQ(program[i], tmp = dut->readmem(0x04*i))
      << std::format("memory data is different at {:#x}: expect:{:#x}, actually:{:#x}", 0x4*i, program[0x4*i], tmp);
  }
  dut->next_clock();
  dut->top->final();
  dut->tfp->close();
}