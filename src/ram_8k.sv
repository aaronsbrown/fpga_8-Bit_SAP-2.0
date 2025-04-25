import arch_defs_pkg::*;

module ram_8k (
    input   logic clk,
    input   logic we,
    input   logic [RAM_8K_ADDR_WIDTH-1:0] address, // 13-bit address (2^13=8Kbytes)  
    input   logic [DATA_WIDTH-1:0] data_in,
    output  logic [DATA_WIDTH-1:0] data_out
);

    localparam RAM_8K_ADDR_WIDTH = 13; // Address width
    localparam RAM_8K_DEPTH = 1 << RAM_8K_ADDR_WIDTH; // 8K ROM depth

    logic [DATA_WIDTH-1:0] mem [0: RAM_8K_DEPTH - 1]; 
    
    always_ff @(posedge clk) begin
        if (we) begin
            mem[address] <= data_in;
        end
    end
    assign data_out = mem[address];

    initial begin
        // Initialize RAM with zeros
        integer i;
        for (i = 0; i < RAM_8K_DEPTH; i = i + 1) begin
            mem[i] = 8'h00;
        end
    end

endmodule
