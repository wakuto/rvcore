`default_nettype none
`include "./riscv_instr.sv"
`include "./common.sv"

module write_back (
    input  logic [31:0] pc_prev,
    output logic [31:0] pc_next,

    input logic [31:0] reg_data[0:31],
    input common::instr_field field,
    input logic [31:0] read_data,
    input logic [31:0] wb_mask,
    input logic [31:0] alu_result,
    output logic [31:0] reg_next,
    output logic wb_en
);
  import common::*;
  pc_sel_t pc_sel;

  always_comb begin
    case (field.opcode)
      7'b1100011: begin
        if (alu_result[0]) pc_sel = BRANCH;
        else pc_sel = PCNEXT;
      end
      7'b1100111: pc_sel = JAL;
      7'b1101111: pc_sel = JALR;
      default: pc_sel = PCNEXT;
    endcase
    case (pc_sel)
      BRANCH: pc_next = pc_prev + 32'(signed'(field.imm_b));
      JAL: pc_next = reg_data[field.rs1] + 32'(signed'(field.imm_i));
      JALR: pc_next = pc_prev + 32'(signed'(field.imm_j));
      PCNEXT: pc_next = pc_prev + 32'h4;
      default: pc_next = 32'h0;
    endcase
    // write back
    if (field.rd != 5'h0) begin
      case (field.opcode)
        // R-Type, I-Type, lui
        7'b0110011, 7'b0010011, 7'b0110111: begin
          reg_next = alu_result;
          wb_en = 1'b1;
        end
        // load instruction
        7'b0000011: begin
          reg_next = read_data & wb_mask;
          wb_en = 1'b1;
        end
        // JAL, JALR
        7'b1100111, 7'b1101111: begin
          reg_next = pc_prev + 32'h4;
          wb_en = 1'b1;
        end
        // other
        default: begin
          reg_next = 32'hdeadbeef;
          wb_en = 1'b0;
        end
      endcase
    end else begin
      reg_next = 32'hdeadbeef;
      wb_en = 1'b0;
    end
    $display("opcode_wb: %h", field.opcode);
    $display("reg_next_wb: %h", reg_next);
    $display("read_data: %h", read_data);
    $display("wb_mask  : %h", wb_mask);
  end
endmodule

