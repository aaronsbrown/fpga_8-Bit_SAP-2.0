`timescale 1ns/1ps
import test_utils_pkg::*; 
import arch_defs_pkg::*;  

// AIDEV-NOTE: Enhanced comprehensive testbench for ADD_B and ADD_C instructions
module computer_tb;

  localparam string HEX_FILE = "../hardware/test/_fixtures_generated/ADD_B_AND_C/ROM.hex";

  logic                  clk;
  logic                  reset;
  logic [DATA_WIDTH-1:0] computer_output;

  computer uut (
        .clk(clk),
        .reset(reset),
        .output_port_1(computer_output),
        .uart_rx(1'b1),     // UART not used in ADD instruction testing - tie high
        .uart_tx()          // UART not used in ADD instruction testing - leave open
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

    // ============================ BEGIN ADD_B AND ADD_C COMPREHENSIVE TESTS ==============================
    $display("\n=== ADD_B and ADD_C Comprehensive Test Suite ===");
    $display("Testing both ADD_B and ADD_C instructions with edge cases and flag behavior\n");

    // =================================================================
    // TEST GROUP 1: ADD_B Basic Operations  
    // =================================================================
    $display("--- TEST GROUP 1: ADD_B Basic Operations ---");
    
    // TEST 1: Basic ADD_B with small positive numbers
    // Assembly: LDI A, #$10; LDI B, #$05; LDI C, #$AA; ADD B
    // Expected: A = $10 + $05 = $15 (Z=0, N=0, C=0)
    $display("\n--- TEST 1: Basic ADD_B ($10 + $05) ---");
    
    // LDI A, #$10
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h10, "A after LDI A, #$10", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "LDI A: Z=0 (non-zero load)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "LDI A: N=0 (positive load)");

    // LDI B, #$05  
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h05, "B after LDI B, #$05", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "LDI B: Z=0 (non-zero load)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "LDI B: N=0 (positive load)");

    // LDI C, #$AA (register preservation test setup)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hAA, "C after LDI C, #$AA (preserve test)", DATA_WIDTH);

    // ADD B: A = A + B = $10 + $05 = $15
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("ADD B: $10 + $05 = $15");
    inspect_register(uut.u_cpu.a_out, 8'h15, "A after ADD B ($10 + $05)", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hAA, "C preserved during ADD B", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "ADD B: Z=0 (result non-zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "ADD B: N=0 (result positive)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "ADD B: C=0 (no carry generated)");

    // TEST 2: ADD_B resulting in zero with carry
    // Assembly: LDI A, #$FF; LDI B, #$01; ADD B
    // Expected: A = $FF + $01 = $00 (Z=1, N=0, C=1)
    $display("\n--- TEST 2: ADD_B resulting in zero ($FF + $01) ---");
    
    // LDI A, #$FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A after LDI A, #$FF", DATA_WIDTH);

    // LDI B, #$01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h01, "B after LDI B, #$01", DATA_WIDTH);

    // ADD B: A = A + B = $FF + $01 = $00 with carry
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("ADD B: $FF + $01 = $00 (with carry)");
    inspect_register(uut.u_cpu.a_out, 8'h00, "A after ADD B ($FF + $01)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "ADD B: Z=1 (result is zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "ADD B: N=0 (result MSB clear)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "ADD B: C=1 (carry from bit 7)");

    // TEST 3: ADD_B with both operands having MSB set
    // Assembly: LDI A, #$80; LDI B, #$80; ADD B
    // Expected: A = $80 + $80 = $00 (Z=1, N=0, C=1)
    $display("\n--- TEST 3: ADD_B both MSB set ($80 + $80) ---");
    
    // LDI A, #$80
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h80, "A after LDI A, #$80", DATA_WIDTH);

    // LDI B, #$80
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h80, "B after LDI B, #$80", DATA_WIDTH);

    // ADD B: A = A + B = $80 + $80 = $00 with carry
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("ADD B: $80 + $80 = $00 (MSB + MSB with carry)");
    inspect_register(uut.u_cpu.a_out, 8'h00, "A after ADD B ($80 + $80)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "ADD B: Z=1 (result is zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "ADD B: N=0 (result MSB clear)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "ADD B: C=1 (carry from MSB addition)");

    // TEST 4: ADD_B resulting in negative (MSB set)
    // Assembly: LDI A, #$7F; LDI B, #$01; ADD B
    // Expected: A = $7F + $01 = $80 (Z=0, N=1, C=0)
    $display("\n--- TEST 4: ADD_B resulting in negative ($7F + $01) ---");
    
    // LDI A, #$7F
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h7F, "A after LDI A, #$7F", DATA_WIDTH);

    // LDI B, #$01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h01, "B after LDI B, #$01", DATA_WIDTH);

    // ADD B: A = A + B = $7F + $01 = $80
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("ADD B: $7F + $01 = $80 (overflow to negative)");
    inspect_register(uut.u_cpu.a_out, 8'h80, "A after ADD B ($7F + $01)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "ADD B: Z=0 (result non-zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "ADD B: N=1 (result MSB set)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "ADD B: C=0 (no carry from bit 7)");

    // TEST 5: ADD_B alternating bit pattern test
    // Assembly: LDI A, #$55; LDI B, #$AA; ADD B
    // Expected: A = $55 + $AA = $FF (Z=0, N=1, C=0)
    $display("\n--- TEST 5: ADD_B alternating patterns ($55 + $AA) ---");
    
    // LDI A, #$55
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h55, "A after LDI A, #$55", DATA_WIDTH);

    // LDI B, #$AA
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'hAA, "B after LDI B, #$AA", DATA_WIDTH);

    // ADD B: A = A + B = $55 + $AA = $FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("ADD B: $55 + $AA = $FF (01010101 + 10101010)");
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A after ADD B ($55 + $AA)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "ADD B: Z=0 (result non-zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "ADD B: N=1 (result MSB set)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "ADD B: C=0 (no carry from bit 7)");

    // TEST 6: ADD_B zero plus zero
    // Assembly: LDI A, #$00; LDI B, #$00; ADD B
    // Expected: A = $00 + $00 = $00 (Z=1, N=0, C=0)
    $display("\n--- TEST 6: ADD_B zero plus zero ($00 + $00) ---");
    
    // LDI A, #$00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "A after LDI A, #$00", DATA_WIDTH);

    // LDI B, #$00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h00, "B after LDI B, #$00", DATA_WIDTH);

    // ADD B: A = A + B = $00 + $00 = $00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("ADD B: $00 + $00 = $00 (identity operation)");
    inspect_register(uut.u_cpu.a_out, 8'h00, "A after ADD B ($00 + $00)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "ADD B: Z=1 (result is zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "ADD B: N=0 (result MSB clear)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "ADD B: C=0 (no carry generated)");

    // TEST 7: ADD_B single bit test (LSB)
    // Assembly: LDI A, #$00; LDI B, #$01; ADD B
    // Expected: A = $00 + $01 = $01 (Z=0, N=0, C=0)
    $display("\n--- TEST 7: ADD_B single bit LSB ($00 + $01) ---");
    
    // LDI A, #$00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "A after LDI A, #$00", DATA_WIDTH);

    // LDI B, #$01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h01, "B after LDI B, #$01", DATA_WIDTH);

    // ADD B: A = A + B = $00 + $01 = $01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("ADD B: $00 + $01 = $01 (LSB only)");
    inspect_register(uut.u_cpu.a_out, 8'h01, "A after ADD B ($00 + $01)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "ADD B: Z=0 (result non-zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "ADD B: N=0 (result MSB clear)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "ADD B: C=0 (no carry generated)");

    // TEST 8: ADD_B single bit test (MSB)
    // Assembly: LDI A, #$00; LDI B, #$80; ADD B
    // Expected: A = $00 + $80 = $80 (Z=0, N=1, C=0)
    $display("\n--- TEST 8: ADD_B single bit MSB ($00 + $80) ---");
    
    // LDI A, #$00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "A after LDI A, #$00", DATA_WIDTH);

    // LDI B, #$80
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h80, "B after LDI B, #$80", DATA_WIDTH);

    // ADD B: A = A + B = $00 + $80 = $80
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("ADD B: $00 + $80 = $80 (MSB only)");
    inspect_register(uut.u_cpu.a_out, 8'h80, "A after ADD B ($00 + $80)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "ADD B: Z=0 (result non-zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "ADD B: N=1 (result MSB set)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "ADD B: C=0 (no carry generated)");

    // =================================================================
    // TEST GROUP 2: ADD_C Basic Operations
    // =================================================================
    $display("\n--- TEST GROUP 2: ADD_C Basic Operations ---");
    
    // TEST 9: Basic ADD_C with small positive numbers
    // Assembly: LDI A, #$08; LDI B, #$BB; LDI C, #$03; ADD C
    // Expected: A = $08 + $03 = $0B (Z=0, N=0, C=0)
    $display("\n--- TEST 9: Basic ADD_C ($08 + $03) ---");
    
    // LDI A, #$08
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h08, "A after LDI A, #$08", DATA_WIDTH);

    // LDI B, #$BB (preservation test)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'hBB, "B after LDI B, #$BB (preserve test)", DATA_WIDTH);

    // LDI C, #$03
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h03, "C after LDI C, #$03", DATA_WIDTH);

    // ADD C: A = A + C = $08 + $03 = $0B
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("ADD C: $08 + $03 = $0B");
    inspect_register(uut.u_cpu.a_out, 8'h0B, "A after ADD C ($08 + $03)", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'hBB, "B preserved during ADD C", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "ADD C: Z=0 (result non-zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "ADD C: N=0 (result positive)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "ADD C: C=0 (no carry generated)");

    // TEST 10: ADD_C resulting in zero with carry
    // Assembly: LDI A, #$FE; LDI C, #$02; ADD C
    // Expected: A = $FE + $02 = $00 (Z=1, N=0, C=1)
    $display("\n--- TEST 10: ADD_C resulting in zero ($FE + $02) ---");
    
    // LDI A, #$FE
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFE, "A after LDI A, #$FE", DATA_WIDTH);

    // LDI C, #$02
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h02, "C after LDI C, #$02", DATA_WIDTH);

    // ADD C: A = A + C = $FE + $02 = $00 with carry
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("ADD C: $FE + $02 = $00 (wraparound with carry)");
    inspect_register(uut.u_cpu.a_out, 8'h00, "A after ADD C ($FE + $02)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "ADD C: Z=1 (result is zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "ADD C: N=0 (result MSB clear)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "ADD C: C=1 (carry from overflow)");

    // TEST 11: ADD_C with both operands having MSB set
    // Assembly: LDI A, #$C0; LDI C, #$C0; ADD C
    // Expected: A = $C0 + $C0 = $80 (Z=0, N=1, C=1)
    $display("\n--- TEST 11: ADD_C both MSB set ($C0 + $C0) ---");
    
    // LDI A, #$C0
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hC0, "A after LDI A, #$C0", DATA_WIDTH);

    // LDI C, #$C0
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hC0, "C after LDI C, #$C0", DATA_WIDTH);

    // ADD C: A = A + C = $C0 + $C0 = $80 with carry
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("ADD C: $C0 + $C0 = $80 (both MSB set with carry)");
    inspect_register(uut.u_cpu.a_out, 8'h80, "A after ADD C ($C0 + $C0)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "ADD C: Z=0 (result non-zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "ADD C: N=1 (result MSB set)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "ADD C: C=1 (carry generated)");

    // TEST 12: ADD_C resulting in negative (MSB set)
    // Assembly: LDI A, #$60; LDI C, #$20; ADD C
    // Expected: A = $60 + $20 = $80 (Z=0, N=1, C=0)
    $display("\n--- TEST 12: ADD_C resulting in negative ($60 + $20) ---");
    
    // LDI A, #$60
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h60, "A after LDI A, #$60", DATA_WIDTH);

    // LDI C, #$20
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h20, "C after LDI C, #$20", DATA_WIDTH);

    // ADD C: A = A + C = $60 + $20 = $80
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("ADD C: $60 + $20 = $80 (positive to negative)");
    inspect_register(uut.u_cpu.a_out, 8'h80, "A after ADD C ($60 + $20)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "ADD C: Z=0 (result non-zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "ADD C: N=1 (result MSB set)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "ADD C: C=0 (no carry from bit 7)");

    // TEST 13: ADD_C alternating bit pattern test
    // Assembly: LDI A, #$33; LDI C, #$CC; ADD C
    // Expected: A = $33 + $CC = $FF (Z=0, N=1, C=0)
    $display("\n--- TEST 13: ADD_C alternating patterns ($33 + $CC) ---");
    
    // LDI A, #$33
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h33, "A after LDI A, #$33", DATA_WIDTH);

    // LDI C, #$CC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hCC, "C after LDI C, #$CC", DATA_WIDTH);

    // ADD C: A = A + C = $33 + $CC = $FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("ADD C: $33 + $CC = $FF (00110011 + 11001100)");
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A after ADD C ($33 + $CC)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "ADD C: Z=0 (result non-zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "ADD C: N=1 (result MSB set)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "ADD C: C=0 (no carry from bit 7)");

    // TEST 14: ADD_C with maximum values
    // Assembly: LDI A, #$FF; LDI C, #$FF; ADD C
    // Expected: A = $FF + $FF = $FE (Z=0, N=1, C=1)
    $display("\n--- TEST 14: ADD_C maximum values ($FF + $FF) ---");
    
    // LDI A, #$FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A after LDI A, #$FF", DATA_WIDTH);

    // LDI C, #$FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hFF, "C after LDI C, #$FF", DATA_WIDTH);

    // ADD C: A = A + C = $FF + $FF = $FE with carry
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("ADD C: $FF + $FF = $FE (maximum addition with carry)");
    inspect_register(uut.u_cpu.a_out, 8'hFE, "A after ADD C ($FF + $FF)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "ADD C: Z=0 (result non-zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "ADD C: N=1 (result MSB set)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "ADD C: C=1 (carry generated)");

    // =================================================================
    // TEST GROUP 3: Register Preservation and Chain Operations
    // =================================================================
    $display("\n--- TEST GROUP 3: Register Preservation and Chain Operations ---");
    
    // TEST 15: ADD_B register preservation verification
    // Assembly: LDI A, #$20; LDI B, #$10; LDI C, #$DD; ADD B
    // Expected: A = $20 + $10 = $30, C should be preserved
    $display("\n--- TEST 15: ADD_B register preservation ($20 + $10) ---");
    
    // LDI A, #$20
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h20, "A after LDI A, #$20", DATA_WIDTH);

    // LDI B, #$10
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h10, "B after LDI B, #$10", DATA_WIDTH);

    // LDI C, #$DD
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hDD, "C after LDI C, #$DD (preserve test)", DATA_WIDTH);

    // ADD B: A = A + B = $20 + $10 = $30
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("ADD B: $20 + $10 = $30 (preservation test)");
    inspect_register(uut.u_cpu.a_out, 8'h30, "A after ADD B ($20 + $10)", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hDD, "C preserved during ADD B", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "ADD B: Z=0 (result non-zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "ADD B: N=0 (result positive)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "ADD B: C=0 (no carry generated)");

    // TEST 16: ADD_C register preservation verification
    // Assembly: LDI A, #$15; LDI C, #$0A; ADD C
    // Expected: A = $15 + $0A = $1F, B should still be preserved
    $display("\n--- TEST 16: ADD_C register preservation ($15 + $0A) ---");
    
    // LDI A, #$15
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h15, "A after LDI A, #$15", DATA_WIDTH);

    // B should still be $10 from previous test
    inspect_register(uut.u_cpu.b_out, 8'h10, "B preserved from previous test", DATA_WIDTH);

    // LDI C, #$0A
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h0A, "C after LDI C, #$0A", DATA_WIDTH);

    // ADD C: A = A + C = $15 + $0A = $1F
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("ADD C: $15 + $0A = $1F (preservation test)");
    inspect_register(uut.u_cpu.a_out, 8'h1F, "A after ADD C ($15 + $0A)", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h10, "B preserved during ADD C", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "ADD C: Z=0 (result non-zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "ADD C: N=0 (result positive)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "ADD C: C=0 (no carry generated)");

    // TEST 17: Chain operations - ADD_B followed by ADD_C
    // Assembly: LDI A, #$10; LDI B, #$05; LDI C, #$05; ADD B; ADD C
    // Expected: First A = $10 + $05 = $15, then A = $15 + $05 = $1A
    $display("\n--- TEST 17: Chain operations ADD_B then ADD_C ---");
    
    // LDI A, #$10
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h10, "A after LDI A, #$10", DATA_WIDTH);

    // LDI B, #$05
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h05, "B after LDI B, #$05", DATA_WIDTH);

    // LDI C, #$05
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h05, "C after LDI C, #$05", DATA_WIDTH);

    // ADD B: A = A + B = $10 + $05 = $15
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("Chain Step 1 - ADD B: $10 + $05 = $15");
    inspect_register(uut.u_cpu.a_out, 8'h15, "A after first ADD B ($10 + $05)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Chain ADD B: Z=0 (result non-zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "Chain ADD B: N=0 (result positive)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "Chain ADD B: C=0 (no carry generated)");

    // ADD C: A = A + C = $15 + $05 = $1A
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("Chain Step 2 - ADD C: $15 + $05 = $1A");
    inspect_register(uut.u_cpu.a_out, 8'h1A, "A after chained ADD C ($15 + $05)", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h05, "B preserved during chain", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'h05, "C preserved during chain", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Chain ADD C: Z=0 (result non-zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "Chain ADD C: N=0 (result positive)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "Chain ADD C: C=0 (no carry generated)");

    // =================================================================
    // HALT verification - ensure CPU properly stops
    // =================================================================
    $display("\n--- Verifying HALT instruction ---");
    run_until_halt(200);  // Increased timeout for comprehensive test suite
    $display("CPU halted successfully");
    
    // Visual buffer for waveform inspection
    repeat(5) @(posedge clk);

    $display("\n=== ADD_B and ADD_C Enhanced Test Summary ===");
    $display("✓ ADD_B basic operations (8 tests)");
    $display("✓ ADD_C basic operations (6 tests)");
    $display("✓ Register preservation verification");
    $display("✓ Chain operations testing");
    $display("✓ Edge cases (zero results, negative results, carries)");
    $display("✓ Bit pattern testing (alternating, single bits, maximum values)");
    $display("✓ All flag states (Zero, Negative, Carry) thoroughly tested");
    $display("ADD_B_AND_C test finished.===========================\n\n");
    $display("All 17 test cases passed successfully!");
    $finish;
    // ============================ END TEST ==============================
  
  end

endmodule