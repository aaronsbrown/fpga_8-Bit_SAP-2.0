`timescale 1ns/1ps
import test_utils_pkg::*; 
import arch_defs_pkg::*;  

module computer_tb;

  localparam string HEX_FILE = "../hardware/test/_fixtures_generated/JN/ROM.hex";

  logic                  clk;
  logic                  reset;
  logic [DATA_WIDTH-1:0] computer_output;

  computer uut (
        .clk(clk),
        .reset(reset),
        .output_port_1(computer_output),
        .uart_rx(1'b1),    // UART not needed for JN microinstruction testing
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
    $display("\n\nRunning JN (Jump if Negative) Enhanced Test ========================");
    $display("Testing JN instruction: Jump to 16-bit address if Negative flag (N=1) is set");
    $display("Opcode: $13, Format: JN address (3 bytes)");
    $display("Flags affected: None (flags preserved during jump)\n");

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
    // Test Group 2: JN when Negative flag is clear (N=0) - Should NOT jump
    // ======================================================================
    $display("\n--- Test Group 2: JN when Negative Clear (Should NOT Jump) ---");
    
    // LDI A, #$7F (positive value, clears N flag)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h7F, "A=$7F (positive, N=0)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "LDI A: N=0 (bit 7 clear)"); 
    inspect_register(uut.u_cpu.b_out, 8'hBB, "LDI A: B preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hCC, "LDI A: C register preserved", DATA_WIDTH);

    // JN TEST2_FAIL (should NOT jump when N=0)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "JN (N=0): Negative still clear"); 
    inspect_register(uut.u_cpu.a_out, 8'h7F, "JN (N=0): A preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'hBB, "JN (N=0): B preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hCC, "JN (N=0): C register preserved", DATA_WIDTH);
    $display("SUCCESS: JN correctly did NOT jump when negative flag was clear");

    // JMP TEST3_SETUP
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;

    // ======================================================================
    // Test Group 3: JN when Negative flag is set (N=1) - Should jump
    // ======================================================================
    $display("\n--- Test Group 3: JN when Negative Set (Should Jump) ---");
    
    // LDI A, #$80 (negative value, sets N flag)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h80, "A=$80 (negative, N=1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "LDI A: N=1 (bit 7 set)"); 
    inspect_register(uut.u_cpu.b_out, 8'hBB, "LDI A: B preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hCC, "LDI A: C register preserved", DATA_WIDTH);

    // JN TEST3_SUCCESS (should jump when N=1)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "JN (N=1): Negative still set"); 
    inspect_register(uut.u_cpu.a_out, 8'h80, "JN (N=1): A preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'hBB, "JN (N=1): B preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hCC, "JN (N=1): C register preserved", DATA_WIDTH);
    $display("SUCCESS: JN correctly jumped when negative flag was set");

    // ======================================================================
    // Test Group 4: JN after SUB operation resulting in negative
    // ======================================================================
    $display("\n--- Test Group 4: JN after SUB Operation (N=1) ---");
    
    // LDI A, #$05
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h05, "A=$05 (5)", DATA_WIDTH);

    // LDI B, #$10
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h10, "B=$10 (16)", DATA_WIDTH);

    // SUB B (5 - 16 = -11, sets N=1)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hF5, "SUB B: A=$05-$10=$F5 (negative result)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "SUB B: Z=0 (result non-zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "SUB B: N=1 (result negative)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "SUB B: C=0 (borrow occurred)");
    inspect_register(uut.u_cpu.b_out, 8'h10, "SUB B: B preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hCC, "SUB B: C register preserved", DATA_WIDTH);

    // JN TEST4_SUCCESS (should jump when N=1 from SUB)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "JN (after SUB): N=1"); 
    $display("SUCCESS: JN correctly jumped after SUB operation set negative flag");

    // ======================================================================
    // Test Group 5: JN after SUB operation resulting in positive
    // ======================================================================
    $display("\n--- Test Group 5: JN after SUB Operation (N=0) ---");
    
    // LDI A, #$10
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h10, "A=$10 (16)", DATA_WIDTH);

    // LDI B, #$05
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h05, "B=$05 (5)", DATA_WIDTH);

    // SUB B (16 - 5 = 11, clears N=0)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h0B, "SUB B: A=$10-$05=$0B (positive result)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "SUB B: Z=0 (result non-zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "SUB B: N=0 (result positive)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "SUB B: C=1 (no borrow)");

    // JN TEST5_FAIL (should NOT jump when N=0)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "JN (after SUB positive): N=0"); 
    $display("SUCCESS: JN correctly did NOT jump after SUB with positive result");

    // JMP TEST6_SETUP
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;

    // ======================================================================
    // Test Group 6: JN after logical AND resulting in zero
    // ======================================================================
    $display("\n--- Test Group 6: JN after Logical AND (N=0, Z=1) ---");
    
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
    inspect_register(uut.u_cpu.b_out, 8'h55, "ANA B: B preserved", DATA_WIDTH);

    // JN TEST6_FAIL (should NOT jump when N=0)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "JN (after ANA): N=0"); 
    $display("SUCCESS: JN correctly did NOT jump after logical AND with zero result");

    // JMP TEST7_SETUP
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;

    // ======================================================================
    // Test Group 7: JN after logical OR resulting in negative
    // ======================================================================
    $display("\n--- Test Group 7: JN after Logical OR (N=1) ---");
    
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
    inspect_register(uut.u_cpu.b_out, 8'h40, "ORA B: B preserved", DATA_WIDTH);

    // JN TEST7_SUCCESS (should jump when N=1)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "JN (after ORA): N=1"); 
    $display("SUCCESS: JN correctly jumped after logical OR set negative flag");

    // ======================================================================
    // Test Group 8: JN after increment overflow to negative
    // ======================================================================
    $display("\n--- Test Group 8: JN after Increment Overflow (N=1) ---");
    
    // LDI A, #$7F
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h7F, "A=$7F (maximum positive)", DATA_WIDTH);

    // INR A ($7F + 1 = $80, sets N=1)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h80, "INR A: A=$7F+1=$80 (overflow to negative)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "INR A: Z=0 (result non-zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "INR A: N=1 (overflow to negative)");

    // JN TEST8_SUCCESS (should jump when N=1)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "JN (after INR overflow): N=1"); 
    $display("SUCCESS: JN correctly jumped after increment overflow set negative flag");

    // ======================================================================
    // Test Group 9: JN after decrement still negative
    // ======================================================================
    $display("\n--- Test Group 9: JN after Decrement Still Negative (N=1) ---");
    
    // LDI A, #$81
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h81, "A=$81 (negative)", DATA_WIDTH);

    // DCR A ($81 - 1 = $80, still N=1)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h80, "DCR A: A=$81-1=$80 (still negative)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "DCR A: Z=0 (result non-zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "DCR A: N=1 (still negative)");

    // JN TEST9_SUCCESS (should jump when N=1)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "JN (after DCR): N=1"); 
    $display("SUCCESS: JN correctly jumped when decrement result was still negative");

    // ======================================================================
    // Test Group 10: JN after rotate left setting MSB
    // ======================================================================
    $display("\n--- Test Group 10: JN after Rotate Left (N=1) ---");
    
    // CLC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "CLC: C=0 (clear before rotate)");

    // LDI A, #$40
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h40, "A=$40 (01000000)", DATA_WIDTH);

    // RAL (rotate A left: bit 7 -> carry, carry -> bit 0)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h80, "RAL: A=$40->$80 (bit 6 to MSB)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "RAL: Z=0 (result non-zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "RAL: N=1 (bit 7 set)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "RAL: C=0 (no bit shifted to carry)");

    // JN TEST10_SUCCESS (should jump when N=1)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "JN (after RAL): N=1"); 
    $display("SUCCESS: JN correctly jumped after rotate left set negative flag");

    // ======================================================================
    // Test Group 11: JN after complement operation
    // ======================================================================
    $display("\n--- Test Group 11: JN after Complement Operation (N=1) ---");
    
    // LDI A, #$7F
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h7F, "A=$7F (01111111, positive)", DATA_WIDTH);

    // CMA (complement A: ~$7F = $80)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h80, "CMA: A=~$7F=$80 (complement)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "CMA: Z=0 (result non-zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "CMA: N=1 (complement sets MSB)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "CMA: C=0 (complement clears carry)");

    // JN TEST11_SUCCESS (should jump when N=1)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "JN (after CMA): N=1"); 
    $display("SUCCESS: JN correctly jumped after complement set negative flag");

    // ======================================================================
    // Test Group 12: JN edge case - maximum negative value
    // ======================================================================
    $display("\n--- Test Group 12: JN with Maximum Negative Value ($FF) ---");
    
    // LDI A, #$FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A=$FF (11111111, all bits set)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "LDI A: N=1 (all bits set)");

    // JN TEST12_SUCCESS (should jump when N=1)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "JN (with $FF): N=1"); 
    $display("SUCCESS: JN correctly jumped with maximum negative value");

    // ======================================================================
    // Test Group 13: JN edge case - minimum negative value
    // ======================================================================
    $display("\n--- Test Group 13: JN with Minimum Negative Value ($80) ---");
    
    // LDI A, #$80
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h80, "A=$80 (10000000, minimum negative)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "LDI A: N=1 (MSB set)");

    // JN TEST13_SUCCESS (should jump when N=1)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "JN (with $80): N=1"); 
    $display("SUCCESS: JN correctly jumped with minimum negative value");

    // ======================================================================
    // Test Group 14: Register preservation test
    // ======================================================================
    $display("\n--- Test Group 14: Register Preservation Test ---");
    
    // LDI A, #$AA
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hAA, "A=$AA (test pattern)", DATA_WIDTH);

    // LDI B, #$BB
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'hBB, "B=$BB (test pattern)", DATA_WIDTH);

    // LDI C, #$CC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hCC, "C=$CC (test pattern)", DATA_WIDTH);

    // SEC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "SEC: C=1 (set for preservation test)");

    // LDI A, #$80 (sets N=1, should preserve C=1)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h80, "A=$80 (negative)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "LDI A: C preserved during load");

    // JN PRESERVE_CHECK (preservation test)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h80, "JN (preserve): A preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'hBB, "JN (preserve): B preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hCC, "JN (preserve): C register preserved", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "JN (preserve): Negative flag preserved");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "JN (preserve): Carry flag preserved");
    $display("SUCCESS: JN preserved all uninvolved registers and flags");

    // ======================================================================
    // Test Group 15: Alternating bit patterns
    // ======================================================================
    $display("\n--- Test Group 15: Alternating Bit Patterns ---");
    
    // LDI A, #$AA (10101010, negative)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hAA, "A=$AA (10101010, negative)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "LDI A: N=1 ($AA is negative)");

    // JN TEST15_SUCCESS (should jump when N=1)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "JN (with $AA): N=1"); 
    $display("SUCCESS: JN correctly jumped with alternating pattern $AA");

    // LDI A, #$55 (01010101, positive)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h55, "A=$55 (01010101, positive)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "LDI A: N=0 ($55 is positive)");

    // JN TEST15_FAIL (should NOT jump when N=0)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "JN (with $55): N=0"); 
    $display("SUCCESS: JN correctly did NOT jump with alternating pattern $55");

    // JMP FINAL_TESTS
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;

    // ======================================================================
    // Test Group 16: Complex operation chain
    // ======================================================================
    $display("\n--- Test Group 16: Complex Operation Chain ---");
    
    // LDI A, #$10
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h10, "A=$10 (start of chain)", DATA_WIDTH);

    // LDI B, #$20
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h20, "B=$20", DATA_WIDTH);

    // SUB B (result negative)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hF0, "SUB B: A=$10-$20=$F0 (negative)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "SUB B: N=1 (result negative)");

    // INR A (still negative)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hF1, "INR A: A=$F0+1=$F1 (still negative)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "INR A: N=1 (still negative)");

    // DCR A (back to original negative)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hF0, "DCR A: A=$F1-1=$F0 (back to negative)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "DCR A: N=1 (back to negative)");

    // JN CHAIN_SUCCESS (should jump when N=1)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "JN (after chain): N=1"); 
    $display("SUCCESS: JN correctly jumped after complex operation chain");

    // ======================================================================
    // Test Group 17: Final Success Verification
    // ======================================================================
    $display("\n--- Test Group 17: Final Success Verification ---");
    
    // LDI A, #$FF (success code)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A=$FF (success code)", DATA_WIDTH);

    // STA OUTPUT_PORT_1
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(computer_output, 8'hFF, "Output: $FF (all tests passed)");
    $display("SUCCESS: All JN tests completed successfully!");

    // Wait for HLT
    wait(uut.cpu_halt);
    $display("CPU halted - test program completed");
    
    // Visual buffer for waveform inspection
    repeat(5) @(posedge clk);

    $display("\n=== JN (Jump if Negative) Enhanced Test Summary ===");
    $display("✓ JN behavior when negative flag clear (should not jump)");
    $display("✓ JN behavior when negative flag set (should jump)");
    $display("✓ JN after arithmetic operations (SUB negative/positive results)");
    $display("✓ JN after logical operations (AND zero, OR negative)");
    $display("✓ JN after increment/decrement operations");
    $display("✓ JN after rotate and complement operations");
    $display("✓ JN with edge case values ($FF, $80, alternating patterns)");
    $display("✓ Register preservation during JN execution");
    $display("✓ Flag preservation (carry, zero) during JN");
    $display("✓ Complex operation chains ending in negative values");
    $display("JN test finished.===========================\n\n");
    $finish;
    // ============================ END TEST ==============================
  
  end

endmodule