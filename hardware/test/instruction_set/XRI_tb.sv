`timescale 1ns/1ps
import test_utils_pkg::*; 
import arch_defs_pkg::*;  

module computer_tb;

  localparam string HEX_FILE = "../hardware/test/_fixtures_generated/XRI/ROM.hex";

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

    // ============================ BEGIN XRI COMPREHENSIVE TESTS ==============================
    $display("\n=== XRI (Bitwise Exclusive OR A with Immediate) Comprehensive Test Suite ===");
    $display("Testing XRI instruction: A = A ^ immediate");
    $display("Flags: Z=+/- (result), N=+/- (result), C=0 (always cleared)\n");

    // =================================================================
    // TEST 1: Basic XOR operation - A=$00 ^ #$FF = $FF
    // Expected: A=$FF, Z=0, N=1, C=0
    // =================================================================
    $display("--- TEST 1: Basic XOR operation ($00 ^ #$FF = $FF) ---");
    
    // LDI A, #$00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "A after LDI A, #$00", DATA_WIDTH);

    // LDI B, #$BB (preservation test)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'hBB, "B after LDI B, #$BB", DATA_WIDTH);

    // LDI C, #$CC (preservation test)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hCC, "C after LDI C, #$CC", DATA_WIDTH);

    // XRI #$FF: $00 ^ $FF = $FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("XRI #$FF: $00 (00000000) ^ $FF (11111111) = $FF (11111111)");
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A after XRI #$FF ($00 ^ $FF)", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'hBB, "B preserved during XRI", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hCC, "C preserved during XRI", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $FF is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result $FF MSB is set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: XRI clears carry");

    // =================================================================
    // TEST 2: XOR operation resulting in zero - A=$FF ^ #$FF = $00
    // Expected: A=$00, Z=1, N=0, C=0
    // =================================================================
    $display("\n--- TEST 2: XOR operation resulting in zero ($FF ^ #$FF = $00) ---");
    
    // LDI A, #$FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A after LDI A, #$FF", DATA_WIDTH);

    // XRI #$FF: $FF ^ $FF = $00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("XRI #$FF: $FF (11111111) ^ $FF (11111111) = $00 (00000000)");
    inspect_register(uut.u_cpu.a_out, 8'h00, "A after XRI #$FF ($FF ^ $FF)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "Z=1: result $00 is zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result $00 MSB is clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: XRI clears carry");

    // =================================================================
    // TEST 3: Alternating pattern - A=$55 ^ #$AA = $FF
    // Expected: A=$FF, Z=0, N=1, C=0
    // =================================================================
    $display("\n--- TEST 3: Alternating pattern ($55 ^ #$AA = $FF) ---");
    
    // LDI A, #$55
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h55, "A after LDI A, #$55", DATA_WIDTH);

    // XRI #$AA: $55 ^ $AA = $FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("XRI #$AA: $55 (01010101) ^ $AA (10101010) = $FF (11111111)");
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A after XRI #$AA ($55 ^ $AA)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $FF is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result $FF MSB is set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: XRI clears carry");

    // =================================================================
    // TEST 4: Same value XOR - A=$42 ^ #$42 = $00
    // Expected: A=$00, Z=1, N=0, C=0
    // =================================================================
    $display("\n--- TEST 4: Same value XOR ($42 ^ #$42 = $00) ---");
    
    // LDI A, #$42
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h42, "A after LDI A, #$42", DATA_WIDTH);

    // XRI #$42: $42 ^ $42 = $00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("XRI #$42: $42 (01000010) ^ $42 (01000010) = $00 (00000000)");
    inspect_register(uut.u_cpu.a_out, 8'h00, "A after XRI #$42 ($42 ^ $42)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "Z=1: result $00 is zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result $00 MSB is clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: XRI clears carry");

    // =================================================================
    // TEST 5: Single bit operations - A=$01 ^ #$80 = $81
    // Expected: A=$81, Z=0, N=1, C=0
    // =================================================================
    $display("\n--- TEST 5: Single bit operations ($01 ^ #$80 = $81) ---");
    
    // LDI A, #$01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h01, "A after LDI A, #$01", DATA_WIDTH);

    // XRI #$80: $01 ^ $80 = $81
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("XRI #$80: $01 (00000001) ^ $80 (10000000) = $81 (10000001)");
    inspect_register(uut.u_cpu.a_out, 8'h81, "A after XRI #$80 ($01 ^ $80)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $81 is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result $81 MSB is set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: XRI clears carry");

    // =================================================================
    // TEST 6: Carry flag clearing test - set carry, then XOR
    // Expected: A=$7F, Z=0, N=0, C=0 (carry cleared by XRI)
    // =================================================================
    $display("\n--- TEST 6: Carry flag clearing test (SEC then $3F ^ #$40 = $7F) ---");
    
    // SEC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: carry set by SEC");

    // LDI A, #$3F
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h3F, "A after LDI A, #$3F", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: carry preserved during LDI");

    // XRI #$40: $3F ^ $40 = $7F (and C should be cleared)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("XRI #$40: $3F (00111111) ^ $40 (01000000) = $7F (01111111), C cleared");
    inspect_register(uut.u_cpu.a_out, 8'h7F, "A after XRI #$40 ($3F ^ $40)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $7F is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result $7F MSB is clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: XRI clears carry flag");

    // =================================================================
    // TEST 7: XOR with zero - A=$80 ^ #$00 = $80
    // Expected: A=$80, Z=0, N=1, C=0
    // =================================================================
    $display("\n--- TEST 7: XOR with zero ($80 ^ #$00 = $80) ---");
    
    // LDI A, #$80
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h80, "A after LDI A, #$80", DATA_WIDTH);

    // XRI #$00: $80 ^ $00 = $80
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("XRI #$00: $80 (10000000) ^ $00 (00000000) = $80 (10000000)");
    inspect_register(uut.u_cpu.a_out, 8'h80, "A after XRI #$00 ($80 ^ $00)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $80 is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result $80 MSB is set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: XRI clears carry");

    // =================================================================
    // TEST 8: Complex bit pattern - A=$69 ^ #$96 = $FF
    // Expected: A=$FF, Z=0, N=1, C=0
    // =================================================================
    $display("\n--- TEST 8: Complex bit pattern ($69 ^ #$96 = $FF) ---");
    
    // LDI A, #$69
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h69, "A after LDI A, #$69", DATA_WIDTH);

    // XRI #$96: $69 ^ $96 = $FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("XRI #$96: $69 (01101001) ^ $96 (10010110) = $FF (11111111)");
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A after XRI #$96 ($69 ^ $96)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $FF is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result $FF MSB is set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: XRI clears carry");

    // =================================================================
    // TEST 9: Register preservation test
    // Expected: B=$5A, C=$5A preserved, A=$66
    // =================================================================
    $display("\n--- TEST 9: Register preservation test ($3C ^ #$5A = $66) ---");
    
    // LDI A, #$3C
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h3C, "A after LDI A, #$3C", DATA_WIDTH);

    // LDI B, #$5A
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h5A, "B after LDI B, #$5A", DATA_WIDTH);

    // LDI C, #$5A
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h5A, "C after LDI C, #$5A", DATA_WIDTH);

    // XRI #$5A: $3C ^ $5A = $66
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("XRI #$5A: $3C (00111100) ^ $5A (01011010) = $66 (01100110)");
    inspect_register(uut.u_cpu.a_out, 8'h66, "A after XRI #$5A ($3C ^ $5A)", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h5A, "B preserved during XRI", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'h5A, "C preserved during XRI", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $66 is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result $66 MSB is clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: XRI clears carry");

    // =================================================================
    // TEST 10: Sequential XOR operations to verify no side effects
    // =================================================================
    $display("\n--- TEST 10: Sequential XOR operations ---");
    
    // LDI A, #$01; XRI #$02 -> A=$03
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h01, "A after LDI A, #$01", DATA_WIDTH);
    
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("1st XRI #$02: $01 ^ $02 = $03");
    inspect_register(uut.u_cpu.a_out, 8'h03, "A after 1st XRI #$02", DATA_WIDTH);
    
    // XRI #$04 -> A=$07
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("2nd XRI #$04: $03 ^ $04 = $07");
    inspect_register(uut.u_cpu.a_out, 8'h07, "A after 2nd XRI #$04", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: sequential result non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: sequential result positive");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: XRI clears carry");

    // =================================================================
    // TEST 11: Boundary value testing - A=$7F ^ #$80 = $FF
    // Expected: A=$FF, Z=0, N=1, C=0
    // =================================================================
    $display("\n--- TEST 11: Boundary value testing ($7F ^ #$80 = $FF) ---");
    
    // LDI A, #$7F
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h7F, "A after LDI A, #$7F", DATA_WIDTH);

    // XRI #$80: $7F ^ $80 = $FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("XRI #$80: $7F (01111111) ^ $80 (10000000) = $FF (11111111)");
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A after XRI #$80 ($7F ^ $80)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $FF is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result $FF MSB is set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: XRI clears carry");

    // =================================================================
    // TEST 12: Final flag state verification with carry clearing
    // Expected: A=$00, Z=1, N=0, C=0 (carry cleared even when set before)
    // =================================================================
    $display("\n--- TEST 12: Final flag state verification (SEC then $AA ^ #$AA = $00) ---");
    
    // SEC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: carry set by SEC");

    // LDI A, #$AA
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hAA, "A after LDI A, #$AA", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: LDI sets negative flag");

    // XRI #$AA: $AA ^ $AA = $00 (and C should be cleared)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("XRI #$AA: $AA (10101010) ^ $AA (10101010) = $00 (00000000), C cleared");
    inspect_register(uut.u_cpu.a_out, 8'h00, "A after final XRI #$AA", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "Z=1: result $00 is zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result $00 MSB is clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: XRI clears carry even when set");

    // =================================================================
    // HALT verification - ensure CPU properly stops
    // =================================================================
    $display("\n--- Verifying HALT instruction ---");
    run_until_halt(100);  // Timeout for comprehensive test suite
    $display("CPU halted successfully");
    
    // Visual buffer for waveform inspection
    repeat(5) @(posedge clk);

    $display("\n=== XRI (Bitwise Exclusive OR A with Immediate) Test Summary ===");
    $display("✓ Basic XOR operations with various bit patterns");
    $display("✓ Zero result verification (Z flag) - same values XOR");
    $display("✓ Negative result verification (N flag)");
    $display("✓ Carry flag clearing behavior (C always 0)");
    $display("✓ Register preservation (B, C unchanged)");
    $display("✓ Alternating and complementary bit patterns");
    $display("✓ Single bit operations (LSB, MSB)");
    $display("✓ Sequential operations without side effects");
    $display("✓ Boundary value testing");
    $display("✓ Complex bit pattern verification");
    $display("✓ XOR-specific properties (A^A=0, A^0=A)");
    $display("XRI test finished.===========================\n\n");
    $finish;
    // ============================ END TEST ==============================
  
  end

endmodule