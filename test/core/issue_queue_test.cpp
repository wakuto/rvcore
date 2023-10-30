#include <iostream>
#include <format>
#include <gtest/gtest.h>
#include <sys/types.h>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vissue_queue.h"
#include "../common/model_tester.hpp"

struct dispatch_data_t {
  uint8_t alu_cmd;
  uint32_t op1;
  bool op1_valid;
  uint32_t op2;
  bool op2_valid;
  uint8_t phys_rd;
};

struct writeback_data_t {
  uint8_t phys_result_tag;
  uint32_t phys_result_data;
};

class IssueQueueTester : public ModelTester<Vissue_queue> {
public:
  IssueQueueTester(std::string dump_filename) : ModelTester("issue_queue_test_vcd", dump_filename) {}
  
  void clock(uint32_t signal) {
    this->top->clk = signal;
  }

  void reset(uint32_t signal) {
    this->top->rst = signal;
  }

  void init() {
    this->reset(1);
    this->top->eval();
    this->do_posedge([](Vissue_queue *isq){
      isq->in_write_enable = 0;
      isq->in_alu_cmd = 0;
      isq->in_op1_valid = 0;
      isq->in_op2_valid = 0;
      isq->in_op1 = 0;
      isq->in_op2 = 0;
      isq->in_phys_rd = 0;
      isq->phys_result_valid = 0;
      isq->phys_result_tag = 0;
      isq->phys_result_data = 0;
    });

    this->next_clock();
    this->next_clock();
    this->reset(0);
  }

  
  void dispatch(dispatch_data_t data) {
    this->do_posedge([data](Vissue_queue *isq){
      isq->in_write_enable = 1;
      isq->in_alu_cmd = data.alu_cmd;
      isq->in_op1_valid = data.op1_valid;
      isq->in_op2_valid = data.op2_valid;
      isq->in_op1 = data.op1;
      isq->in_op2 = data.op2;
      isq->in_phys_rd = data.phys_rd;
      isq->phys_result_valid = 0;
    });
  }

  void writeback(writeback_data_t data) {
    this->do_posedge([data](Vissue_queue *isq){
      isq->in_write_enable = 0;
      isq->phys_result_valid = 1;
      isq->phys_result_tag = data.phys_result_tag;
      isq->phys_result_data = data.phys_result_data;
    });
  }

  bool get_issue_data(dispatch_data_t *data) {
    data->alu_cmd = this->top->issue_alu_cmd;
    data->op1 = this->top->issue_op1;
    data->op2 = this->top->issue_op2;
    data->phys_rd = this->top->phys_rd;
    return this->top->alu_cmd_valid;
  }

  bool check_issue(dispatch_data_t *data, dispatch_data_t *expected) {
    if ((data->alu_cmd) != (expected->alu_cmd)) {
      std::cout << std::format("alu_cmd: expect 0x{:02x}, actual 0x{:02x}\n", expected->alu_cmd, data->alu_cmd);
      return false;
    }
    if (expected->op1 != data->op1) {
      std::cout << std::format("op1: expect 0x{:08x}, actual 0x{:08x}\n", expected->op1, data->op1);
      return false;
    }
    if (expected->op2 != data->op2) {
      std::cout << std::format("op2: expect 0x{:08x}, actual 0x{:08x}\n", expected->op2, data->op2);
      return false;
    }
    if (expected->phys_rd != data->phys_rd) {
      std::cout << std::format("phys_rd: expect 0x{:02x}, actual 0x{:02x}\n", expected->phys_rd, data->phys_rd);
      return false;
    }
    return true;
  }

};


TEST (IssueQueueTest, Basic) {
  auto dut =  std::make_unique<IssueQueueTester>("issue_queue_test.vcd");

  dispatch_data_t data[] = {
    //            alu_cmd op1 op1_valid  op2 op2_valid  phys_rd
    dispatch_data_t{0xaa, 0x00000001, 0, 0x00000001, 0, 0x1},
    dispatch_data_t{0xbb, 0x00000002, 1, 0x00000002, 0, 0x1},
    dispatch_data_t{0xcc, 0x00000003, 0, 0x00000003, 1, 0x1},
    dispatch_data_t{0xdd, 0x00000004, 1, 0x00000004, 1, 0x1},
    dispatch_data_t{0xee, 0x00000005, 0, 0x00000005, 0, 0x1},
    dispatch_data_t{0xff, 0x00000006, 0, 0x00000006, 0, 0x1},
  };

  writeback_data_t writeback_data[] = {
    writeback_data_t{0x4, 0xdddddddd},
    writeback_data_t{0x6, 0xffffffff},
    writeback_data_t{0x2, 0xbbbbbbbb},
    writeback_data_t{0x5, 0xeeeeeeee},
    writeback_data_t{0x3, 0xcccccccc},
    writeback_data_t{0x1, 0xaaaaaaaa}
  };

  dispatch_data_t issue_expected[] = {
    dispatch_data_t{0x1d, 0x00000004, 1, 0x00000004, 1, 0x1},
    dispatch_data_t{0x1f, 0xffffffff, 1, 0xffffffff, 1, 0x1},
    dispatch_data_t{0x1b, 0x00000002, 1, 0xbbbbbbbb, 1, 0x1},
    dispatch_data_t{0x0e, 0xeeeeeeee, 1, 0xeeeeeeee, 1, 0x1},
    dispatch_data_t{0x0c, 0xcccccccc, 1, 0x00000003, 1, 0x1},
    dispatch_data_t{0x0a, 0xaaaaaaaa, 1, 0xaaaaaaaa, 1, 0x1},
  };

  dispatch_data_t buffer = {0, 0, 0, 0, 0, 0};

  dut->init();

  dut->dispatch(data[0]);
  dut->dispatch(data[1]);
  dut->dispatch(data[2]);
  dut->dispatch(data[3]);
  dut->dispatch(data[4]);

  EXPECT_TRUE(dut->get_issue_data(&buffer));
  EXPECT_TRUE(dut->check_issue(&buffer, &issue_expected[0]));

  dut->dispatch(data[5]);

  dut->writeback(writeback_data[0]);
  dut->do_posedge([] (Vissue_queue *isq) {
    isq->phys_result_valid = 0;
  });
  EXPECT_FALSE(dut->get_issue_data(&buffer));

  dut->writeback(writeback_data[1]);
  dut->writeback(writeback_data[2]);

  EXPECT_TRUE(dut->get_issue_data(&buffer));
  EXPECT_TRUE(dut->check_issue(&buffer, &issue_expected[1]));

  dut->writeback(writeback_data[3]);

  EXPECT_TRUE(dut->get_issue_data(&buffer));
  EXPECT_TRUE(dut->check_issue(&buffer, &issue_expected[2]));

  dut->writeback(writeback_data[4]);

  EXPECT_TRUE(dut->get_issue_data(&buffer));
  EXPECT_TRUE(dut->check_issue(&buffer, &issue_expected[3]));

  dut->writeback(writeback_data[5]);

  EXPECT_TRUE(dut->get_issue_data(&buffer));
  EXPECT_TRUE(dut->check_issue(&buffer, &issue_expected[4]));

  dut->do_posedge([](Vissue_queue *isq) {
    isq->phys_result_valid = 0;
    isq->in_write_enable = 0;
  });

  EXPECT_TRUE(dut->get_issue_data(&buffer));
  EXPECT_TRUE(dut->check_issue(&buffer, &issue_expected[5]));


  dut->next_clock();
  // EXPECT_TRUE(dut->check_issue(issue_expected[5]));
  dut->next_clock();
}
