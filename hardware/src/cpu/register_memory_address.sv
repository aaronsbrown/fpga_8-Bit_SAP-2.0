import arch_defs_pkg::*;

module register_memory_address (
    input logic                     clk,
    input logic                     reset,
    input logic                     load_pc, 
    input logic                     load_sp,
    input logic                     load_addr_high,
    input logic                     load_addr_low,
    input logic                     load_reset_vec_addr_low,
    input logic                     load_reset_vec_addr_high, 
    input logic  [DATA_WIDTH-1:0]   bus_in,
    input logic  [ADDR_WIDTH-1:0]   program_counter_in,
    input logic  [ADDR_WIDTH-1:0]   stack_pointer_in,
    output logic [ADDR_WIDTH-1:0]   address_out
);

    localparam MAR_RESET_VEC_ADDR_LOW = RESET_VECTOR_ADDR_LOW;
    localparam MAR_RESET_VEC_ADDR_HIGH = RESET_VECTOR_ADDR_HIGH;

    always_ff @(posedge clk) begin
        if (reset) begin // No need to wait for clock edge
            address_out <= {ADDR_WIDTH{1'b0}};
        end else if (load_addr_high) begin 
            address_out[ADDR_WIDTH-1:DATA_WIDTH] <= bus_in;
        end else if (load_addr_low) begin
            address_out[DATA_WIDTH-1:0] <= bus_in;  
        end else if (load_pc) begin
            address_out <= program_counter_in;
        end else if (load_sp) begin
            address_out <= stack_pointer_in;
        end else if (load_reset_vec_addr_low) begin
            address_out <= MAR_RESET_VEC_ADDR_LOW;
        end else if (load_reset_vec_addr_high) begin
            address_out <= MAR_RESET_VEC_ADDR_HIGH;
        end
    end


endmodule
