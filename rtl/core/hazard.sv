`default_nettype none

module hazard(
    input wire freelist_empty,
    input wire rob_full,
    input wire issue_queue_full,
    output logic stall_if,
    output logic stall_rn,
    output logic stall_disp,
    output logic stall_issue
);

    always_comb begin
        if (issue_queue_full) begin
            stall_if = 1;
            stall_rn = 1;
            stall_disp = 1;
            stall_issue = 1;
        end else if (rob_full) begin
            stall_if = 1;
            stall_rn = 1;
            stall_disp = 1;
            stall_issue = 0;
        end else if (freelist_empty) begin
            stall_if = 1;
            stall_rn = 1;
            stall_disp = 0;
            stall_issue = 0;
        end else begin
            stall_if = 0;
            stall_rn = 0;
            stall_disp = 0;
            stall_issue = 0;
        end
    end
endmodule
`default_nettype wire
