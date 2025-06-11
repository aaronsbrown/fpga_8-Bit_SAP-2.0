`timescale 1ns/1ps
import test_utils_pkg::*; 
import arch_defs_pkg::*;  
// AIDEV-NOTE: Enhanced SUB_C testbench with 16 comprehensive test cases, following SUB_B pattern

module computer_tb;

  localparam string HEX_FILE = "../hardware/test/_fixtures_generated/SUB_C/ROM.hex";

  logic                  clk;
  logic                  reset;
  logic [DATA_WIDTH-1:0] computer_output;

  computer uut (
        .clk(clk),
        .reset(reset),
        .output_port_1(computer_output),
        .uart_rx(1'b1),    // UART not needed for SUB_C microinstruction testing
        .uart_tx()         // Leave unconnected - not needed for this test
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

    // ============================ BEGIN SUB_C COMPREHENSIVE TESTS ==============================
    $display("\n=== SUB_C (Subtract C from A) Comprehensive Test Suite ===");
    $display("Testing SUB_C instruction: A = A - C");
    $display("Flags: Z=+/- (result), N=+/- (result), C=1 if no borrow, C=0 if borrow\n");

    // ======================================================================
    // TEST 1: Basic subtraction with no borrow (A > C)
    // Assembly: LDI A, #$10; LDI B, #$BB; LDI C, #$05; SUB C
    // Expected: A=$0B, B=$BB, C=$05, Z=0, N=0, C=1 (no borrow)
    // ======================================================================
    $display("--- TEST 1: Basic subtraction no borrow ($10 - $05 = $0B) ---");
    
    // LDI A, #$10
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h10, "A after LDI A, #$10", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "LDI A: Z=0 (non-zero loaded)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "LDI A: N=0 (MSB clear)");

    // LDI B, #$BB (preservation test)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'hBB, "B after LDI B, #$BB", DATA_WIDTH);

    // LDI C, #$05
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h05, "C after LDI C, #$05", DATA_WIDTH);

    // SUB C: $10 - $05 = $0B, C=1 (no borrow)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("SUB C: $10 - $05 = $0B, C=1 (no borrow needed)");
    inspect_register(uut.u_cpu.a_out, 8'h0B, "A after SUB C ($10-$05)", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'hBB, "B preserved during SUB C", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'h05, "C preserved during SUB C", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $0B is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result $0B MSB clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: no borrow occurred");

    // ======================================================================
    // TEST 2: Basic subtraction with borrow (A < C)
    // Assembly: LDI A, #$05; LDI B, #$CC; LDI C, #$10; SUB C
    // Expected: A=$F5, B=$CC, C=$10, Z=0, N=1, C=0 (borrow)
    // ======================================================================
    $display("\n--- TEST 2: Basic subtraction with borrow ($05 - $10 = $F5) ---");
    
    // LDI A, #$05
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h05, "A after LDI A, #$05", DATA_WIDTH);

    // LDI B, #$CC (preservation test)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'hCC, "B after LDI B, #$CC", DATA_WIDTH);

    // LDI C, #$10
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h10, "C after LDI C, #$10", DATA_WIDTH);

    // SUB C: $05 - $10 = $F5, C=0 (borrow occurred)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("SUB C: $05 - $10 = $F5, C=0 (borrow required)");
    inspect_register(uut.u_cpu.a_out, 8'hF5, "A after SUB C ($05-$10)", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'hCC, "B preserved during SUB C", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'h10, "C preserved during SUB C", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $F5 is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result $F5 MSB set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: borrow occurred");

    // ======================================================================
    // TEST 3: Subtraction resulting in zero (A == C)
    // Assembly: LDI A, #$42; LDI B, #$DD; LDI C, #$42; SUB C
    // Expected: A=$00, B=$DD, C=$42, Z=1, N=0, C=1 (no borrow)
    // ======================================================================
    $display("\n--- TEST 3: Subtraction resulting in zero ($42 - $42 = $00) ---");
    
    // LDI A, #$42
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h42, "A after LDI A, #$42", DATA_WIDTH);

    // LDI B, #$DD (preservation test)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'hDD, "B after LDI B, #$DD", DATA_WIDTH);

    // LDI C, #$42
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h42, "C after LDI C, #$42", DATA_WIDTH);

    // SUB C: $42 - $42 = $00, C=1 (no borrow)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("SUB C: $42 - $42 = $00, C=1 (no borrow, zero result)");
    inspect_register(uut.u_cpu.a_out, 8'h00, "A after SUB C ($42-$42)", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'hDD, "B preserved during SUB C", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'h42, "C preserved during SUB C", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "Z=1: result $00 is zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result $00 MSB clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: no borrow occurred");

    // ======================================================================
    // TEST 4: Subtraction from zero (A=0, C>0)
    // Assembly: LDI A, #$00; LDI B, #$EE; LDI C, #$01; SUB C
    // Expected: A=$FF, B=$EE, C=$01, Z=0, N=1, C=0 (borrow)
    // ======================================================================
    $display("\n--- TEST 4: Subtraction from zero ($00 - $01 = $FF) ---");
    
    // LDI A, #$00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "A after LDI A, #$00", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "LDI A: Z=1 (zero loaded)");

    // LDI B, #$EE (preservation test)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'hEE, "B after LDI B, #$EE", DATA_WIDTH);

    // LDI C, #$01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h01, "C after LDI C, #$01", DATA_WIDTH);

    // SUB C: $00 - $01 = $FF, C=0 (borrow)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("SUB C: $00 - $01 = $FF, C=0 (borrow from zero)");
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A after SUB C ($00-$01)", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'hEE, "B preserved during SUB C", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'h01, "C preserved during SUB C", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $FF is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result $FF MSB set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: borrow occurred");

    // ======================================================================
    // TEST 5: Maximum value minus one (A=$FF, C=$01)
    // Assembly: LDI A, #$FF; LDI B, #$11; LDI C, #$01; SUB C
    // Expected: A=$FE, B=$11, C=$01, Z=0, N=1, C=1 (no borrow)
    // ======================================================================
    $display("\n--- TEST 5: Maximum value minus one ($FF - $01 = $FE) ---");
    
    // LDI A, #$FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A after LDI A, #$FF", DATA_WIDTH);

    // LDI B, #$11 (preservation test)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h11, "B after LDI B, #$11", DATA_WIDTH);

    // LDI C, #$01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h01, "C after LDI C, #$01", DATA_WIDTH);

    // SUB C: $FF - $01 = $FE, C=1 (no borrow)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("SUB C: $FF - $01 = $FE, C=1 (no borrow needed)");
    inspect_register(uut.u_cpu.a_out, 8'hFE, "A after SUB C ($FF-$01)", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h11, "B preserved during SUB C", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'h01, "C preserved during SUB C", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $FE is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result $FE MSB set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: no borrow occurred");

    // ======================================================================
    // TEST 6: Alternating bit patterns (A=$AA, C=$55)
    // Assembly: LDI A, #$AA; LDI B, #$22; LDI C, #$55; SUB C
    // Expected: A=$55, B=$22, C=$55, Z=0, N=0, C=1 (no borrow)
    // ======================================================================
    $display("\n--- TEST 6: Alternating bit patterns ($AA - $55 = $55) ---");
    
    // LDI A, #$AA
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hAA, "A after LDI A, #$AA", DATA_WIDTH);

    // LDI B, #$22 (preservation test)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h22, "B after LDI B, #$22", DATA_WIDTH);

    // LDI C, #$55
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h55, "C after LDI C, #$55", DATA_WIDTH);

    // SUB C: $AA - $55 = $55, C=1 (no borrow)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("SUB C: $AA (10101010) - $55 (01010101) = $55 (01010101), C=1");
    inspect_register(uut.u_cpu.a_out, 8'h55, "A after SUB C ($AA-$55)", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h22, "B preserved during SUB C", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'h55, "C preserved during SUB C", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $55 is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result $55 MSB clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: no borrow occurred");

    // ======================================================================
    // TEST 7: Reverse alternating with borrow (A=$55, C=$AA)
    // Assembly: LDI A, #$55; LDI B, #$33; LDI C, #$AA; SUB C
    // Expected: A=$AB, B=$33, C=$AA, Z=0, N=1, C=0 (borrow)
    // ======================================================================
    $display("\n--- TEST 7: Reverse alternating with borrow ($55 - $AA = $AB) ---");
    
    // LDI A, #$55
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h55, "A after LDI A, #$55", DATA_WIDTH);

    // LDI B, #$33 (preservation test)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h33, "B after LDI B, #$33", DATA_WIDTH);

    // LDI C, #$AA
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hAA, "C after LDI C, #$AA", DATA_WIDTH);

    // SUB C: $55 - $AA = $AB, C=0 (borrow)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("SUB C: $55 (01010101) - $AA (10101010) = $AB (10101011), C=0");
    inspect_register(uut.u_cpu.a_out, 8'hAB, "A after SUB C ($55-$AA)", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h33, "B preserved during SUB C", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hAA, "C preserved during SUB C", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $AB is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result $AB MSB set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: borrow occurred");

    // ======================================================================
    // TEST 8: Single bit subtraction (MSB test)
    // Assembly: LDI A, #$80; LDI B, #$44; LDI C, #$01; SUB C
    // Expected: A=$7F, B=$44, C=$01, Z=0, N=0, C=1 (no borrow)
    // ======================================================================
    $display("\n--- TEST 8: Single bit subtraction MSB test ($80 - $01 = $7F) ---");
    
    // LDI A, #$80
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h80, "A after LDI A, #$80", DATA_WIDTH);

    // LDI B, #$44 (preservation test)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h44, "B after LDI B, #$44", DATA_WIDTH);

    // LDI C, #$01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h01, "C after LDI C, #$01", DATA_WIDTH);

    // SUB C: $80 - $01 = $7F, C=1 (no borrow)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("SUB C: $80 (10000000) - $01 (00000001) = $7F (01111111), C=1");
    inspect_register(uut.u_cpu.a_out, 8'h7F, "A after SUB C ($80-$01)", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h44, "B preserved during SUB C", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'h01, "C preserved during SUB C", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $7F is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result $7F MSB clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: no borrow occurred");

    // ======================================================================
    // TEST 9: LSB boundary test (A=$01, C=$01)
    // Assembly: LDI A, #$01; LDI B, #$55; LDI C, #$01; SUB C
    // Expected: A=$00, B=$55, C=$01, Z=1, N=0, C=1 (no borrow)
    // ======================================================================
    $display("\n--- TEST 9: LSB boundary test ($01 - $01 = $00) ---");
    
    // LDI A, #$01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h01, "A after LDI A, #$01", DATA_WIDTH);

    // LDI B, #$55 (preservation test)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h55, "B after LDI B, #$55", DATA_WIDTH);

    // LDI C, #$01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h01, "C after LDI C, #$01", DATA_WIDTH);

    // SUB C: $01 - $01 = $00, C=1 (no borrow)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("SUB C: $01 - $01 = $00, C=1 (no borrow, zero result)");
    inspect_register(uut.u_cpu.a_out, 8'h00, "A after SUB C ($01-$01)", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h55, "B preserved during SUB C", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'h01, "C preserved during SUB C", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "Z=1: result $00 is zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result $00 MSB clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: no borrow occurred");

    // ======================================================================
    // TEST 10: MSB boundary test (A=$80, C=$80)
    // Assembly: LDI A, #$80; LDI B, #$66; LDI C, #$80; SUB C
    // Expected: A=$00, B=$66, C=$80, Z=1, N=0, C=1 (no borrow)
    // ======================================================================
    $display("\n--- TEST 10: MSB boundary test ($80 - $80 = $00) ---");
    
    // LDI A, #$80
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h80, "A after LDI A, #$80", DATA_WIDTH);

    // LDI B, #$66 (preservation test)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h66, "B after LDI B, #$66", DATA_WIDTH);

    // LDI C, #$80
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h80, "C after LDI C, #$80", DATA_WIDTH);

    // SUB C: $80 - $80 = $00, C=1 (no borrow)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("SUB C: $80 - $80 = $00, C=1 (no borrow, zero result)");
    inspect_register(uut.u_cpu.a_out, 8'h00, "A after SUB C ($80-$80)", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h66, "B preserved during SUB C", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'h80, "C preserved during SUB C", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "Z=1: result $00 is zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result $00 MSB clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: no borrow occurred");

    // ======================================================================
    // TEST 11: Large subtraction resulting in MSB set
    // Assembly: LDI A, #$C0; LDI B, #$77; LDI C, #$40; SUB C
    // Expected: A=$80, B=$77, C=$40, Z=0, N=1, C=1 (no borrow)
    // ======================================================================
    $display("\n--- TEST 11: Large subtraction with MSB set ($C0 - $40 = $80) ---");
    
    // LDI A, #$C0
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hC0, "A after LDI A, #$C0", DATA_WIDTH);

    // LDI B, #$77 (preservation test)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h77, "B after LDI B, #$77", DATA_WIDTH);

    // LDI C, #$40
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h40, "C after LDI C, #$40", DATA_WIDTH);

    // SUB C: $C0 - $40 = $80, C=1 (no borrow)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("SUB C: $C0 (11000000) - $40 (01000000) = $80 (10000000), C=1");
    inspect_register(uut.u_cpu.a_out, 8'h80, "A after SUB C ($C0-$40)", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h77, "B preserved during SUB C", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'h40, "C preserved during SUB C", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $80 is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result $80 MSB set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: no borrow occurred");

    // ======================================================================
    // TEST 12: Small numbers subtraction
    // Assembly: LDI A, #$03; LDI B, #$88; LDI C, #$02; SUB C
    // Expected: A=$01, B=$88, C=$02, Z=0, N=0, C=1 (no borrow)
    // ======================================================================
    $display("\n--- TEST 12: Small numbers subtraction ($03 - $02 = $01) ---");
    
    // LDI A, #$03
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h03, "A after LDI A, #$03", DATA_WIDTH);

    // LDI B, #$88 (preservation test)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h88, "B after LDI B, #$88", DATA_WIDTH);

    // LDI C, #$02
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h02, "C after LDI C, #$02", DATA_WIDTH);

    // SUB C: $03 - $02 = $01, C=1 (no borrow)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("SUB C: $03 - $02 = $01, C=1 (no borrow needed)");
    inspect_register(uut.u_cpu.a_out, 8'h01, "A after SUB C ($03-$02)", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h88, "B preserved during SUB C", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'h02, "C preserved during SUB C", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $01 is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result $01 MSB clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: no borrow occurred");

    // ======================================================================
    // TEST 13: Complex bit pattern 1
    // Assembly: LDI A, #$B7; LDI B, #$99; LDI C, #$29; SUB C
    // Expected: A=$8E, B=$99, C=$29, Z=0, N=1, C=1 (no borrow)
    // ======================================================================
    $display("\n--- TEST 13: Complex bit pattern 1 ($B7 - $29 = $8E) ---");
    
    // LDI A, #$B7
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hB7, "A after LDI A, #$B7", DATA_WIDTH);

    // LDI B, #$99 (preservation test)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h99, "B after LDI B, #$99", DATA_WIDTH);

    // LDI C, #$29
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h29, "C after LDI C, #$29", DATA_WIDTH);

    // SUB C: $B7 - $29 = $8E, C=1 (no borrow)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("SUB C: $B7 (10110111) - $29 (00101001) = $8E (10001110), C=1");
    inspect_register(uut.u_cpu.a_out, 8'h8E, "A after SUB C ($B7-$29)", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h99, "B preserved during SUB C", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'h29, "C preserved during SUB C", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $8E is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result $8E MSB set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: no borrow occurred");

    // ======================================================================
    // TEST 14: Complex bit pattern 2 (with borrow)
    // Assembly: LDI A, #$3C; LDI B, #$AA; LDI C, #$5E; SUB C
    // Expected: A=$DE, B=$AA, C=$5E, Z=0, N=1, C=0 (borrow)
    // ======================================================================
    $display("\n--- TEST 14: Complex bit pattern 2 with borrow ($3C - $5E = $DE) ---");
    
    // LDI A, #$3C
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h3C, "A after LDI A, #$3C", DATA_WIDTH);

    // LDI B, #$AA (preservation test)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'hAA, "B after LDI B, #$AA", DATA_WIDTH);

    // LDI C, #$5E
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h5E, "C after LDI C, #$5E", DATA_WIDTH);

    // SUB C: $3C - $5E = $DE, C=0 (borrow)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("SUB C: $3C (00111100) - $5E (01011110) = $DE (11011110), C=0");
    inspect_register(uut.u_cpu.a_out, 8'hDE, "A after SUB C ($3C-$5E)", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'hAA, "B preserved during SUB C", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'h5E, "C preserved during SUB C", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $DE is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result $DE MSB set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: borrow occurred");

    // ======================================================================
    // TEST 15: Register preservation final check
    // Assembly: LDI A, #$F0; LDI B, #$BB; LDI C, #$0F; SUB C
    // Expected: A=$E1, B=$BB (preserved), C=$0F, Z=0, N=1, C=1
    // ======================================================================
    $display("\n--- TEST 15: Register preservation final check ($F0 - $0F = $E1) ---");
    
    // LDI A, #$F0
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hF0, "A after LDI A, #$F0", DATA_WIDTH);

    // LDI B, #$BB (preservation test)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'hBB, "B after LDI B, #$BB", DATA_WIDTH);

    // LDI C, #$0F
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h0F, "C after LDI C, #$0F", DATA_WIDTH);

    // SUB C: $F0 - $0F = $E1, C=1 (no borrow)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("SUB C: $F0 (11110000) - $0F (00001111) = $E1 (11100001), C=1");
    inspect_register(uut.u_cpu.a_out, 8'hE1, "A after SUB C ($F0-$0F)", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'hBB, "B preserved during SUB C", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'h0F, "C preserved during SUB C", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $E1 is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result $E1 MSB set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: no borrow occurred");

    // ======================================================================
    // TEST 16: Edge case - subtract larger from smaller
    // Assembly: LDI A, #$01; LDI B, #$CC; LDI C, #$02; SUB C
    // Expected: A=$FF, B=$CC, C=$02, Z=0, N=1, C=0 (borrow)
    // ======================================================================
    $display("\n--- TEST 16: Edge case subtraction ($01 - $02 = $FF) ---");
    
    // LDI A, #$01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h01, "A after LDI A, #$01", DATA_WIDTH);

    // LDI B, #$CC (preservation test)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'hCC, "B after LDI B, #$CC", DATA_WIDTH);

    // LDI C, #$02
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h02, "C after LDI C, #$02", DATA_WIDTH);

    // SUB C: $01 - $02 = $FF, C=0 (borrow)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("SUB C: $01 - $02 = $FF, C=0 (borrow required)");
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A after SUB C ($01-$02)", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'hCC, "B preserved during SUB C", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'h02, "C preserved during SUB C", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $FF is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result $FF MSB set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: borrow occurred");

    // ======================================================================
    // HALT verification - ensure CPU properly stops
    // ======================================================================
    $display("\n--- Verifying HALT instruction ---");
    run_until_halt(300);  // Increased timeout for comprehensive test suite
    $display("CPU halted successfully");
    
    // Visual buffer for waveform inspection
    repeat(5) @(posedge clk);

    $display("SUB_C test finished.===========================\n\n");
    $display("All 16 SUB_C test cases passed successfully!");
    $display("- Tested basic subtraction with and without borrow");
    $display("- Verified zero result scenarios");
    $display("- Checked all bit patterns (all 0s, all 1s, alternating)");
    $display("- Validated flag behavior (Z, N, C) for all cases");
    $display("- Confirmed register preservation (B, C unaffected)");
    $display("- Tested edge cases and complex bit patterns");
    $display("- Verified borrow flag behavior correctly");
    $finish;
    // ============================ END TEST ==============================
  
  end

endmodule