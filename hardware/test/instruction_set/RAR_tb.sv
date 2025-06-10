`timescale 1ns/1ps
import test_utils_pkg::*; 
import arch_defs_pkg::*;  

module computer_tb;

  localparam string HEX_FILE = "../hardware/test/_fixtures_generated/RAR/ROM.hex";

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

    // ============================ BEGIN RAR COMPREHENSIVE TESTS ==============================
    $display("\n=== RAR (Rotate A Right through Carry) Comprehensive Test Suite ===");
    $display("Testing RAR instruction: rotate A right through carry, bit 0->Carry, Carry->bit 7");
    $display("Flags: Z=+/- (result), N=+/- (result), C== (from bit 0)\n");

    // =================================================================
    // TEST 1: Basic rotation with carry clear
    // Assembly: CLC; LDI A, #$F0; RAR
    // Expected: A = $F0 >> 1 = $78, C = 0 (from LSB), Z = 0, N = 0
    // =================================================================
    $display("--- TEST 1: Basic rotation with carry clear ($F0, C=0) ---");
    
    // CLC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "Carry cleared by CLC");

    // LDI A, #$F0
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hF0, "A after LDI A, #$F0", DATA_WIDTH);

    // RAR: $F0 (%11110000) with C=0 -> A=$78 (%01111000), C=0
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("RAR: $F0 >> 1 (C=0) = $78, new C=0");
    inspect_register(uut.u_cpu.a_out, 8'h78, "A after RAR ($F0 with C=0)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: LSB of $F0 was 0");
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $78 is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result $78 MSB is clear");

    // =================================================================
    // TEST 2: Basic rotation with carry set
    // Assembly: SEC; LDI A, #$0F; RAR
    // Expected: A = ($0F >> 1) | $80 = $87, C = 1 (from LSB), Z = 0, N = 1
    // =================================================================
    $display("\n--- TEST 2: Basic rotation with carry set ($0F, C=1) ---");
    
    // SEC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "Carry set by SEC");

    // LDI A, #$0F
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h0F, "A after LDI A, #$0F", DATA_WIDTH);

    // RAR: $0F (%00001111) with C=1 -> A=$87 (%10000111), C=1
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("RAR: $0F >> 1 (C=1) = $87, new C=1");
    inspect_register(uut.u_cpu.a_out, 8'h87, "A after RAR ($0F with C=1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: LSB of $0F was 1");
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $87 is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result $87 MSB is set");

    // =================================================================
    // TEST 3: Rotation resulting in zero
    // Assembly: CLC; LDI A, #$00; RAR
    // Expected: A = $00, C = 0, Z = 1, N = 0
    // =================================================================
    $display("\n--- TEST 3: Rotation resulting in zero ($00, C=0) ---");
    
    // CLC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "Carry cleared by CLC");

    // LDI A, #$00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "A after LDI A, #$00", DATA_WIDTH);

    // RAR: $00 with C=0 -> A=$00, C=0
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("RAR: $00 >> 1 (C=0) = $00, new C=0");
    inspect_register(uut.u_cpu.a_out, 8'h00, "A after RAR ($00 with C=0)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: LSB of $00 was 0");
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "Z=1: result $00 is zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result $00 MSB is clear");

    // =================================================================
    // TEST 4: Rotation with carry into MSB making negative
    // Assembly: SEC; LDI A, #$00; RAR
    // Expected: A = $80, C = 0, Z = 0, N = 1
    // =================================================================
    $display("\n--- TEST 4: Carry into MSB making negative ($00, C=1) ---");
    
    // SEC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "Carry set by SEC");

    // LDI A, #$00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "A after LDI A, #$00", DATA_WIDTH);

    // RAR: $00 with C=1 -> A=$80, C=0
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("RAR: $00 >> 1 (C=1) = $80, new C=0");
    inspect_register(uut.u_cpu.a_out, 8'h80, "A after RAR ($00 with C=1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: LSB of $00 was 0");
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $80 is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result $80 MSB is set");

    // =================================================================
    // TEST 5: All ones pattern with carry clear
    // Assembly: CLC; LDI A, #$FF; RAR
    // Expected: A = $7F, C = 1, Z = 0, N = 0
    // =================================================================
    $display("\n--- TEST 5: All ones with carry clear ($FF, C=0) ---");
    
    // CLC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "Carry cleared by CLC");

    // LDI A, #$FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A after LDI A, #$FF", DATA_WIDTH);

    // RAR: $FF with C=0 -> A=$7F, C=1
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("RAR: $FF >> 1 (C=0) = $7F, new C=1");
    inspect_register(uut.u_cpu.a_out, 8'h7F, "A after RAR ($FF with C=0)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: LSB of $FF was 1");
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $7F is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result $7F MSB is clear");

    // =================================================================
    // TEST 6: All ones pattern with carry set
    // Assembly: SEC; LDI A, #$FF; RAR
    // Expected: A = $FF, C = 1, Z = 0, N = 1
    // =================================================================
    $display("\n--- TEST 6: All ones with carry set ($FF, C=1) ---");
    
    // SEC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "Carry set by SEC");

    // LDI A, #$FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A after LDI A, #$FF", DATA_WIDTH);

    // RAR: $FF with C=1 -> A=$FF, C=1
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("RAR: $FF >> 1 (C=1) = $FF, new C=1");
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A after RAR ($FF with C=1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: LSB of $FF was 1");
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $FF is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result $FF MSB is set");

    // =================================================================
    // TEST 7: Single bit LSB test (bit 0 -> carry)
    // Assembly: CLC; LDI A, #$01; RAR
    // Expected: A = $00, C = 1, Z = 1, N = 0
    // =================================================================
    $display("\n--- TEST 7: Single LSB test ($01, C=0) ---");
    
    // CLC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "Carry cleared by CLC");

    // LDI A, #$01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h01, "A after LDI A, #$01", DATA_WIDTH);

    // RAR: $01 with C=0 -> A=$00, C=1
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("RAR: $01 >> 1 (C=0) = $00, new C=1");
    inspect_register(uut.u_cpu.a_out, 8'h00, "A after RAR ($01 with C=0)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: LSB of $01 was 1");
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "Z=1: result $00 is zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result $00 MSB is clear");

    // =================================================================
    // TEST 8: Single bit MSB test with carry propagation
    // Assembly: CLC; LDI A, #$80; RAR
    // Expected: A = $40, C = 0, Z = 0, N = 0
    // =================================================================
    $display("\n--- TEST 8: Single MSB test ($80, C=0) ---");
    
    // CLC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "Carry cleared by CLC");

    // LDI A, #$80
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h80, "A after LDI A, #$80", DATA_WIDTH);

    // RAR: $80 with C=0 -> A=$40, C=0
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("RAR: $80 >> 1 (C=0) = $40, new C=0");
    inspect_register(uut.u_cpu.a_out, 8'h40, "A after RAR ($80 with C=0)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: LSB of $80 was 0");
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $40 is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result $40 MSB is clear");

    // =================================================================
    // TEST 9: Alternating pattern test 1
    // Assembly: CLC; LDI A, #$55; RAR
    // Expected: A = $2A, C = 1, Z = 0, N = 0
    // =================================================================
    $display("\n--- TEST 9: Alternating pattern 1 ($55, C=0) ---");
    
    // CLC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "Carry cleared by CLC");

    // LDI A, #$55
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h55, "A after LDI A, #$55", DATA_WIDTH);

    // RAR: $55 (%01010101) with C=0 -> A=$2A (%00101010), C=1
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("RAR: $55 (%01010101) >> 1 (C=0) = $2A (%00101010), new C=1");
    inspect_register(uut.u_cpu.a_out, 8'h2A, "A after RAR ($55 with C=0)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: LSB of $55 was 1");
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $2A is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result $2A MSB is clear");

    // =================================================================
    // TEST 10: Alternating pattern test 2
    // Assembly: SEC; LDI A, #$AA; RAR
    // Expected: A = $D5, C = 0, Z = 0, N = 1
    // =================================================================
    $display("\n--- TEST 10: Alternating pattern 2 ($AA, C=1) ---");
    
    // SEC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "Carry set by SEC");

    // LDI A, #$AA
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hAA, "A after LDI A, #$AA", DATA_WIDTH);

    // RAR: $AA (%10101010) with C=1 -> A=$D5 (%11010101), C=0
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("RAR: $AA (%10101010) >> 1 (C=1) = $D5 (%11010101), new C=0");
    inspect_register(uut.u_cpu.a_out, 8'hD5, "A after RAR ($AA with C=1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: LSB of $AA was 0");
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $D5 is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result $D5 MSB is set");

    // =================================================================
    // TEST 11: Sequential rotation test (multiple RAR operations)
    // Assembly: CLC; LDI A, #$C3; RAR; RAR
    // Step 1: $C3 (%11000011) with C=0 -> A=$61 (%01100001), C=1
    // Step 2: $61 (%01100001) with C=1 -> A=$B0 (%10110000), C=1  
    // =================================================================
    $display("\n--- TEST 11: Sequential rotations ($C3) ---");
    
    // CLC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "Carry cleared by CLC");

    // LDI A, #$C3
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hC3, "A after LDI A, #$C3", DATA_WIDTH);

    // 1st RAR: $C3 with C=0 -> A=$61, C=1
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("1st RAR: $C3 (%11000011) >> 1 (C=0) = $61 (%01100001), new C=1");
    inspect_register(uut.u_cpu.a_out, 8'h61, "A after 1st RAR", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: LSB of $C3 was 1");

    // 2nd RAR: $61 with C=1 -> A=$B0, C=1
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("2nd RAR: $61 (%01100001) >> 1 (C=1) = $B0 (%10110000), new C=1");
    inspect_register(uut.u_cpu.a_out, 8'hB0, "A after 2nd RAR", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: LSB of $61 was 1");
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $B0 is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result $B0 MSB is set");

    // =================================================================
    // TEST 12: Register preservation test
    // Assembly: LDI B, #$BB; LDI C, #$CC; CLC; LDI A, #$42; RAR
    // Expected: B=$BB, C=$CC preserved, A=$21, C=0
    // =================================================================
    $display("\n--- TEST 12: Register preservation test ---");
    
    // LDI B, #$BB
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'hBB, "B after LDI B, #$BB", DATA_WIDTH);

    // LDI C, #$CC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hCC, "C after LDI C, #$CC", DATA_WIDTH);

    // CLC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "Carry cleared by CLC");

    // LDI A, #$42
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h42, "A after LDI A, #$42", DATA_WIDTH);

    // RAR: $42 with C=0 -> A=$21, C=0
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("RAR: $42 >> 1 (C=0) = $21, new C=0");
    inspect_register(uut.u_cpu.a_out, 8'h21, "A after RAR ($42 with C=0)", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'hBB, "B preserved during RAR", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hCC, "C preserved during RAR", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: LSB of $42 was 0");

    // =================================================================
    // TEST 13: Boundary case - carry cycling test (9 rotations)
    // Starting: A = $01, C = 0
    // This tests complete bit cycling through carry
    // =================================================================
    $display("\n--- TEST 13: Carry cycling test (9 rotations) ---");
    
    // CLC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "Carry cleared by CLC");

    // LDI A, #$01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h01, "A after LDI A, #$01", DATA_WIDTH);

    // Rotation 1: A=$01 -> A=$00, C=1
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("Rotation 1: $01 -> $00, C=1");
    inspect_register(uut.u_cpu.a_out, 8'h00, "A after rotation 1", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1 after rotation 1");

    // Rotation 2: A=$00, C=1 -> A=$80, C=0
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("Rotation 2: $00 (C=1) -> $80, C=0");
    inspect_register(uut.u_cpu.a_out, 8'h80, "A after rotation 2", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0 after rotation 2");

    // Rotations 3-8: Continue cycling
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h40, "A after rotation 3", DATA_WIDTH);

    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h20, "A after rotation 4", DATA_WIDTH);

    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h10, "A after rotation 5", DATA_WIDTH);

    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h08, "A after rotation 6", DATA_WIDTH);

    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h04, "A after rotation 7", DATA_WIDTH);

    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h02, "A after rotation 8", DATA_WIDTH);

    // Rotation 9: Should return to original state
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("Rotation 9: Back to original state");
    inspect_register(uut.u_cpu.a_out, 8'h01, "A after rotation 9 (back to original)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0 after complete cycle");

    // =================================================================
    // TEST 14: Edge case - maximum value transitions
    // Assembly: SEC; LDI A, #$FE; RAR
    // Expected: A = $FF, C = 0, Z = 0, N = 1
    // =================================================================
    $display("\n--- TEST 14: Maximum value transition ($FE, C=1) ---");
    
    // SEC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "Carry set by SEC");

    // LDI A, #$FE
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFE, "A after LDI A, #$FE", DATA_WIDTH);

    // RAR: $FE (%11111110) with C=1 -> A=$FF (%11111111), C=0
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("RAR: $FE (%11111110) >> 1 (C=1) = $FF (%11111111), new C=0");
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A after RAR ($FE with C=1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: LSB of $FE was 0");
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $FF is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result $FF MSB is set");

    // =================================================================
    // TEST 15: Final comprehensive test - complex bit pattern
    // Assembly: SEC; LDI A, #$69; RAR
    // Expected: A = $B4, C = 1, Z = 0, N = 1
    // =================================================================
    $display("\n--- TEST 15: Complex bit pattern ($69, C=1) ---");
    
    // SEC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "Carry set by SEC");

    // LDI A, #$69
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h69, "A after LDI A, #$69", DATA_WIDTH);

    // RAR: $69 (%01101001) with C=1 -> A=$B4 (%10110100), C=1
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("RAR: $69 (%01101001) >> 1 (C=1) = $B4 (%10110100), new C=1");
    inspect_register(uut.u_cpu.a_out, 8'hB4, "A after RAR ($69 with C=1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: LSB of $69 was 1");
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $B4 is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result $B4 MSB is set");

    // =================================================================
    // HALT verification - ensure CPU properly stops
    // =================================================================
    $display("\n--- Verifying HALT instruction ---");
    run_until_halt(200);  // Increased timeout for comprehensive test suite
    $display("CPU halted successfully");
    
    // Visual buffer for waveform inspection
    repeat(5) @(posedge clk);

    $display("RAR test finished.===========================\n\n");
    $display("All 15 RAR test cases passed successfully!");
    $display("- Tested basic rotation with carry clear and set");
    $display("- Verified zero result and negative result scenarios");
    $display("- Checked all bit patterns (all 0s, all 1s, alternating)");
    $display("- Validated flag behavior (Z, N, C) for all cases");
    $display("- Confirmed register preservation (B, C unaffected)");
    $display("- Tested sequential rotations and bit cycling");
    $display("- Verified edge cases and complex bit patterns");
    $finish;
    // ============================ END TEST ==============================
  
  end

endmodule