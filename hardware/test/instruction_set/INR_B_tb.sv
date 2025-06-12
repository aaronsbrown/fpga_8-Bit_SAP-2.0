`timescale 1ns/1ps
import test_utils_pkg::*; 
import arch_defs_pkg::*;  

// AIDEV-NOTE: Enhanced INR_B testbench with 13 comprehensive test cases, systematic verification, and clear organization
module computer_tb;

  localparam string HEX_FILE = "../hardware/test/_fixtures_generated/INR_B/ROM.hex";

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

    // ============================ BEGIN INR_B COMPREHENSIVE TESTS ==============================
    $display("\n=== INR_B Comprehensive Test Suite ===");
    $display("Testing INR_B instruction functionality, edge cases, and flag behavior");
    $display("INR_B: Increment B (B=B+1), affects Z and N flags, C unaffected\n");

    // =================================================================
    // TEST 1: Basic increment - positive number
    // Assembly: LDI B, #$01; LDI A, #$55; LDI C, #$AA; SEC; INR B
    // Expected: B = $01 + 1 = $02 (Z=0, N=0, C=1 preserved)
    // =================================================================
    $display("--- TEST 1: Basic increment ($01 + 1) ---");
    
    // LDI B, #$01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h01, "B after LDI B, #$01", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z flag clear after LDI B");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N flag clear after LDI B");

    // LDI A, #$55 (register preservation test setup)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h55, "A after LDI A, #$55", DATA_WIDTH);

    // LDI C, #$AA (register preservation test setup)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hAA, "C after LDI C, #$AA", DATA_WIDTH);

    // SEC (set carry to test preservation)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C flag set after SEC");

    // INR B: B = B + 1 = $01 + 1 = $02
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("INR B: $01 + 1 = $02");
    inspect_register(uut.u_cpu.b_out, 8'h02, "B after INR B ($01 + 1)", DATA_WIDTH);
    inspect_register(uut.u_cpu.a_out, 8'h55, "A preserved during INR B", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hAA, "C preserved during INR B", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result is positive");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: carry preserved (unaffected)");

    // =================================================================
    // TEST 2: Increment resulting in zero (overflow from $FF)
    // Assembly: LDI B, #$FF; INR B
    // Expected: B = $FF + 1 = $00 (Z=1, N=0, C unchanged)
    // =================================================================
    $display("\n--- TEST 2: Increment with overflow ($FF + 1) ---");
    
    // LDI B, #$FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'hFF, "B after LDI B, #$FF", DATA_WIDTH);

    // INR B: B = B + 1 = $FF + 1 = $00 (overflow)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("INR B: $FF + 1 = $00 (overflow to zero)");
    inspect_register(uut.u_cpu.b_out, 8'h00, "B after INR B ($FF + 1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "Z=1: result is zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result MSB is clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: carry still preserved");

    // =================================================================
    // TEST 3: Zero increment
    // Assembly: LDI B, #$00; INR B
    // Expected: B = $00 + 1 = $01 (Z=0, N=0, C unchanged)
    // =================================================================
    $display("\n--- TEST 3: Zero increment ($00 + 1) ---");
    
    // LDI B, #$00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h00, "B after LDI B, #$00", DATA_WIDTH);

    // INR B: B = B + 1 = $00 + 1 = $01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("INR B: $00 + 1 = $01");
    inspect_register(uut.u_cpu.b_out, 8'h01, "B after INR B ($00 + 1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result MSB is clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: carry still preserved");

    // =================================================================
    // TEST 4: Increment from $7F (max positive) to $80 (negative)
    // Assembly: LDI B, #$7F; INR B
    // Expected: B = $7F + 1 = $80 (Z=0, N=1, C unchanged)
    // =================================================================
    $display("\n--- TEST 4: Max positive to negative ($7F + 1) ---");
    
    // LDI B, #$7F
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h7F, "B after LDI B, #$7F", DATA_WIDTH);

    // INR B: B = B + 1 = $7F + 1 = $80
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("INR B: $7F + 1 = $80 (positive to negative transition)");
    inspect_register(uut.u_cpu.b_out, 8'h80, "B after INR B ($7F + 1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result MSB set (negative)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: carry still preserved");

    // =================================================================
    // TEST 5: Increment negative value from MSB set
    // Assembly: LDI B, #$80; INR B
    // Expected: B = $80 + 1 = $81 (Z=0, N=1, C unchanged)
    // =================================================================
    $display("\n--- TEST 5: Increment from most negative ($80 + 1) ---");
    
    // LDI B, #$80
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h80, "B after LDI B, #$80", DATA_WIDTH);

    // INR B: B = B + 1 = $80 + 1 = $81
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("INR B: $80 + 1 = $81 (negative stays negative)");
    inspect_register(uut.u_cpu.b_out, 8'h81, "B after INR B ($80 + 1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result MSB still set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: carry still preserved");

    // =================================================================
    // TEST 6: Increment from $FE to $FF (all ones result)
    // Assembly: LDI B, #$FE; INR B
    // Expected: B = $FE + 1 = $FF (Z=0, N=1, C unchanged)
    // =================================================================
    $display("\n--- TEST 6: Increment to all ones ($FE + 1) ---");
    
    // LDI B, #$FE
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'hFE, "B after LDI B, #$FE", DATA_WIDTH);

    // INR B: B = B + 1 = $FE + 1 = $FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("INR B: $FE + 1 = $FF (11111110 + 1 = 11111111)");
    inspect_register(uut.u_cpu.b_out, 8'hFF, "B after INR B ($FE + 1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result MSB is set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: carry still preserved");

    // =================================================================
    // TEST 7: Alternating pattern (0x54) increment
    // Assembly: LDI B, #$54; INR B
    // Expected: B = $54 + 1 = $55 (Z=0, N=0, C unchanged)
    // =================================================================
    $display("\n--- TEST 7: Alternating pattern increment ($54 + 1) ---");
    
    // LDI B, #$54
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h54, "B after LDI B, #$54", DATA_WIDTH);

    // INR B: B = B + 1 = $54 + 1 = $55
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("INR B: $54 + 1 = $55 (01010100 + 1 = 01010101)");
    inspect_register(uut.u_cpu.b_out, 8'h55, "B after INR B ($54 + 1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result MSB clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: carry still preserved");

    // =================================================================
    // TEST 8: Alternating pattern (0xA9) increment
    // Assembly: LDI B, #$A9; INR B
    // Expected: B = $A9 + 1 = $AA (Z=0, N=1, C unchanged)
    // =================================================================
    $display("\n--- TEST 8: Alternating pattern increment ($A9 + 1) ---");
    
    // LDI B, #$A9
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'hA9, "B after LDI B, #$A9", DATA_WIDTH);

    // INR B: B = B + 1 = $A9 + 1 = $AA
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("INR B: $A9 + 1 = $AA (10101001 + 1 = 10101010)");
    inspect_register(uut.u_cpu.b_out, 8'hAA, "B after INR B ($A9 + 1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result MSB is set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: carry still preserved");

    // =================================================================
    // TEST 9: Increment $7E to $7F (stays positive)
    // Assembly: LDI B, #$7E; INR B
    // Expected: B = $7E + 1 = $7F (Z=0, N=0, C unchanged)
    // =================================================================
    $display("\n--- TEST 9: High positive increment ($7E + 1) ---");
    
    // LDI B, #$7E
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h7E, "B after LDI B, #$7E", DATA_WIDTH);

    // INR B: B = B + 1 = $7E + 1 = $7F
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("INR B: $7E + 1 = $7F (stays positive)");
    inspect_register(uut.u_cpu.b_out, 8'h7F, "B after INR B ($7E + 1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result MSB clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: carry still preserved");

    // =================================================================
    // TEST 10: Power of 2 boundary test ($0F + 1)
    // Assembly: LDI B, #$0F; INR B
    // Expected: B = $0F + 1 = $10 (Z=0, N=0, C unchanged)
    // =================================================================
    $display("\n--- TEST 10: Power of 2 boundary ($0F + 1) ---");
    
    // LDI B, #$0F
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h0F, "B after LDI B, #$0F", DATA_WIDTH);

    // INR B: B = B + 1 = $0F + 1 = $10
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("INR B: $0F + 1 = $10 (power of 2 boundary)");
    inspect_register(uut.u_cpu.b_out, 8'h10, "B after INR B ($0F + 1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result MSB clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: carry still preserved");

    // =================================================================
    // TEST 11: Power of 2 boundary test ($07 + 1)
    // Assembly: LDI B, #$07; INR B
    // Expected: B = $07 + 1 = $08 (Z=0, N=0, C unchanged)
    // =================================================================
    $display("\n--- TEST 11: Power of 2 boundary ($07 + 1) ---");
    
    // LDI B, #$07
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h07, "B after LDI B, #$07", DATA_WIDTH);

    // INR B: B = B + 1 = $07 + 1 = $08
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("INR B: $07 + 1 = $08 (power of 2 boundary)");
    inspect_register(uut.u_cpu.b_out, 8'h08, "B after INR B ($07 + 1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result MSB clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: carry still preserved");

    // =================================================================
    // TEST 12: Carry flag preservation test with clear flag
    // Assembly: LDI B, #$04; CLC; INR B
    // Expected: B = $04 + 1 = $05 (Z=0, N=0, C=0 preserved)
    // =================================================================
    $display("\n--- TEST 12: Carry flag preservation with clear ($04 + 1) ---");
    
    // LDI B, #$04
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h04, "B after LDI B, #$04", DATA_WIDTH);

    // CLC (clear carry to test preservation)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C flag clear after CLC");

    // INR B: B = B + 1 = $04 + 1 = $05 (C should remain 0)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("INR B: $04 + 1 = $05 (with C=0 preserved)");
    inspect_register(uut.u_cpu.b_out, 8'h05, "B after INR B ($04 + 1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result MSB clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: carry preserved (unaffected)");

    // =================================================================
    // TEST 13: Register preservation final verification
    // Assembly: LDI B, #$02; INR B
    // Expected: B = $02 + 1 = $03, A=$55, C=$AA unchanged from TEST 1
    // =================================================================
    $display("\n--- TEST 13: Final register preservation test ($02 + 1) ---");
    
    // LDI B, #$02
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h02, "B after LDI B, #$02", DATA_WIDTH);

    // INR B: B = B + 1 = $02 + 1 = $03
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("INR B: $02 + 1 = $03 (final verification)");
    inspect_register(uut.u_cpu.b_out, 8'h03, "B after INR B ($02 + 1)", DATA_WIDTH);
    inspect_register(uut.u_cpu.a_out, 8'h55, "A register still preserved", DATA_WIDTH);
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

    $display("INR_B test finished.===========================\n\n");
    $display("All 13 test cases passed successfully!");
    $finish;
    // ============================ END TEST ==============================
  
  end

endmodule