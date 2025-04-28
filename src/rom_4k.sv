import arch_defs_pkg::*;

module rom_4k (
    input   logic clk,
    input   logic [ROM_ADDR_WIDTH-1:0] address, // 12-bit address (2^12=4096 bytes)
    output  logic [DATA_WIDTH-1:0] data_out
);

    localparam ROM_ADDR_WIDTH = 12; 
    localparam ROM_DEPTH = 1 << ROM_ADDR_WIDTH; // 4K ROM depth

    logic [DATA_WIDTH-1:0] mem [0: ROM_DEPTH - 1];  
    
    assign data_out = mem[address]; // Combinational eead data from RAM

    // Task to dump ROM contents
    task dump;
      integer j;
      begin

        $display("--- ROM Content Dump ---");
        // iterate over ROM memory addresses
        for (j = 0; j < ROM_DEPTH; j = j + 1) begin
          if( mem[j] !== 8'hxx) begin
            // Print only non-zero values
            $display("ROM[%0d] = %02h", j, mem[j]);
          end
        end
        $display("--- End ROM Dump ---");
      end
    endtask

    task init_sim_rom;
        integer i;
        $display("--- Task: Initializing Simulation ROM (4KB) to 0x00 ---");
        for (i = 0; i < ROM_DEPTH; i = i + 1) begin
            mem[i] = {DATA_WIDTH{1'bx}}; // Initialize to zero
        end
        $display("--- Task: Simulation ROM Initialized ---");
    endtask

  `ifndef SIMULATION
    initial begin
        // Synthesis tool reads this file during compilation
        $readmemh("../fixture/default_program_synth.hex", mem);
    end
  `endif

endmodule
