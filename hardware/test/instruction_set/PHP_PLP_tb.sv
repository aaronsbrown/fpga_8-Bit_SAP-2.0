`timescale 1ns/1ps
import test_utils_pkg::*; 
import arch_defs_pkg::*;  

// AIDEV-NOTE: Comprehensive PHP_PLP testbench covering all flag combinations and edge cases
module computer_tb;

  localparam string HEX_FILE = "../hardware/test/_fixtures_generated/PHP_PLP/ROM.hex";
  localparam logic [DATA_WIDTH-1:0] SUCCESS_CODE = 8'h88;

  // Module-level logic declarations (required for SystemVerilog)
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
    $dumpvars(0, computer_tb);

    // Initialize memory to clean state
    uut.u_ram.init_sim_ram();
    uut.u_rom.init_sim_rom();

    // Load the comprehensive test program
    $display("=== Loading PHP_PLP Comprehensive Test Suite ===");
    $display("--- Loading hex file: %s ---", HEX_FILE);
    safe_readmemh_rom(HEX_FILE);  
    uut.u_rom.dump(); 

    // Apply reset and wait for release
    reset_and_wait(0); 

    // === PHP_PLP INSTRUCTION TEST SUITE ===
    $display("\n==================================================");
    $display("  COMPREHENSIVE PHP_PLP INSTRUCTION TEST SUITE   ");
    $display("==================================================");
    $display("Testing PHP (Push Processor Status) and PLP (Pull Processor Status)");
    $display("PHP: Pushes all flags (Z,N,C) to stack, flags unchanged");
    $display("PLP: Pulls all flags from stack, restores complete flag state");
    $display("");
    
    $display("Test Coverage:");
    $display("  1. Basic PHP/PLP flag restoration");
    $display("  2. All flags zero state (Z=0, N=0, C=0)");
    $display("  3. Mixed flag patterns (combinations of Z,N,C)");
    $display("  4. Nested PHP/PLP operations (stack depth)");
    $display("  5. Individual flag preservation tests");
    $display("  6. Stack depth with multiple flag states");
    $display("  7. Alternating flag patterns");
    $display("  8. Single bit flag isolation tests");
    $display("  9. Register corruption verification");
    $display(" 10. Final comprehensive state verification");
    $display("");
    
    $display("Expected Behavior:");
    $display("  • PHP preserves all current flags while pushing to stack");
    $display("  • PLP restores exact flag state from stack");
    $display("  • Stack operates LIFO (Last In, First Out)");
    $display("  • Registers A, B, C remain unaffected by PHP/PLP");
    $display("  • Flag combinations: Z (bit 1), N (bit 7), C (bit 0)");
    $display("");
    
    $display("Success Criteria:");
    $display("  ✓ All 14 test cases pass without error");
    $display("  ✓ Output port shows SUCCESS_CODE ($88)");
    $display("  ✓ Any test failure outputs unique error code ($E1-$EF)");
    $display("==================================================\n");

    // Wait for program completion with extended timeout for comprehensive tests
    wait(uut.cpu_halt);
    
    // Verify final result
    $display("\n==================================================");
    $display("             TEST RESULTS VERIFICATION            ");
    $display("==================================================");
    
    if (computer_output == SUCCESS_CODE) begin
        $display("✓ SUCCESS: All PHP_PLP tests passed!");
        $display("  • Basic flag restoration: PASS");
        $display("  • All zeros flag state: PASS"); 
        $display("  • Mixed flag patterns: PASS");
        $display("  • Nested operations: PASS");
        $display("  • Flag preservation: PASS");
        $display("  • Stack depth tests: PASS");
        $display("  • Alternating patterns: PASS");
        $display("  • Single bit isolation: PASS");
        $display("  • Register corruption check: PASS");
        $display("  • Final state verification: PASS");
        $display("==================================================");
    end else begin
        $display("✗ FAILURE: Test failed with error code: $%02X", computer_output);
        case (computer_output)
            8'hE1: $display("  Error: Basic flag restore failed");
            8'hE2: $display("  Error: All zeros flag pattern failed");
            8'hE3: $display("  Error: All ones flag pattern failed");
            8'hE4: $display("  Error: Mixed flag patterns failed");
            8'hE5: $display("  Error: Nested push/pull operations failed");
            8'hE6: $display("  Error: Carry flag preservation failed");
            8'hE7: $display("  Error: Zero flag preservation failed");
            8'hE8: $display("  Error: Negative flag preservation failed");
            8'hE9: $display("  Error: Stack depth test failed");
            8'hEA: $display("  Error: Alternating pattern test failed");
            8'hEB: $display("  Error: Single bit carry test failed");
            8'hEC: $display("  Error: Single bit zero test failed");
            8'hED: $display("  Error: Single bit negative test failed");
            8'hEE: $display("  Error: Register corruption check failed");
            8'hEF: $display("  Error: Final state verification failed");
            default: $display("  Error: Unknown error code");
        endcase
        $display("==================================================");
    end
    
    // Final assertion with descriptive message
    inspect_register(computer_output, SUCCESS_CODE, 
        "PHP_PLP comprehensive test: All 14 test cases must pass (SUCCESS=$88)", 
        DATA_WIDTH);
    
    // Allow additional cycles for clean termination
    repeat(10) @(posedge clk);

    $display("\n==================================================");
    $display("PHP_PLP test finished.===========================");
    $display("==================================================\n\n");
    $finish;
  end

endmodule