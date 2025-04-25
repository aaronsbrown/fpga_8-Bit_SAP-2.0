import arch_defs_pkg::*;

module program_counter (
    input logic                         clk,
    input logic                         reset,
    input logic                         enable,
    input logic                         load_origin,
    input logic                         load_high_byte,
    input logic                         load_low_byte,
    input logic     [DATA_WIDTH-1:0]    counter_in,
    input logic     [ADDR_WIDTH-1:0]    origin_address,
    output logic    [ADDR_WIDTH-1:0]    counter_out
);
    
    always_ff @(posedge clk) begin
        if (reset) begin // No need to wait for clock edge
            counter_out <= {ADDR_WIDTH{1'b0}};
        end else if (load_high_byte) begin 
            counter_out[ADDR_WIDTH-1:DATA_WIDTH] <= counter_in;
        end else if (load_low_byte) begin
            counter_out[DATA_WIDTH-1:0] <= counter_in;  
        end else if (load_origin) begin
            counter_out <= origin_address;
        end else if (enable) begin
            counter_out <= counter_out + 1;
        end
        
    end


endmodule
