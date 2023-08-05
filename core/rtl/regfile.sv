`default_nettype none
module regfile(
    input wire logic clock,
    input wire logic reset,
    input wire logic [4:0] addr_rs1,
    input wire logic [4:0] addr_rs2,
    input wire logic [4:0] addr_rd,
    input wire logic [31:0] rd_data,
    input wire logic wen,
    output     logic [31:0] rs1,
    output     logic [31:0] rs2,
    output     logic [31:0] debug_reg [0:31]
);
    logic [31:0] regfile[0:31];
    
    always_comb begin
        for(int i = 0; i < 32; i++) begin
            debug_reg[i] = regfile[i];
        end

        rs1 = regfile[addr_rs1];
        rs2 = regfile[addr_rs2];
    end
    
    always_ff @(posedge clock) begin
        if (reset) begin
            int i;
            for (i = 0; i < 32; i++) begin
                regfile[i] <= 32'd0;
            end
        end
        else begin
            if (wen) begin
                regfile[addr_rd] <= rd_data;
            end
        end
    end
endmodule

`default_nettype wire