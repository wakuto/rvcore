#include <iostream>
#include <format>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include <gtest/gtest.h>
#include "../../obj_dir/Vfifo.h"
#include "model_tester.hpp"

class FifoTester : public ModelTester<Vfifo> {
public:
  FifoTester(std::string dump_filename) : ModelTester("fifo_test_vcd", dump_filename) {}
  
  void clock(uint32_t signal) {
    this->top->clk = signal;
  }

  void reset(uint32_t signal) {
    this->top->rst = signal;
  }
  void init() {
    this->reset(1);
    this->change_signal([](Vfifo *fifo) {
      fifo->wr_en = 0;
      fifo->rd_en = 0;
      fifo-> wr_data = 0;
    });

    this->next_clock();
    this->next_clock();
    this->reset(0);
  }

  void enqueue(uint32_t data) {
    bool full = this->top->full;
    this->do_posedge([data, full](Vfifo *fifo) {
      if (!full) {
        fifo->wr_en = 1;
        fifo->wr_data = data;
      }
    });
    this->do_posedge([](Vfifo *fifo) {
      fifo->wr_en = 0;
    });
  }

  uint32_t dequeue() {
    bool empty = this->top->empty;
    this->do_posedge([empty](Vfifo *fifo) {
      if (!empty) {
        fifo->rd_en = 1;
      }
    });
    uint32_t result = 0;
    this->do_posedge([&result](Vfifo *fifo) {
      result = fifo->rd_data;
      fifo->rd_en = 0;
    });
    return empty ? 0 : result;
  }

  uint32_t en_de_queue(uint32_t data) {
    bool full = this->top->full;
    bool empty = this->top->empty;
    this->do_posedge([data, full, empty](Vfifo *fifo) {
      if (!full) {
        fifo->wr_en = 1;
        fifo->wr_data = data;
      }
      if (!empty) {
        fifo->rd_en = 1;
      }
    });
    this->do_posedge([](Vfifo *fifo) {
      fifo->wr_en = 0;
      fifo->rd_en = 0;
    });
    return empty ? 0 : this->top->rd_data;
  }

};

TEST (fifo_test, fifo) {
  auto dut = new FifoTester("fifo_test.vcd");
  dut->init();

  EXPECT_EQ(dut->dequeue(), 0);

  dut->enqueue(0xdeadbeef);
  EXPECT_EQ(dut->dequeue(), 0xdeadbeef);

  EXPECT_EQ(dut->dequeue(), 0);

  dut->enqueue(0xdeadbeef);
  dut->enqueue(0xcafebabe);
  EXPECT_EQ(dut->dequeue(), 0xdeadbeef);
  EXPECT_EQ(dut->dequeue(), 0xcafebabe);

  for(size_t i = 0; i < 20; i++) {
    dut->enqueue(i);
  }

  for(size_t i = 0; i < 16; i++) {
    uint32_t val = dut->dequeue();
    EXPECT_EQ(val, i);
  }

  dut->enqueue(1);
  for (int i = 2; i < 16; i++) {
    uint32_t val = dut->en_de_queue(i);
    EXPECT_EQ(val, i-1);
  }

  dut->next_clock();
  dut->next_clock();

  delete(dut);
}
