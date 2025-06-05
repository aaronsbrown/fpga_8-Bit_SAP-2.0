import arch_defs_pkg::*;

module program_counter (
    input logic                         clk,
    input logic                         reset,
    input logic                         enable,
    input logic                         output_high_byte,
    input logic                         output_low_byte,
    input logic                         load_high_byte,
    input logic                         load_low_byte,
    input logic     [DATA_WIDTH-1:0]    counter_in,
    output logic    [ADDR_WIDTH-1:0]    counter_out,
    output logic    [DATA_WIDTH-1:0]    counter_byte_out
);
    
    always_ff @(posedge clk) begin
        if (reset) begin // No need to wait for clock edge
            counter_out <= {ADDR_WIDTH{1'b0}};
        end else if (load_high_byte) begin 
            counter_out[ADDR_WIDTH-1:DATA_WIDTH] <= counter_in;
        end else if (load_low_byte) begin
            counter_out[DATA_WIDTH-1:0] <= counter_in;  
        end else if (enable) begin
            counter_out <= counter_out + 1;
        end else if (output_high_byte) begin
            counter_byte_out <= counter_out[ADDR_WIDTH-1:DATA_WIDTH];
        end else if (output_low_byte) begin
            counter_byte_out <= counter_out[DATA_WIDTH-1:0];
        end    
    end


endmodule
