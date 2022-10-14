`default_nettype none
`include "./riscv_instr.sv"
`include "./common.sv"

module write_back (
    input wire logic [31:0] pc_plus_4,
    input wire logic [31:0] pc_branch,
    input wire logic is_jump_instr,
    output logic [31:0] pc_next,

    input common::wb_sel_t wb_sel,
    input wire logic [31:0] read_data,
    input wire logic [31:0] wb_mask,
    input wire logic [31:0] alu_result,
    output logic [31:0] reg_next,
    output logic wb_en,
    input wire logic [31:0] csr_data,
    output logic [31:0] csr_next,
    output logic csr_wb_en
);
  import common::*;

  always_comb begin
    // update pc
    if (is_jump_instr && alu_result[0]) pc_next = pc_branch;
    else pc_next = pc_plus_4;

    // write back
    case (wb_sel)
      RI_TYPE_LUI: begin
        reg_next = alu_result;
        wb_en = 1'b1;
        csr_wb_en = 1'b0;
        csr_next = 32'h0;
      end
      LOAD: begin
        reg_next = read_data & wb_mask;
        wb_en = 1'b1;
        csr_wb_en = 1'b0;
        csr_next = 32'h0;
      end
      JUMP: begin
        reg_next = pc_plus_4;
        wb_en = 1'b1;
        csr_wb_en = 1'b0;
        csr_next = 32'h0;
      end
      ZICSR: begin
        wb_en = 1'b1;
        csr_wb_en = 1'b1;
        reg_next = csr_data;
        csr_next = alu_result;
      end
      default: begin
        reg_next = 32'hdeadbeef;
        wb_en = 1'b0;
        csr_wb_en = 1'b0;
        csr_next = 32'h0;
      end
    endcase
    $display("wb_en :%h", wb_en);
    $display("csr_wb_en :%h", csr_wb_en);
    $display("csr_next :%h", csr_next);
    $display("alu_result :%h", alu_result);
  end
endmodule

`default_nettype wire
