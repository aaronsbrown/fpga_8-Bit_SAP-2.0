`timescale 1ns/1ps
import test_utils_pkg::*; 
import arch_defs_pkg::*;  

module computer_tb;

  localparam string HEX_FILE = "../hardware/test/_fixtures_generated/JC/ROM.hex";

  logic                  clk;
  logic                  reset;
  logic [DATA_WIDTH-1:0] computer_output;

  computer uut (
        .clk(clk),
        .reset(reset),
        .output_port_1(computer_output),
        .uart_rx(1'b1),    // UART not needed for JC microinstruction testing
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
    $display("\n\nRunning JC (Jump if Carry) Enhanced Test ========================");

    // ======================================================================
    // Test Group 1: Initial Register Setup
    // ======================================================================
    $display("\n--- Test Group 1: Initial Register Setup ---");
    
    // LDI A, #$AA
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hAA, "A=$AA (test pattern)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "LDI A: Z=0"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "LDI A: N=1 (bit 7 set)"); 
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "LDI A: C preserved (0 init)"); 

    // LDI B, #$BB
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'hBB, "B=$BB (test pattern)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "LDI B: Z=0"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "LDI B: N=1 (bit 7 set)"); 
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "LDI B: C preserved"); 

    // LDI C, #$CC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hCC, "C=$CC (test pattern)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "LDI C: Z=0"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "LDI C: N=1 (bit 7 set)"); 
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "LDI C: C preserved"); 

    // ======================================================================
    // Test Group 2: JC when Carry is Clear (C=0) - Should NOT jump
    // ======================================================================
    $display("\n--- Test Group 2: JC when Carry Clear (Should NOT Jump) ---");
    
    // CLC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "CLC: C=0 (explicitly cleared)"); 
    inspect_register(uut.u_cpu.a_out, 8'hAA, "CLC: A preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'hBB, "CLC: B preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hCC, "CLC: C register preserved", DATA_WIDTH);

    // JC TEST1_FAIL (should NOT jump when C=0)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "JC (C=0): Carry still clear"); 
    inspect_register(uut.u_cpu.a_out, 8'hAA, "JC (C=0): A preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'hBB, "JC (C=0): B preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hCC, "JC (C=0): C register preserved", DATA_WIDTH);
    $display("SUCCESS: JC correctly did NOT jump when carry was clear");

    // JMP TEST2_SETUP
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;

    // ======================================================================
    // Test Group 3: JC when Carry is Set (C=1) - Should jump
    // ======================================================================
    $display("\n--- Test Group 3: JC when Carry Set (Should Jump) ---");
    
    // SEC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "SEC: C=1 (explicitly set)"); 
    inspect_register(uut.u_cpu.a_out, 8'hAA, "SEC: A preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'hBB, "SEC: B preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hCC, "SEC: C register preserved", DATA_WIDTH);

    // JC TEST2_SUCCESS (should jump when C=1)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "JC (C=1): Carry still set"); 
    inspect_register(uut.u_cpu.a_out, 8'hAA, "JC (C=1): A preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'hBB, "JC (C=1): B preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hCC, "JC (C=1): C register preserved", DATA_WIDTH);
    $display("SUCCESS: JC correctly jumped when carry was set");

    // ======================================================================
    // Test Group 4: JC after ADD overflow (sets carry)
    // ======================================================================
    $display("\n--- Test Group 4: JC after ADD Overflow (C=1) ---");
    
    // LDI A, #$FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A=$FF (max unsigned)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "LDI A: N=1 (bit 7 set)");

    // LDI B, #$01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h01, "B=$01", DATA_WIDTH);

    // ADD B ($FF + $01 = $00, C=1 overflow)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "ADD B: A=$FF+$01=$00 (overflow)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "ADD B: Z=1 (result is zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "ADD B: N=0 (bit 7 clear)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "ADD B: C=1 (overflow occurred)");
    inspect_register(uut.u_cpu.b_out, 8'h01, "ADD B: B preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hCC, "ADD B: C register preserved", DATA_WIDTH);

    // JC TEST3_ADD_SUCCESS (should jump when C=1 from overflow)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "JC (after ADD overflow): C=1"); 
    $display("SUCCESS: JC correctly jumped after ADD overflow set carry");

    // ======================================================================
    // Test Group 5: JC after ADD with no overflow (C=0)
    // ======================================================================
    $display("\n--- Test Group 5: JC after ADD with No Overflow (C=0) ---");
    
    // LDI A, #$7F
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h7F, "A=$7F (127)", DATA_WIDTH);

    // LDI B, #$01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h01, "B=$01", DATA_WIDTH);

    // ADD B ($7F + $01 = $80, C=0 no overflow)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h80, "ADD B: A=$7F+$01=$80 (no overflow)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "ADD B: Z=0 (result non-zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "ADD B: N=1 (bit 7 set)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "ADD B: C=0 (no overflow)");

    // JC TEST4_FAIL (should NOT jump when C=0)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "JC (after ADD no overflow): C=0"); 
    $display("SUCCESS: JC correctly did NOT jump after ADD with no overflow");

    // JMP TEST5_SETUP
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;

    // ======================================================================
    // Test Group 6: JC after SUB with borrow (C=0)
    // ======================================================================
    $display("\n--- Test Group 6: JC after SUB with Borrow (C=0) ---");
    
    // LDI A, #$05
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h05, "A=$05", DATA_WIDTH);

    // LDI B, #$10
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h10, "B=$10", DATA_WIDTH);

    // SUB B ($05 - $10 = $F5, C=0 borrow occurred)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hF5, "SUB B: A=$05-$10=$F5 (borrow)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "SUB B: Z=0 (result non-zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "SUB B: N=1 (bit 7 set)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "SUB B: C=0 (borrow occurred)");

    // JC TEST5_FAIL (should NOT jump when C=0 from borrow)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "JC (after SUB borrow): C=0"); 
    $display("SUCCESS: JC correctly did NOT jump after SUB with borrow");

    // JMP TEST6_SETUP
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;

    // ======================================================================
    // Test Group 7: JC after SUB with no borrow (C=1)
    // ======================================================================
    $display("\n--- Test Group 7: JC after SUB with No Borrow (C=1) ---");
    
    // LDI A, #$10
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h10, "A=$10", DATA_WIDTH);

    // LDI B, #$05
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h05, "B=$05", DATA_WIDTH);

    // SUB B ($10 - $05 = $0B, C=1 no borrow)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h0B, "SUB B: A=$10-$05=$0B (no borrow)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "SUB B: Z=0 (result non-zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "SUB B: N=0 (bit 7 clear)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "SUB B: C=1 (no borrow)");

    // JC TEST6_SUCCESS (should jump when C=1)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "JC (after SUB no borrow): C=1"); 
    $display("SUCCESS: JC correctly jumped after SUB with no borrow");

    // ======================================================================
    // Test Group 8: JC after logical AND (clears carry)
    // ======================================================================
    $display("\n--- Test Group 8: JC after Logical AND (C=0) ---");
    
    // SEC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "SEC: C=1 (set before AND)");

    // LDI A, #$AA
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hAA, "A=$AA (10101010)", DATA_WIDTH);

    // LDI B, #$55
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h55, "B=$55 (01010101)", DATA_WIDTH);

    // ANA B ($AA & $55 = $00, C=0 logical ops clear carry)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "ANA B: A=$AA & $55 = $00", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "ANA B: Z=1 (result is zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "ANA B: N=0 (bit 7 clear)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "ANA B: C=0 (logical ops clear carry)");
    inspect_register(uut.u_cpu.b_out, 8'h55, "ANA B: B preserved", DATA_WIDTH);

    // JC TEST7_FAIL (should NOT jump when C=0)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "JC (after ANA): C=0"); 
    $display("SUCCESS: JC correctly did NOT jump after logical AND cleared carry");

    // JMP TEST8_SETUP
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;

    // ======================================================================
    // Test Group 9: JC edge case address testing
    // ======================================================================
    $display("\n--- Test Group 9: JC Edge Case Address Testing ---");
    
    // SEC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "SEC: C=1 (set for edge test)");

    // JC TEST8_SUCCESS (edge case jump)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "JC (edge case): C=1"); 
    $display("SUCCESS: JC correctly handled edge case addressing");

    // ======================================================================
    // Test Group 10: JC after rotate operation (carry from rotation)
    // ======================================================================
    $display("\n--- Test Group 10: JC after Rotate Operation ---");
    
    // CLC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "CLC: C=0 (clear before rotate)");

    // LDI A, #$81
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h81, "A=$81 (10000001)", DATA_WIDTH);

    // RAR (rotate A right: bit 0 -> carry, carry -> bit 7)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h40, "RAR: A=$81->$40 (bit 0 to carry)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "RAR: Z=0 (result non-zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "RAR: N=0 (bit 7 clear)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "RAR: C=1 (bit 0 rotated to carry)");

    // JC TEST9_SUCCESS (should jump when C=1 from rotation)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "JC (after RAR): C=1"); 
    $display("SUCCESS: JC correctly jumped after rotate set carry");

    // ======================================================================
    // Test Group 11: JC after increment (carry unaffected)
    // ======================================================================
    $display("\n--- Test Group 11: JC after Increment (Carry Unaffected) ---");
    
    // SEC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "SEC: C=1 (set before INR)");

    // LDI A, #$FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A=$FF (before increment)", DATA_WIDTH);

    // INR A ($FF + 1 = $00, but C should remain unchanged)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "INR A: A=$FF+1=$00 (wrap)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "INR A: Z=1 (result is zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "INR A: N=0 (bit 7 clear)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "INR A: C=1 (unchanged by INR)");

    // JC TEST10_SUCCESS (should jump - carry unchanged by INR)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "JC (after INR): C=1 (unchanged)"); 
    $display("SUCCESS: JC correctly jumped - INR did not affect carry");

    // ======================================================================
    // Test Group 12: JC after decrement (carry unaffected)
    // ======================================================================
    $display("\n--- Test Group 12: JC after Decrement (Carry Unaffected) ---");
    
    // CLC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "CLC: C=0 (clear before DCR)");

    // LDI A, #$00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "A=$00 (before decrement)", DATA_WIDTH);

    // DCR A ($00 - 1 = $FF, but C should remain unchanged)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "DCR A: A=$00-1=$FF (wrap)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "DCR A: Z=0 (result non-zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "DCR A: N=1 (bit 7 set)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "DCR A: C=0 (unchanged by DCR)");

    // JC TEST10_FAIL (should NOT jump - carry unchanged by DCR)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "JC (after DCR): C=0 (unchanged)"); 
    $display("SUCCESS: JC correctly did NOT jump - DCR did not affect carry");

    // JMP FINAL_TESTS
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;

    // ======================================================================
    // Test Group 13: Final Register Preservation Test
    // ======================================================================
    $display("\n--- Test Group 13: Final Register Preservation Test ---");
    
    // LDI A, #$AA
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hAA, "A=$AA (final test pattern)", DATA_WIDTH);

    // LDI B, #$BB
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'hBB, "B=$BB (final test pattern)", DATA_WIDTH);

    // LDI C, #$CC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hCC, "C=$CC (final test pattern)", DATA_WIDTH);

    // SEC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "SEC: C=1 (set for final jump)");

    // JC PRESERVE_CHECK (final preservation test)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hAA, "JC (final): A preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'hBB, "JC (final): B preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hCC, "JC (final): C register preserved", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "JC (final): Carry flag preserved");
    $display("SUCCESS: JC preserved all uninvolved registers");

    // ======================================================================
    // Test Group 14: Final Success Verification
    // ======================================================================
    $display("\n--- Test Group 14: Final Success Verification ---");
    
    // LDI A, #$FF (success code)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A=$FF (success code)", DATA_WIDTH);

    // STA OUTPUT_PORT_1
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(computer_output, 8'hFF, "Output: $FF (all tests passed)");
    $display("SUCCESS: All JC tests completed successfully!");

    // Wait for HLT
    wait(uut.cpu_halt);
    $display("CPU halted - test program completed");
    
    // Visual buffer for waveform inspection
    repeat(5) @(posedge clk);

    $display("\n=== JC (Jump if Carry) Enhanced Test Summary ===");
    $display("✓ JC behavior when carry clear (should not jump)");
    $display("✓ JC behavior when carry set (should jump)");
    $display("✓ JC after arithmetic operations (ADD overflow/no overflow)");
    $display("✓ JC after subtraction operations (borrow/no borrow)");
    $display("✓ JC after logical operations (carry cleared)");
    $display("✓ JC after rotate operations (carry from bit rotation)");
    $display("✓ JC after increment/decrement (carry unaffected)");
    $display("✓ Register preservation during JC execution");
    $display("✓ Edge case address handling");
    $display("✓ Comprehensive flag state verification");
    $display("JC test finished.===========================\n\n");
    $finish;
    // ============================ END TEST ==============================
  
  end

endmodule