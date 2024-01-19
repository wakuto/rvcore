`default_nettype none
`include "parameters.sv"
`include "common.sv"

module hazard(
    input  wire          is_speculative_if,
    input  wire          instr_valid_if     [0:DISPATCH_WIDTH-1],
    input  common::branch_type_t branch_type_if     [0:DISPATCH_WIDTH-1],
    input  wire          freelist_empty,
    input  wire          rob_full,
    input  wire          issue_queue_full,
    output logic         stall_if,
    output logic         stall_id,
    output logic         stall_rn,
    output logic         stall_disp,
    output logic         stall_issue
);
    import parameters::*;
    import common::*;
    
    logic branch_instr_when_speculative;
    logic reg_relatively_branch_instr;

    always_comb begin
        branch_instr_when_speculative = is_speculative_if && 
            ((instr_valid_if[0] && branch_type_if[0] == COND_BR) ||
             (instr_valid_if[1] && branch_type_if[1] == COND_BR));
        reg_relatively_branch_instr = (instr_valid_if[0] && branch_type_if[0] == REG_JMP) ||
                                      (instr_valid_if[1] && branch_type_if[1] == REG_JMP);

        if (branch_instr_when_speculative || reg_relatively_branch_instr) begin
            stall_if = 1;
            stall_id = 0;
            stall_rn = 0;
            stall_disp = 0;
            stall_issue = 0;
        end else if (issue_queue_full) begin
            stall_if = 0;
            stall_id = 1;
            stall_rn = 1;
            stall_disp = 1;
            stall_issue = 1;
        end else if (rob_full) begin
            stall_if = 0;
            stall_id = 1;
            stall_rn = 1;
            stall_disp = 1;
            stall_issue = 0;
        end else if (freelist_empty) begin
            stall_if = 0;
            stall_id = 1;
            stall_rn = 1;
            stall_disp = 0;
            stall_issue = 0;
        end else begin
            stall_if = 0;
            stall_id = 0;
            stall_rn = 0;
            stall_disp = 0;
            stall_issue = 0;
        end
    end
endmodule
`default_nettype wire
