`default_nettype none
`include "parameters.sv"

module regfile #(
    parameter NUM_REGS = 32,
    parameter REG_WIDTH = 32
    )(
    input  wire  clk,
    input  wire  rst,
    input  wire  [NUM_REGS_WIDTH-1:0] addr_rs1 [0:DISPATCH_WIDTH-1],
    input  wire  [NUM_REGS_WIDTH-1:0] addr_rs2 [0:DISPATCH_WIDTH-1],
    input  wire  [NUM_REGS_WIDTH-1:0] addr_rd  [0:DISPATCH_WIDTH-1],
    input  wire  [REG_WIDTH-1:0]      rd_data  [0:DISPATCH_WIDTH-1],
    input  wire                       rd_wen   [0:DISPATCH_WIDTH-1],

    output logic [REG_WIDTH-1:0]      rs1_data [0:DISPATCH_WIDTH-1],
    output logic [REG_WIDTH-1:0]      rs2_data [0:DISPATCH_WIDTH-1]
);
    parameter NUM_REGS_WIDTH = $clog2(NUM_REGS);
    logic [NUM_REGS_WIDTH-1:0] regfile[0:REG_WIDTH-1];
    
    always_comb begin
        for (int i = 0; i < DISPATCH_WIDTH; i++) begin
            rs1[i] = regfile[addr_rs1[i]];
            rs2[i] = regfile[addr_rs2[i]];
        end
    end
    
    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < NUM_REGS; i++) begin
                regfile[i] <= REG_WIDTH'd0;
            end
        end
        else begin
            for (int i = 0; i < DISPATCH_WIDTH; i++) begin
                if (rd_wen[i]) begin
                    regfile[addr_rd[i]] <= rd_data[i];
                end
            end
        end
    end
endmodule

`default_nettype wire
