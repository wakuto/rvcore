#include "../obj_dir/Vmemory.h"
#include <fstream>
#include <iostream>
#include <functional>
#include <verilated.h>       // Defines common routines
#include <verilated_vcd_c.h> // VCD output
                             //
unsigned int main_time = 0;  // Current simulation time

double sc_time_stamp() { // Called by $time in Verilog
  return main_time;
}

bool posedge(Vmemory *top) {
  static int prev_clk = 0;
  bool res = prev_clk != top->clk && top->clk == 1;
  prev_clk = top->clk;
  return res;
}

void copy_input_data(Vmemory *src, Vmemory *dest) {
  dest->clk = src->clk;
  dest->reset = src->reset;
  dest->address = src->address;
  dest->read_enable = src->read_enable;
  dest->write_data = src->write_data;
  dest->write_enable = src->write_enable;
  dest->write_wstrb = src->write_wstrb;
}

void copy_output_data(Vmemory *src, Vmemory *dest) {
  dest->read_data = src->read_data;
  dest->read_valid = src->read_valid;
  dest->write_ready = src->write_ready;
}

void do_posedge(Vmemory *top, void (*func)(Vmemory *)) {
  Vmemory *tmp = new Vmemory;
  copy_input_data(top, tmp);
  copy_output_data(top, tmp);

  func(tmp);

  top->clk = 1;

  top->eval();
  
  copy_input_data(tmp, top);
}


void processing(Vmemory *top) {
  static int state_count = 0;
  if (!top->reset) {
    // 1 byte書き込み
    // 2 byte書き込み
    // 4 byte書き込み
    switch(state_count) {
      case 0: {
        
        break;
      }
    }
  }
}

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
    while(!*signal) {
      this->top->clk = 0;
      this->eval_dump();
      this->top->clk = 1;
      this->eval_dump();
    }
  }
  
  void next_clock() {
    this->top->clk = 0;
    this->eval_dump();
    this->top->clk = 1;
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
};


