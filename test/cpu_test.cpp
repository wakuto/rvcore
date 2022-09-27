#include <iostream>
#include <fstream>
#include <verilated.h>          // Defines common routines
#include "../obj_dir//Vcpu.h"   // From Verilating "../rtl/cpu.sv"

unsigned int main_time = 0;     // Current simulation time

double sc_time_stamp () {       // Called by $time in Verilog
  return main_time;
}

int read_hexfile(std::string filename, uint8_t* buf, size_t len) {
  std::ifstream hexfile(filename, std::ios::binary);
  hexfile.seekg(0, std::ios::end);
  size_t size = hexfile.tellg();

  if(size > len)
    return 1;

  hexfile.seekg(0);
  hexfile.read((char*)buf, size);

  return 0;
}

uint32_t fetch_4byte(uint8_t *memory, size_t size, uint32_t addr) {
  if(addr+3 > size) {
    std::cerr << "Address out of memory:";
    std::cerr << std::showbase << std::hex;
    std::cerr << addr+3 << "/" << size << std::endl;
    std::cerr << std::noshowbase;
    exit(1);
  }
  auto data_word = (memory[addr+3] << 3*8) | 
         (memory[addr+2] << 2*8) | 
         (memory[addr+1] << 1*8) | 
         memory[addr];

  return data_word;
}

int main(int argc, char** argv) {

  Verilated::commandArgs(argc, argv);   // Remember args

  Vcpu *top = new Vcpu();       // Create instance
  uint8_t *program = new uint8_t[0x1000];   // 4kB memory
  if(read_hexfile("../sample_src/program.bin", program, 0x1000)) {
    std::cerr << "Could not read program.bin" << std::endl;
    exit(1);
  }

  top->reset = 0;       // Set some inputs
  top->clock = 0;
  top->instruction = fetch_4byte(program, 0x1000, top->pc);
  top->read_data = 0;
  top->read_enable = 0;


  while (!Verilated::gotFinish()) {

    //if ((main_time % 5) == 0)
      //top->clock = !top->clock;         // Toggle clock
    top->clock = !top->clock;

    //if (main_time > 10000)               // Release reset
    //  top->reset = 1;
    // Assert start flag

    top->instruction = fetch_4byte(program, 0x1000, top->pc);

    top->eval();                      // Evaluate model

    // Wait for done
    if (main_time>200)
      break;

    // debug output
    std::cout << std::showbase << std::dec;
    std::cout << "registers: main_time=" << main_time << std::endl;
    std::cout << "pc: " << std::hex << top->pc << std::endl;
    //for (int i = 0; i < 32; i++)
    for (int i = 0; i < 10; i++) {
      std::cout << "x" << std::dec << i << ": ";
      std::cout << std::hex << top->debug_reg[i] << std::endl;
    }


    if(top->debug_ebreak) {
      std::cout << "EBREAK!!!!!!!" << std::endl;
      break;
    }
    main_time++;                      // Time passes...

  }

  top->final();               // Done simulating
}
