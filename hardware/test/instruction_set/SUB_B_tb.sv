`timescale 1ns/1ps
import test_utils_pkg::*; 
import arch_defs_pkg::*;  
// AIDEV-NOTE: Enhanced SUB_B testbench with 16 comprehensive test cases, following JC/RAR/STA patterns

module computer_tb;

  localparam string HEX_FILE = "../hardware/test/_fixtures_generated/SUB_B/ROM.hex";

  logic                  clk;
  logic                  reset;
  logic [DATA_WIDTH-1:0] computer_output;

  computer uut (
        .clk(clk),
        .reset(reset),
        .output_port_1(computer_output),
        .uart_rx(1'b1),    // UART not needed for SUB_B microinstruction testing
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

    // ============================ BEGIN SUB_B COMPREHENSIVE TESTS ==============================
    $display("\n=== SUB_B (Subtract B from A) Comprehensive Test Suite ===");
    $display("Testing SUB_B instruction: A = A - B");
    $display("Flags: Z=+/- (result), N=+/- (result), C=1 if no borrow, C=0 if borrow\n");

    // ======================================================================
    // TEST 1: Basic subtraction with no borrow (A > B)
    // Assembly: LDI A, #$10; LDI B, #$05; LDI C, #$CC; SUB B
    // Expected: A=$0B, B=$05, C=$CC, Z=0, N=0, C=1 (no borrow)
    // ======================================================================
    $display("--- TEST 1: Basic subtraction no borrow ($10 - $05 = $0B) ---");
    
    // LDI A, #$10
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h10, "A after LDI A, #$10", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "LDI A: Z=0 (non-zero loaded)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "LDI A: N=0 (MSB clear)");

    // LDI B, #$05
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h05, "B after LDI B, #$05", DATA_WIDTH);

    // LDI C, #$CC (preservation test)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hCC, "C after LDI C, #$CC", DATA_WIDTH);

    // SUB B: $10 - $05 = $0B, C=1 (no borrow)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("SUB B: $10 - $05 = $0B, C=1 (no borrow needed)");
    inspect_register(uut.u_cpu.a_out, 8'h0B, "A after SUB B ($10-$05)", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h05, "B preserved during SUB B", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hCC, "C preserved during SUB B", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $0B is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result $0B MSB clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: no borrow occurred");

    // ======================================================================
    // TEST 2: Basic subtraction with borrow (A < B)
    // Assembly: LDI A, #$05; LDI B, #$10; SUB B
    // Expected: A=$F5, B=$10, C=$CC, Z=0, N=1, C=0 (borrow)
    // ======================================================================
    $display("\n--- TEST 2: Basic subtraction with borrow ($05 - $10 = $F5) ---");
    
    // LDI A, #$05
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h05, "A after LDI A, #$05", DATA_WIDTH);

    // LDI B, #$10
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h10, "B after LDI B, #$10", DATA_WIDTH);

    // SUB B: $05 - $10 = $F5, C=0 (borrow occurred)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("SUB B: $05 - $10 = $F5, C=0 (borrow required)");
    inspect_register(uut.u_cpu.a_out, 8'hF5, "A after SUB B ($05-$10)", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h10, "B preserved during SUB B", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hCC, "C preserved during SUB B", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $F5 is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result $F5 MSB set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: borrow occurred");

    // ======================================================================
    // TEST 3: Subtraction resulting in zero (A == B)
    // Assembly: LDI A, #$42; LDI B, #$42; SUB B
    // Expected: A=$00, B=$42, C=$CC, Z=1, N=0, C=1 (no borrow)
    // ======================================================================
    $display("\n--- TEST 3: Subtraction resulting in zero ($42 - $42 = $00) ---");
    
    // LDI A, #$42
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h42, "A after LDI A, #$42", DATA_WIDTH);

    // LDI B, #$42
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h42, "B after LDI B, #$42", DATA_WIDTH);

    // SUB B: $42 - $42 = $00, C=1 (no borrow)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("SUB B: $42 - $42 = $00, C=1 (no borrow, zero result)");
    inspect_register(uut.u_cpu.a_out, 8'h00, "A after SUB B ($42-$42)", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h42, "B preserved during SUB B", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hCC, "C preserved during SUB B", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "Z=1: result $00 is zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result $00 MSB clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: no borrow occurred");

    // ======================================================================
    // TEST 4: Subtraction from zero (A=0, B>0)
    // Assembly: LDI A, #$00; LDI B, #$01; SUB B
    // Expected: A=$FF, B=$01, C=$CC, Z=0, N=1, C=0 (borrow)
    // ======================================================================
    $display("\n--- TEST 4: Subtraction from zero ($00 - $01 = $FF) ---");
    
    // LDI A, #$00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "A after LDI A, #$00", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "LDI A: Z=1 (zero loaded)");

    // LDI B, #$01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h01, "B after LDI B, #$01", DATA_WIDTH);

    // SUB B: $00 - $01 = $FF, C=0 (borrow)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("SUB B: $00 - $01 = $FF, C=0 (borrow from zero)");
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A after SUB B ($00-$01)", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h01, "B preserved during SUB B", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hCC, "C preserved during SUB B", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $FF is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result $FF MSB set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: borrow occurred");

    // ======================================================================
    // TEST 5: Maximum value minus one (A=$FF, B=$01)
    // Assembly: LDI A, #$FF; LDI B, #$01; SUB B
    // Expected: A=$FE, B=$01, C=$CC, Z=0, N=1, C=1 (no borrow)
    // ======================================================================
    $display("\n--- TEST 5: Maximum value minus one ($FF - $01 = $FE) ---");
    
    // LDI A, #$FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A after LDI A, #$FF", DATA_WIDTH);

    // LDI B, #$01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h01, "B after LDI B, #$01", DATA_WIDTH);

    // SUB B: $FF - $01 = $FE, C=1 (no borrow)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("SUB B: $FF - $01 = $FE, C=1 (no borrow needed)");
    inspect_register(uut.u_cpu.a_out, 8'hFE, "A after SUB B ($FF-$01)", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h01, "B preserved during SUB B", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hCC, "C preserved during SUB B", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $FE is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result $FE MSB set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: no borrow occurred");

    // ======================================================================
    // TEST 6: Alternating bit patterns (A=$AA, B=$55)
    // Assembly: LDI A, #$AA; LDI B, #$55; SUB B
    // Expected: A=$55, B=$55, C=$CC, Z=0, N=0, C=1 (no borrow)
    // ======================================================================
    $display("\n--- TEST 6: Alternating bit patterns ($AA - $55 = $55) ---");
    
    // LDI A, #$AA
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hAA, "A after LDI A, #$AA", DATA_WIDTH);

    // LDI B, #$55
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h55, "B after LDI B, #$55", DATA_WIDTH);

    // SUB B: $AA - $55 = $55, C=1 (no borrow)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("SUB B: $AA (10101010) - $55 (01010101) = $55 (01010101), C=1");
    inspect_register(uut.u_cpu.a_out, 8'h55, "A after SUB B ($AA-$55)", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h55, "B preserved during SUB B", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hCC, "C preserved during SUB B", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $55 is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result $55 MSB clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: no borrow occurred");

    // ======================================================================
    // TEST 7: Reverse alternating pattern with borrow (A=$55, B=$AA)
    // Assembly: LDI A, #$55; LDI B, #$AA; SUB B
    // Expected: A=$AB, B=$AA, C=$CC, Z=0, N=1, C=0 (borrow)
    // ======================================================================
    $display("\n--- TEST 7: Reverse alternating with borrow ($55 - $AA = $AB) ---");
    
    // LDI A, #$55
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h55, "A after LDI A, #$55", DATA_WIDTH);

    // LDI B, #$AA
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'hAA, "B after LDI B, #$AA", DATA_WIDTH);

    // SUB B: $55 - $AA = $AB, C=0 (borrow)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("SUB B: $55 (01010101) - $AA (10101010) = $AB (10101011), C=0");
    inspect_register(uut.u_cpu.a_out, 8'hAB, "A after SUB B ($55-$AA)", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'hAA, "B preserved during SUB B", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hCC, "C preserved during SUB B", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $AB is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result $AB MSB set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: borrow occurred");

    // ======================================================================
    // TEST 8: Single bit subtraction (MSB test)
    // Assembly: LDI A, #$80; LDI B, #$01; SUB B
    // Expected: A=$7F, B=$01, C=$CC, Z=0, N=0, C=1 (no borrow)
    // ======================================================================
    $display("\n--- TEST 8: Single bit subtraction MSB test ($80 - $01 = $7F) ---");
    
    // LDI A, #$80
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h80, "A after LDI A, #$80", DATA_WIDTH);

    // LDI B, #$01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h01, "B after LDI B, #$01", DATA_WIDTH);

    // SUB B: $80 - $01 = $7F, C=1 (no borrow)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("SUB B: $80 (10000000) - $01 (00000001) = $7F (01111111), C=1");
    inspect_register(uut.u_cpu.a_out, 8'h7F, "A after SUB B ($80-$01)", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h01, "B preserved during SUB B", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hCC, "C preserved during SUB B", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $7F is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result $7F MSB clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: no borrow occurred");

    // ======================================================================
    // TEST 9: LSB boundary test (A=$01, B=$01)
    // Assembly: LDI A, #$01; LDI B, #$01; SUB B
    // Expected: A=$00, B=$01, C=$CC, Z=1, N=0, C=1 (no borrow)
    // ======================================================================
    $display("\n--- TEST 9: LSB boundary test ($01 - $01 = $00) ---");
    
    // LDI A, #$01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h01, "A after LDI A, #$01", DATA_WIDTH);

    // LDI B, #$01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h01, "B after LDI B, #$01", DATA_WIDTH);

    // SUB B: $01 - $01 = $00, C=1 (no borrow)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("SUB B: $01 - $01 = $00, C=1 (no borrow, zero result)");
    inspect_register(uut.u_cpu.a_out, 8'h00, "A after SUB B ($01-$01)", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h01, "B preserved during SUB B", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hCC, "C preserved during SUB B", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "Z=1: result $00 is zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result $00 MSB clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: no borrow occurred");

    // ======================================================================
    // TEST 10: MSB boundary test (A=$80, B=$80)
    // Assembly: LDI A, #$80; LDI B, #$80; SUB B
    // Expected: A=$00, B=$80, C=$CC, Z=1, N=0, C=1 (no borrow)
    // ======================================================================
    $display("\n--- TEST 10: MSB boundary test ($80 - $80 = $00) ---");
    
    // LDI A, #$80
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h80, "A after LDI A, #$80", DATA_WIDTH);

    // LDI B, #$80
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h80, "B after LDI B, #$80", DATA_WIDTH);

    // SUB B: $80 - $80 = $00, C=1 (no borrow)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("SUB B: $80 - $80 = $00, C=1 (no borrow, zero result)");
    inspect_register(uut.u_cpu.a_out, 8'h00, "A after SUB B ($80-$80)", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h80, "B preserved during SUB B", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hCC, "C preserved during SUB B", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "Z=1: result $00 is zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result $00 MSB clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: no borrow occurred");

    // ======================================================================
    // TEST 11: Large subtraction resulting in MSB set
    // Assembly: LDI A, #$C0; LDI B, #$40; SUB B
    // Expected: A=$80, B=$40, C=$CC, Z=0, N=1, C=1 (no borrow)
    // ======================================================================
    $display("\n--- TEST 11: Large subtraction with MSB set ($C0 - $40 = $80) ---");
    
    // LDI A, #$C0
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hC0, "A after LDI A, #$C0", DATA_WIDTH);

    // LDI B, #$40
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h40, "B after LDI B, #$40", DATA_WIDTH);

    // SUB B: $C0 - $40 = $80, C=1 (no borrow)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("SUB B: $C0 (11000000) - $40 (01000000) = $80 (10000000), C=1");
    inspect_register(uut.u_cpu.a_out, 8'h80, "A after SUB B ($C0-$40)", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h40, "B preserved during SUB B", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hCC, "C preserved during SUB B", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $80 is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result $80 MSB set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: no borrow occurred");

    // ======================================================================
    // TEST 12: Small numbers subtraction
    // Assembly: LDI A, #$03; LDI B, #$02; SUB B
    // Expected: A=$01, B=$02, C=$CC, Z=0, N=0, C=1 (no borrow)
    // ======================================================================
    $display("\n--- TEST 12: Small numbers subtraction ($03 - $02 = $01) ---");
    
    // LDI A, #$03
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h03, "A after LDI A, #$03", DATA_WIDTH);

    // LDI B, #$02
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h02, "B after LDI B, #$02", DATA_WIDTH);

    // SUB B: $03 - $02 = $01, C=1 (no borrow)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("SUB B: $03 - $02 = $01, C=1 (no borrow needed)");
    inspect_register(uut.u_cpu.a_out, 8'h01, "A after SUB B ($03-$02)", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h02, "B preserved during SUB B", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hCC, "C preserved during SUB B", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $01 is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result $01 MSB clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: no borrow occurred");

    // ======================================================================
    // TEST 13: Complex bit pattern 1
    // Assembly: LDI A, #$B7; LDI B, #$29; SUB B
    // Expected: A=$8E, B=$29, C=$CC, Z=0, N=1, C=1 (no borrow)
    // ======================================================================
    $display("\n--- TEST 13: Complex bit pattern 1 ($B7 - $29 = $8E) ---");
    
    // LDI A, #$B7
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hB7, "A after LDI A, #$B7", DATA_WIDTH);

    // LDI B, #$29
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h29, "B after LDI B, #$29", DATA_WIDTH);

    // SUB B: $B7 - $29 = $8E, C=1 (no borrow)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("SUB B: $B7 (10110111) - $29 (00101001) = $8E (10001110), C=1");
    inspect_register(uut.u_cpu.a_out, 8'h8E, "A after SUB B ($B7-$29)", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h29, "B preserved during SUB B", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hCC, "C preserved during SUB B", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $8E is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result $8E MSB set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: no borrow occurred");

    // ======================================================================
    // TEST 14: Complex bit pattern 2 (with borrow)
    // Assembly: LDI A, #$3C; LDI B, #$5E; SUB B
    // Expected: A=$DE, B=$5E, C=$CC, Z=0, N=1, C=0 (borrow)
    // ======================================================================
    $display("\n--- TEST 14: Complex bit pattern 2 with borrow ($3C - $5E = $DE) ---");
    
    // LDI A, #$3C
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h3C, "A after LDI A, #$3C", DATA_WIDTH);

    // LDI B, #$5E
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h5E, "B after LDI B, #$5E", DATA_WIDTH);

    // SUB B: $3C - $5E = $DE, C=0 (borrow)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("SUB B: $3C (00111100) - $5E (01011110) = $DE (11011110), C=0");
    inspect_register(uut.u_cpu.a_out, 8'hDE, "A after SUB B ($3C-$5E)", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h5E, "B preserved during SUB B", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hCC, "C preserved during SUB B", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $DE is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result $DE MSB set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: borrow occurred");

    // ======================================================================
    // TEST 15: Register preservation final check
    // Assembly: LDI A, #$F0; LDI B, #$0F; LDI C, #$AA; SUB B
    // Expected: A=$E1, B=$0F, C=$AA (preserved), Z=0, N=1, C=1
    // ======================================================================
    $display("\n--- TEST 15: Register preservation final check ($F0 - $0F = $E1) ---");
    
    // LDI A, #$F0
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hF0, "A after LDI A, #$F0", DATA_WIDTH);

    // LDI B, #$0F
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h0F, "B after LDI B, #$0F", DATA_WIDTH);

    // LDI C, #$AA
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hAA, "C after LDI C, #$AA", DATA_WIDTH);

    // SUB B: $F0 - $0F = $E1, C=1 (no borrow)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("SUB B: $F0 (11110000) - $0F (00001111) = $E1 (11100001), C=1");
    inspect_register(uut.u_cpu.a_out, 8'hE1, "A after SUB B ($F0-$0F)", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h0F, "B preserved during SUB B", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hAA, "C preserved during SUB B", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result $E1 is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result $E1 MSB set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: no borrow occurred");

    // ======================================================================
    // TEST 16: Edge case - subtract larger from smaller
    // Assembly: LDI A, #$01; LDI B, #$02; SUB B
    // Expected: A=$FF, B=$02, C=$AA, Z=0, N=1, C=0 (borrow)
    // ======================================================================
    $display("\n--- TEST 16: Edge case subtraction ($01 - $02 = $FF) ---");
    
    // LDI A, #$01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h01, "A after LDI A, #$01", DATA_WIDTH);

    // LDI B, #$02
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h02, "B after LDI B, #$02", DATA_WIDTH);

    // SUB B: $01 - $02 = $FF, C=0 (borrow)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("SUB B: $01 - $02 = $FF, C=0 (borrow required)");
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A after SUB B ($01-$02)", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h02, "B preserved during SUB B", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hAA, "C preserved during SUB B", DATA_WIDTH);
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

    $display("SUB_B test finished.===========================\n\n");
    $display("All 16 SUB_B test cases passed successfully!");
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