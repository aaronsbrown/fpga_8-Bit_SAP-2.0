`timescale 1ns/1ps
import test_utils_pkg::*; 
import arch_defs_pkg::*;  

// AIDEV-NOTE: Enhanced CMA testbench with comprehensive test coverage for complement operation
module computer_tb;

  localparam string HEX_FILE = "../hardware/test/_fixtures_generated/CMA/ROM.hex";

  logic                  clk;
  logic                  reset;
  logic [DATA_WIDTH-1:0] computer_output;
  
  // Storage for register preservation tests
  logic [7:0] saved_b_reg, saved_c_reg;

  computer uut (
        .clk(clk),
        .reset(reset),
        .output_port_1(computer_output),
        .uart_rx(),  // Leave unconnected
        .uart_tx()   // Leave unconnected
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

    // ============================ BEGIN TEST ==============================
    $display("\n\n=== CMA Comprehensive Microinstruction Test Suite ===");
    $display("Testing Complement Accumulator operation: A = ~A with 14 different test cases");
    $display("Covers edge cases, bit patterns, and flag behavior\n");

    // Test 1: Basic complement with alternating pattern
    $display("=== Test 1: Basic complement $AA -> $55 ===");
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;  // LDI A, #$AA
    inspect_register(uut.u_cpu.a_out, 8'hAA, "Register A after LDI", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "LDI: Zero flag == 0"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "LDI: Negative flag == 1");

    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;  // SEC
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "SEC: Carry flag set to 1");

    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;  // CMA
    inspect_register(uut.u_cpu.a_out, 8'h55, "Register A after CMA (~$AA = $55)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "CMA: Zero flag == 0 (non-zero result)"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "CMA: Negative flag == 0 (bit 7 = 0)");  
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "CMA: Carry flag cleared to 0");
    $display("Bit explanation: ~1010_1010 = 0101_0101\n");

    // Test 2: Complement back to original
    $display("=== Test 2: Complement back $55 -> $AA ===");
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;  // CMA
    inspect_register(uut.u_cpu.a_out, 8'hAA, "Register A after second CMA (~$55 = $AA)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "CMA: Zero flag == 0"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "CMA: Negative flag == 1 (bit 7 = 1)");  
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "CMA: Carry flag cleared to 0");
    $display("Bit explanation: ~0101_0101 = 1010_1010\n");

    // Test 3: Complement zero (should give all ones)
    $display("=== Test 3: Complement zero $00 -> $FF ===");
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;  // LDI A, #$00
    inspect_register(uut.u_cpu.a_out, 8'h00, "Register A after LDI", DATA_WIDTH);
    
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;  // SEC
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "SEC: Carry flag set to 1");

    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;  // CMA
    inspect_register(uut.u_cpu.a_out, 8'hFF, "Register A after CMA (~$00 = $FF)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "CMA: Zero flag == 0 (result is $FF)"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "CMA: Negative flag == 1 (bit 7 = 1)");  
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "CMA: Carry flag cleared to 0");
    $display("Bit explanation: ~0000_0000 = 1111_1111\n");

    // Test 4: Complement all ones (should give zero - test Zero flag)
    $display("=== Test 4: Complement all ones $FF -> $00 (Zero flag test) ===");
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;  // LDI A, #$FF
    inspect_register(uut.u_cpu.a_out, 8'hFF, "Register A after LDI", DATA_WIDTH);
    
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;  // SEC
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "SEC: Carry flag set to 1");

    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;  // CMA
    inspect_register(uut.u_cpu.a_out, 8'h00, "Register A after CMA (~$FF = $00)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "CMA: Zero flag == 1 (result is zero)"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "CMA: Negative flag == 0 (bit 7 = 0)");  
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "CMA: Carry flag cleared to 0");
    $display("Bit explanation: ~1111_1111 = 0000_0000\n");

    // Test 5: High bit isolation (negative flag boundary)
    $display("=== Test 5: High bit test $80 -> $7F ===");
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;  // LDI A, #$80
    inspect_register(uut.u_cpu.a_out, 8'h80, "Register A after LDI", DATA_WIDTH);
    
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;  // CLC
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "CLC: Carry flag cleared to 0");

    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;  // CMA
    inspect_register(uut.u_cpu.a_out, 8'h7F, "Register A after CMA (~$80 = $7F)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "CMA: Zero flag == 0"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "CMA: Negative flag == 0 (bit 7 = 0)");  
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "CMA: Carry flag still cleared");
    $display("Bit explanation: ~1000_0000 = 0111_1111\n");

    // Test 6: Low bit isolation 
    $display("=== Test 6: Low bit test $01 -> $FE ===");
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;  // LDI A, #$01
    inspect_register(uut.u_cpu.a_out, 8'h01, "Register A after LDI", DATA_WIDTH);
    
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;  // SEC
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "SEC: Carry flag set to 1");

    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;  // CMA
    inspect_register(uut.u_cpu.a_out, 8'hFE, "Register A after CMA (~$01 = $FE)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "CMA: Zero flag == 0"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "CMA: Negative flag == 1 (bit 7 = 1)");  
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "CMA: Carry flag cleared to 0");
    $display("Bit explanation: ~0000_0001 = 1111_1110\n");

    // Test 7: Upper nibble pattern
    $display("=== Test 7: Upper nibble $F0 -> $0F ===");
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;  // LDI A, #$F0
    inspect_register(uut.u_cpu.a_out, 8'hF0, "Register A after LDI", DATA_WIDTH);

    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;  // CMA
    inspect_register(uut.u_cpu.a_out, 8'h0F, "Register A after CMA (~$F0 = $0F)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "CMA: Zero flag == 0"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "CMA: Negative flag == 0 (bit 7 = 0)");  
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "CMA: Carry flag cleared to 0");
    $display("Bit explanation: ~1111_0000 = 0000_1111\n");

    // Test 8: Lower nibble pattern
    $display("=== Test 8: Lower nibble $0F -> $F0 ===");
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;  // LDI A, #$0F
    inspect_register(uut.u_cpu.a_out, 8'h0F, "Register A after LDI", DATA_WIDTH);

    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;  // CMA
    inspect_register(uut.u_cpu.a_out, 8'hF0, "Register A after CMA (~$0F = $F0)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "CMA: Zero flag == 0"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "CMA: Negative flag == 1 (bit 7 = 1)");  
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "CMA: Carry flag cleared to 0");
    $display("Bit explanation: ~0000_1111 = 1111_0000\n");

    // Test 9: Checkerboard pattern
    $display("=== Test 9: Checkerboard $55 -> $AA ===");
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;  // LDI A, #$55
    inspect_register(uut.u_cpu.a_out, 8'h55, "Register A after LDI", DATA_WIDTH);
    
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;  // SEC
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "SEC: Carry flag set to 1");

    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;  // CMA
    inspect_register(uut.u_cpu.a_out, 8'hAA, "Register A after CMA (~$55 = $AA)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "CMA: Zero flag == 0"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "CMA: Negative flag == 1 (bit 7 = 1)");  
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "CMA: Carry flag cleared to 0");
    $display("Bit explanation: ~0101_0101 = 1010_1010\n");

    // Test 10: Middle value pattern
    $display("=== Test 10: Middle pattern $3C -> $C3 ===");
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;  // LDI A, #$3C
    inspect_register(uut.u_cpu.a_out, 8'h3C, "Register A after LDI", DATA_WIDTH);

    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;  // CMA
    inspect_register(uut.u_cpu.a_out, 8'hC3, "Register A after CMA (~$3C = $C3)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "CMA: Zero flag == 0"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "CMA: Negative flag == 1 (bit 7 = 1)");  
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "CMA: Carry flag cleared to 0");
    $display("Bit explanation: ~0011_1100 = 1100_0011\n");

    // Test 11: Single bit test
    $display("=== Test 11: Single bit $40 -> $BF ===");
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;  // LDI A, #$40
    inspect_register(uut.u_cpu.a_out, 8'h40, "Register A after LDI", DATA_WIDTH);

    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;  // CMA
    inspect_register(uut.u_cpu.a_out, 8'hBF, "Register A after CMA (~$40 = $BF)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "CMA: Zero flag == 0"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "CMA: Negative flag == 1 (bit 7 = 1)");  
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "CMA: Carry flag cleared to 0");
    $display("Bit explanation: ~0100_0000 = 1011_1111\n");

    // Test 12: Register preservation test
    $display("=== Test 12: Register preservation test ===");
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;  // LDI B, #$42
    inspect_register(uut.u_cpu.b_out, 8'h42, "Register B loaded", DATA_WIDTH);
    saved_b_reg = uut.u_cpu.b_out;

    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;  // LDI C, #$24
    inspect_register(uut.u_cpu.c_out, 8'h24, "Register C loaded", DATA_WIDTH);
    saved_c_reg = uut.u_cpu.c_out;

    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;  // LDI A, #$33
    inspect_register(uut.u_cpu.a_out, 8'h33, "Register A loaded", DATA_WIDTH);

    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;  // CMA
    inspect_register(uut.u_cpu.a_out, 8'hCC, "Register A after CMA (~$33 = $CC)", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, saved_b_reg, "Register B preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, saved_c_reg, "Register C preserved", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "CMA: Zero flag == 0"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "CMA: Negative flag == 1 (bit 7 = 1)");  
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "CMA: Carry flag cleared to 0");
    $display("Bit explanation: ~0011_0011 = 1100_1100\n");

    // Test 13: Final zero test
    $display("=== Test 13: Final zero test $FF -> $00 ===");
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;  // LDI A, #$FF
    inspect_register(uut.u_cpu.a_out, 8'hFF, "Register A after LDI", DATA_WIDTH);

    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;  // CMA
    inspect_register(uut.u_cpu.a_out, 8'h00, "Register A after CMA (~$FF = $00)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "CMA: Zero flag == 1 (result is zero)"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "CMA: Negative flag == 0 (bit 7 = 0)");  
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "CMA: Carry flag cleared to 0");
    $display("Bit explanation: ~1111_1111 = 0000_0000\n");

    // Test 14: Final pattern verification
    $display("=== Test 14: Final pattern $E7 -> $18 ===");
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;  // LDI A, #$E7
    inspect_register(uut.u_cpu.a_out, 8'hE7, "Register A after LDI", DATA_WIDTH);

    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;  // CMA
    inspect_register(uut.u_cpu.a_out, 8'h18, "Register A after CMA (~$E7 = $18)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "CMA: Zero flag == 0"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "CMA: Negative flag == 0 (bit 7 = 0)");  
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "CMA: Carry flag cleared to 0");
    $display("Bit explanation: ~1110_0111 = 0001_1000\n");

    // Wait for HLT and verify program completion
    run_until_halt(60);  // Increased timeout for expanded test suite
    
    // Visual buffer for waveform inspection
    repeat(2) @(posedge clk);

    $display("=== CMA Test Suite Summary ===");
    $display("✓ All 14 test cases completed successfully");
    $display("✓ Verified complement operation for various bit patterns");
    $display("✓ Confirmed Zero flag behavior (set when result = $00)");
    $display("✓ Confirmed Negative flag behavior (set when bit 7 = 1)");
    $display("✓ Confirmed Carry flag always cleared by CMA");
    $display("✓ Verified register preservation (B and C unchanged)");
    $display("CMA test finished.===========================\n\n");
    $finish;
    // ============================ END TEST ==============================
  
  end

endmodule