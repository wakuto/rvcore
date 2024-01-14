`default_nettype none
`include "common.sv"
`include "parameters.sv"
`include "riscv_instr.sv"

module branchPredictor (
  input  wire         clk,
  input  wire         rst,

  input  wire  [31:0] pc                  [DISPATCH_WIDTH-1:0],
  input  wire  [31:0] instr               [DISPATCH_WIDTH-1:0],
  input  wire         fetch_valid,                               // cache から命令を取得できたか
  output logic        instr_valid         [DISPATCH_WIDTH-1:0],  // 分岐命令によって無効化されないか
  output logic        is_branch_instr     [DISPATCH_WIDTH-1:0],  // 分岐命令か？

  output logic [31:0] next_pc,
  output logic        is_speculative,
  
  input  wire         branch_result_valid,
  input  wire         branch_correct
);

  import parameters::*;
  import riscv_instr::*;
  
  typedef enum logic [1:0] {
    STRONG_NOT_TAKEN,
    WEAK_NOT_TAKEN,
    WEAK_TAKEN,
    STRONG_TAKEN
  } branch_state_t;
  
  typedef enum logic [1:0] {
    I_TYPE,
    B_TYPE,
    J_TYPE,
    NOT_BRANCH
  } instr_type_t;
  
  branch_state_t branch_state;

  instr_type_t instr_type           [DISPATCH_WIDTH-1:0];
  instr_type_t valid_instr_type;
  logic [31:0] pred_branch_target_i [DISPATCH_WIDTH-1:0];
  logic [31:0] pred_branch_target_b [DISPATCH_WIDTH-1:0];
  // logic [31:0] pred_branch_target_j [DISPATCH_WIDTH-1:0];
  logic [31:0] valid_pred_branch_target_i;
  logic [31:0] valid_pred_branch_target_b;
  // logic [31:0] valid_pred_branch_target_j;
  logic [31:0] imm_b                [DISPATCH_WIDTH-1:0];
  logic [31:0] imm_i                [DISPATCH_WIDTH-1:0];
  // logic [31:0] imm_j                [DISPATCH_WIDTH-1:0];
  
  logic        taken;
  logic [31:0] target;
  
  always_ff @(posedge clk) begin
    if (rst) begin
      is_speculative <= 0;
      branch_state <= WEAK_NOT_TAKEN;
    end else begin
      // is_speculative & is_branch_instr の場合、外部でストールする
      // 分岐命令が実行されるのは、!is_speculative & is_branch_instr の場合
      if (branch_result_valid) begin
        is_speculative <= 0;
      end else if (is_branch_instr[0] | is_branch_instr[1]) begin
        is_speculative <= 1;
      end

      // 2bit 飽和カウンター による予測
      case(branch_state)
        STRONG_NOT_TAKEN: begin
          if (branch_result_valid && branch_correct) begin
            branch_state <= WEAK_NOT_TAKEN;
          end
        end
        WEAK_NOT_TAKEN: begin
          if (branch_result_valid && branch_correct) begin
            branch_state <= WEAK_TAKEN;
          end else if (branch_result_valid && !branch_correct) begin
            branch_state <= STRONG_NOT_TAKEN;
          end
        end
        WEAK_TAKEN: begin
          if (branch_result_valid && branch_correct) begin
            branch_state <= STRONG_TAKEN;
          end else if (branch_result_valid && !branch_correct) begin
            branch_state <= WEAK_NOT_TAKEN;
          end
        end
        STRONG_TAKEN: begin
          if (branch_result_valid && !branch_correct) begin
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
        BEQ, BGE, BGEU, BLT, BLTU, BNE: instr_type[i] = B_TYPE;
        // i-type jump
        JAL: instr_type[i] = I_TYPE;
        // j-type jump
        JALR: instr_type[i] = J_TYPE;
        default: instr_type[i] = NOT_BRANCH;
      endcase
      is_branch_instr[i] = (instr_type[i] != NOT_BRANCH);
    end
    
    
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
      B_TYPE: begin
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
      I_TYPE: begin // 無条件分岐
        taken = 1;
        target = valid_pred_branch_target_i;
      end
      default: begin
        taken = 0;
        target = 0;
      end
    endcase
      
    // next_pc_generator
    if (taken) begin
      next_pc = target;
    end else begin
      if (instr_type[0] == B_TYPE && instr_type[1] == B_TYPE) begin
        next_pc = pc[1];
      end else begin
        next_pc = pc[1] + 4;
      end
    end
    
    // 分岐命令によって無効化されないか
    instr_valid[0] = 1 & fetch_valid;
    instr_valid[1] = !(
      (instr_type[0] == B_TYPE && ((instr_type[1] == B_TYPE) || taken))
    );
  end
endmodule
`default_nettype wire

