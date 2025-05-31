`timescale 1ns/1ps
import test_utils_pkg::*; 
import arch_defs_pkg::*;  

module computer_tb;

  localparam string HEX_FILE = "../hardware/test/fixtures_generated/op_PHP_PLP/ROM.hex";

  logic clk;
  logic reset;
  wire  [DATA_WIDTH-1:0] computer_output;
  
  computer uut (
        .clk(clk),
        .reset(reset),
        .output_port_1(computer_output)
  );

  // --- Clock Generation: 10 ns period ---
  initial begin clk = 0;  forever #5 clk = ~clk; end

  // --- Testbench Stimulus ---
  initial begin

    // Setup waveform dumping
    $dumpfile("waveform.vcd");
    $dumpvars(0, computer_tb); // Dump all signals in this module and below

    // Init ram/rom to 00 
    uut.u_ram.init_sim_ram();
    uut.u_rom.init_sim_rom();

    // load the hex file into RAM
    $display("--- Loading hex file: %s ---", HEX_FILE);
    $readmemh(HEX_FILE, uut.u_rom.mem); 
    uut.u_rom.dump(); 

    // Apply reset and wait for it to release
    reset_and_wait(0); 

    // --- Execute the instruction ---
    $display("\n\nRunning PHA_PLA instruction test");

    wait(uut.cpu_halt);
    inspect_register(computer_output, 8'h88, "Output Port 1 = SUCCESS CODE (88)", DATA_WIDTH);
    
    repeat(10) @(posedge clk);

    $display("PHA_PLA instruction finished.\n\n");
    $finish;
  end

endmodule