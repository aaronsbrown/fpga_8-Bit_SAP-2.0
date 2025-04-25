import arch_defs_pkg::*;

module register_memory_address (
    input logic                     clk,
    input logic                     reset,
    input logic                     load_pc, 
    input logic                     load_addr_high,
    input logic                     load_addr_low,
    input logic  [DATA_WIDTH-1:0]   bus_in,
    input logic  [ADDR_WIDTH-1:0]   program_counter_in,
    output logic [ADDR_WIDTH-1:0]   address_out
);
    
    always_ff @(posedge clk) begin
        if (reset) begin // No need to wait for clock edge
            address_out <= {ADDR_WIDTH{1'b0}};
        end else if (load_addr_high) begin 
            address_out[ADDR_WIDTH-1:DATA_WIDTH] <= bus_in;
        end else if (load_addr_low) begin
            address_out[DATA_WIDTH-1:0] <= bus_in;  
        end else if (load_pc) begin
            address_out <= program_counter_in;
        end 
    end


endmodule
