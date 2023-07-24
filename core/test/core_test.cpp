#include "../obj_dir/Vcore.h" // From Verilating "../rtl/core.sv"
#include <fstream>
#include <iostream>
#include <format>
#include <verilated.h>       // Defines common routines
#include <verilated_vcd_c.h> // VCD output
#include <gtest/gtest.h>
#include "model_tester.hpp"

#define MEM_SIZE 0x20000

class CoreTester : public ModelTester<Vcore> {
private:
  const uint32_t MEMORY_SIZE = 0x20000;
  uint8_t *program = new uint8_t[MEMORY_SIZE]; // 4kB instruction memory
  uint8_t *memory = new uint8_t[MEMORY_SIZE];  // 4kB data memory

public:
  CoreTester(const char* dump_filename) : ModelTester(dump_filename) {}
  
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
    hexfile.read((char *)this->program, size);
  }
};

unsigned int main_time = 0; // Current simulation time

double sc_time_stamp() { // Called by $time in Verilog
  return main_time;
}

int read_hexfile(std::string filename, uint8_t *buf) {
  size_t len = MEM_SIZE;
  std::ifstream hexfile(filename, std::ios::binary);
  hexfile.seekg(0, std::ios::end);
  size_t size = hexfile.tellg();

  if (size > len)
    return 1;

  hexfile.seekg(0);
  hexfile.read((char *)buf, size);

  return 0;
}

uint32_t fetch_4byte(uint8_t *memory, uint32_t addr) {
  size_t size = MEM_SIZE;
  if (addr + 3 > size) {
    std::cerr << "Address out of memory(fetch):";
    std::cerr << std::showbase << std::hex;
    std::cerr << addr + 3 << "/" << size << std::endl;
    std::cerr << std::noshowbase;
    exit(1);
  }
  auto data_word = (memory[addr + 3] << 3 * 8) | (memory[addr + 2] << 2 * 8) |
                   (memory[addr + 1] << 1 * 8) | memory[addr];

  return data_word;
}

void mem_write(uint8_t *memory, uint32_t addr, uint32_t data, uint8_t wstrb) {
  size_t size = MEM_SIZE;
  uint32_t write_size = wstrb + 1;
  if (addr + write_size >= size) {
    std::cerr << "Address out of memory(write):";
    std::cerr << std::showbase << std::hex;
    std::cerr << addr + 3 << "/" << size << std::endl;
    std::cerr << std::noshowbase;
    exit(1);
  }
  switch (write_size) {
  case 4:
    memory[addr + 2] = (data & 0x00FF0000) >> 16;
    memory[addr + 3] = (data & 0xFF000000) >> 24;
  case 2:
    memory[addr + 1] = (data & 0x0000FF00) >> 8;
  case 1:
    memory[addr + 0] = data & 0x000000FF;
  default:
    break;
  }
}

// TODO: サンプルプログラムを実行するテストを書く
TEST (core_test, run_sample_program) {
  auto dut = new CoreTester("sample_program.vcd");
  dut->read_program("../sample_src/program.bin");
  dut->init();
  
  dut->do_posedge([](Vcore *core) {
  });
}

// TODO: RISC-V Tests を実行するテストを書く
TEST (core_test, run_riscv_test) {
  
}

// int main(int argc, char **argv) {
TEST (core_test, core) {
  // Verilated::commandArgs(argc, argv); // Remember args

  Vcore *top = new Vcore(); // Create instance

  // Trace DUMP ON
  Verilated::traceEverOn(true);
  VerilatedVcdC *tfp = new VerilatedVcdC;

  uint8_t *program = new uint8_t[MEM_SIZE]; // 4kB instruction memory
  uint8_t *memory = new uint8_t[MEM_SIZE];  // 4kB data memory
  for (int i = 0; i < MEM_SIZE; i++)
    memory[i] = i;
  if (read_hexfile("../sample_src/program.bin", program)) {
    std::cerr << "Could not read program.bin" << std::endl;
    exit(1);
  }

  // initialize
  top->trace(tfp, 100);
  tfp->open("cpu_sim.vcd");
  top->clock = 1;
  top->reset = 0;
  top->instruction = fetch_4byte(program, top->pc);
  top->read_data = 0;
  top->read_valid = 0;
  top->timer_int = 0;
  top->soft_int = 0;
  top->ext_int = 0;

  // とりあえずwrite/fetchのレイテンシは無視
  top->instr_valid = 1;
  top->write_ready = 1;

  int access_counter = 0;

  while (!Verilated::gotFinish()) {

    top->instruction = fetch_4byte(program, top->pc);
    if (top->read_enable) {
      if (access_counter < 4) {
        top->read_data = 0xdeadbeef;
        top->read_valid = 0;
        access_counter++;
      } else {
        top->read_data = fetch_4byte(memory, top->address);
        top->read_valid = 1;
        access_counter = 0;
      }
    }
    if (top->write_enable) {
      mem_write(memory, top->address, top->write_data, top->strb);
    }

    int tmp = main_time - 100;
    if (tmp >= 0 && tmp < 2)
      top->soft_int = 1;
    else
      top->soft_int = 0;

    top->eval();

    top->clock = !top->clock;

    top->eval(); // Evaluate model
    tfp->dump(main_time);

    // Wait for done
    if (main_time > 10000)
      break;

    // debug output
    std::cout << std::showbase << std::dec;
    std::cout << "registers: main_time=" << main_time << std::endl;
    std::cout << "pc: " << std::hex << top->pc << std::endl;
    std::cout << "instruction: " << std::hex << top->instruction << std::endl;
    for (int i = 0; i < 16; i++) {
      std::cout << "x" << std::dec << i << ": ";
      std::cout << std::hex << top->debug_reg[i] << std::endl;
    }

    if (top->illegal_instr) {
      std::cout << "Illegal Instruction: " << std::endl;
      std::cout << "pc: " << std::hex << top->pc << std::endl;
      std::cout << "instr: " << std::hex << top->instruction << std::endl;
    }
    if (top->debug_ebreak) {
      std::cout << "EBREAK!!!!!!!" << std::endl;
      break;
    }
    main_time++; // Time passes...
  }

  top->final(); // Done simulating
  tfp->close();
}
