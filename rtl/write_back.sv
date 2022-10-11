`default_nettype none
`include "./riscv_instr.sv"
`include "./common.sv"

module write_back (
    input logic [31:0] pc_plus_4,
    input logic [31:0] pc_branch,
    input logic is_jump_instr,
    output logic [31:0] pc_next,

    input common::instr_field field,
    input logic [31:0] read_data,
    input logic [31:0] wb_mask,
    input logic [31:0] alu_result,
    output logic [31:0] reg_next,
    output logic wb_en,
    input logic [31:0] csr_data,
    output logic [31:0] csr_next,
    output logic csr_wb_en
);
  import common::*;

  always_comb begin
    // update pc
    if (is_jump_instr && alu_result[0]) pc_next = pc_branch;
    else pc_next = pc_plus_4;

    // write back
    if (field.rd != 5'h0) begin
      case (field.opcode)
        // R-Type, I-Type, lui
        7'b0110011, 7'b0010011, 7'b0110111: begin
          reg_next = alu_result;
          wb_en = 1'b1;
          csr_wb_en = 1'b0;
          csr_next = 32'h0;
        end
        // load instruction
        7'b0000011: begin
          reg_next = read_data & wb_mask;
          wb_en = 1'b1;
          csr_wb_en = 1'b0;
          csr_next = 32'h0;
        end
        // JAL, JALR
        7'b1100111, 7'b1101111: begin
          reg_next = pc_plus_4;
          wb_en = 1'b1;
          csr_wb_en = 1'b0;
          csr_next = 32'h0;
        end
        // zicsr
        7'b1110011: begin
          // if (instruction) is csr_instrs -> wb_en = 1
          if (field.funct3[1:0] >= 2'd1) wb_en = 1'b1;
          else wb_en = 1'b0;
          csr_wb_en = wb_en;
          reg_next  = csr_data;
          csr_next  = alu_result;
        end
        // other
        default: begin
          reg_next = 32'hdeadbeef;
          wb_en = 1'b0;
          csr_wb_en = 1'b0;
          csr_next = 32'h0;
        end
      endcase
    end else begin
      reg_next = 32'hdeadbeef;
      wb_en = 1'b0;
      csr_wb_en = 1'b0;
      csr_next = 32'h0;
    end
    $display("wb_en :%h", wb_en);
    $display("csr_wb_en :%h", csr_wb_en);
    $display("csr_next :%h", csr_next);
    $display("alu_result :%h", alu_result);
  end
endmodule

