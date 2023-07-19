`default_nettype none
`include "./riscv_instr.sv"
`include "./common.sv"

module memory_access (
    input wire logic [3:0] access_type,
    output logic [3:0] strb,
    output logic write_enable,
    input wire logic write_ready,
    output logic read_enable,
    input wire logic read_valid,
    output logic [31:0] wb_mask,
    output logic [4:0] wb_msb_bit,
    output logic mem_stall,
    output logic load_access  // load access fault
);
  import common::*;

  always_comb begin
    load_access = 1'b0;
    case (access_type)
      SB, SH, SW: begin
        write_enable = 1'b1;
        read_enable  = 1'b0;
        mem_stall = !write_ready;
      end
      LB, LBU, LH, LHU, LW: begin
        write_enable = 1'b0;
        read_enable  = 1'b1;
        mem_stall = !read_valid;
      end
      default: begin
        write_enable = 1'b0;
        read_enable  = 1'b0;
        mem_stall = 1'b0;
      end
    endcase

    case (access_type)
      SB, LB, LBU: begin
        strb = 4'b0001;
        wb_mask = 32'h000000FF;
        wb_msb_bit = 5'd7;
      end
      SH, LH, LHU: begin
        strb = 4'b0011;
        wb_mask = 32'h0000FFFF;
        wb_msb_bit = 5'd15;
      end
      SW, LW: begin
        strb = 4'b1111;
        wb_mask = 32'hFFFFFFFF;
        wb_msb_bit = 5'd31;
      end
      default: begin
        strb = 4'b1111;
        wb_mask = 32'hFFFFFFFF;
        wb_msb_bit = 5'd31;
      end
    endcase
    if (access_type == LBU | access_type == LHU) begin
      // zero extend
      wb_msb_bit = 5'd0;
    end
  end

endmodule

`default_nettype wire
