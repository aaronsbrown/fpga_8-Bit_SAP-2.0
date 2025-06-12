`timescale 1ns/1ps
import test_utils_pkg::*; 
import arch_defs_pkg::*;  
// AIDEV-NOTE: Simplified JNN testbench focusing on essential negative flag scenarios

module computer_tb;

  localparam string HEX_FILE = "../hardware/test/_fixtures_generated/JNN/ROM.hex";

  logic                  clk;
  logic                  reset;
  logic [DATA_WIDTH-1:0] computer_output;

  computer uut (
        .clk(clk),
        .reset(reset),
        .output_port_1(computer_output),
        .uart_rx(1'b1),    // UART not needed for JNN microinstruction testing
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

    // ============================ BEGIN TEST ==============================
    $display("\n\nRunning JNN (Jump if Not Negative) Essential Test ========================");
    $display("Testing JNN instruction: Jump to 16-bit address if Negative flag (N=0) is clear");
    $display("Opcode: $14, Format: JNN address (3 bytes)");
    $display("Flags affected: None (flags preserved during jump)\n");

    // ======================================================================
    // Test 1: Setup test patterns and verify JNN when N=1 (should NOT jump)
    // ======================================================================
    $display("\n--- Test 1: Setup and JNN when N=1 (Should NOT Jump) ---");
    
    // LDI A, #$AA
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hAA, "A=$AA (test pattern 10101010)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "LDI A: Z=0"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "LDI A: N=1 (bit 7 set)"); 
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "LDI A: C preserved (0 init)"); 

    // LDI B, #$BB
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'hBB, "B=$BB (test pattern)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "LDI B: N=1 (bit 7 set)"); 

    // LDI C, #$CC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hCC, "C=$CC (test pattern)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "LDI C: N=1 (bit 7 set)"); 

    // JNN FAIL_TEST1 (should NOT jump when N=1)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "JNN (N=1): Negative still set"); 
    inspect_register(uut.u_cpu.a_out, 8'hAA, "JNN (N=1): A preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'hBB, "JNN (N=1): B preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hCC, "JNN (N=1): C register preserved", DATA_WIDTH);
    $display("SUCCESS: JNN correctly did NOT jump when negative flag was set");

    // JMP TEST2
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;

    // ======================================================================
    // Test 2: JNN when N=0 (should jump)
    // ======================================================================
    $display("\n--- Test 2: JNN when N=0 (Should Jump) ---");
    
    // LDI A, #$7F (positive value, clears N flag)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h7F, "A=$7F (positive, N=0)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "LDI A: N=0 (bit 7 clear)"); 
    inspect_register(uut.u_cpu.b_out, 8'hBB, "LDI A: B preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hCC, "LDI A: C register preserved", DATA_WIDTH);

    // JNN TEST2_SUCCESS (should jump when N=0)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "JNN (N=0): Negative still clear"); 
    inspect_register(uut.u_cpu.a_out, 8'h7F, "JNN (N=0): A preserved", DATA_WIDTH);
    $display("SUCCESS: JNN correctly jumped when negative flag was clear");

    // JMP TEST3
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;

    // ======================================================================
    // Test 3: JNN after SUB operation resulting in positive (N=0)
    // ======================================================================
    $display("\n--- Test 3: JNN after SUB Operation (N=0) ---");
    
    // LDI A, #$20
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h20, "A=$20 (32)", DATA_WIDTH);

    // LDI B, #$10
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h10, "B=$10 (16)", DATA_WIDTH);

    // SUB B (32 - 16 = 16, positive result)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h10, "SUB B: A=$20-$10=$10 (positive result)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "SUB B: Z=0 (result non-zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "SUB B: N=0 (result positive)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "SUB B: C=1 (no borrow)");

    // JNN TEST3_SUCCESS (should jump when N=0 from positive SUB)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "JNN (after SUB positive): N=0"); 
    $display("SUCCESS: JNN correctly jumped after SUB operation with positive result");

    // JMP TEST4
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;

    // ======================================================================
    // Test 4: JNN after SUB operation resulting in negative (N=1)
    // ======================================================================
    $display("\n--- Test 4: JNN after SUB Operation (N=1) ---");
    
    // LDI A, #$05
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h05, "A=$05 (5)", DATA_WIDTH);

    // LDI B, #$15
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h15, "B=$15 (21)", DATA_WIDTH);

    // SUB B (5 - 21 = -16, negative result)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hF0, "SUB B: A=$05-$15=$F0 (negative result)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "SUB B: Z=0 (result non-zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "SUB B: N=1 (result negative)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "SUB B: C=0 (borrow occurred)");

    // JNN FAIL_TEST4 (should NOT jump when N=1)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "JNN (after SUB negative): N=1"); 
    $display("SUCCESS: JNN correctly did NOT jump after SUB with negative result");

    // JMP TEST5
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;

    // ======================================================================
    // Test 5: JNN after logical AND resulting in zero (N=0)
    // ======================================================================
    $display("\n--- Test 5: JNN after Logical AND (N=0, Z=1) ---");
    
    // LDI A, #$AA
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hAA, "A=$AA (10101010)", DATA_WIDTH);

    // LDI B, #$55
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h55, "B=$55 (01010101)", DATA_WIDTH);

    // ANA B ($AA & $55 = $00, N=0, Z=1)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "ANA B: A=$AA & $55 = $00", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "ANA B: Z=1 (result is zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "ANA B: N=0 (bit 7 clear)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "ANA B: C=0 (logical ops clear carry)");

    // JNN TEST5_SUCCESS (should jump when N=0)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "JNN (after ANA): N=0"); 
    $display("SUCCESS: JNN correctly jumped after logical AND cleared negative flag");

    // JMP TEST6
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;

    // ======================================================================
    // Test 6: JNN after logical OR resulting in negative (N=1)
    // ======================================================================
    $display("\n--- Test 6: JNN after Logical OR (N=1) ---");
    
    // LDI A, #$80
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h80, "A=$80 (10000000)", DATA_WIDTH);

    // LDI B, #$40
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h40, "B=$40 (01000000)", DATA_WIDTH);

    // ORA B ($80 | $40 = $C0, N=1)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hC0, "ORA B: A=$80 | $40 = $C0", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "ORA B: Z=0 (result non-zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "ORA B: N=1 (bit 7 set)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "ORA B: C=0 (logical ops clear carry)");

    // JNN FAIL_TEST6 (should NOT jump when N=1)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "JNN (after ORA): N=1"); 
    $display("SUCCESS: JNN correctly did NOT jump after logical OR set negative flag");

    // JMP TEST7
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;

    // ======================================================================
    // Test 7: JNN after increment to zero (N=0)
    // ======================================================================
    $display("\n--- Test 7: JNN after Increment to Zero (N=0) ---");
    
    // LDI A, #$FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A=$FF (255, negative)", DATA_WIDTH);

    // INR A (255 + 1 = 0, overflow to zero)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "INR A: A=$FF+1=$00 (overflow to zero)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "INR A: Z=1 (result is zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "INR A: N=0 (zero is not negative)");

    // JNN TEST7_SUCCESS (should jump when N=0)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "JNN (after INR overflow): N=0"); 
    $display("SUCCESS: JNN correctly jumped after increment overflow to zero");

    // JMP TEST8
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;

    // ======================================================================
    // Test 8: Register preservation test
    // ======================================================================
    $display("\n--- Test 8: Register Preservation Test ---");
    
    // LDI A, #$33
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h33, "A=$33 (positive)", DATA_WIDTH);

    // LDI B, #$44
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h44, "B=$44 (test pattern)", DATA_WIDTH);

    // LDI C, #$55
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h55, "C=$55 (test pattern)", DATA_WIDTH);

    // JNN PRESERVE_CHECK (preservation test - should jump and preserve everything)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h33, "JNN (preserve): A preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h44, "JNN (preserve): B preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'h55, "JNN (preserve): C register preserved", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "JNN (preserve): Negative flag preserved");
    $display("SUCCESS: JNN preserved all uninvolved registers and flags");

    // ======================================================================
    // Final Success Verification
    // ======================================================================
    $display("\n--- Final Success Verification ---");
    
    // LDI A, #$FF (success code)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A=$FF (success code)", DATA_WIDTH);

    // STA OUTPUT_PORT_1
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(computer_output, 8'hFF, "Output: $FF (all tests passed)");
    $display("SUCCESS: All JNN tests completed successfully!");

    // Wait for HLT
    wait(uut.cpu_halt);
    $display("CPU halted - test program completed");
    
    // Visual buffer for waveform inspection
    repeat(5) @(posedge clk);

    $display("\n=== JNN (Jump if Not Negative) Essential Test Summary ===");
    $display("✓ JNN behavior when negative flag set (should not jump)");
    $display("✓ JNN behavior when negative flag clear (should jump)");
    $display("✓ JNN after SUB operations (positive/negative results)");
    $display("✓ JNN after logical operations (AND zero, OR negative)");
    $display("✓ JNN after increment overflow to zero");
    $display("✓ Register preservation during JNN execution");
    $display("JNN test finished.===========================\n\n");
    $finish;
    // ============================ END TEST ==============================
  
  end

endmodule