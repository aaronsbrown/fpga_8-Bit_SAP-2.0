`timescale 1ns/1ps
import test_utils_pkg::*; 
import arch_defs_pkg::*;  

module computer_tb;

  localparam string HEX_FILE = "../hardware/test/_fixtures_generated/XRA_C/ROM.hex";

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

    // ============================ BEGIN XRA_C COMPREHENSIVE TESTS ==============================
    $display("\n=== XRA_C (Bitwise Exclusive OR A with C) Comprehensive Test Suite ===");
    $display("Testing XRA_C instruction: A = A ^ C");
    $display("Flags: Z=+/- (result), N=+/- (result), C=0 (always cleared)\n");

    // =================================================================
    // TEST 1: Basic XOR operation - A=$00 ^ C=$FF = $FF
    // Expected: A=$FF, Z=0, N=1, C=0
    // =================================================================
    $display("--- TEST 1: Basic XOR operation ($00 ^ $FF = $FF) ---");
    
    // LDI A, #$00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "A after LDI A, #$00", DATA_WIDTH);

    // LDI C, #$FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hFF, "C after LDI C, #$FF", DATA_WIDTH);

    // LDI B, #$BB (preservation test)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'hBB, "B after LDI B, #$BB", DATA_WIDTH);

    // XRA C: $00 ^ $FF = $FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("XRA C: $00 (00000000) ^ $FF (11111111) = $FF (11111111)");
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A after XRA C ($00 ^ $FF)", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hFF, "C preserved during XRA C", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'hBB, "B preserved during XRA C", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $FF is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result $FF MSB is set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: XRA_C clears carry");

    // =================================================================
    // TEST 2: Basic XOR operation - A=$FF ^ C=$00 = $FF
    // Expected: A=$FF, Z=0, N=1, C=0
    // =================================================================
    $display("\n--- TEST 2: Basic XOR operation ($FF ^ $00 = $FF) ---");
    
    // LDI A, #$FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A after LDI A, #$FF", DATA_WIDTH);

    // LDI C, #$00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h00, "C after LDI C, #$00", DATA_WIDTH);

    // XRA C: $FF ^ $00 = $FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("XRA C: $FF (11111111) ^ $00 (00000000) = $FF (11111111)");
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A after XRA C ($FF ^ $00)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $FF is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result $FF MSB is set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: XRA_C clears carry");

    // =================================================================
    // TEST 3: XOR operation resulting in zero - A=$FF ^ C=$FF = $00
    // Expected: A=$00, Z=1, N=0, C=0
    // =================================================================
    $display("\n--- TEST 3: XOR operation resulting in zero ($FF ^ $FF = $00) ---");
    
    // LDI A, #$FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A after LDI A, #$FF", DATA_WIDTH);

    // LDI C, #$FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hFF, "C after LDI C, #$FF", DATA_WIDTH);

    // XRA C: $FF ^ $FF = $00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("XRA C: $FF (11111111) ^ $FF (11111111) = $00 (00000000)");
    inspect_register(uut.u_cpu.a_out, 8'h00, "A after XRA C ($FF ^ $FF)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "Z=1: result $00 is zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result $00 MSB is clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: XRA_C clears carry");

    // =================================================================
    // TEST 4: XOR operation resulting in zero - A=$55 ^ C=$55 = $00
    // Expected: A=$00, Z=1, N=0, C=0
    // =================================================================
    $display("\n--- TEST 4: XOR operation resulting in zero ($55 ^ $55 = $00) ---");
    
    // LDI A, #$55
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h55, "A after LDI A, #$55", DATA_WIDTH);

    // LDI C, #$55
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h55, "C after LDI C, #$55", DATA_WIDTH);

    // XRA C: $55 ^ $55 = $00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("XRA C: $55 (01010101) ^ $55 (01010101) = $00 (00000000)");
    inspect_register(uut.u_cpu.a_out, 8'h00, "A after XRA C ($55 ^ $55)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "Z=1: result $00 is zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result $00 MSB is clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: XRA_C clears carry");

    // =================================================================
    // TEST 5: Alternating pattern 1 - A=$55 ^ C=$AA = $FF
    // Expected: A=$FF, Z=0, N=1, C=0
    // =================================================================
    $display("\n--- TEST 5: Alternating pattern 1 ($55 ^ $AA = $FF) ---");
    
    // LDI A, #$55
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h55, "A after LDI A, #$55", DATA_WIDTH);

    // LDI C, #$AA
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hAA, "C after LDI C, #$AA", DATA_WIDTH);

    // XRA C: $55 ^ $AA = $FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("XRA C: $55 (01010101) ^ $AA (10101010) = $FF (11111111)");
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A after XRA C ($55 ^ $AA)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $FF is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result $FF MSB is set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: XRA_C clears carry");

    // =================================================================
    // TEST 6: Alternating pattern 2 - A=$AA ^ C=$55 = $FF
    // Expected: A=$FF, Z=0, N=1, C=0
    // =================================================================
    $display("\n--- TEST 6: Alternating pattern 2 ($AA ^ $55 = $FF) ---");
    
    // LDI A, #$AA
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hAA, "A after LDI A, #$AA", DATA_WIDTH);

    // LDI C, #$55
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h55, "C after LDI C, #$55", DATA_WIDTH);

    // XRA C: $AA ^ $55 = $FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("XRA C: $AA (10101010) ^ $55 (01010101) = $FF (11111111)");
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A after XRA C ($AA ^ $55)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $FF is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result $FF MSB is set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: XRA_C clears carry");

    // =================================================================
    // TEST 7: Partial overlap - A=$0F ^ C=$F0 = $FF
    // Expected: A=$FF, Z=0, N=1, C=0
    // =================================================================
    $display("\n--- TEST 7: Partial overlap ($0F ^ $F0 = $FF) ---");
    
    // LDI A, #$0F
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h0F, "A after LDI A, #$0F", DATA_WIDTH);

    // LDI C, #$F0
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hF0, "C after LDI C, #$F0", DATA_WIDTH);

    // XRA C: $0F ^ $F0 = $FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("XRA C: $0F (00001111) ^ $F0 (11110000) = $FF (11111111)");
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A after XRA C ($0F ^ $F0)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $FF is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result $FF MSB is set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: XRA_C clears carry");

    // =================================================================
    // TEST 8: Single bit operations - A=$01 ^ C=$80 = $81
    // Expected: A=$81, Z=0, N=1, C=0
    // =================================================================
    $display("\n--- TEST 8: Single bit operations ($01 ^ $80 = $81) ---");
    
    // LDI A, #$01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h01, "A after LDI A, #$01", DATA_WIDTH);

    // LDI C, #$80
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h80, "C after LDI C, #$80", DATA_WIDTH);

    // XRA C: $01 ^ $80 = $81
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("XRA C: $01 (00000001) ^ $80 (10000000) = $81 (10000001)");
    inspect_register(uut.u_cpu.a_out, 8'h81, "A after XRA C ($01 ^ $80)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $81 is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result $81 MSB is set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: XRA_C clears carry");

    // =================================================================
    // TEST 9: Same value XOR - A=$42 ^ C=$42 = $00
    // Expected: A=$00, Z=1, N=0, C=0
    // =================================================================
    $display("\n--- TEST 9: Same value XOR ($42 ^ $42 = $00) ---");
    
    // LDI A, #$42
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h42, "A after LDI A, #$42", DATA_WIDTH);

    // LDI C, #$42
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h42, "C after LDI C, #$42", DATA_WIDTH);

    // XRA C: $42 ^ $42 = $00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("XRA C: $42 (01000010) ^ $42 (01000010) = $00 (00000000)");
    inspect_register(uut.u_cpu.a_out, 8'h00, "A after XRA C ($42 ^ $42)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "Z=1: result $00 is zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result $00 MSB is clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: XRA_C clears carry");

    // =================================================================
    // TEST 10: Positive result from mixed operands - A=$C0 ^ C=$30 = $F0
    // Expected: A=$F0, Z=0, N=1, C=0
    // =================================================================
    $display("\n--- TEST 10: Positive result from mixed operands ($C0 ^ $30 = $F0) ---");
    
    // LDI A, #$C0
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hC0, "A after LDI A, #$C0", DATA_WIDTH);

    // LDI C, #$30
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h30, "C after LDI C, #$30", DATA_WIDTH);

    // XRA C: $C0 ^ $30 = $F0
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("XRA C: $C0 (11000000) ^ $30 (00110000) = $F0 (11110000)");
    inspect_register(uut.u_cpu.a_out, 8'hF0, "A after XRA C ($C0 ^ $30)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $F0 is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result $F0 MSB is set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: XRA_C clears carry");

    // =================================================================
    // TEST 11: Carry flag clearing test - set carry, then XOR
    // Expected: A=$7F, Z=0, N=0, C=0 (carry cleared by XRA_C)
    // =================================================================
    $display("\n--- TEST 11: Carry flag clearing test (SEC then $3F ^ $40 = $7F) ---");
    
    // SEC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: carry set by SEC");

    // LDI A, #$3F
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h3F, "A after LDI A, #$3F", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: carry preserved during LDI");

    // LDI C, #$40
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h40, "C after LDI C, #$40", DATA_WIDTH);

    // XRA C: $3F ^ $40 = $7F (and C should be cleared)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("XRA C: $3F (00111111) ^ $40 (01000000) = $7F (01111111), C cleared");
    inspect_register(uut.u_cpu.a_out, 8'h7F, "A after XRA C ($3F ^ $40)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $7F is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result $7F MSB is clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: XRA_C clears carry flag");

    // =================================================================
    // TEST 12: All zeros except LSB - A=$01 ^ C=$00 = $01
    // Expected: A=$01, Z=0, N=0, C=0
    // =================================================================
    $display("\n--- TEST 12: All zeros except LSB ($01 ^ $00 = $01) ---");
    
    // LDI A, #$01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h01, "A after LDI A, #$01", DATA_WIDTH);

    // LDI C, #$00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h00, "C after LDI C, #$00", DATA_WIDTH);

    // XRA C: $01 ^ $00 = $01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("XRA C: $01 (00000001) ^ $00 (00000000) = $01 (00000001)");
    inspect_register(uut.u_cpu.a_out, 8'h01, "A after XRA C ($01 ^ $00)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $01 is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result $01 MSB is clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: XRA_C clears carry");

    // =================================================================
    // TEST 13: All zeros except MSB - A=$80 ^ C=$00 = $80
    // Expected: A=$80, Z=0, N=1, C=0
    // =================================================================
    $display("\n--- TEST 13: All zeros except MSB ($80 ^ $00 = $80) ---");
    
    // LDI A, #$80
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h80, "A after LDI A, #$80", DATA_WIDTH);

    // LDI C, #$00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h00, "C after LDI C, #$00", DATA_WIDTH);

    // XRA C: $80 ^ $00 = $80
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("XRA C: $80 (10000000) ^ $00 (00000000) = $80 (10000000)");
    inspect_register(uut.u_cpu.a_out, 8'h80, "A after XRA C ($80 ^ $00)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $80 is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result $80 MSB is set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: XRA_C clears carry");

    // =================================================================
    // TEST 14: Complex bit pattern - A=$69 ^ C=$96 = $FF
    // Expected: A=$FF, Z=0, N=1, C=0
    // =================================================================
    $display("\n--- TEST 14: Complex bit pattern ($69 ^ $96 = $FF) ---");
    
    // LDI A, #$69
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h69, "A after LDI A, #$69", DATA_WIDTH);

    // LDI C, #$96
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h96, "C after LDI C, #$96", DATA_WIDTH);

    // XRA C: $69 ^ $96 = $FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("XRA C: $69 (01101001) ^ $96 (10010110) = $FF (11111111)");
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A after XRA C ($69 ^ $96)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $FF is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result $FF MSB is set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: XRA_C clears carry");

    // =================================================================
    // TEST 15: Subset pattern - A=$0C ^ C=$03 = $0F
    // Expected: A=$0F, Z=0, N=0, C=0
    // =================================================================
    $display("\n--- TEST 15: Subset pattern ($0C ^ $03 = $0F) ---");
    
    // LDI A, #$0C
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h0C, "A after LDI A, #$0C", DATA_WIDTH);

    // LDI C, #$03
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h03, "C after LDI C, #$03", DATA_WIDTH);

    // XRA C: $0C ^ $03 = $0F
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("XRA C: $0C (00001100) ^ $03 (00000011) = $0F (00001111)");
    inspect_register(uut.u_cpu.a_out, 8'h0F, "A after XRA C ($0C ^ $03)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $0F is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result $0F MSB is clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: XRA_C clears carry");

    // =================================================================
    // TEST 16: Edge case - maximum positive ^ minimum positive = $7E
    // Expected: A=$7E, Z=0, N=0, C=0
    // =================================================================
    $display("\n--- TEST 16: Edge case ($7F ^ $01 = $7E) ---");
    
    // LDI A, #$7F
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h7F, "A after LDI A, #$7F", DATA_WIDTH);

    // LDI C, #$01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h01, "C after LDI C, #$01", DATA_WIDTH);

    // XRA C: $7F ^ $01 = $7E
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("XRA C: $7F (01111111) ^ $01 (00000001) = $7E (01111110)");
    inspect_register(uut.u_cpu.a_out, 8'h7E, "A after XRA C ($7F ^ $01)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $7E is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result $7E MSB is clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: XRA_C clears carry");

    // =================================================================
    // TEST 17: Register preservation test
    // Expected: B=$5A, C=$5A preserved, A=$66
    // =================================================================
    $display("\n--- TEST 17: Register preservation test ($3C ^ $5A = $66) ---");
    
    // LDI A, #$3C
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h3C, "A after LDI A, #$3C", DATA_WIDTH);

    // LDI B, #$5A
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h5A, "B after LDI B, #$5A", DATA_WIDTH);

    // LDI C, #$5A
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h5A, "C after LDI C, #$5A", DATA_WIDTH);

    // XRA C: $3C ^ $5A = $66
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("XRA C: $3C (00111100) ^ $5A (01011010) = $66 (01100110)");
    inspect_register(uut.u_cpu.a_out, 8'h66, "A after XRA C ($3C ^ $5A)", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h5A, "B preserved during XRA C", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'h5A, "C preserved during XRA C", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $66 is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result $66 MSB is clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: XRA_C clears carry");

    // =================================================================
    // TEST 18: All bits set except one - A=$FE ^ C=$01 = $FF
    // Expected: A=$FF, Z=0, N=1, C=0
    // =================================================================
    $display("\n--- TEST 18: All bits set except one ($FE ^ $01 = $FF) ---");
    
    // LDI A, #$FE
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFE, "A after LDI A, #$FE", DATA_WIDTH);

    // LDI C, #$01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h01, "C after LDI C, #$01", DATA_WIDTH);

    // XRA C: $FE ^ $01 = $FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("XRA C: $FE (11111110) ^ $01 (00000001) = $FF (11111111)");
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A after XRA C ($FE ^ $01)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $FF is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result $FF MSB is set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: XRA_C clears carry");

    // =================================================================
    // TEST 19: Sequential XOR operations to verify no side effects
    // =================================================================
    $display("\n--- TEST 19: Sequential XOR operations ---");
    
    // LDI A, #$01; LDI C, #$02; XRA C -> A=$03
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h01, "A after LDI A, #$01", DATA_WIDTH);
    
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h02, "C after LDI C, #$02", DATA_WIDTH);
    
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("1st XRA C: $01 ^ $02 = $03");
    inspect_register(uut.u_cpu.a_out, 8'h03, "A after 1st XRA C", DATA_WIDTH);
    
    // LDI C, #$04; XRA C -> A=$07
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h04, "C after LDI C, #$04", DATA_WIDTH);
    
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("2nd XRA C: $03 ^ $04 = $07");
    inspect_register(uut.u_cpu.a_out, 8'h07, "A after 2nd XRA C", DATA_WIDTH);
    
    // LDI C, #$08; XRA C -> A=$0F
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h08, "C after LDI C, #$08", DATA_WIDTH);
    
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("3rd XRA C: $07 ^ $08 = $0F");
    inspect_register(uut.u_cpu.a_out, 8'h0F, "A after 3rd XRA C", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: sequential result non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: sequential result positive");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: XRA_C clears carry");

    // =================================================================
    // TEST 20: Boundary value testing - A=$7F ^ C=$80 = $FF
    // Expected: A=$FF, Z=0, N=1, C=0
    // =================================================================
    $display("\n--- TEST 20: Boundary value testing ($7F ^ $80 = $FF) ---");
    
    // LDI A, #$7F
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h7F, "A after LDI A, #$7F", DATA_WIDTH);

    // LDI C, #$80
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h80, "C after LDI C, #$80", DATA_WIDTH);

    // XRA C: $7F ^ $80 = $FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("XRA C: $7F (01111111) ^ $80 (10000000) = $FF (11111111)");
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A after XRA C ($7F ^ $80)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $FF is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result $FF MSB is set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: XRA_C clears carry");

    // =================================================================
    // TEST 21: Final flag state verification
    // Expected: A=$00, Z=1, N=0, C=0 (carry cleared even when set before)
    // =================================================================
    $display("\n--- TEST 21: Final flag state verification (SEC then $AA ^ $AA = $00) ---");
    
    // SEC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: carry set by SEC");

    // LDI A, #$AA
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hAA, "A after LDI A, #$AA", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: LDI sets negative flag");

    // LDI C, #$AA
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hAA, "C after LDI C, #$AA", DATA_WIDTH);

    // XRA C: $AA ^ $AA = $00 (and C should be cleared)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("XRA C: $AA (10101010) ^ $AA (10101010) = $00 (00000000), C cleared");
    inspect_register(uut.u_cpu.a_out, 8'h00, "A after final XRA C", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "Z=1: result $00 is zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result $00 MSB is clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: XRA_C clears carry even when set");

    // =================================================================
    // TEST 22: XOR with alternating bits creating specific pattern
    // Expected: A=$F0, Z=0, N=1, C=0
    // =================================================================
    $display("\n--- TEST 22: Alternating bits pattern ($CC ^ $3C = $F0) ---");
    
    // LDI A, #$CC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hCC, "A after LDI A, #$CC", DATA_WIDTH);

    // LDI C, #$3C
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h3C, "C after LDI C, #$3C", DATA_WIDTH);

    // XRA C: $CC ^ $3C = $F0
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("XRA C: $CC (11001100) ^ $3C (00111100) = $F0 (11110000)");
    inspect_register(uut.u_cpu.a_out, 8'hF0, "A after XRA C ($CC ^ $3C)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $F0 is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result $F0 MSB is set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: XRA_C clears carry");

    // =================================================================
    // TEST 23: XOR creating positive result from negative operands
    // Expected: A=$33, Z=0, N=0, C=0
    // =================================================================
    $display("\n--- TEST 23: Positive from negative operands ($C3 ^ $F0 = $33) ---");
    
    // LDI A, #$C3
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hC3, "A after LDI A, #$C3", DATA_WIDTH);

    // LDI C, #$F0
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hF0, "C after LDI C, #$F0", DATA_WIDTH);

    // XRA C: $C3 ^ $F0 = $33
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("XRA C: $C3 (11000011) ^ $F0 (11110000) = $33 (00110011)");
    inspect_register(uut.u_cpu.a_out, 8'h33, "A after XRA C ($C3 ^ $F0)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $33 is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result $33 MSB is clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: XRA_C clears carry");

    // =================================================================
    // TEST 24: Final comprehensive multi-bit test
    // Expected: A=$5A, Z=0, N=0, C=0
    // =================================================================
    $display("\n--- TEST 24: Final comprehensive test ($A5 ^ $FF = $5A) ---");
    
    // LDI A, #$A5
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hA5, "A after LDI A, #$A5", DATA_WIDTH);

    // LDI C, #$FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hFF, "C after LDI C, #$FF", DATA_WIDTH);

    // XRA C: $A5 ^ $FF = $5A
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("XRA C: $A5 (10100101) ^ $FF (11111111) = $5A (01011010)");
    inspect_register(uut.u_cpu.a_out, 8'h5A, "A after XRA C ($A5 ^ $FF)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $5A is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result $5A MSB is clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: XRA_C clears carry");

    // =================================================================
    // HALT verification - ensure CPU properly stops
    // =================================================================
    $display("\n--- Verifying HALT instruction ---");
    run_until_halt(200);  // Increased timeout for comprehensive test suite
    $display("CPU halted successfully");
    
    // Visual buffer for waveform inspection
    repeat(5) @(posedge clk);

    $display("\n=== XRA_C (Bitwise Exclusive OR A with C) Test Summary ===");
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
    $display("✓ XOR-specific properties (A^A=0, A^0=A, A^FF=~A)");
    $display("XRA_C test finished.===========================\n\n");
    $finish;
    // ============================ END TEST ==============================
  
  end

endmodule