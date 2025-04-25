import arch_defs_pkg::*;

module ram (
    input   logic clk,
    input   logic we,
    input   logic [ADDR_WIDTH-1:0] address, // 16-bit address (2^16=64Kbytes)  
    input   logic [DATA_WIDTH-1:0] data_in,
    output  logic [DATA_WIDTH-1:0] data_out
);

    // Declare the RAM register without an initializer
    logic [DATA_WIDTH-1:0] mem [0: RAM_DEPTH - 1]; 
    

    always_ff @(posedge clk) begin
        if (we) begin
            mem[address] <= data_in; // Write data to RAM
        end
    //    data_out_i <= mem[address]; // Read data from RAM       
    end
    assign data_out = mem[address]; // Combinational eead data from RAM


    // TODO: uncomment for registered output
    //logic [DATA_WIDTH-1: 0] data_out_i;
    // assign data_out = data_out_i;

    // Task to dump RAM contents
    task dump;
      integer j;
      begin

        $display("--- RAM Content Dump ---");
        // iterate over ROM memory addresses
        for (j = 0; j < RAM_DEPTH; j = j + 1) begin
          if( mem[j] !== 8'h00 && mem[j] !== 8'hxx) begin
            // Print only non-zero values
            $display("RAM[%0d] = %02h", j, mem[j]);
          end
        end
        $display("--- End RAM Dump ---");
      end
    endtask

`ifndef SIMULATION
    initial begin
        // Synthesis tool reads this file during compilation
        $readmemh("../fixture/default_program_synth.hex", mem);
    end
`endif

endmodule
