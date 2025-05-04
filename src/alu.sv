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
    
    // Local variables for intermediate calculation within this block
    logic [DATA_WIDTH:0]    comb_arith_result_i; // 9 bits to accommodate carry
    logic [DATA_WIDTH-1:0]  comb_logic_result_i;
    logic                   comb_carry_out_i;
    logic [DATA_WIDTH-1:0]  comb_result_final_i;
    logic [2:0]             flags_i;

    always_comb begin
        
        // default all values to prevent latch inference
        comb_arith_result_i = { (DATA_WIDTH + 1) {1'b0} };
        comb_logic_result_i =  { DATA_WIDTH {1'b0} };
        
        comb_result_final_i = { DATA_WIDTH {1'b0} };
        comb_carry_out_i = 1'b0;
        
        case (alu_op)

            // ARITHMETIC 
            ALU_ADD: comb_arith_result_i = {1'b0, in_one} + {1'b0, in_two};
            ALU_ADC: comb_arith_result_i = {1'b0, in_one} + {1'b0, in_two} + {{DATA_WIDTH{1'b0}}, in_carry}; 
            
            ALU_SUB: comb_arith_result_i = {1'b0, in_one} + {1'b0, ~in_two} + {{DATA_WIDTH{1'b0}}, 1'b1};
            ALU_SBC: comb_arith_result_i = {1'b0, in_one} + {1'b0, ~in_two} + in_carry; 
            
            ALU_INR: comb_arith_result_i = {1'b0, in_one} + {1'b0, 8'd1};
            ALU_DCR: comb_arith_result_i = {1'b0, in_one} + {1'b0, ~8'd1} + {{DATA_WIDTH{1'b0}}, 1'b1};

            // LOGIC
            ALU_AND: comb_logic_result_i = in_one & in_two;
            ALU_OR:  comb_logic_result_i = in_one | in_two;
            ALU_XOR: comb_logic_result_i = in_one ^ in_two;

            // MISC
            ALU_INV: comb_logic_result_i = ~in_one; 
            
            default: comb_logic_result_i = 1'bx; 
        
        endcase
        
        case (alu_op)
            ALU_ADD, ALU_SUB, ALU_INR, ALU_DCR,
            ALU_ADC, ALU_SBC: 
            begin
                comb_carry_out_i = comb_arith_result_i[DATA_WIDTH]; // Check for carry out
                comb_result_final_i = comb_arith_result_i[DATA_WIDTH-1:0];  
            end
            default: begin
                comb_carry_out_i = 1'b0;
                comb_result_final_i = comb_logic_result_i; 
            end
        endcase

    end 
    
    // Carry Flag = 1 means No Borrow occurred (unsigned A >= B).
    // Carry Flag = 0 means a Borrow occurred (unsigned A < B).
    assign carry_flag = flags_i[0];
    assign zero_flag = flags_i[1];
    assign negative_flag = flags_i[2];
    
    always_ff @(posedge clk) begin
        if (reset) begin
            flags_i[0] <= 1'b0; // no carry, but previous borrow
            flags_i[1] <= 1'b1; // zero == true
            flags_i[2] <= 1'b0; // not negative
            latched_result <= { DATA_WIDTH{1'b0} };
        end else begin
            latched_result <= comb_result_final_i;
            flags_i[0] <= comb_carry_out_i;
            flags_i[1] <= (comb_result_final_i == { DATA_WIDTH{1'b0} }); // result == 0
            flags_i[2] <= comb_result_final_i[DATA_WIDTH-1]; // MSBit (0 = non-negative, 1 = negative)
        end
    end

endmodule