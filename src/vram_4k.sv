import arch_defs_pkg::*;

module vram_4k (
    input   logic clk,
    input   logic we,
    input   logic [VRAM_4K_ADDR_WIDTH-1:0] address, // 12-bit address (2^12=4Kbytes)  
    input   logic [DATA_WIDTH-1:0] data_in,
    output  logic [DATA_WIDTH-1:0] data_out
);

    localparam VRAM_4K_ADDR_WIDTH = 12; // Address width
    localparam VRAM_4K_DEPTH = 1 << VRAM_4K_ADDR_WIDTH; // 4K ROM depth

    logic [DATA_WIDTH-1:0] mem [0: VRAM_4K_DEPTH - 1]; 
    logic [DATA_WIDTH-1: 0] data_out_i;
 
    always_ff @(posedge clk) begin
        if (we) begin
            mem[address] <= data_in;
        end
        data_out_i <= mem[address];
    end
    assign data_out = data_out_i;

    initial begin
        // Initialize RAM with zeros
        integer i;
        for (i = 0; i < VRAM_4K_DEPTH; i = i + 1) begin
            mem[i] = 8'h00;
        end
    end

endmodule
