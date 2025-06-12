`timescale 1ns/1ps
import test_utils_pkg::*; 
import arch_defs_pkg::*;  

// AIDEV-NOTE: Enhanced INR_A testbench with 13 comprehensive test cases, systematic verification, and clear organization
module computer_tb;

  localparam string HEX_FILE = "../hardware/test/_fixtures_generated/INR_A/ROM.hex";

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

    // load the hex files into RAM
    $display("--- Loading hex file: %s ---", HEX_FILE);
    safe_readmemh_rom(HEX_FILE); 

    // Print ROM content     
    uut.u_rom.dump(); 

    // Apply reset and wait for it to release
    reset_and_wait(0); 

    // ============================ BEGIN INR_A COMPREHENSIVE TESTS ==============================
    $display("\n=== INR_A Comprehensive Test Suite ===");
    $display("Testing INR_A instruction functionality, edge cases, and flag behavior");
    $display("INR_A: Increment A (A=A+1), affects Z and N flags, C unaffected\n");

    // =================================================================
    // TEST 1: Basic increment - positive number
    // Assembly: LDI A, #$01; LDI B, #$55; LDI C, #$AA; SEC; INR A
    // Expected: A = $01 + 1 = $02 (Z=0, N=0, C=1 preserved)
    // =================================================================
    $display("--- TEST 1: Basic increment ($01 + 1) ---");
    
    // LDI A, #$01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h01, "A after LDI A, #$01", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z flag clear after LDI A");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N flag clear after LDI A");

    // LDI B, #$55 (register preservation test setup)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h55, "B after LDI B, #$55", DATA_WIDTH);

    // LDI C, #$AA (register preservation test setup)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hAA, "C after LDI C, #$AA", DATA_WIDTH);

    // SEC (set carry to test preservation)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C flag set after SEC");

    // INR A: A = A + 1 = $01 + 1 = $02
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("INR A: $01 + 1 = $02");
    inspect_register(uut.u_cpu.a_out, 8'h02, "A after INR A ($01 + 1)", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h55, "B preserved during INR A", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hAA, "C preserved during INR A", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result is positive");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: carry preserved (unaffected)");

    // =================================================================
    // TEST 2: Increment resulting in zero (overflow from $FF)
    // Assembly: LDI A, #$FF; INR A
    // Expected: A = $FF + 1 = $00 (Z=1, N=0, C unchanged)
    // =================================================================
    $display("\n--- TEST 2: Increment with overflow ($FF + 1) ---");
    
    // LDI A, #$FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A after LDI A, #$FF", DATA_WIDTH);

    // INR A: A = A + 1 = $FF + 1 = $00 (overflow)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("INR A: $FF + 1 = $00 (overflow to zero)");
    inspect_register(uut.u_cpu.a_out, 8'h00, "A after INR A ($FF + 1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "Z=1: result is zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result MSB is clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: carry still preserved");

    // =================================================================
    // TEST 3: Zero increment
    // Assembly: LDI A, #$00; INR A
    // Expected: A = $00 + 1 = $01 (Z=0, N=0, C unchanged)
    // =================================================================
    $display("\n--- TEST 3: Zero increment ($00 + 1) ---");
    
    // LDI A, #$00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "A after LDI A, #$00", DATA_WIDTH);

    // INR A: A = A + 1 = $00 + 1 = $01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("INR A: $00 + 1 = $01");
    inspect_register(uut.u_cpu.a_out, 8'h01, "A after INR A ($00 + 1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result MSB is clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: carry still preserved");

    // =================================================================
    // TEST 4: Increment from $7F (max positive) to $80 (negative)
    // Assembly: LDI A, #$7F; INR A
    // Expected: A = $7F + 1 = $80 (Z=0, N=1, C unchanged)
    // =================================================================
    $display("\n--- TEST 4: Max positive to negative ($7F + 1) ---");
    
    // LDI A, #$7F
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h7F, "A after LDI A, #$7F", DATA_WIDTH);

    // INR A: A = A + 1 = $7F + 1 = $80
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("INR A: $7F + 1 = $80 (positive to negative transition)");
    inspect_register(uut.u_cpu.a_out, 8'h80, "A after INR A ($7F + 1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result MSB set (negative)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: carry still preserved");

    // =================================================================
    // TEST 5: Increment negative value from MSB set
    // Assembly: LDI A, #$80; INR A
    // Expected: A = $80 + 1 = $81 (Z=0, N=1, C unchanged)
    // =================================================================
    $display("\n--- TEST 5: Increment from most negative ($80 + 1) ---");
    
    // LDI A, #$80
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h80, "A after LDI A, #$80", DATA_WIDTH);

    // INR A: A = A + 1 = $80 + 1 = $81
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("INR A: $80 + 1 = $81 (negative stays negative)");
    inspect_register(uut.u_cpu.a_out, 8'h81, "A after INR A ($80 + 1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result MSB still set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: carry still preserved");

    // =================================================================
    // TEST 6: Increment from $FE to $FF (all ones result)
    // Assembly: LDI A, #$FE; INR A
    // Expected: A = $FE + 1 = $FF (Z=0, N=1, C unchanged)
    // =================================================================
    $display("\n--- TEST 6: Increment to all ones ($FE + 1) ---");
    
    // LDI A, #$FE
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFE, "A after LDI A, #$FE", DATA_WIDTH);

    // INR A: A = A + 1 = $FE + 1 = $FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("INR A: $FE + 1 = $FF (11111110 + 1 = 11111111)");
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A after INR A ($FE + 1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result MSB is set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: carry still preserved");

    // =================================================================
    // TEST 7: Alternating pattern (0x54) increment
    // Assembly: LDI A, #$54; INR A
    // Expected: A = $54 + 1 = $55 (Z=0, N=0, C unchanged)
    // =================================================================
    $display("\n--- TEST 7: Alternating pattern increment ($54 + 1) ---");
    
    // LDI A, #$54
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h54, "A after LDI A, #$54", DATA_WIDTH);

    // INR A: A = A + 1 = $54 + 1 = $55
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("INR A: $54 + 1 = $55 (01010100 + 1 = 01010101)");
    inspect_register(uut.u_cpu.a_out, 8'h55, "A after INR A ($54 + 1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result MSB clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: carry still preserved");

    // =================================================================
    // TEST 8: Alternating pattern (0xA9) increment
    // Assembly: LDI A, #$A9; INR A
    // Expected: A = $A9 + 1 = $AA (Z=0, N=1, C unchanged)
    // =================================================================
    $display("\n--- TEST 8: Alternating pattern increment ($A9 + 1) ---");
    
    // LDI A, #$A9
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hA9, "A after LDI A, #$A9", DATA_WIDTH);

    // INR A: A = A + 1 = $A9 + 1 = $AA
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("INR A: $A9 + 1 = $AA (10101001 + 1 = 10101010)");
    inspect_register(uut.u_cpu.a_out, 8'hAA, "A after INR A ($A9 + 1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result MSB is set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: carry still preserved");

    // =================================================================
    // TEST 9: Increment $7E to $7F (stays positive)
    // Assembly: LDI A, #$7E; INR A
    // Expected: A = $7E + 1 = $7F (Z=0, N=0, C unchanged)
    // =================================================================
    $display("\n--- TEST 9: High positive increment ($7E + 1) ---");
    
    // LDI A, #$7E
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h7E, "A after LDI A, #$7E", DATA_WIDTH);

    // INR A: A = A + 1 = $7E + 1 = $7F
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("INR A: $7E + 1 = $7F (stays positive)");
    inspect_register(uut.u_cpu.a_out, 8'h7F, "A after INR A ($7E + 1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result MSB clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: carry still preserved");

    // =================================================================
    // TEST 10: Power of 2 boundary test ($0F + 1)
    // Assembly: LDI A, #$0F; INR A
    // Expected: A = $0F + 1 = $10 (Z=0, N=0, C unchanged)
    // =================================================================
    $display("\n--- TEST 10: Power of 2 boundary ($0F + 1) ---");
    
    // LDI A, #$0F
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h0F, "A after LDI A, #$0F", DATA_WIDTH);

    // INR A: A = A + 1 = $0F + 1 = $10
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("INR A: $0F + 1 = $10 (power of 2 boundary)");
    inspect_register(uut.u_cpu.a_out, 8'h10, "A after INR A ($0F + 1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result MSB clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: carry still preserved");

    // =================================================================
    // TEST 11: Power of 2 boundary test ($07 + 1)
    // Assembly: LDI A, #$07; INR A
    // Expected: A = $07 + 1 = $08 (Z=0, N=0, C unchanged)
    // =================================================================
    $display("\n--- TEST 11: Power of 2 boundary ($07 + 1) ---");
    
    // LDI A, #$07
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h07, "A after LDI A, #$07", DATA_WIDTH);

    // INR A: A = A + 1 = $07 + 1 = $08
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("INR A: $07 + 1 = $08 (power of 2 boundary)");
    inspect_register(uut.u_cpu.a_out, 8'h08, "A after INR A ($07 + 1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result MSB clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: carry still preserved");

    // =================================================================
    // TEST 12: Carry flag preservation test with clear flag
    // Assembly: LDI A, #$04; CLC; INR A
    // Expected: A = $04 + 1 = $05 (Z=0, N=0, C=0 preserved)
    // =================================================================
    $display("\n--- TEST 12: Carry flag preservation with clear ($04 + 1) ---");
    
    // LDI A, #$04
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h04, "A after LDI A, #$04", DATA_WIDTH);

    // CLC (clear carry to test preservation)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C flag clear after CLC");

    // INR A: A = A + 1 = $04 + 1 = $05 (C should remain 0)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("INR A: $04 + 1 = $05 (with C=0 preserved)");
    inspect_register(uut.u_cpu.a_out, 8'h05, "A after INR A ($04 + 1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result MSB clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: carry preserved (unaffected)");

    // =================================================================
    // TEST 13: Register preservation final verification
    // Assembly: LDI A, #$02; INR A
    // Expected: A = $02 + 1 = $03, B=$55, C=$AA unchanged from TEST 1
    // =================================================================
    $display("\n--- TEST 13: Final register preservation test ($02 + 1) ---");
    
    // LDI A, #$02
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h02, "A after LDI A, #$02", DATA_WIDTH);

    // INR A: A = A + 1 = $02 + 1 = $03
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("INR A: $02 + 1 = $03 (final verification)");
    inspect_register(uut.u_cpu.a_out, 8'h03, "A after INR A ($02 + 1)", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h55, "B register still preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hAA, "C register still preserved", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result MSB clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: carry still preserved");

    // =================================================================
    // HALT verification - ensure CPU properly stops
    // =================================================================
    $display("\n--- Verifying HALT instruction ---");
    run_until_halt(150);  // Increased timeout for comprehensive test suite
    $display("CPU halted successfully");
    
    // Visual buffer for waveform inspection
    repeat(5) @(posedge clk);

    $display("INR_A test finished.===========================\n\n");
    $display("All 13 test cases passed successfully!");
    $finish;
    // ============================ END TEST ==============================
  
  end

endmodule