`default_nettype none
`include "./riscv_instr.sv"
`include "./common.sv"

module memory_access (
    input logic [3:0] access_type,
    output logic [1:0] write_wstrb,  // write $(wstrb+1) bytes
    output logic write_enable,
    output logic read_enable,
    output logic [31:0] wb_mask
);
  import common::*;

  always_comb begin
    case (access_type)
      SB, SH, SW: begin
        write_enable = 1'b1;
        read_enable  = 1'b0;
      end
      LB, LBU, LH, LHU, LW: begin
        write_enable = 1'b0;
        read_enable  = 1'b1;
      end
      default: begin
        write_enable = 1'b0;
        read_enable  = 1'b0;
      end
    endcase

    case (access_type)
      SB, LB, LBU: begin
        write_wstrb = 2'h0;
        wb_mask = 32'h000000FF;
      end
      SH, LH, LHU: begin
        write_wstrb = 2'h1;
        wb_mask = 32'h0000FFFF;
      end
      SW, LW: begin
        write_wstrb = 2'h3;
        wb_mask = 32'hFFFFFFFF;
      end
      default: begin
        write_wstrb = 2'h0;
        wb_mask = 32'hFFFFFFFF;
      end
    endcase
  end

endmodule

