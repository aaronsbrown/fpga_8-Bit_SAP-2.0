`timescale 1ns/1ps
import test_utils_pkg::*; 
import arch_defs_pkg::*;  

// AIDEV-NOTE: Enhanced DCR_A testbench with 13 comprehensive test cases, systematic verification, and clear organization
module computer_tb;

  localparam string HEX_FILE = "../hardware/test/_fixtures_generated/DCR_A/ROM.hex";

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

    // ============================ BEGIN DCR_A COMPREHENSIVE TESTS ==============================
    $display("\n=== DCR_A Comprehensive Test Suite ===");
    $display("Testing DCR_A instruction functionality, edge cases, and flag behavior");
    $display("DCR_A: Decrement A (A=A-1), affects Z and N flags, C unaffected\n");

    // =================================================================
    // TEST 1: Basic decrement - positive number
    // Assembly: LDI A, #$02; LDI B, #$55; LDI C, #$AA; SEC; DCR A
    // Expected: A = $02 - 1 = $01 (Z=0, N=0, C=1 preserved)
    // =================================================================
    $display("--- TEST 1: Basic decrement ($02 - 1) ---");
    
    // LDI A, #$02
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h02, "A after LDI A, #$02", DATA_WIDTH);
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

    // DCR A: A = A - 1 = $02 - 1 = $01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("DCR A: $02 - 1 = $01");
    inspect_register(uut.u_cpu.a_out, 8'h01, "A after DCR A ($02 - 1)", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h55, "B preserved during DCR A", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hAA, "C preserved during DCR A", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result is positive");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: carry preserved (unaffected)");

    // =================================================================
    // TEST 2: Decrement resulting in zero
    // Assembly: LDI A, #$01; DCR A
    // Expected: A = $01 - 1 = $00 (Z=1, N=0, C unchanged)
    // =================================================================
    $display("\n--- TEST 2: Decrement resulting in zero ($01 - 1) ---");
    
    // LDI A, #$01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h01, "A after LDI A, #$01", DATA_WIDTH);

    // DCR A: A = A - 1 = $01 - 1 = $00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("DCR A: $01 - 1 = $00 (zero result)");
    inspect_register(uut.u_cpu.a_out, 8'h00, "A after DCR A ($01 - 1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "Z=1: result is zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result MSB is clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: carry still preserved");

    // =================================================================
    // TEST 3: Decrement zero (underflow to $FF)
    // Assembly: LDI A, #$00; DCR A
    // Expected: A = $00 - 1 = $FF (Z=0, N=1, C unchanged)
    // =================================================================
    $display("\n--- TEST 3: Decrement zero with underflow ($00 - 1) ---");
    
    // LDI A, #$00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "A after LDI A, #$00", DATA_WIDTH);

    // DCR A: A = A - 1 = $00 - 1 = $FF (underflow)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("DCR A: $00 - 1 = $FF (underflow)");
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A after DCR A ($00 - 1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result MSB is set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: carry still preserved");

    // =================================================================
    // TEST 4: Decrement from MSB set
    // Assembly: LDI A, #$81; DCR A
    // Expected: A = $81 - 1 = $80 (Z=0, N=1, C unchanged)
    // =================================================================
    $display("\n--- TEST 4: Decrement from MSB set ($81 - 1) ---");
    
    // LDI A, #$81
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h81, "A after LDI A, #$81", DATA_WIDTH);

    // DCR A: A = A - 1 = $81 - 1 = $80
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("DCR A: $81 - 1 = $80 (negative result)");
    inspect_register(uut.u_cpu.a_out, 8'h80, "A after DCR A ($81 - 1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result MSB is set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: carry still preserved");

    // =================================================================
    // TEST 5: Decrement from $80 (most negative) to $7F (positive)
    // Assembly: LDI A, #$80; DCR A
    // Expected: A = $80 - 1 = $7F (Z=0, N=0, C unchanged)
    // =================================================================
    $display("\n--- TEST 5: Decrement from most negative ($80 - 1) ---");
    
    // LDI A, #$80
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h80, "A after LDI A, #$80", DATA_WIDTH);

    // DCR A: A = A - 1 = $80 - 1 = $7F
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("DCR A: $80 - 1 = $7F (negative to positive transition)");
    inspect_register(uut.u_cpu.a_out, 8'h7F, "A after DCR A ($80 - 1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result MSB clear (positive)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: carry still preserved");

    // =================================================================
    // TEST 6: All ones pattern decrement
    // Assembly: LDI A, #$FF; DCR A
    // Expected: A = $FF - 1 = $FE (Z=0, N=1, C unchanged)
    // =================================================================
    $display("\n--- TEST 6: All ones pattern decrement ($FF - 1) ---");
    
    // LDI A, #$FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A after LDI A, #$FF", DATA_WIDTH);

    // DCR A: A = A - 1 = $FF - 1 = $FE
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("DCR A: $FF - 1 = $FE (11111111 - 1 = 11111110)");
    inspect_register(uut.u_cpu.a_out, 8'hFE, "A after DCR A ($FF - 1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result MSB is set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: carry still preserved");

    // =================================================================
    // TEST 7: Alternating pattern (0x55) decrement
    // Assembly: LDI A, #$55; DCR A
    // Expected: A = $55 - 1 = $54 (Z=0, N=0, C unchanged)
    // =================================================================
    $display("\n--- TEST 7: Alternating pattern decrement ($55 - 1) ---");
    
    // LDI A, #$55
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h55, "A after LDI A, #$55", DATA_WIDTH);

    // DCR A: A = A - 1 = $55 - 1 = $54
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("DCR A: $55 - 1 = $54 (01010101 - 1 = 01010100)");
    inspect_register(uut.u_cpu.a_out, 8'h54, "A after DCR A ($55 - 1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result MSB clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: carry still preserved");

    // =================================================================
    // TEST 8: Alternating pattern (0xAA) decrement
    // Assembly: LDI A, #$AA; DCR A
    // Expected: A = $AA - 1 = $A9 (Z=0, N=1, C unchanged)
    // =================================================================
    $display("\n--- TEST 8: Alternating pattern decrement ($AA - 1) ---");
    
    // LDI A, #$AA
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hAA, "A after LDI A, #$AA", DATA_WIDTH);

    // DCR A: A = A - 1 = $AA - 1 = $A9
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("DCR A: $AA - 1 = $A9 (10101010 - 1 = 10101001)");
    inspect_register(uut.u_cpu.a_out, 8'hA9, "A after DCR A ($AA - 1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result MSB is set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: carry still preserved");

    // =================================================================
    // TEST 9: Maximum positive 7-bit value decrement
    // Assembly: LDI A, #$7F; DCR A
    // Expected: A = $7F - 1 = $7E (Z=0, N=0, C unchanged)
    // =================================================================
    $display("\n--- TEST 9: Maximum positive decrement ($7F - 1) ---");
    
    // LDI A, #$7F
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h7F, "A after LDI A, #$7F", DATA_WIDTH);

    // DCR A: A = A - 1 = $7F - 1 = $7E
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("DCR A: $7F - 1 = $7E (max positive - 1)");
    inspect_register(uut.u_cpu.a_out, 8'h7E, "A after DCR A ($7F - 1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result MSB clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: carry still preserved");

    // =================================================================
    // TEST 10: Power of 2 boundary test ($10 = 16)
    // Assembly: LDI A, #$10; DCR A
    // Expected: A = $10 - 1 = $0F (Z=0, N=0, C unchanged)
    // =================================================================
    $display("\n--- TEST 10: Power of 2 boundary ($10 - 1) ---");
    
    // LDI A, #$10
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h10, "A after LDI A, #$10", DATA_WIDTH);

    // DCR A: A = A - 1 = $10 - 1 = $0F
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("DCR A: $10 - 1 = $0F (power of 2 boundary)");
    inspect_register(uut.u_cpu.a_out, 8'h0F, "A after DCR A ($10 - 1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result MSB clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: carry still preserved");

    // =================================================================
    // TEST 11: Power of 2 boundary test ($08 = 8)
    // Assembly: LDI A, #$08; DCR A
    // Expected: A = $08 - 1 = $07 (Z=0, N=0, C unchanged)
    // =================================================================
    $display("\n--- TEST 11: Power of 2 boundary ($08 - 1) ---");
    
    // LDI A, #$08
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h08, "A after LDI A, #$08", DATA_WIDTH);

    // DCR A: A = A - 1 = $08 - 1 = $07
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("DCR A: $08 - 1 = $07 (power of 2 boundary)");
    inspect_register(uut.u_cpu.a_out, 8'h07, "A after DCR A ($08 - 1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result MSB clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: carry still preserved");

    // =================================================================
    // TEST 12: Carry flag preservation test with clear flag
    // Assembly: LDI A, #$05; CLC; DCR A
    // Expected: A = $05 - 1 = $04 (Z=0, N=0, C=0 preserved)
    // =================================================================
    $display("\n--- TEST 12: Carry flag preservation with clear ($05 - 1) ---");
    
    // LDI A, #$05
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h05, "A after LDI A, #$05", DATA_WIDTH);

    // CLC (clear carry to test preservation)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C flag clear after CLC");

    // DCR A: A = A - 1 = $05 - 1 = $04 (C should remain 0)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("DCR A: $05 - 1 = $04 (with C=0 preserved)");
    inspect_register(uut.u_cpu.a_out, 8'h04, "A after DCR A ($05 - 1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result MSB clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: carry preserved (unaffected)");

    // =================================================================
    // TEST 13: Register preservation final verification
    // Assembly: LDI A, #$03; DCR A
    // Expected: A = $03 - 1 = $02, B=$55, C=$AA unchanged from TEST 1
    // =================================================================
    $display("\n--- TEST 13: Final register preservation test ($03 - 1) ---");
    
    // LDI A, #$03
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h03, "A after LDI A, #$03", DATA_WIDTH);

    // DCR A: A = A - 1 = $03 - 1 = $02
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("DCR A: $03 - 1 = $02 (final verification)");
    inspect_register(uut.u_cpu.a_out, 8'h02, "A after DCR A ($03 - 1)", DATA_WIDTH);
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

    $display("DCR_A test finished.===========================\n\n");
    $display("All 13 test cases passed successfully!");
    $finish;
    // ============================ END TEST ==============================
  
  end

endmodule