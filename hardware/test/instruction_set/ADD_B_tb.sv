`timescale 1ns/1ps
import test_utils_pkg::*; 
import arch_defs_pkg::*;  

module computer_tb;

  localparam string HEX_FILE = "../hardware/test/fixtures_generated/ADD_B/ROM.hex";

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

    // ============================ BEGIN ADD_B COMPREHENSIVE TESTS ==============================
    $display("\n=== ADD_B Comprehensive Test Suite ===");
    $display("Testing ADD_B instruction functionality, edge cases, and flag behavior\n");

    // =================================================================
    // TEST 1: Basic Addition - Small positive numbers
    // Assembly: LDI A, #$01; LDI B, #$02; LDI C, #$AA; ADD B
    // Expected: A = $01 + $02 = $03 (Z=0, N=0, C=0)
    // =================================================================
    $display("--- TEST 1: Basic Addition ($01 + $02) ---");
    
    // LDI A, #$01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h01, "A after LDI A, #$01", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z flag clear after LDI A");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N flag clear after LDI A");

    // LDI B, #$02  
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h02, "B after LDI B, #$02", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z flag clear after LDI B");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N flag clear after LDI B");

    // LDI C, #$AA (register preservation test setup)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hAA, "C after LDI C, #$AA", DATA_WIDTH);

    // ADD B: A = A + B = $01 + $02 = $03
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("ADD B: $01 + $02 = $03");
    inspect_register(uut.u_cpu.a_out, 8'h03, "A after ADD B ($01 + $02)", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hAA, "C preserved during ADD B", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result is positive");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: no carry generated");

    // =================================================================
    // TEST 2: Addition resulting in zero
    // Assembly: LDI A, #$FF; LDI B, #$01; ADD B  
    // Expected: A = $FF + $01 = $00 (Z=1, N=0, C=1)
    // =================================================================
    $display("\n--- TEST 2: Addition resulting in zero ($FF + $01) ---");
    
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
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "Z=1: result is zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result MSB is clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: carry generated from bit 7");

    // =================================================================
    // TEST 3: Addition with carry generation  
    // Assembly: LDI A, #$80; LDI B, #$80; ADD B
    // Expected: A = $80 + $80 = $00 (Z=1, N=0, C=1)
    // =================================================================
    $display("\n--- TEST 3: Addition with carry ($80 + $80) ---");
    
    // LDI A, #$80
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h80, "A after LDI A, #$80", DATA_WIDTH);

    // LDI B, #$80
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h80, "B after LDI B, #$80", DATA_WIDTH);

    // ADD B: A = A + B = $80 + $80 = $00 with carry
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("ADD B: $80 + $80 = $00 (with carry)");
    inspect_register(uut.u_cpu.a_out, 8'h00, "A after ADD B ($80 + $80)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "Z=1: result is zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result MSB is clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: carry from MSB addition");

    // =================================================================
    // TEST 4: Addition resulting in negative (MSB set)
    // Assembly: LDI A, #$7F; LDI B, #$01; ADD B
    // Expected: A = $7F + $01 = $80 (Z=0, N=1, C=0)
    // =================================================================
    $display("\n--- TEST 4: Addition resulting in negative ($7F + $01) ---");
    
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
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result MSB is set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: no carry from bit 7");

    // =================================================================
    // TEST 5: Addition with both operands having MSB set
    // Assembly: LDI A, #$FF; LDI B, #$FF; ADD B
    // Expected: A = $FF + $FF = $FE (Z=0, N=1, C=1)
    // =================================================================
    $display("\n--- TEST 5: Both operands MSB set ($FF + $FF) ---");
    
    // LDI A, #$FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A after LDI A, #$FF", DATA_WIDTH);

    // LDI B, #$FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'hFF, "B after LDI B, #$FF", DATA_WIDTH);

    // ADD B: A = A + B = $FF + $FF = $FE with carry
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("ADD B: $FF + $FF = $FE (with carry)");
    inspect_register(uut.u_cpu.a_out, 8'hFE, "A after ADD B ($FF + $FF)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result MSB is set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: carry generated");

    // =================================================================
    // TEST 6: Zero plus zero
    // Assembly: LDI A, #$00; LDI B, #$00; ADD B
    // Expected: A = $00 + $00 = $00 (Z=1, N=0, C=0)
    // =================================================================
    $display("\n--- TEST 6: Zero plus zero ($00 + $00) ---");
    
    // LDI A, #$00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "A after LDI A, #$00", DATA_WIDTH);

    // LDI B, #$00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h00, "B after LDI B, #$00", DATA_WIDTH);

    // ADD B: A = A + B = $00 + $00 = $00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("ADD B: $00 + $00 = $00 (identity)");
    inspect_register(uut.u_cpu.a_out, 8'h00, "A after ADD B ($00 + $00)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "Z=1: result is zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result MSB clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: no carry generated");

    // =================================================================
    // TEST 7: Alternating bit pattern test
    // Assembly: LDI A, #$55; LDI B, #$AA; ADD B
    // Expected: A = $55 + $AA = $FF (Z=0, N=1, C=0)
    // =================================================================
    $display("\n--- TEST 7: Alternating bit patterns ($55 + $AA) ---");
    
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
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result MSB set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: no carry from bit 7");

    // =================================================================
    // TEST 8: Single bit test (LSB)
    // Assembly: LDI A, #$00; LDI B, #$01; ADD B
    // Expected: A = $00 + $01 = $01 (Z=0, N=0, C=0)
    // =================================================================
    $display("\n--- TEST 8: Single bit LSB ($00 + $01) ---");
    
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
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result MSB clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: no carry generated");

    // =================================================================
    // TEST 9: Single bit test (MSB)
    // Assembly: LDI A, #$00; LDI B, #$80; ADD B
    // Expected: A = $00 + $80 = $80 (Z=0, N=1, C=0)
    // =================================================================
    $display("\n--- TEST 9: Single bit MSB ($00 + $80) ---");
    
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
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: result MSB set");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: no carry generated");

    // =================================================================
    // TEST 10: Maximum unsigned addition with carry
    // Assembly: LDI A, #$FE; LDI B, #$02; ADD B
    // Expected: A = $FE + $02 = $00 (Z=1, N=0, C=1)
    // =================================================================
    $display("\n--- TEST 10: Maximum addition with wraparound ($FE + $02) ---");
    
    // LDI A, #$FE
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFE, "A after LDI A, #$FE", DATA_WIDTH);

    // LDI B, #$02
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h02, "B after LDI B, #$02", DATA_WIDTH);

    // ADD B: A = A + B = $FE + $02 = $00 with carry
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("ADD B: $FE + $02 = $00 (wraparound with carry)");
    inspect_register(uut.u_cpu.a_out, 8'h00, "A after ADD B ($FE + $02)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "Z=1: result is zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result MSB clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: carry from overflow");

    // =================================================================
    // TEST 11: Register preservation final verification
    // Assembly: LDI A, #$10; LDI B, #$20; ADD B
    // Expected: A = $10 + $20 = $30, C should still be $AA from TEST 1
    // =================================================================
    $display("\n--- TEST 11: Final register preservation test ($10 + $20) ---");
    
    // LDI A, #$10
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h10, "A after LDI A, #$10", DATA_WIDTH);

    // LDI B, #$20
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h20, "B after LDI B, #$20", DATA_WIDTH);

    // ADD B: A = A + B = $10 + $20 = $30
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("ADD B: $10 + $20 = $30 (final verification)");
    inspect_register(uut.u_cpu.a_out, 8'h30, "A after ADD B ($10 + $20)", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hAA, "C register still preserved", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z=0: result is non-zero");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N=0: result MSB clear");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C=0: no carry generated");

    // =================================================================
    // HALT verification - ensure CPU properly stops
    // =================================================================
    $display("\n--- Verifying HALT instruction ---");
    run_until_halt(100);  // Increased timeout for comprehensive test suite
    $display("CPU halted successfully");
    
    // Visual buffer for waveform inspection
    repeat(5) @(posedge clk);

    $display("\n=== ADD_B Comprehensive Test Suite COMPLETED ===");
    $display("All 11 test cases passed successfully!");
    $finish;
    // ============================ END TEST ==============================
  
  end

endmodule