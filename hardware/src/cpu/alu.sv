import arch_defs_pkg::*;

module alu (
    input logic clk,
    input logic reset,
    input logic [DATA_WIDTH-1:0] in_one,
    input logic [DATA_WIDTH-1:0] in_two,
    input logic in_carry,
    input logic [3:0] alu_op,
    output logic [DATA_WIDTH-1:0] latched_result,
    output logic zero_flag,
    output logic carry_flag,
    output logic negative_flag
);
    
    
    logic [DATA_WIDTH-1:0] comb_result;
    logic [DATA_WIDTH-1:0] comb_carry;

    always_comb begin
        
        case (alu_op)
        
            //ARITHMETIC
            ALU_ADD: begin
                logic [DATA_WIDTH:0] sum = {1'b0, in_one} + {1'b0, in_two};
                comb_result = sum[DATA_WIDTH-1:0];
                comb_carry  = sum[DATA_WIDTH];
            end
            ALU_ADC: begin
                logic [DATA_WIDTH:0] sum = {1'b0, in_one} + {1'b0, in_two} + in_carry;
                comb_result = sum[DATA_WIDTH-1:0];
                comb_carry  = sum[DATA_WIDTH];
            end
            ALU_SUB: begin
                logic [DATA_WIDTH:0] sum = {1'b0, in_one} + {1'b0, ~in_two} + 1'b1;
                comb_result = sum[DATA_WIDTH-1:0];
                comb_carry  = sum[DATA_WIDTH]; // Carry=1 means No Borrow
            end
            ALU_SBC: begin
                logic [DATA_WIDTH:0] sum = {1'b0, in_one} + {1'b0, ~in_two} + in_carry;
                comb_result = sum[DATA_WIDTH-1:0];
                comb_carry  = sum[DATA_WIDTH]; // Carry=1 means No Borrow
            end
            ALU_INR: begin
                logic [DATA_WIDTH:0] sum = {1'b0, in_one} + 1'b1;
                comb_result = sum[DATA_WIDTH-1:0];
                comb_carry  = sum[DATA_WIDTH]; // Natural carry out
            end
            ALU_DCR: begin
                logic [DATA_WIDTH:0] sum = {1'b0, in_one} + 8'hFE + 1'b1;
                comb_result = sum[DATA_WIDTH-1:0];
                comb_carry  = sum[DATA_WIDTH];
            end
            
            // LOGIC (force carry = 0)
            ALU_AND: begin
                comb_result = in_one & in_two;
                comb_carry  = 1'b0;
            end
            ALU_OR: begin
                comb_result = in_one | in_two;
                comb_carry  = 1'b0;
            end
            ALU_XOR: begin
                comb_result = in_one ^ in_two;
                comb_carry  = 1'b0;
            end
            ALU_INV: begin
                comb_result = ~in_one;
                comb_carry  = 1'b0;
            end

            // ROTATES
            ALU_ROL: begin
                comb_result = {in_one[DATA_WIDTH-2:0], in_carry};
                comb_carry  = in_one[DATA_WIDTH-1];
            end
            ALU_ROR: begin
                comb_result = {in_carry, in_one[DATA_WIDTH-1:1]};
                comb_carry  = in_one[0];
            end

            ALU_UNDEFINED: begin
                comb_result = '0;
                comb_carry  = 1'b0;  
            end

            default: begin
                comb_result = 'x;
                comb_carry = 1'bx;
            end
        endcase
    end



    // Carry Flag = 1 means No Borrow occurred (unsigned A >= B).
    // Carry Flag = 0 means a Borrow occurred (unsigned A < B).
    always_ff @(posedge clk) begin
        if (reset) begin
            carry_flag <= 1'b0; // no carry, but previous borrow
            zero_flag <= 1'b1; // zero == true
            negative_flag <= 1'b0; // not negative
            latched_result <= { DATA_WIDTH{1'b0} };
        end else begin
            latched_result <= comb_result;
            carry_flag <= comb_carry;
            zero_flag <= (comb_result == { DATA_WIDTH{1'b0} }); // result == 0
            negative_flag <= comb_result[DATA_WIDTH-1]; // MSBit (0 = non-negative, 1 = negative)
        end
    end

endmodule