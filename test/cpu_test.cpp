#include "../obj_dir//Vcpu.h" // From Verilating "../rtl/cpu.sv"
#include <fstream>
#include <iostream>
#include <verilated.h>       // Defines common routines
#include <verilated_vcd_c.h> // VCD output

#define MEM_SIZE 0x20000

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

int main(int argc, char **argv) {

  Verilated::commandArgs(argc, argv); // Remember args

  Vcpu *top = new Vcpu(); // Create instance

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

  while (!Verilated::gotFinish()) {

    top->instruction = fetch_4byte(program, top->pc);
    if (top->read_enable) {
      top->read_data = fetch_4byte(memory, top->address);
    }
    if (top->write_enable) {
      mem_write(memory, top->address, top->write_data, top->write_wstrb);
    }

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

    if (top->illegal_instruction) {
      std::cout << "Illegal Instruction: ";
      std::cout << "pc: " << std::hex << top->pc;
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
