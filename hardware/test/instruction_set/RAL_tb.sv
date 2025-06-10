`timescale 1ns/1ps
import test_utils_pkg::*; 
import arch_defs_pkg::*;  

module computer_tb;

  localparam string HEX_FILE = "../hardware/test/_fixtures_generated/RAL/ROM.hex";

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

    // ============================ BEGIN RAL COMPREHENSIVE TESTS ==============================
    $display("\n=== RAL (Rotate A Left through Carry) Comprehensive Test Suite ===");
    $display("Testing RAL instruction: rotate A left through carry, bit 7->Carry, Carry->bit 0");
    $display("Flags: Z=+/- (result), N=+/- (result), C== (from bit 7)\n");

    // =================================================================
    // TEST 1: Basic rotation with carry clear
    // Assembly: CLC; LDI A, #$0F; RAL
    // Expected: A = $0F << 1 = $1E, C = 0 (from MSB), Z = 0, N = 0
    // =================================================================
    $display("--- TEST 1: Basic rotation with carry clear ($0F, C=0) ---");
    
    // CLC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "Carry cleared by CLC");

    // LDI A, #$0F
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h0F, "A after LDI A, #$0F", DATA_WIDTH);

    // RAL: $0F (%00001111) with C=0 -> A=$1E (%00011110), C=0
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("RAL: $0F << 1 (C=0) = $1E, new C=0");
    inspect_register(uut.u_cpu.a_out, 8'h1E, "A after RAL ($0F with C=0)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: MSB of $0F was 0");
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $1E is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result $1E MSB is clear");

    // =================================================================
    // TEST 2: Basic rotation with carry set
    // Assembly: SEC; LDI A, #$F0; RAL
    // Expected: A = ($F0 << 1) | $01 = $E1, C = 1 (from MSB), Z = 0, N = 1
    // =================================================================
    $display("\n--- TEST 2: Basic rotation with carry set ($F0, C=1) ---");
    
    // SEC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "Carry set by SEC");

    // LDI A, #$F0
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hF0, "A after LDI A, #$F0", DATA_WIDTH);

    // RAL: $F0 (%11110000) with C=1 -> A=$E1 (%11100001), C=1
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("RAL: $F0 << 1 (C=1) = $E1, new C=1");
    inspect_register(uut.u_cpu.a_out, 8'hE1, "A after RAL ($F0 with C=1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: MSB of $F0 was 1");
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $E1 is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result $E1 MSB is set");

    // =================================================================
    // TEST 3: Rotation resulting in zero
    // Assembly: CLC; LDI A, #$00; RAL
    // Expected: A = $00, C = 0, Z = 1, N = 0
    // =================================================================
    $display("\n--- TEST 3: Rotation resulting in zero ($00, C=0) ---");
    
    // CLC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "Carry cleared by CLC");

    // LDI A, #$00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "A after LDI A, #$00", DATA_WIDTH);

    // RAL: $00 with C=0 -> A=$00, C=0
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("RAL: $00 << 1 (C=0) = $00, new C=0");
    inspect_register(uut.u_cpu.a_out, 8'h00, "A after RAL ($00 with C=0)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: MSB of $00 was 0");
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "Z=1: result $00 is zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result $00 MSB is clear");

    // =================================================================
    // TEST 4: Rotation with carry into LSB 
    // Assembly: SEC; LDI A, #$00; RAL
    // Expected: A = $01, C = 0, Z = 0, N = 0
    // =================================================================
    $display("\n--- TEST 4: Carry into LSB ($00, C=1) ---");
    
    // SEC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "Carry set by SEC");

    // LDI A, #$00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "A after LDI A, #$00", DATA_WIDTH);

    // RAL: $00 with C=1 -> A=$01, C=0
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("RAL: $00 << 1 (C=1) = $01, new C=0");
    inspect_register(uut.u_cpu.a_out, 8'h01, "A after RAL ($00 with C=1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: MSB of $00 was 0");
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $01 is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result $01 MSB is clear");

    // =================================================================
    // TEST 5: All ones pattern with carry clear
    // Assembly: CLC; LDI A, #$FF; RAL
    // Expected: A = $FE, C = 1, Z = 0, N = 1
    // =================================================================
    $display("\n--- TEST 5: All ones with carry clear ($FF, C=0) ---");
    
    // CLC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "Carry cleared by CLC");

    // LDI A, #$FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A after LDI A, #$FF", DATA_WIDTH);

    // RAL: $FF with C=0 -> A=$FE, C=1
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("RAL: $FF << 1 (C=0) = $FE, new C=1");
    inspect_register(uut.u_cpu.a_out, 8'hFE, "A after RAL ($FF with C=0)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: MSB of $FF was 1");
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $FE is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result $FE MSB is set");

    // =================================================================
    // TEST 6: All ones pattern with carry set
    // Assembly: SEC; LDI A, #$FF; RAL
    // Expected: A = $FF, C = 1, Z = 0, N = 1
    // =================================================================
    $display("\n--- TEST 6: All ones with carry set ($FF, C=1) ---");
    
    // SEC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "Carry set by SEC");

    // LDI A, #$FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A after LDI A, #$FF", DATA_WIDTH);

    // RAL: $FF with C=1 -> A=$FF, C=1
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("RAL: $FF << 1 (C=1) = $FF, new C=1");
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A after RAL ($FF with C=1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: MSB of $FF was 1");
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $FF is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result $FF MSB is set");

    // =================================================================
    // TEST 7: Single bit MSB test (bit 7 -> carry)
    // Assembly: CLC; LDI A, #$80; RAL
    // Expected: A = $00, C = 1, Z = 1, N = 0
    // =================================================================
    $display("\n--- TEST 7: Single MSB test ($80, C=0) ---");
    
    // CLC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "Carry cleared by CLC");

    // LDI A, #$80
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h80, "A after LDI A, #$80", DATA_WIDTH);

    // RAL: $80 with C=0 -> A=$00, C=1
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("RAL: $80 << 1 (C=0) = $00, new C=1");
    inspect_register(uut.u_cpu.a_out, 8'h00, "A after RAL ($80 with C=0)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: MSB of $80 was 1");
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "Z=1: result $00 is zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result $00 MSB is clear");

    // =================================================================
    // TEST 8: Single bit LSB test with carry propagation
    // Assembly: CLC; LDI A, #$01; RAL
    // Expected: A = $02, C = 0, Z = 0, N = 0
    // =================================================================
    $display("\n--- TEST 8: Single LSB test ($01, C=0) ---");
    
    // CLC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "Carry cleared by CLC");

    // LDI A, #$01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h01, "A after LDI A, #$01", DATA_WIDTH);

    // RAL: $01 with C=0 -> A=$02, C=0
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("RAL: $01 << 1 (C=0) = $02, new C=0");
    inspect_register(uut.u_cpu.a_out, 8'h02, "A after RAL ($01 with C=0)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: MSB of $01 was 0");
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $02 is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result $02 MSB is clear");

    // =================================================================
    // TEST 9: Alternating pattern test 1
    // Assembly: CLC; LDI A, #$55; RAL
    // Expected: A = $AA, C = 0, Z = 0, N = 1
    // =================================================================
    $display("\n--- TEST 9: Alternating pattern 1 ($55, C=0) ---");
    
    // CLC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "Carry cleared by CLC");

    // LDI A, #$55
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h55, "A after LDI A, #$55", DATA_WIDTH);

    // RAL: $55 (%01010101) with C=0 -> A=$AA (%10101010), C=0
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("RAL: $55 (%01010101) << 1 (C=0) = $AA (%10101010), new C=0");
    inspect_register(uut.u_cpu.a_out, 8'hAA, "A after RAL ($55 with C=0)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: MSB of $55 was 0");
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $AA is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result $AA MSB is set");

    // =================================================================
    // TEST 10: Alternating pattern test 2
    // Assembly: SEC; LDI A, #$AA; RAL
    // Expected: A = $55, C = 1, Z = 0, N = 0
    // =================================================================
    $display("\n--- TEST 10: Alternating pattern 2 ($AA, C=1) ---");
    
    // SEC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "Carry set by SEC");

    // LDI A, #$AA
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hAA, "A after LDI A, #$AA", DATA_WIDTH);

    // RAL: $AA (%10101010) with C=1 -> A=$55 (%01010101), C=1
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("RAL: $AA (%10101010) << 1 (C=1) = $55 (%01010101), new C=1");
    inspect_register(uut.u_cpu.a_out, 8'h55, "A after RAL ($AA with C=1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: MSB of $AA was 1");
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $55 is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result $55 MSB is clear");

    // =================================================================
    // TEST 11: Sequential rotation test (multiple RAL operations)
    // Assembly: CLC; LDI A, #$C3; RAL; RAL
    // Step 1: $C3 (%11000011) with C=0 -> A=$86 (%10000110), C=1
    // Step 2: $86 (%10000110) with C=1 -> A=$0D (%00001101), C=1  
    // =================================================================
    $display("\n--- TEST 11: Sequential rotations ($C3) ---");
    
    // CLC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "Carry cleared by CLC");

    // LDI A, #$C3
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hC3, "A after LDI A, #$C3", DATA_WIDTH);

    // 1st RAL: $C3 with C=0 -> A=$86, C=1
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("1st RAL: $C3 (%11000011) << 1 (C=0) = $86 (%10000110), new C=1");
    inspect_register(uut.u_cpu.a_out, 8'h86, "A after 1st RAL", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: MSB of $C3 was 1");

    // 2nd RAL: $86 with C=1 -> A=$0D, C=1
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("2nd RAL: $86 (%10000110) << 1 (C=1) = $0D (%00001101), new C=1");
    inspect_register(uut.u_cpu.a_out, 8'h0D, "A after 2nd RAL", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: MSB of $86 was 1");
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $0D is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result $0D MSB is clear");

    // =================================================================
    // TEST 12: Register preservation test
    // Assembly: LDI B, #$BB; LDI C, #$CC; CLC; LDI A, #$42; RAL
    // Expected: B=$BB, C=$CC preserved, A=$84, C=0
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

    // RAL: $42 with C=0 -> A=$84, C=0
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("RAL: $42 << 1 (C=0) = $84, new C=0");
    inspect_register(uut.u_cpu.a_out, 8'h84, "A after RAL ($42 with C=0)", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'hBB, "B preserved during RAL", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hCC, "C preserved during RAL", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: MSB of $42 was 0");

    // =================================================================
    // TEST 13: Boundary case - carry cycling test (9 rotations)
    // Starting: A = $80, C = 0
    // This tests complete bit cycling through carry
    // =================================================================
    $display("\n--- TEST 13: Carry cycling test (9 rotations) ---");
    
    // CLC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "Carry cleared by CLC");

    // LDI A, #$80
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h80, "A after LDI A, #$80", DATA_WIDTH);

    // Rotation 1: A=$80 -> A=$00, C=1
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("Rotation 1: $80 -> $00, C=1");
    inspect_register(uut.u_cpu.a_out, 8'h00, "A after rotation 1", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1 after rotation 1");

    // Rotation 2: A=$00, C=1 -> A=$01, C=0
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("Rotation 2: $00 (C=1) -> $01, C=0");
    inspect_register(uut.u_cpu.a_out, 8'h01, "A after rotation 2", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0 after rotation 2");

    // Rotations 3-8: Continue cycling
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h02, "A after rotation 3", DATA_WIDTH);

    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h04, "A after rotation 4", DATA_WIDTH);

    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h08, "A after rotation 5", DATA_WIDTH);

    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h10, "A after rotation 6", DATA_WIDTH);

    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h20, "A after rotation 7", DATA_WIDTH);

    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h40, "A after rotation 8", DATA_WIDTH);

    // Rotation 9: Should return to original state
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("Rotation 9: Back to original state");
    inspect_register(uut.u_cpu.a_out, 8'h80, "A after rotation 9 (back to original)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0 after complete cycle");

    // =================================================================
    // TEST 14: Edge case - maximum value transitions
    // Assembly: SEC; LDI A, #$7F; RAL
    // Expected: A = $FF, C = 0, Z = 0, N = 1
    // =================================================================
    $display("\n--- TEST 14: Maximum value transition ($7F, C=1) ---");
    
    // SEC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "Carry set by SEC");

    // LDI A, #$7F
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h7F, "A after LDI A, #$7F", DATA_WIDTH);

    // RAL: $7F (%01111111) with C=1 -> A=$FF (%11111111), C=0
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("RAL: $7F (%01111111) << 1 (C=1) = $FF (%11111111), new C=0");
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A after RAL ($7F with C=1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: MSB of $7F was 0");
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $FF is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result $FF MSB is set");

    // =================================================================
    // TEST 15: Final comprehensive test - complex bit pattern
    // Assembly: SEC; LDI A, #$96; RAL
    // Expected: A = $2D, C = 1, Z = 0, N = 0
    // =================================================================
    $display("\n--- TEST 15: Complex bit pattern ($96, C=1) ---");
    
    // SEC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "Carry set by SEC");

    // LDI A, #$96
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h96, "A after LDI A, #$96", DATA_WIDTH);

    // RAL: $96 (%10010110) with C=1 -> A=$2D (%00101101), C=1
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("RAL: $96 (%10010110) << 1 (C=1) = $2D (%00101101), new C=1");
    inspect_register(uut.u_cpu.a_out, 8'h2D, "A after RAL ($96 with C=1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: MSB of $96 was 1");
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $2D is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result $2D MSB is clear");

    // =================================================================
    // HALT verification - ensure CPU properly stops
    // =================================================================
    $display("\n--- Verifying HALT instruction ---");
    run_until_halt(300);  // Increased timeout for comprehensive test suite
    $display("CPU halted successfully");
    
    // Visual buffer for waveform inspection
    repeat(5) @(posedge clk);

    $display("RAL test finished.===========================\n\n");
    $display("All 15 RAL test cases passed successfully!");
    $display("- Tested basic rotation with carry clear and set");
    $display("- Verified zero result scenarios");
    $display("- Checked all bit patterns (all 0s, all 1s, alternating)");
    $display("- Validated flag behavior (Z, N, C) for all cases");
    $display("- Confirmed register preservation (B, C unaffected)");
    $display("- Tested sequential rotations and bit cycling");
    $display("- Verified edge cases and complex bit patterns");
    $finish;
    // ============================ END TEST ==============================
  
  end

endmodule