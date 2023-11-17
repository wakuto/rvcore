`default_nettype none

`include "parameters.sv"
`include "common.sv"

module op2ValidLogic(
  input  wire  [$bits(common::op_type_t)-1:0]     op2_type  [DISPATCH_WIDTH-1:0],
  input  wire  [PHYS_REGS_ADDR_WIDTH-1:0] rs2       [DISPATCH_WIDTH-1:0],
  input  wire                             rs2_valid [DISPATCH_WIDTH-1:0],
  input  wire  [31:0]                     imm       [DISPATCH_WIDTH-1:0],
  output logic [31:0]                     op2       [DISPATCH_WIDTH-1:0],
  output logic                            op2_valid [DISPATCH_WIDTH-1:0]
);
  import parameters::*;

  always_comb begin
    for(int bank = 0; bank < DISPATCH_WIDTH; bank++) begin
      case (op2_type[bank])
        common::REG: begin
          op2[bank]       = 32'(rs2[bank]);
          op2_valid[bank] = rs2_valid[bank];
        end
        common::IMM: begin
          op2[bank]       = imm[bank];
          op2_valid[bank] = 1'b1;
        end
        default: begin
          op2[bank]       = 32'h0;
          op2_valid[bank] = 1'b0;
        end
      endcase
    end
  end
endmodule
`default_nettype wire

