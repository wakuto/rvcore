#ifndef MODEL_TESTER_HPP
#define MODEL_TESTER_HPP

#include <verilated.h>
#include <verilated_vcd_c.h> // VCD output
#include <filesystem>
#include <functional>

// Verilatorモデルを操作するクラス
template <class V>
class ModelTester {
public:
  V *top;
  VerilatedVcdC *tfp;
  uint32_t main_time;

  ModelTester(std::string dump_dirname, std::string dump_filename) {
    std::filesystem::create_directory(dump_dirname);
    this->top = new V();
    Verilated::traceEverOn(true);
    this->tfp = new VerilatedVcdC;

    this->top->trace(this->tfp, 100);
    this->tfp->open((dump_dirname + "/" + dump_filename).c_str());
  }
  
  /// @brief clockを操作する関数
  /// @param signal 設定する値
  virtual void clock(uint32_t signal) = 0;

  /// @brief resetを操作する関数
  /// @param signal 設定する値
  virtual void reset(uint32_t signal) = 0;

  virtual ~ModelTester() {
    this->top->final();
    this->tfp->close();
  }
  
  virtual void init() {
    this->reset(1);

    this->next_clock();

    this->reset(0);
  }

  virtual void dump() final {
    this->tfp->dump(this->main_time++);
  }

  virtual void eval_dump() final {
    this->top->eval();
    this->dump();
  }

  // signalがvalid(=1)になるまで待機
  // クロックの立ち上がりまで解析を続ける
  virtual void wait_for_signal(CData *signal) {
    do {
      this->next_clock();
    } while(!*signal);
  }
  
  virtual void next_clock() {
    this->clock(1);
    this->eval_dump();
    this->clock(0);
    this->eval_dump();
  }
  
  virtual void change_signal(std::function<void(V*)> func) final {
    func(top);
  }
  
  // posedge と同等のことを再現するには…
  // 1. 今の値で演算してまだ代入しない
  // 2. clk を 0 -> 1 にする
  // 3. eval() 呼ぶ
  // 4. 1.で計算した内容を代入する
  // 5. dump() 呼ぶ
  // 6. clk を 1 -> 0 にする
  // 6. eval_dump() 呼ぶ
  virtual void do_posedge(std::function<void(V*)> func) {
    // クロックの立ち上げ
    this->clock(1);
    this->top->eval();

    // 立ち上がったクロックに反応して信号を操作
    func(this->top);
    this->eval_dump();

    this->clock(0);
    this->eval_dump();
  }

};

#endif // guard
