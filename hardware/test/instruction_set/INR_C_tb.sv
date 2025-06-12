`timescale 1ns/1ps
import test_utils_pkg::*; 
import arch_defs_pkg::*;  

// AIDEV-NOTE: Enhanced INR_C testbench with 13 comprehensive test cases, systematic verification, and clear organization
module computer_tb;

  localparam string HEX_FILE = "../hardware/test/_fixtures_generated/INR_C/ROM.hex";

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

    // ============================ BEGIN INR_C COMPREHENSIVE TESTS ==============================
    $display("\n=== INR_C Comprehensive Test Suite ===");
    $display("Testing INR_C instruction functionality, edge cases, and flag behavior");
    $display("INR_C: Increment C (C=C+1), affects Z and N flags, Carry unaffected\n");

    // =================================================================
    // TEST 1: Basic increment - positive number
    // Assembly: LDI C, #$01; LDI A, #$55; LDI B, #$AA; SEC; INR C
    // Expected: C = $01 + 1 = $02 (Z=0, N=0, Carry=1 preserved)
    // =================================================================
    $display("--- TEST 1: Basic increment ($01 + 1) ---");
    
    // LDI C, #$01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h01, "C after LDI C, #$01", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z flag clear after LDI C");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N flag clear after LDI C");

    // LDI A, #$55 (register preservation test setup)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h55, "A after LDI A, #$55", DATA_WIDTH);

    // LDI B, #$AA (register preservation test setup)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'hAA, "B after LDI B, #$AA", DATA_WIDTH);

    // SEC (set carry to test preservation)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "Carry flag set after SEC");

    // INR C: C = C + 1 = $01 + 1 = $02
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("INR C: $01 + 1 = $02");
    inspect_register(uut.u_cpu.c_out, 8'h02, "C after INR C ($01 + 1)", DATA_WIDTH);
    inspect_register(uut.u_cpu.a_out, 8'h55, "A preserved during INR C", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'hAA, "B preserved during INR C", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result is positive");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "Carry=1: carry preserved (unaffected)");

    // =================================================================
    // TEST 2: Increment resulting in zero (overflow from $FF)
    // Assembly: LDI C, #$FF; INR C
    // Expected: C = $FF + 1 = $00 (Z=1, N=0, Carry unchanged)
    // =================================================================
    $display("\n--- TEST 2: Increment with overflow ($FF + 1) ---");
    
    // LDI C, #$FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hFF, "C after LDI C, #$FF", DATA_WIDTH);

    // INR C: C = C + 1 = $FF + 1 = $00 (overflow)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("INR C: $FF + 1 = $00 (overflow to zero)");
    inspect_register(uut.u_cpu.c_out, 8'h00, "C after INR C ($FF + 1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "Z=1: result is zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result MSB is clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "Carry=1: carry still preserved");

    // =================================================================
    // TEST 3: Zero increment
    // Assembly: LDI C, #$00; INR C
    // Expected: C = $00 + 1 = $01 (Z=0, N=0, Carry unchanged)
    // =================================================================
    $display("\n--- TEST 3: Zero increment ($00 + 1) ---");
    
    // LDI C, #$00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h00, "C after LDI C, #$00", DATA_WIDTH);

    // INR C: C = C + 1 = $00 + 1 = $01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("INR C: $00 + 1 = $01");
    inspect_register(uut.u_cpu.c_out, 8'h01, "C after INR C ($00 + 1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result MSB is clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "Carry=1: carry still preserved");

    // =================================================================
    // TEST 4: Increment from $7F (max positive) to $80 (negative)
    // Assembly: LDI C, #$7F; INR C
    // Expected: C = $7F + 1 = $80 (Z=0, N=1, Carry unchanged)
    // =================================================================
    $display("\n--- TEST 4: Max positive to negative ($7F + 1) ---");
    
    // LDI C, #$7F
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h7F, "C after LDI C, #$7F", DATA_WIDTH);

    // INR C: C = C + 1 = $7F + 1 = $80
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("INR C: $7F + 1 = $80 (positive to negative transition)");
    inspect_register(uut.u_cpu.c_out, 8'h80, "C after INR C ($7F + 1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result MSB set (negative)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "Carry=1: carry still preserved");

    // =================================================================
    // TEST 5: Increment negative value from MSB set
    // Assembly: LDI C, #$80; INR C
    // Expected: C = $80 + 1 = $81 (Z=0, N=1, Carry unchanged)
    // =================================================================
    $display("\n--- TEST 5: Increment from most negative ($80 + 1) ---");
    
    // LDI C, #$80
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h80, "C after LDI C, #$80", DATA_WIDTH);

    // INR C: C = C + 1 = $80 + 1 = $81
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("INR C: $80 + 1 = $81 (negative stays negative)");
    inspect_register(uut.u_cpu.c_out, 8'h81, "C after INR C ($80 + 1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result MSB still set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "Carry=1: carry still preserved");

    // =================================================================
    // TEST 6: Increment from $FE to $FF (all ones result)
    // Assembly: LDI C, #$FE; INR C
    // Expected: C = $FE + 1 = $FF (Z=0, N=1, Carry unchanged)
    // =================================================================
    $display("\n--- TEST 6: Increment to all ones ($FE + 1) ---");
    
    // LDI C, #$FE
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hFE, "C after LDI C, #$FE", DATA_WIDTH);

    // INR C: C = C + 1 = $FE + 1 = $FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("INR C: $FE + 1 = $FF (11111110 + 1 = 11111111)");
    inspect_register(uut.u_cpu.c_out, 8'hFF, "C after INR C ($FE + 1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result MSB is set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "Carry=1: carry still preserved");

    // =================================================================
    // TEST 7: Alternating pattern (0x54) increment
    // Assembly: LDI C, #$54; INR C
    // Expected: C = $54 + 1 = $55 (Z=0, N=0, Carry unchanged)
    // =================================================================
    $display("\n--- TEST 7: Alternating pattern increment ($54 + 1) ---");
    
    // LDI C, #$54
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h54, "C after LDI C, #$54", DATA_WIDTH);

    // INR C: C = C + 1 = $54 + 1 = $55
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("INR C: $54 + 1 = $55 (01010100 + 1 = 01010101)");
    inspect_register(uut.u_cpu.c_out, 8'h55, "C after INR C ($54 + 1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result MSB clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "Carry=1: carry still preserved");

    // =================================================================
    // TEST 8: Alternating pattern (0xA9) increment
    // Assembly: LDI C, #$A9; INR C
    // Expected: C = $A9 + 1 = $AA (Z=0, N=1, Carry unchanged)
    // =================================================================
    $display("\n--- TEST 8: Alternating pattern increment ($A9 + 1) ---");
    
    // LDI C, #$A9
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hA9, "C after LDI C, #$A9", DATA_WIDTH);

    // INR C: C = C + 1 = $A9 + 1 = $AA
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("INR C: $A9 + 1 = $AA (10101001 + 1 = 10101010)");
    inspect_register(uut.u_cpu.c_out, 8'hAA, "C after INR C ($A9 + 1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result MSB is set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "Carry=1: carry still preserved");

    // =================================================================
    // TEST 9: Increment $7E to $7F (stays positive)
    // Assembly: LDI C, #$7E; INR C
    // Expected: C = $7E + 1 = $7F (Z=0, N=0, Carry unchanged)
    // =================================================================
    $display("\n--- TEST 9: High positive increment ($7E + 1) ---");
    
    // LDI C, #$7E
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h7E, "C after LDI C, #$7E", DATA_WIDTH);

    // INR C: C = C + 1 = $7E + 1 = $7F
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("INR C: $7E + 1 = $7F (stays positive)");
    inspect_register(uut.u_cpu.c_out, 8'h7F, "C after INR C ($7E + 1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result MSB clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "Carry=1: carry still preserved");

    // =================================================================
    // TEST 10: Power of 2 boundary test ($0F + 1)
    // Assembly: LDI C, #$0F; INR C
    // Expected: C = $0F + 1 = $10 (Z=0, N=0, Carry unchanged)
    // =================================================================
    $display("\n--- TEST 10: Power of 2 boundary ($0F + 1) ---");
    
    // LDI C, #$0F
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h0F, "C after LDI C, #$0F", DATA_WIDTH);

    // INR C: C = C + 1 = $0F + 1 = $10
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("INR C: $0F + 1 = $10 (power of 2 boundary)");
    inspect_register(uut.u_cpu.c_out, 8'h10, "C after INR C ($0F + 1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result MSB clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "Carry=1: carry still preserved");

    // =================================================================
    // TEST 11: Power of 2 boundary test ($07 + 1)
    // Assembly: LDI C, #$07; INR C
    // Expected: C = $07 + 1 = $08 (Z=0, N=0, Carry unchanged)
    // =================================================================
    $display("\n--- TEST 11: Power of 2 boundary ($07 + 1) ---");
    
    // LDI C, #$07
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h07, "C after LDI C, #$07", DATA_WIDTH);

    // INR C: C = C + 1 = $07 + 1 = $08
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("INR C: $07 + 1 = $08 (power of 2 boundary)");
    inspect_register(uut.u_cpu.c_out, 8'h08, "C after INR C ($07 + 1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result MSB clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "Carry=1: carry still preserved");

    // =================================================================
    // TEST 12: Carry flag preservation test with clear flag
    // Assembly: LDI C, #$04; CLC; INR C
    // Expected: C = $04 + 1 = $05 (Z=0, N=0, Carry=0 preserved)
    // =================================================================
    $display("\n--- TEST 12: Carry flag preservation with clear ($04 + 1) ---");
    
    // LDI C, #$04
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h04, "C after LDI C, #$04", DATA_WIDTH);

    // CLC (clear carry to test preservation)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "Carry flag clear after CLC");

    // INR C: C = C + 1 = $04 + 1 = $05 (Carry should remain 0)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("INR C: $04 + 1 = $05 (with Carry=0 preserved)");
    inspect_register(uut.u_cpu.c_out, 8'h05, "C after INR C ($04 + 1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result MSB clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "Carry=0: carry preserved (unaffected)");

    // =================================================================
    // TEST 13: Register preservation final verification
    // Assembly: LDI C, #$02; INR C
    // Expected: C = $02 + 1 = $03, A=$55, B=$AA unchanged from TEST 1
    // =================================================================
    $display("\n--- TEST 13: Final register preservation test ($02 + 1) ---");
    
    // LDI C, #$02
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h02, "C after LDI C, #$02", DATA_WIDTH);

    // INR C: C = C + 1 = $02 + 1 = $03
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("INR C: $02 + 1 = $03 (final verification)");
    inspect_register(uut.u_cpu.c_out, 8'h03, "C after INR C ($02 + 1)", DATA_WIDTH);
    inspect_register(uut.u_cpu.a_out, 8'h55, "A register still preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'hAA, "B register still preserved", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result MSB clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "Carry=0: carry still preserved");

    // =================================================================
    // HALT verification - ensure CPU properly stops
    // =================================================================
    $display("\n--- Verifying HALT instruction ---");
    run_until_halt(150);  // Increased timeout for comprehensive test suite
    $display("CPU halted successfully");
    
    // Visual buffer for waveform inspection
    repeat(5) @(posedge clk);

    $display("INR_C test finished.===========================\n\n");
    $display("All 13 test cases passed successfully!");
    $finish;
    // ============================ END TEST ==============================
  
  end

endmodule