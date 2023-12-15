`default_nettype none

`include "parameters.sv"

module freelist(
  input clk, rst,
  freelistIf.freelist freelist_if
);
  import parameters::*;

  // this contains free phys reg number
  logic [PHYS_REGS-1:0][PHYS_REGS_ADDR_WIDTH-1:0] freelist_queue;

  logic [PHYS_REGS_ADDR_WIDTH-1:0] head;
  logic [PHYS_REGS_ADDR_WIDTH-1:0] tail;

  logic [PHYS_REGS_ADDR_WIDTH:0] num_free;

  logic [DISPATCH_WIDTH:0] num_pop;
  logic [DISPATCH_WIDTH:0] num_push;

  always_comb begin
    num_push = 0;
    num_pop = 0;
    for(int i = 0; i < DISPATCH_WIDTH; i++) begin
      num_push += (DISPATCH_WIDTH+1)'(freelist_if.push_en[i]);
      num_pop += (DISPATCH_WIDTH+1)'(freelist_if.pop_en[i]);
    end

    freelist_if.num_free = num_free;
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      // initial state is all free
      tail <= 1;
      head <= PHYS_REGS_ADDR_WIDTH'(PHYS_REGS-1);
      for (int i = 0; i < PHYS_REGS; i++) begin
        freelist_queue[i] <= PHYS_REGS_ADDR_WIDTH'(i);
      end
      num_free <= (PHYS_REGS_ADDR_WIDTH+1)'(PHYS_REGS)-1;
    end else begin
      if (|freelist_if.pop_en && (PHYS_REGS_ADDR_WIDTH+1)'(num_pop) <= num_free) begin
        case(freelist_if.pop_en) 
          2'b01: freelist_if.pop_reg[0] <= freelist_queue[tail+0];
          2'b10: freelist_if.pop_reg[1] <= freelist_queue[tail+0];
          2'b11: begin
            freelist_if.pop_reg[0] <= freelist_queue[tail+0];
            freelist_if.pop_reg[1] <= freelist_queue[tail+1];
          end
          /*
          DISPATCH_WIDTH'b100: freelist_if.pop_reg[2] <= freelist_queue[tail+0];
          DISPATCH_WIDTH'b101: begin
            freelist_if.pop_reg[0] <= freelist_queue[tail+0];
            freelist_if.pop_reg[2] <= freelist_queue[tail+1];
          end
          DISPATCH_WIDTH'b110: begin
            freelist_if.pop_reg[1] <= freelist_queue[tail+0];
            freelist_if.pop_reg[2] <= freelist_queue[tail+1];
          end
          DISPATCH_WIDTH'b111: begin
            freelist_if.pop_reg[0] <= freelist_queue[tail+0];
            freelist_if.pop_reg[1] <= freelist_queue[tail+1];
            freelist_if.pop_reg[2] <= freelist_queue[tail+2];
          end
          */
          default :;
        endcase
        tail <= tail + PHYS_REGS_ADDR_WIDTH'(num_pop);
      end
      if (|freelist_if.push_en && (PHYS_REGS_ADDR_WIDTH+1)'(num_push) + num_free <= (PHYS_REGS_ADDR_WIDTH+1)'(PHYS_REGS)) begin
        case(freelist_if.push_en)
          'b01 : freelist_queue[head+0] <= freelist_if.push_reg[0];
          'b10 : freelist_queue[head+0] <= freelist_if.push_reg[1];
          'b11 : begin
            freelist_queue[head+0] <= freelist_if.push_reg[0];
            freelist_queue[head+1] <= freelist_if.push_reg[1];
          end
          /*
          DISPATCH_WIDTH'b100: freelist_queue[head+0] <= freelist_if.push_reg[2];
          DISPATCH_WIDTH'b101: begin
            freelist_queue[head+0] <= freelist_if.push_reg[0];
            freelist_queue[head+1] <= freelist_if.push_reg[2];
          end
          DISPATCH_WIDTH'b110: begin
            freelist_queue[head+0] <= freelist_if.push_reg[1];
            freelist_queue[head+1] <= freelist_if.push_reg[2];
          end
          DISPATCH_WIDTH'b111: begin
            freelist_queue[head+0] <= freelist_if.push_reg[0];
            freelist_queue[head+1] <= freelist_if.push_reg[1];
            freelist_queue[head+2] <= freelist_if.push_reg[2];
          end
          */
          default :;
        endcase
        head <= head + PHYS_REGS_ADDR_WIDTH'(num_push);
      end
      if (num_push != 0 && num_pop != 0) begin
        if (num_push > num_pop) begin
          num_free <= num_free + ((PHYS_REGS_ADDR_WIDTH+1)'(num_push) - (PHYS_REGS_ADDR_WIDTH+1)'(num_pop));
        end else begin
          num_free <= num_free - ((PHYS_REGS_ADDR_WIDTH+1)'(num_pop) - (PHYS_REGS_ADDR_WIDTH+1)'(num_push));
        end
      end else if (num_push != 0) begin
        num_free <= num_free + (PHYS_REGS_ADDR_WIDTH+1)'(num_push);
      end else if (num_pop != 0) begin
        num_free <= num_free - (PHYS_REGS_ADDR_WIDTH+1)'(num_pop);
      end
    end
  end

endmodule


`default_nettype wire

