`timescale 1ns/1ps
import test_utils_pkg::*; 
import arch_defs_pkg::*;  
// AIDEV-NOTE: Enhanced from basic 1-test to comprehensive 20-test suite covering all LDI_B edge cases

module computer_tb;

  localparam string HEX_FILE = "../hardware/test/_fixtures_generated/LDI_B/ROM.hex";

  logic                  clk;
  logic                  reset;
  logic [DATA_WIDTH-1:0] computer_output;

  computer uut (
        .clk(clk),
        .reset(reset),
        .output_port_1(computer_output),
        .uart_rx(1'b1),     // UART not used in this test - tie high
        .uart_tx()          // UART not used in this test - leave open
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

    // load the hex files into ROM
    $display("--- Loading hex file: %s ---", HEX_FILE);
    safe_readmemh_rom(HEX_FILE); 

    // Print ROM content     
    uut.u_rom.dump(); 

    // Apply reset and wait for it to release
    reset_and_wait(0); 

    // ============================ BEGIN LDI_B COMPREHENSIVE TESTS ==============================
    $display("\n=== LDI_B (Load B Register with Immediate) Comprehensive Test Suite ===");
    $display("Testing LDI_B instruction: B = immediate_value");
    $display("Flags: Z=+/- (result), N=+/- (result), C=- (unaffected)\n");

    // =================================================================
    // TEST GROUP 1: Basic Bit Pattern Tests
    // =================================================================
    $display("--- TEST GROUP 1: Basic Bit Pattern Tests ---");
    
    // Test 1: Load zero value (should set Z=1, N=0, C=unaffected)
    $display("\n--- TEST 1: Load zero value ($00) ---");
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("LDI_B #$00: B = $00 (all zeros)");
    inspect_register(uut.u_cpu.b_out, 8'h00, "B after LDI_B #$00", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "Z=1: result $00 is zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result $00 MSB is clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: carry unaffected (init state)");

    // Test 2: Load all ones pattern (should set Z=0, N=1, C=unaffected)
    $display("\n--- TEST 2: Load all ones pattern ($FF) ---");
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("LDI_B #$FF: B = $FF (all ones)");
    inspect_register(uut.u_cpu.b_out, 8'hFF, "B after LDI_B #$FF", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $FF is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result $FF MSB is set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: carry unaffected");

    // Test 3: Load positive maximum (should set Z=0, N=0, C=unaffected)
    $display("\n--- TEST 3: Load positive maximum ($7F) ---");
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("LDI_B #$7F: B = $7F (01111111 - max positive in signed)");
    inspect_register(uut.u_cpu.b_out, 8'h7F, "B after LDI_B #$7F", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $7F is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result $7F MSB is clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: carry unaffected");

    // Test 4: Load negative minimum (should set Z=0, N=1, C=unaffected)
    $display("\n--- TEST 4: Load negative minimum ($80) ---");
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("LDI_B #$80: B = $80 (10000000 - min negative in signed)");
    inspect_register(uut.u_cpu.b_out, 8'h80, "B after LDI_B #$80", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $80 is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result $80 MSB is set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: carry unaffected");

    // =================================================================
    // TEST GROUP 2: Alternating Patterns
    // =================================================================
    $display("\n--- TEST GROUP 2: Alternating Patterns ---");
    
    // Test 5: Alternating pattern 1 (should set Z=0, N=0, C=unaffected)
    $display("\n--- TEST 5: Alternating pattern 1 ($55) ---");
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("LDI_B #$55: B = $55 (01010101)");
    inspect_register(uut.u_cpu.b_out, 8'h55, "B after LDI_B #$55", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $55 is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result $55 MSB is clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: carry unaffected");

    // Test 6: Alternating pattern 2 (should set Z=0, N=1, C=unaffected)
    $display("\n--- TEST 6: Alternating pattern 2 ($AA) ---");
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("LDI_B #$AA: B = $AA (10101010)");
    inspect_register(uut.u_cpu.b_out, 8'hAA, "B after LDI_B #$AA", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $AA is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result $AA MSB is set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: carry unaffected");

    // =================================================================
    // TEST GROUP 3: Single Bit Tests
    // =================================================================
    $display("\n--- TEST GROUP 3: Single Bit Tests ---");
    
    // Test 7: Single LSB set (should set Z=0, N=0, C=unaffected)
    $display("\n--- TEST 7: Single LSB set ($01) ---");
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("LDI_B #$01: B = $01 (00000001)");
    inspect_register(uut.u_cpu.b_out, 8'h01, "B after LDI_B #$01", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $01 is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result $01 MSB is clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: carry unaffected");

    // Test 8: Single MSB set (should set Z=0, N=1, C=unaffected)
    $display("\n--- TEST 8: Single MSB set ($80) ---");
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("LDI_B #$80: B = $80 (10000000)");
    inspect_register(uut.u_cpu.b_out, 8'h80, "B after LDI_B #$80", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $80 is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result $80 MSB is set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: carry unaffected");

    // Test 9: Single middle bit set (should set Z=0, N=0, C=unaffected)
    $display("\n--- TEST 9: Single middle bit set ($10) ---");
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("LDI_B #$10: B = $10 (00010000)");
    inspect_register(uut.u_cpu.b_out, 8'h10, "B after LDI_B #$10", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $10 is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result $10 MSB is clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: carry unaffected");

    // =================================================================
    // TEST GROUP 4: Edge Case Values
    // =================================================================
    $display("\n--- TEST GROUP 4: Edge Case Values ---");
    
    // Test 10: One less than max (should set Z=0, N=1, C=unaffected)
    $display("\n--- TEST 10: One less than max ($FE) ---");
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("LDI_B #$FE: B = $FE (11111110)");
    inspect_register(uut.u_cpu.b_out, 8'hFE, "B after LDI_B #$FE", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $FE is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result $FE MSB is set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: carry unaffected");

    // Test 11: One more than zero (should set Z=0, N=0, C=unaffected)
    $display("\n--- TEST 11: One more than zero ($01) ---");
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("LDI_B #$01: B = $01 (00000001)");
    inspect_register(uut.u_cpu.b_out, 8'h01, "B after LDI_B #$01", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $01 is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result $01 MSB is clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: carry unaffected");

    // Test 12: Mid-range value (should set Z=0, N=0, C=unaffected)
    $display("\n--- TEST 12: Mid-range value ($42) ---");
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("LDI_B #$42: B = $42 (01000010)");
    inspect_register(uut.u_cpu.b_out, 8'h42, "B after LDI_B #$42", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $42 is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result $42 MSB is clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: carry unaffected");

    // =================================================================
    // TEST GROUP 5: Carry Flag Preservation Tests
    // =================================================================
    $display("\n--- TEST GROUP 5: Carry Flag Preservation Tests ---");
    
    // Test 13: LDI_B with carry clear (C should remain 0)
    $display("\n--- TEST 13: LDI_B with carry clear ($CC) ---");
    
    // CLC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "CLC: Carry cleared");
    
    // LDI_B #$CC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("LDI_B #$CC: B = $CC, carry should remain 0");
    inspect_register(uut.u_cpu.b_out, 8'hCC, "B after LDI_B #$CC", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $CC is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result $CC MSB is set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: carry preserved (clear)");

    // Test 14: LDI_B with carry set (C should remain 1)
    $display("\n--- TEST 14: LDI_B with carry set ($33) ---");
    
    // SEC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "SEC: Carry set");
    
    // LDI_B #$33
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("LDI_B #$33: B = $33, carry should remain 1");
    inspect_register(uut.u_cpu.b_out, 8'h33, "B after LDI_B #$33", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $33 is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result $33 MSB is clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: carry preserved (set)");

    // =================================================================
    // TEST GROUP 6: Register Preservation Tests
    // =================================================================
    $display("\n--- TEST GROUP 6: Register Preservation Tests ---");
    
    // Test 15: Set up other registers, verify LDI_B doesn't affect them
    $display("\n--- TEST 15: Register preservation test ---");
    
    // LDI A, #$AA
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hAA, "A after LDI A, #$AA", DATA_WIDTH);
    
    // LDI C, #$CC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hCC, "C after LDI C, #$CC", DATA_WIDTH);
    
    // CLC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "CLC: Carry cleared");
    
    // LDI B, #$BB
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("LDI_B #$BB: B = $BB, A and C should be preserved");
    inspect_register(uut.u_cpu.b_out, 8'hBB, "B after LDI_B #$BB", DATA_WIDTH);
    inspect_register(uut.u_cpu.a_out, 8'hAA, "A preserved during LDI_B", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hCC, "C preserved during LDI_B", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: carry preserved");

    // =================================================================
    // TEST GROUP 7: Multiple Sequential Operations
    // =================================================================
    $display("\n--- TEST GROUP 7: Multiple Sequential Operations ---");
    
    // Test 16: Sequential LDI_B operations
    $display("\n--- TEST 16: Sequential LDI_B operations ---");
    
    // LDI B, #$11
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("LDI_B #$11: B = $11");
    inspect_register(uut.u_cpu.b_out, 8'h11, "B after LDI_B #$11", DATA_WIDTH);
    
    // LDI B, #$22
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("LDI_B #$22: B = $22 (overwrites previous)");
    inspect_register(uut.u_cpu.b_out, 8'h22, "B after LDI_B #$22", DATA_WIDTH);
    
    // LDI B, #$33
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("LDI_B #$33: B = $33 (overwrites previous)");
    inspect_register(uut.u_cpu.b_out, 8'h33, "B after LDI_B #$33", DATA_WIDTH);

    // =================================================================
    // TEST GROUP 8: Boundary Value Analysis
    // =================================================================
    $display("\n--- TEST GROUP 8: Boundary Value Analysis ---");
    
    // Test 17: Powers of 2 patterns
    $display("\n--- TEST 17: Powers of 2 patterns ---");
    
    // LDI B, #$02
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("LDI_B #$02: B = $02 (00000010)");
    inspect_register(uut.u_cpu.b_out, 8'h02, "B after LDI_B #$02", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $02 is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result $02 MSB is clear");
    
    // Continue with other powers of 2
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h04, "B after LDI_B #$04", DATA_WIDTH);
    
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h08, "B after LDI_B #$08", DATA_WIDTH);
    
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h20, "B after LDI_B #$20", DATA_WIDTH);
    
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h40, "B after LDI_B #$40", DATA_WIDTH);

    // =================================================================
    // TEST GROUP 9: Complex Bit Patterns
    // =================================================================
    $display("\n--- TEST GROUP 9: Complex Bit Patterns ---");
    
    // Test 18: Complex patterns for thorough testing
    $display("\n--- TEST 18: Complex bit patterns ---");
    
    // LDI B, #$69
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("LDI_B #$69: B = $69 (01101001)");
    inspect_register(uut.u_cpu.b_out, 8'h69, "B after LDI_B #$69", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $69 is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result $69 MSB is clear");
    
    // Continue with other complex patterns
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h96, "B after LDI_B #$96", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result $96 MSB is set");
    
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'hC3, "B after LDI_B #$C3", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result $C3 MSB is set");
    
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h3C, "B after LDI_B #$3C", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result $3C MSB is clear");

    // =================================================================
    // TEST GROUP 10: Final Comprehensive Test
    // =================================================================
    $display("\n--- TEST GROUP 10: Final Comprehensive Test ---");
    
    // Test 19: Final test with register preservation check
    $display("\n--- TEST 19: Final preservation test ---");
    
    // LDI A, #$DE
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hDE, "A after LDI A, #$DE", DATA_WIDTH);
    
    // LDI C, #$AD
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hAD, "C after LDI C, #$AD", DATA_WIDTH);
    
    // SEC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "SEC: Carry set");
    
    // LDI B, #$BE
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("LDI_B #$BE: B = $BE, other registers/flags preserved");
    inspect_register(uut.u_cpu.b_out, 8'hBE, "B after LDI_B #$BE", DATA_WIDTH);
    inspect_register(uut.u_cpu.a_out, 8'hDE, "A preserved during final test", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hAD, "C preserved during final test", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: carry preserved");
    
    // LDI B, #$EF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("LDI_B #$EF: B = $EF (final test pattern)");
    inspect_register(uut.u_cpu.b_out, 8'hEF, "B after LDI_B #$EF", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result $EF MSB is set");

    // Test 20: Zero flag test (ensure it's properly set)
    $display("\n--- TEST 20: Final zero flag verification ---");
    
    // LDI B, #$00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("LDI_B #$00: B = $00 (should set zero flag)");
    inspect_register(uut.u_cpu.b_out, 8'h00, "B after final LDI_B #$00", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "Z=1: final zero flag test");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: final negative flag test");

    // =================================================================
    // HALT verification - ensure CPU properly stops
    // =================================================================
    $display("\n--- Verifying HALT instruction ---");
    run_until_halt(300);  // Increased timeout for comprehensive test suite
    $display("CPU halted successfully");
    
    // Visual buffer for waveform inspection
    repeat(5) @(posedge clk);

    $display("\n=== LDI_B Comprehensive Test Summary ===");
    $display("✓ Basic bit patterns (all zeros, all ones, max positive/negative)");
    $display("✓ Alternating patterns ($55, $AA)");
    $display("✓ Single bit tests (LSB, MSB, middle bits)");
    $display("✓ Edge case values (boundary conditions)");
    $display("✓ Carry flag preservation (clear and set states)");
    $display("✓ Register preservation (A, C registers unaffected)");
    $display("✓ Sequential operations (overwrite behavior)");
    $display("✓ Powers of 2 patterns");
    $display("✓ Complex bit patterns");
    $display("✓ Zero and Negative flag behavior verification");
    $display("✓ Comprehensive register and flag preservation");
    
    $display("LDI_B test finished.===========================\n\n");
    $display("All 20 LDI_B test groups passed successfully!");
    $finish;
    // ============================ END TEST ==============================
  
  end

endmodule