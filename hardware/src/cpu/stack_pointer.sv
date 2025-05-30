import arch_defs_pkg::*;

module stack_pointer (
    input logic                         clk,
    input logic                         reset,
    input logic                         increment,
    input logic                         decrement,
    input logic                         load_initial_address,
    input logic     [ADDR_WIDTH-1:0]    address_in,
    output logic    [ADDR_WIDTH-1:0]    address_out
);

    logic [ADDR_WIDTH-1:0] stack_pointer_reg_i;
    assign address_out = stack_pointer_reg_i;

    always_ff @(posedge clk) begin
        if (reset) begin // No need to wait for clock edge
            stack_pointer_reg_i <= {ADDR_WIDTH{1'b0}};
        end else if (load_initial_address) begin
            stack_pointer_reg_i <= address_in;
        end else if (increment) begin
            stack_pointer_reg_i <= stack_pointer_reg_i + 1;
        end else if (decrement) begin
            stack_pointer_reg_i <= stack_pointer_reg_i - 1;
        end
        
    end

endmodule
