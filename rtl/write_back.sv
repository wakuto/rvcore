`default_nettype none
`include "./riscv_instr.sv"
`include "./common.sv"

module write_back (

    input logic [1:0] pc_sel,
    input logic [31:0] pc_prev,
    input logic [31:0] reg_data [0:31],
    input logic [6:0] opcode,
    input logic [4:0]  rs1,
    input logic [11:0] imm_i,
    input logic [12:0] imm_b,
    input logic [20:0] imm_j,

    input logic [31:0] read_data,
    input logic [31:0] wb_mask,

    input logic [31:0] alu_result,

    output logic [31:0] reg_out
);

  always_ff @(posedge clock or posedge reset) begin
    if (reset) begin
      reg_pc <= 32'h0;
    end else begin
      case (pc_sel)
        BRANCH: reg_pc <= pc_prev + 32'(signed'(imm_b));
        JAL: reg_pc <= reg_data[rs1] + 32'(signed'(imm_i));
        JALR: reg_pc <= pc_prev + 32'(signed'(imm_j));
        PCNEXT: reg_pc <= pc_prev + 32'h4;
      endcase
      // write back
      if(rd != 5'h0) begin
        case (opcode)
          // R-Type, I-Type, lui
          7'b0110011, 7'b0010011, 7'b0110111: reg_data[rd] <= alu_result;
          // load instruction
          7'b0000011: regfile[rd] <= read_data & wb_mask;
          // JAL, JALR
          7'b1100111, 7'b1101111: reg_data[rd] <= pc_prev + 32'h4;
          // other
          default: ;
        endcase
      end
    end
  end
endmodule

