`default_nettype none
`include "common.sv"
`include "parameters.sv"
`include "riscv_instr.sv"

module branchPredictor (
  input  wire          clk,
  input  wire          rst,

  input  wire  [31:0]  pc                  [0:DISPATCH_WIDTH-1],
  input  wire  [31:0]  instr               [0:DISPATCH_WIDTH-1],
  input  wire          fetch_valid         [0:DISPATCH_WIDTH-1],  // cache から命令を取得できたか
  output logic         instr_valid         [0:DISPATCH_WIDTH-1],  // 分岐命令によって無効化されないか
  output common::branch_type_t branch_type [0:DISPATCH_WIDTH-1],  // 分岐命令の種類

  output logic [31:0]  next_pc,
  output logic         pred_taken          [0:DISPATCH_WIDTH-1],  // 分岐予測の方向
  output logic         is_speculative,
  
  input  wire          branch_result_valid [0:DISPATCH_WIDTH-1],
  input  wire          branch_taken      [0:DISPATCH_WIDTH-1]
);

  import parameters::*;
  import riscv_instr::*;
  import common::*;
  
  typedef enum logic [1:0] {
    STRONG_NOT_TAKEN,
    WEAK_NOT_TAKEN,
    WEAK_TAKEN,
    STRONG_TAKEN
  } branch_state_t;
  
  branch_state_t branch_state;

  common::branch_type_t instr_type          [0:DISPATCH_WIDTH-1];
  common::branch_type_t valid_instr_type;
  logic [31:0] pred_branch_target_i [0:DISPATCH_WIDTH-1];
  logic [31:0] pred_branch_target_b [0:DISPATCH_WIDTH-1];
  // logic [31:0] pred_branch_target_j [0:DISPATCH_WIDTH-1];
  logic [31:0] valid_pred_branch_target_i;
  logic [31:0] valid_pred_branch_target_b;
  // logic [31:0] valid_pred_branch_target_j;
  logic [31:0] imm_b                [0:DISPATCH_WIDTH-1];
  logic [31:0] imm_i                [0:DISPATCH_WIDTH-1];
  // logic [31:0] imm_j                [0:DISPATCH_WIDTH-1];
  
  logic        taken;
  logic [31:0] target;
  
  logic br_result_valid, br_taken, br_not_taken;
  
  always_comb begin
    br_result_valid = branch_result_valid[0] || branch_result_valid[1];
    br_taken = (branch_result_valid[0] && branch_taken[0]) ||
                 (branch_result_valid[1] && branch_taken[1]);
    br_not_taken = (branch_result_valid[0] && !branch_taken[0]) ||
              (branch_result_valid[1] && !branch_taken[1]);
  end
  
  always_ff @(posedge clk) begin
    if (rst) begin
      is_speculative <= 0;
      branch_state <= WEAK_NOT_TAKEN;
    end else begin
      // is_speculative & is_branch_instr の場合、外部でストールする
      // 分岐命令が実行されるのは、!is_speculative & is_branch_instr の場合
      if (br_result_valid) begin
        is_speculative <= 0;
      end else if ((fetch_valid[0] && branch_type[0] == COND_BR) || (fetch_valid[1] && branch_type[1] == COND_BR)) begin
        is_speculative <= 1;
      end

      // 2bit 飽和カウンター による予測
      case(branch_state)
        STRONG_NOT_TAKEN: begin
          if (br_taken) begin
            branch_state <= WEAK_NOT_TAKEN;
          end
        end
        WEAK_NOT_TAKEN: begin
          if (br_taken) begin
            branch_state <= WEAK_TAKEN;
          end else if (br_not_taken) begin
            branch_state <= STRONG_NOT_TAKEN;
          end
        end
        WEAK_TAKEN: begin
          if (br_taken) begin
            branch_state <= STRONG_TAKEN;
          end else if (br_not_taken) begin
            branch_state <= WEAK_NOT_TAKEN;
          end
        end
        STRONG_TAKEN: begin
          if (br_not_taken) begin
            branch_state <= WEAK_TAKEN;
          end
        end
        default: ;
      endcase
    end
  end
  
  
  always_comb begin
    // 分岐先アドレスの計算
    for(int i = 0; i < DISPATCH_WIDTH; i++) begin
      imm_i[i] = 32'(signed'(instr[i][31:20]));
      imm_b[i] = 32'(signed'({
        instr[i][31], instr[i][7], instr[i][30:25], instr[i][11:8], 1'b0
      }));
      // imm_j[i] = 32'(signed'({
      //   instr[i][31], instr[i][19:12], instr[i][20], instr[i][30:21], 1'b0
      // }));
      pred_branch_target_i[i] = pc[i] + imm_i[i];
      pred_branch_target_b[i] = pc[i] + imm_b[i];
      // pred_branch_target_j[i] = regfile[i] + imm_j[i]; <- 投機実行しない
    end

    // 命令タイプの識別
    for(int i = 0; i < DISPATCH_WIDTH; i++) begin
      casez(instr[i])
        // b-type jump
        BEQ, BGE, BGEU, BLT, BLTU, BNE: instr_type[i] = COND_BR;
        // i-type jump
        JAL: instr_type[i] = PC_JMP;
        // j-type jump
        JALR: instr_type[i] = REG_JMP;
        default: instr_type[i] = NOT_BRANCH;
      endcase
    end
    branch_type = instr_type;
    
    
    // 処理の対象となる分岐命令の選択
    if (instr_type[0] != NOT_BRANCH) begin
      valid_instr_type = instr_type[0];
      valid_pred_branch_target_b = pred_branch_target_b[0];
      valid_pred_branch_target_i = pred_branch_target_i[0];
      // valid_pred_branch_target_j = pred_branch_target_j[0];
    end else begin
      valid_instr_type = instr_type[1];
      valid_pred_branch_target_b = pred_branch_target_b[1];
      valid_pred_branch_target_i = pred_branch_target_i[1];
      // valid_pred_branch_target_j = pred_branch_target_j[1];
    end
    
    case(valid_instr_type)
      COND_BR: begin
        target = valid_pred_branch_target_b;
        case(branch_state)
          STRONG_NOT_TAKEN, WEAK_NOT_TAKEN:
            taken = 0;
          STRONG_TAKEN, WEAK_TAKEN:
            taken = 1;
          default: 
            taken = 0;
        endcase
      end
      PC_JMP: begin // 無条件分岐
        taken = 1;
        target = valid_pred_branch_target_i;
      end
      default: begin
        taken = 0;
        target = 0;
      end
    endcase
    
    // 分岐方向の書き込み
    if (instr_type[0] == COND_BR) begin
      pred_taken[0] = taken;
      pred_taken[1] = 0;
    end else if (instr_type[0] == NOT_BRANCH && instr_type[1] == COND_BR) begin
      pred_taken[0] = 0;
      pred_taken[1] = taken;
    end else begin
      pred_taken[0] = 0;
      pred_taken[1] = 0;
    end
    
    // 分岐命令によって無効化されないか
    // また、 is_speculative == 1 ならば、新たな分岐命令を受け付けない
    if (!is_speculative) begin
      instr_valid[0] = fetch_valid[0];
      instr_valid[1] = fetch_valid[0] && (instr_type[0] == NOT_BRANCH) && fetch_valid[1];
    end else begin
      instr_valid[0] = fetch_valid[0] && branch_type[0] != COND_BR;
      instr_valid[1] = fetch_valid[0] && (instr_type[0] == NOT_BRANCH) && fetch_valid[1] && branch_type[1] != COND_BR;
    end
      
    // next_pc_generator
    // 投機実行中でない場合、taken なら分岐
    //                     not taken なら 2つ目の分岐命令が出現するまで実行
    case({instr_valid[1], instr_valid[0]})
      2'b11 : begin
        if (taken) begin
          next_pc = target;
        end else begin
          next_pc = pc[1] + 4;
        end
      end
      2'b01 : begin
        if (taken) begin
          next_pc = target;
        end else begin
          next_pc = pc[1];
        end
      end
      default: next_pc = pc[0];
    endcase
  end
endmodule
`default_nettype wire

