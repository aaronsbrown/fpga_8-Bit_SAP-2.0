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

    // Task to dump RAM contents
    task dump;
      integer j;
      begin

        $display("--- RAM Content Dump ---");
        // iterate over RAM memory addresses
        for (j = 0; j < RAM_8K_DEPTH; j = j + 1) begin
          if( mem[j] !== 8'h00 && mem[j] !== 8'hxx) begin
            // Print only non-zero values
            $display("RAM[%0d] = %02h", j, mem[j]);
          end
        end
        $display("--- End RAM Dump ---");
      end
    endtask

    task init_sim_ram;
        integer i;
        $display("--- Task: Initializing Simulation RAM (8KB) to 0x00 ---");
        for (i = 0; i < RAM_8K_DEPTH; i = i + 1) begin
            mem[i] = {DATA_WIDTH{1'b0}}; // Initialize to zero
        end
        $display("--- Task: Simulation RAM Initialized ---");
    endtask

endmodule