// 
int main(int argc, char **argv) {
  std::cout << "Starting memory_test..." << std::endl;
  std::cout << std::showbase << std::hex;
  
  auto dut = new Model<Vmemory>();

  Verilated::commandArgs(argc, argv); // Remember args

  Vmemory *top = new Vmemory(); // Create instance

  // Trace DUMP ON
  Verilated::traceEverOn(true);
  VerilatedVcdC *tfp = new VerilatedVcdC;

  // initialize
  top->trace(tfp, 100);
  tfp->open("memory_test.vcd");
  
  dut->change_signal([](Vmemory *vmem){
    vmem->reset = 1;
    vmem->read_enable = 0;
    vmem->write_data = 0;
    vmem->write_wstrb = 0;
    vmem->write_enable = 0;
  });

  /*
  top->reset = 1;
  top->read_enable = 0;
  top->write_data = 0;
  top->write_wstrb = 0;
  top->write_enable = 0;
  */
  dut->next_clock();
  /*
  top->clk = 0;
  top->eval();
  tfp->dump(main_time++);
  top->clk = 1;
  top->eval();
  tfp->dump(main_time++);
  */
  top->clk = 0;
  top->eval();
  tfp->dump(main_time++);
  
  top->reset = 0;
  top->clk = 1;
  top->eval();
  tfp->dump(main_time++);
  top->clk = 0;
  top->eval();
  tfp->dump(main_time++);

  // 0x00を読み込み-----
  // クロックを立ち上げ
  top->clk = 1;
  top->eval();
  // 立ち上がったクロックに反応して入力信号を変化
  top->address = 0x00;
  top->read_enable = 1;
  top->eval();
  tfp->dump(main_time++);

  
  // データがvalidになるまで待機
  while(!top->read_valid) {
    top->clk = 0;
    top->eval();
    tfp->dump(main_time++);
    top->clk = 1;
    top->eval();
    tfp->dump(main_time++);
  }
  std::cout << "[0x00] = " << +(uint8_t)top->read_data << std::endl;

  top->clk = 0;
  top->eval();
  tfp->dump(main_time++);

  // 0x00に書き込み-----
  top->clk = 1;
  top->eval();
  top->read_enable = 0;
  top->write_enable = 1;
  top->write_data = 0xef;
  top->write_wstrb = 0x01;
  top->eval();
  tfp->dump(main_time++);
  
  // 書き込み完了まで待機
  while(!top->write_ready) {
    top->clk = 0;
    top->eval();
    tfp->dump(main_time++);
    top->clk = 1;
    top->eval();
    tfp->dump(main_time++);
  }
  std::cout << "write [0x00] <= " << +(uint8_t)top->write_data << std::endl;

  top->clk = 0;
  top->eval();
  tfp->dump(main_time++);
  
  // 0x00を読み込み-----
  top->clk = 1;
  top->eval();
  top->write_enable = 0;
  top->read_enable = 1;
  top->eval();
  tfp->dump(main_time++);

  // 読み込み完了まで待機
  while(!top->read_valid) {
    top->clk = 0;
    top->eval();
    tfp->dump(main_time++);
    top->clk = 1;
    top->eval();
    tfp->dump(main_time++);
  }
  
  top->clk = 0;
  top->eval();
  tfp->dump(main_time++);

  std::cout << "[0x00] = " << +(uint8_t)top->read_data << std::endl;

  // 0x04を読み込み-----
  top->clk = 1;
  top->eval();
  top->read_enable = 1;
  top->address = 0x04;
  top->eval();
  tfp->dump(main_time++);

  // 読み込み完了まで待機
  while(!top->read_valid) {
    top->clk = 0;
    top->eval();
    tfp->dump(main_time++);
    top->clk = 1;
    top->eval();
    tfp->dump(main_time++);
  }
  
  top->clk = 0;
  top->eval();
  tfp->dump(main_time++);
  std::cout << "[0x01] = " << +(uint8_t)top->read_data << std::endl;
  
  // 0x04に書き込み-----
  top->clk = 1;
  top->eval();
  top->read_enable = 0;
  top->write_enable = 1;
  top->write_data = 0xef;
  top->write_wstrb = 0x03;
  top->eval();
  tfp->dump(main_time++);

  // 書き込み完了まで待機
  while(!top->write_ready) {
    top->clk = 0;
    top->eval();
    tfp->dump(main_time++);
    top->clk = 1;
    top->eval();
    tfp->dump(main_time++);
  }
  
  top->clk = 0;
  top->eval();
  tfp->dump(main_time++);
  std::cout << "write [0x04] <= " << +(uint8_t)top->write_data << std::endl;

  // 0x04を読み込み-----
  top->clk = 1;
  top->eval();
  top->write_enable = 0;
  top->read_enable = 1;
  top->eval();
  tfp->dump(main_time++);
  
  // 読み込み完了まで待機
  while(!top->read_valid) {
    top->clk = 0;
    top->eval();
    tfp->dump(main_time++);
    top->clk = 1;
    top->eval();
    tfp->dump(main_time++);
  }

  top->clk = 0;
  top->eval();
  tfp->dump(main_time++);
  std::cout << "[0x04] = " << +(uint8_t)top->read_data << std::endl;
  
  // 0x04に書き込み-----
  top->clk = 1;
  top->eval();
  top->address = 0x04;
  top->read_enable = 0;
  top->write_enable = 1;
  top->write_data = 0xbe;
  top->eval();
  tfp->dump(main_time++);

  // 書き込み完了まで待機
  while(!top->write_ready) {
    top->clk = 0;
    top->eval();
    tfp->dump(main_time++);
    top->clk = 1;
    top->eval();
    tfp->dump(main_time++);
  }
  top->clk = 0;
  top->eval();
  tfp->dump(main_time++);
  std::cout << "write [0x04] <= " << +(uint8_t)top->write_data << std::endl;

  
  tfp->close();
  return 0;
  

  for(int i = 0; i < 5; i++) {
    top->clk = 1;
    top->eval();
    top->clk = 0;
    top->eval();
  }

  top->reset = 0;

  while (!Verilated::gotFinish()) {
    top->clk = !top->clk;

    if (posedge(top)) {
      top->clk = !top->clk;

      do_posedge(top, processing);

      top->clk = !top->clk;
    }

    top->eval();
    tfp->dump(main_time);

    main_time++;
    if (main_time > 100) {
      break;
    }
  }

  top->final(); // Done simulating
  tfp->close();
}



