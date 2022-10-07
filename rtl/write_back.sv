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
  common::pc_sel_t pc_sel;

  always_comb begin
    case (field.opcode)
      7'b1100011: begin
        if (alu_result[0]) pc_sel = common::BRANCH;
        else pc_sel = common::PCNEXT;
      end
      7'b1100111: pc_sel = common::JAL;
      7'b1101111: pc_sel = common::JALR;
      default: pc_sel = common::PCNEXT;
    endcase
    case (pc_sel)
      common::BRANCH: pc_next = pc_prev + 32'(signed'(field.imm_b));
      common::JAL: pc_next = reg_data[field.rs1] + 32'(signed'(field.imm_i));
      common::JALR: pc_next = pc_prev + 32'(signed'(field.imm_j));
      common::PCNEXT: pc_next = pc_prev + 32'h4;
    endcase
    // write back
    if (field.rd != 5'h0) begin
      case (field.opcode)
        // R-Type, I-Type, lui
        7'b0110011, 7'b0010011, 7'b0110111: reg_next = alu_result;
        // load instruction
        7'b0000011: reg_next = read_data & wb_mask;
        // JAL, JALR
        7'b1100111, 7'b1101111: reg_next = pc_prev + 32'h4;
        // other
        default: reg_next = 32'h0;
      endcase
      case (field.opcode)
        7'b0110011, 7'b0010011, 7'b0110111, 7'b0000011, 7'b1100111, 7'b1101111: wb_en = 1'b1;
        default: wb_en = 1'b0;
      endcase
    end else begin
      reg_next = 32'h0;
      wb_en = 1'b0;
    end
  end
endmodule

