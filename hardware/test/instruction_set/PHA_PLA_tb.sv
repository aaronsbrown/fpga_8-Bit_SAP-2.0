`timescale 1ns/1ps
import test_utils_pkg::*; 
import arch_defs_pkg::*;  

module computer_tb;

  localparam string HEX_FILE = "../hardware/test/fixtures_generated/PHA_PLA/ROM.hex"; // Ensure this path is correct for your build system

  localparam logic [DATA_WIDTH-1:0] SUCCESS_CODE = 8'h88; // Match EQU SUCCESS_CODE in .asm

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

    // load the hex file into ROM (Corrected from RAM, assuming ROM holds program)
    $display("--- Loading hex file: %s into ROM ---", HEX_FILE);
    safe_readmemh_rom(HEX_FILE);  // This function should target uut.u_rom.memory_array or similar
    uut.u_rom.dump(); 

    // Apply reset and wait for it to release
    reset_and_wait(0); 

    // --- Execute the instruction test sequence ---
    $display("\n\nRunning enhanced PHA_PLA instruction test suite:");
    $display("  Test 0: Original 3-level push/pull ($AA, $AB, $AC).");
    $display("  Test 1: PLA sets Z flag (value $00), preserves C (initially 0).");
    $display("  Test 2: PLA sets N flag (value $80), Z clear, preserves C (initially 1).");
    $display("  Test 3: PLA clears N, Z flags (value $42), preserves C (initially 0).");
    $display("  Test 4: Stack operation at initial top ($01FF) with value $EE.");
    $display("If any test fails, a unique error code (not $88) will be output.");


    wait(uut.cpu_halt);
    // The assembly code is designed to output SUCCESS_CODE (8'h88) if all tests pass.
    // If any specific test fails, it will output a unique error code (e.g., $E1, $E2, etc.).
    // This inspect_register call will thus fail if any error code is outputted.
    // The specific error code can then be checked in the simulation waveform/log.
    inspect_register(computer_output, SUCCESS_CODE, "Output Port 1 = SUCCESS_CODE (88h if all tests pass, otherwise specific error code)", DATA_WIDTH);
    
    repeat(10) @(posedge clk);

    $display("PHA_PLA test finished.===========================\n\n");
    $finish;
  end

endmodule