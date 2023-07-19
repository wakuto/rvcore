`default_nettype none
`include "./riscv_instr.sv"
`include "./common.sv"

module write_back (
    input wire logic [31:0] pc,
    input wire logic [31:0] pc_plus_4,
    input wire logic [31:0] pc_branch,
    input wire logic mem_stall,
    input wire logic instr_valid,
    input wire logic is_jump_instr,
    input common::pc_sel_t pc_sel,
    output logic [31:0] pc_next,

    input common::wb_sel_t wb_sel,
    input wire logic [31:0] read_data,
    input wire logic read_valid,
    input wire logic [31:0] wb_mask,
    input wire logic [31:0] alu_result,
    output logic [31:0] reg_next,
    output logic wb_en,
    input wire logic [31:0] csr_data
);
  import common::*;
  logic wb_en_without_stall;

  always_comb begin
    if (!instr_valid) begin
      pc_next = pc;
    end else begin
      // update pc
      case(pc_sel)
        PC_BRANCH: begin
          if(alu_result[0]) pc_next = pc_branch;
          else pc_next = pc_plus_4;
        end
        PC_NEXT: begin
          pc_next = mem_stall ? pc : pc_plus_4;
        end
        default: pc_next = 32'h0;
      endcase
    end

    // write back
    case (wb_sel)
      RI_TYPE_LUI: begin
        reg_next = alu_result;
        wb_en_without_stall = 1'b1;
      end
      LOAD: begin
        reg_next = read_data & wb_mask;
        wb_en_without_stall = 1'b1;
      end
      JUMP: begin
        reg_next = pc_plus_4;
        wb_en_without_stall = 1'b1;
      end
      ZICSR: begin
        wb_en_without_stall = 1'b1;
        reg_next = csr_data;
      end
      WB_MRET: begin
        wb_en_without_stall = 1'b0;
        reg_next = 32'h0;
      end
      default: begin
        reg_next = 32'hdeadbeef;
        wb_en_without_stall = 1'b0;
      end
    endcase
    wb_en = wb_en_without_stall & !mem_stall;
  end
endmodule

`default_nettype wire
