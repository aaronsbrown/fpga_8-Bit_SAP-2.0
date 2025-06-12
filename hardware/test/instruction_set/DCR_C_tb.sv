`timescale 1ns/1ps
import test_utils_pkg::*; 
import arch_defs_pkg::*;  

// AIDEV-NOTE: Enhanced DCR_C testbench with 13 comprehensive test cases, systematic verification, and clear organization
module computer_tb;

  localparam string HEX_FILE = "../hardware/test/_fixtures_generated/DCR_C/ROM.hex";

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

    // ============================ BEGIN DCR_C COMPREHENSIVE TESTS ==============================
    $display("\n=== DCR_C Comprehensive Test Suite ===");
    $display("Testing DCR_C instruction functionality, edge cases, and flag behavior");
    $display("DCR_C: Decrement C (C=C-1), affects Z and N flags, Carry unaffected\n");

    // =================================================================
    // TEST 1: Basic decrement - positive number
    // Assembly: LDI C, #$02; LDI A, #$33; LDI B, #$55; SEC; DCR C
    // Expected: C = $02 - 1 = $01 (Z=0, N=0, Carry=1 preserved)
    // =================================================================
    $display("--- TEST 1: Basic decrement ($02 - 1) ---");
    
    // LDI C, #$02
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h02, "C after LDI C, #$02", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z flag clear after LDI C");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N flag clear after LDI C");

    // LDI A, #$33 (register preservation test setup)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h33, "A after LDI A, #$33", DATA_WIDTH);

    // LDI B, #$55 (register preservation test setup)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h55, "B after LDI B, #$55", DATA_WIDTH);

    // SEC (set carry to test preservation)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "Carry flag set after SEC");

    // DCR C: C = C - 1 = $02 - 1 = $01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("DCR C: $02 - 1 = $01");
    inspect_register(uut.u_cpu.c_out, 8'h01, "C after DCR C ($02 - 1)", DATA_WIDTH);
    inspect_register(uut.u_cpu.a_out, 8'h33, "A preserved during DCR C", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h55, "B preserved during DCR C", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result is positive");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "Carry=1: carry preserved (unaffected)");

    // =================================================================
    // TEST 2: Decrement resulting in zero
    // Assembly: LDI C, #$01; DCR C
    // Expected: C = $01 - 1 = $00 (Z=1, N=0, Carry unchanged)
    // =================================================================
    $display("\n--- TEST 2: Decrement resulting in zero ($01 - 1) ---");
    
    // LDI C, #$01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h01, "C after LDI C, #$01", DATA_WIDTH);

    // DCR C: C = C - 1 = $01 - 1 = $00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("DCR C: $01 - 1 = $00 (zero result)");
    inspect_register(uut.u_cpu.c_out, 8'h00, "C after DCR C ($01 - 1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "Z=1: result is zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result MSB is clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "Carry=1: carry still preserved");

    // =================================================================
    // TEST 3: Decrement zero (underflow to $FF)
    // Assembly: LDI C, #$00; DCR C
    // Expected: C = $00 - 1 = $FF (Z=0, N=1, Carry unchanged)
    // =================================================================
    $display("\n--- TEST 3: Decrement zero with underflow ($00 - 1) ---");
    
    // LDI C, #$00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h00, "C after LDI C, #$00", DATA_WIDTH);

    // DCR C: C = C - 1 = $00 - 1 = $FF (underflow)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("DCR C: $00 - 1 = $FF (underflow)");
    inspect_register(uut.u_cpu.c_out, 8'hFF, "C after DCR C ($00 - 1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result MSB is set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "Carry=1: carry still preserved");

    // =================================================================
    // TEST 4: Decrement from MSB set
    // Assembly: LDI C, #$81; DCR C
    // Expected: C = $81 - 1 = $80 (Z=0, N=1, Carry unchanged)
    // =================================================================
    $display("\n--- TEST 4: Decrement from MSB set ($81 - 1) ---");
    
    // LDI C, #$81
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h81, "C after LDI C, #$81", DATA_WIDTH);

    // DCR C: C = C - 1 = $81 - 1 = $80
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("DCR C: $81 - 1 = $80 (negative result)");
    inspect_register(uut.u_cpu.c_out, 8'h80, "C after DCR C ($81 - 1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result MSB is set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "Carry=1: carry still preserved");

    // =================================================================
    // TEST 5: Decrement from $80 (most negative) to $7F (positive)
    // Assembly: LDI C, #$80; DCR C
    // Expected: C = $80 - 1 = $7F (Z=0, N=0, Carry unchanged)
    // =================================================================
    $display("\n--- TEST 5: Decrement from most negative ($80 - 1) ---");
    
    // LDI C, #$80
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h80, "C after LDI C, #$80", DATA_WIDTH);

    // DCR C: C = C - 1 = $80 - 1 = $7F
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("DCR C: $80 - 1 = $7F (negative to positive transition)");
    inspect_register(uut.u_cpu.c_out, 8'h7F, "C after DCR C ($80 - 1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result MSB clear (positive)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "Carry=1: carry still preserved");

    // =================================================================
    // TEST 6: All ones pattern decrement
    // Assembly: LDI C, #$FF; DCR C
    // Expected: C = $FF - 1 = $FE (Z=0, N=1, Carry unchanged)
    // =================================================================
    $display("\n--- TEST 6: All ones pattern decrement ($FF - 1) ---");
    
    // LDI C, #$FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hFF, "C after LDI C, #$FF", DATA_WIDTH);

    // DCR C: C = C - 1 = $FF - 1 = $FE
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("DCR C: $FF - 1 = $FE (11111111 - 1 = 11111110)");
    inspect_register(uut.u_cpu.c_out, 8'hFE, "C after DCR C ($FF - 1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result MSB is set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "Carry=1: carry still preserved");

    // =================================================================
    // TEST 7: Alternating pattern (0x55) decrement
    // Assembly: LDI C, #$55; DCR C
    // Expected: C = $55 - 1 = $54 (Z=0, N=0, Carry unchanged)
    // =================================================================
    $display("\n--- TEST 7: Alternating pattern decrement ($55 - 1) ---");
    
    // LDI C, #$55
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h55, "C after LDI C, #$55", DATA_WIDTH);

    // DCR C: C = C - 1 = $55 - 1 = $54
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("DCR C: $55 - 1 = $54 (01010101 - 1 = 01010100)");
    inspect_register(uut.u_cpu.c_out, 8'h54, "C after DCR C ($55 - 1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result MSB clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "Carry=1: carry still preserved");

    // =================================================================
    // TEST 8: Alternating pattern (0xAA) decrement
    // Assembly: LDI C, #$AA; DCR C
    // Expected: C = $AA - 1 = $A9 (Z=0, N=1, Carry unchanged)
    // =================================================================
    $display("\n--- TEST 8: Alternating pattern decrement ($AA - 1) ---");
    
    // LDI C, #$AA
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hAA, "C after LDI C, #$AA", DATA_WIDTH);

    // DCR C: C = C - 1 = $AA - 1 = $A9
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("DCR C: $AA - 1 = $A9 (10101010 - 1 = 10101001)");
    inspect_register(uut.u_cpu.c_out, 8'hA9, "C after DCR C ($AA - 1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result MSB is set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "Carry=1: carry still preserved");

    // =================================================================
    // TEST 9: Maximum positive 7-bit value decrement
    // Assembly: LDI C, #$7F; DCR C
    // Expected: C = $7F - 1 = $7E (Z=0, N=0, Carry unchanged)
    // =================================================================
    $display("\n--- TEST 9: Maximum positive decrement ($7F - 1) ---");
    
    // LDI C, #$7F
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h7F, "C after LDI C, #$7F", DATA_WIDTH);

    // DCR C: C = C - 1 = $7F - 1 = $7E
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("DCR C: $7F - 1 = $7E (max positive - 1)");
    inspect_register(uut.u_cpu.c_out, 8'h7E, "C after DCR C ($7F - 1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result MSB clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "Carry=1: carry still preserved");

    // =================================================================
    // TEST 10: Power of 2 boundary test ($10 = 16)
    // Assembly: LDI C, #$10; DCR C
    // Expected: C = $10 - 1 = $0F (Z=0, N=0, Carry unchanged)
    // =================================================================
    $display("\n--- TEST 10: Power of 2 boundary ($10 - 1) ---");
    
    // LDI C, #$10
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h10, "C after LDI C, #$10", DATA_WIDTH);

    // DCR C: C = C - 1 = $10 - 1 = $0F
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("DCR C: $10 - 1 = $0F (power of 2 boundary)");
    inspect_register(uut.u_cpu.c_out, 8'h0F, "C after DCR C ($10 - 1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result MSB clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "Carry=1: carry still preserved");

    // =================================================================
    // TEST 11: Power of 2 boundary test ($08 = 8)
    // Assembly: LDI C, #$08; DCR C
    // Expected: C = $08 - 1 = $07 (Z=0, N=0, Carry unchanged)
    // =================================================================
    $display("\n--- TEST 11: Power of 2 boundary ($08 - 1) ---");
    
    // LDI C, #$08
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h08, "C after LDI C, #$08", DATA_WIDTH);

    // DCR C: C = C - 1 = $08 - 1 = $07
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("DCR C: $08 - 1 = $07 (power of 2 boundary)");
    inspect_register(uut.u_cpu.c_out, 8'h07, "C after DCR C ($08 - 1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result MSB clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "Carry=1: carry still preserved");

    // =================================================================
    // TEST 12: Carry flag preservation test with clear flag
    // Assembly: LDI C, #$05; CLC; DCR C
    // Expected: C = $05 - 1 = $04 (Z=0, N=0, Carry=0 preserved)
    // =================================================================
    $display("\n--- TEST 12: Carry flag preservation with clear ($05 - 1) ---");
    
    // LDI C, #$05
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h05, "C after LDI C, #$05", DATA_WIDTH);

    // CLC (clear carry to test preservation)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "Carry flag clear after CLC");

    // DCR C: C = C - 1 = $05 - 1 = $04 (Carry should remain 0)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("DCR C: $05 - 1 = $04 (with Carry=0 preserved)");
    inspect_register(uut.u_cpu.c_out, 8'h04, "C after DCR C ($05 - 1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result MSB clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "Carry=0: carry preserved (unaffected)");

    // =================================================================
    // TEST 13: Register preservation final verification
    // Assembly: LDI C, #$03; DCR C
    // Expected: C = $03 - 1 = $02, A=$33, B=$55 unchanged from TEST 1
    // =================================================================
    $display("\n--- TEST 13: Final register preservation test ($03 - 1) ---");
    
    // LDI C, #$03
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h03, "C after LDI C, #$03", DATA_WIDTH);

    // DCR C: C = C - 1 = $03 - 1 = $02
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("DCR C: $03 - 1 = $02 (final verification)");
    inspect_register(uut.u_cpu.c_out, 8'h02, "C after DCR C ($03 - 1)", DATA_WIDTH);
    inspect_register(uut.u_cpu.a_out, 8'h33, "A register still preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h55, "B register still preserved", DATA_WIDTH);
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

    $display("DCR_C test finished.===========================\n\n");
    $display("All 13 test cases passed successfully!");
    $finish;
    // ============================ END TEST ==============================
  
  end

endmodule