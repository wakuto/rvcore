`default_nettype none
`include "./riscv_instr.sv"
`include "./common.sv"

module cpu(
  input  logic clock,
  input  logic reset,
  // instruction data
  output logic [31:0] pc,
  input  logic [31:0] instruction,
  // memory data
  output logic [31:0] address,
  input  logic [31:0] read_data,
  input  logic read_enable,
  output logic [31:0] write_data,
  output logic write_enable,
  output logic debug_ebreak,
  output logic [31:0] debug_reg [0:31]
);
  // regfile
  logic [31:0] reg_pc;
  logic [31:0] regfile [0:31];

  // data_output
  logic [31:0] data_out;
  logic data_out_enable;
  assign write_data = data_out;
  assign write_enable = data_out_enable;

  // instruction fields
  logic [6:0] opcode;
  logic [4:0] rd;

  logic [31:0] op1;
  logic [31:0] op2;
  logic [31:0] alu_out;

  // decoded data
  common::alu_cmd operation_type;
  common::mem_access_type access_type;

  // <= だとwarning出るけどなんで？
  initial begin
    reg_pc = 32'h0;
    address = 32'h0;
    data_out = 32'h0;
    data_out_enable = 1'b0;
    for(int i = 0; i < 32; i++)
      regfile[i] = 32'h0;
  end

  decoder decoder(
    .clock,
    .reset,
    .instruction,
    .alu_ops(operation_type),
    .op1,
    .op2,
    .regfile,
    .pc(reg_pc)
  );

  execute execute(
    .op1,
    .op2,
    .alu_ops(operation_type),
    .alu_out
  );


  assign opcode = instruction[6:0];
  assign rd = instruction[11:7];

  always_comb begin
    // debug output
    debug_ebreak = instruction == riscv_instr::EBREAK;
    for(int i = 0; i < 32; i++)
      debug_reg[i] = regfile[i];
    pc = reg_pc;
  end

  always_ff @(posedge clock or posedge reset) begin
    if(reset) begin
      reg_pc <= 32'h0;
      address <= 32'h0;
    end
    else begin
      reg_pc <= reg_pc + 32'h4;
      // write back
      case(opcode)
        // R-Type, I-Type(not load instruction)
        7'b0110011, 7'b0010011: begin
          regfile[rd] <= alu_out;
        end
        // load instruction
        //7'b0000011: regfile[rd] = 
        // other
        default:;
      endcase
    end
  end
endmodule
