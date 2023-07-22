#include "../obj_dir/Vmemory.h"
#include <fstream>
#include <iostream>
#include <functional>
#include <verilated.h>       // Defines common routines
#include <verilated_vcd_c.h> // VCD output
                             //
// Verilatorモデルを操作するクラス
template <typename V>
class Model {
public:
  V *top;
  VerilatedVcdC *tfp;
  uint32_t main_time;

  Model() {
    this->top = new V();
    Verilated::traceEverOn(true);
    this->tfp = new VerilatedVcdC;

    this->top->trace(this->tfp, 100);
    this->tfp->open("memory_test.vcd");
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
      vmem->read_enable = 0;
      vmem->write_enable = 1;
      vmem->write_data = data;
      vmem->write_wstrb = 0x01;
    });
    this->wait_for_signal(&this->top->write_ready);
  }

  void writemem(uint32_t addr, uint16_t data) {
    this->do_posedge([=](Vmemory *vmem) {
      vmem->read_enable = 0;
      vmem->write_enable = 1;
      vmem->write_data = data;
      vmem->write_wstrb = 0x03;
    });
    this->wait_for_signal(&this->top->write_ready);
  }

  void writemem(uint32_t addr, uint32_t data) {
    this->do_posedge([=](Vmemory *vmem) {
      vmem->read_enable = 0;
      vmem->write_enable = 1;
      vmem->write_data = data;
      vmem->write_wstrb = 0x0F;
    });
    this->wait_for_signal(&this->top->write_ready);
  }
};


int main(int argc, char **argv) {
  std::cout << "Starting memory_test..." << std::endl;
  std::cout << std::showbase << std::hex;
  
  auto dut = new Model<Vmemory>();

  // reset
  dut->change_signal([](Vmemory *vmem){
    vmem->reset = 1;
    vmem->read_enable = 0;
    vmem->write_data = 0;
    vmem->write_wstrb = 0;
    vmem->write_enable = 0;
  });

  dut->next_clock();
  dut->do_posedge([](Vmemory *vmem){
    vmem->reset = 0;
  });

  // 0x00を読み込み
  std::cout << "[0x00] = " << dut->readmem(0x00) << std::endl;

  // 0x00に書き込み-----
  dut->writemem(0x00, (uint8_t)0xef);
  std::cout << "write [0x00] <= " << (uint32_t)0xef << std::endl;

  // 0x00を読み込み-----
  std::cout << "[0x00] = " << dut->readmem(0x00) << std::endl;

  // 0x04を読み込み-----
  std::cout << "[0x04] = " << dut->readmem(0x04) << std::endl;
  
  // 0x04に書き込み-----
  dut->writemem(0x04, (uint8_t)0xef);
  std::cout << "write [0x04] <= " << (uint32_t)0xef << std::endl;

  // 0x04を読み込み-----
  std::cout << "[0x04] = " << dut->readmem(0x04) << std::endl;
  
  // 0x04に書き込み-----
  dut->writemem(0x04, (uint8_t)0xbe);
  std::cout << "write [0x04] <= " << (uint32_t)0xbe << std::endl;

  // 0x04を読み込み-----
  std::cout << "[0x04] = " << dut->readmem(0x04) << std::endl;
  
  dut->next_clock();

  
  dut->top->final();
  dut->tfp->close();
  return 0;
}



