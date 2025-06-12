`timescale 1ns/1ps
import test_utils_pkg::*; 
import arch_defs_pkg::*;  
// AIDEV-NOTE: Enhanced JNZ testbench with 16 test groups covering comprehensive zero flag scenarios

module computer_tb;

  localparam string HEX_FILE = "../hardware/test/_fixtures_generated/JNZ/ROM.hex";

  logic                  clk;
  logic                  reset;
  logic [DATA_WIDTH-1:0] computer_output;

  computer uut (
        .clk(clk),
        .reset(reset),
        .output_port_1(computer_output),
        .uart_rx(1'b1),    // UART not needed for JNZ microinstruction testing
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
    $display("\n\nRunning JNZ (Jump if Not Zero) Enhanced Test ========================");
    $display("Testing JNZ instruction: Jump to 16-bit address if Zero flag (Z=0) is clear");
    $display("Opcode: $12, Format: JNZ address (3 bytes)");
    $display("Flags affected: None (flags preserved during jump)\n");

    // ======================================================================
    // Test Group 1: Initial Register Setup
    // ======================================================================
    $display("\n--- Test Group 1: Initial Register Setup ---");
    
    // LDI A, #$AA
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hAA, "A=$AA (test pattern 10101010)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "LDI A: Z=0"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "LDI A: N=1 (bit 7 set)"); 
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "LDI A: C preserved (0 init)"); 

    // LDI B, #$BB
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'hBB, "B=$BB (test pattern 10111011)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "LDI B: Z=0"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "LDI B: N=1 (bit 7 set)"); 
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "LDI B: C preserved"); 

    // LDI C, #$CC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hCC, "C=$CC (test pattern 11001100)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "LDI C: Z=0"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "LDI C: N=1 (bit 7 set)"); 
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "LDI C: C preserved"); 

    // ======================================================================
    // Test Group 2: JNZ when Zero flag is clear (Z=0) - Should jump
    // ======================================================================
    $display("\n--- Test Group 2: JNZ when Zero Clear (Should Jump) ---");
    
    // LDI A, #$7F
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h7F, "A=$7F (positive non-zero, Z=0)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "LDI A: Z=0 (non-zero)"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "LDI A: N=0 (positive)"); 
    inspect_register(uut.u_cpu.b_out, 8'hBB, "LDI A: B preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hCC, "LDI A: C register preserved", DATA_WIDTH);

    // JNZ TEST1_SUCCESS (should jump when Z=0)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "JNZ (Z=0): Zero still clear"); 
    inspect_register(uut.u_cpu.a_out, 8'h7F, "JNZ (Z=0): A preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'hBB, "JNZ (Z=0): B preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hCC, "JNZ (Z=0): C register preserved", DATA_WIDTH);
    $display("SUCCESS: JNZ correctly jumped when zero flag was clear");

    // ======================================================================
    // Test Group 3: JNZ when Zero flag is set (Z=1) - Should NOT jump
    // ======================================================================
    $display("\n--- Test Group 3: JNZ when Zero Set (Should NOT Jump) ---");
    
    // LDI A, #$00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "A=$00 (zero value, Z=1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "LDI A: Z=1 (zero value)"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "LDI A: N=0 (not negative)"); 
    inspect_register(uut.u_cpu.b_out, 8'hBB, "LDI A: B preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hCC, "LDI A: C register preserved", DATA_WIDTH);

    // JNZ should NOT jump (Z=1), continue to next instruction
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "JNZ (Z=1): Zero still set"); 
    inspect_register(uut.u_cpu.a_out, 8'h00, "JNZ (Z=1): A preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'hBB, "JNZ (Z=1): B preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hCC, "JNZ (Z=1): C register preserved", DATA_WIDTH);
    $display("SUCCESS: JNZ correctly did NOT jump when zero flag was set");

    // JMP TEST2_SUCCESS
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;

    // ======================================================================
    // Test Group 4: JNZ after ADD with overflow resulting in zero (Z=1)
    // ======================================================================
    $display("\n--- Test Group 4: JNZ after ADD with Overflow (Z=1) ---");
    
    // LDI A, #$FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A=$FF (max unsigned)", DATA_WIDTH);

    // LDI B, #$01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h01, "B=$01", DATA_WIDTH);

    // ADD B ($FF + $01 = $00, Z=1, C=1 overflow)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "ADD B: A=$FF+$01=$00 (overflow to zero)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "ADD B: Z=1 (result is zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "ADD B: N=0 (bit 7 clear)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "ADD B: C=1 (overflow occurred)");
    inspect_register(uut.u_cpu.b_out, 8'h01, "ADD B: B preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hCC, "ADD B: C register preserved", DATA_WIDTH);

    // JNZ should NOT jump (Z=1)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "JNZ (after ADD overflow): Z=1"); 
    $display("SUCCESS: JNZ correctly did NOT jump after ADD overflow to zero");

    // JMP TEST3_SUCCESS
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;

    // ======================================================================
    // Test Group 5: JNZ after ADD with no overflow resulting in non-zero (Z=0)
    // ======================================================================
    $display("\n--- Test Group 5: JNZ after ADD with No Overflow (Z=0) ---");
    
    // LDI A, #$7F
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h7F, "A=$7F (127)", DATA_WIDTH);

    // LDI B, #$01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h01, "B=$01", DATA_WIDTH);

    // ADD B ($7F + $01 = $80, Z=0, no overflow)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h80, "ADD B: A=$7F+$01=$80 (non-zero result)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "ADD B: Z=0 (result non-zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "ADD B: N=1 (bit 7 set)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "ADD B: C=0 (no overflow)");

    // JNZ TEST4_SUCCESS (should jump when Z=0)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "JNZ (after ADD non-zero): Z=0"); 
    $display("SUCCESS: JNZ correctly jumped after ADD with non-zero result");

    // ======================================================================
    // Test Group 6: JNZ after SUB resulting in zero (Z=1)
    // ======================================================================
    $display("\n--- Test Group 6: JNZ after SUB Resulting in Zero (Z=1) ---");
    
    // LDI A, #$10
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h10, "A=$10", DATA_WIDTH);

    // LDI B, #$10
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h10, "B=$10", DATA_WIDTH);

    // SUB B ($10 - $10 = $00, Z=1)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "SUB B: A=$10-$10=$00 (zero result)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "SUB B: Z=1 (result is zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "SUB B: N=0 (bit 7 clear)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "SUB B: C=1 (no borrow)");

    // JNZ should NOT jump (Z=1)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "JNZ (after SUB zero): Z=1"); 
    $display("SUCCESS: JNZ correctly did NOT jump after SUB with zero result");

    // JMP TEST5_SUCCESS
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;

    // ======================================================================
    // Test Group 7: JNZ after SUB resulting in non-zero (Z=0)
    // ======================================================================
    $display("\n--- Test Group 7: JNZ after SUB Resulting in Non-Zero (Z=0) ---");
    
    // LDI A, #$20
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h20, "A=$20", DATA_WIDTH);

    // LDI B, #$05
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h05, "B=$05", DATA_WIDTH);

    // SUB B ($20 - $05 = $1B, Z=0)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h1B, "SUB B: A=$20-$05=$1B (non-zero result)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "SUB B: Z=0 (result non-zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "SUB B: N=0 (positive result)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "SUB B: C=1 (no borrow)");

    // JNZ TEST6_SUCCESS (should jump when Z=0)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "JNZ (after SUB non-zero): Z=0"); 
    $display("SUCCESS: JNZ correctly jumped after SUB with non-zero result");

    // ======================================================================
    // Test Group 8: JNZ after logical AND resulting in zero (Z=1)
    // ======================================================================
    $display("\n--- Test Group 8: JNZ after Logical AND (Z=1) ---");
    
    // LDI A, #$AA
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hAA, "A=$AA (10101010)", DATA_WIDTH);

    // LDI B, #$55
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h55, "B=$55 (01010101)", DATA_WIDTH);

    // ANA B ($AA & $55 = $00, Z=1)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "ANA B: A=$AA & $55 = $00", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "ANA B: Z=1 (result is zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "ANA B: N=0 (bit 7 clear)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "ANA B: C=0 (logical ops clear carry)");

    // JNZ should NOT jump (Z=1)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "JNZ (after ANA): Z=1"); 
    $display("SUCCESS: JNZ correctly did NOT jump after logical AND with zero result");

    // JMP TEST7_SUCCESS
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;

    // ======================================================================
    // Test Group 9: JNZ after logical OR resulting in non-zero (Z=0)
    // ======================================================================
    $display("\n--- Test Group 9: JNZ after Logical OR (Z=0) ---");
    
    // LDI A, #$80
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h80, "A=$80 (10000000)", DATA_WIDTH);

    // LDI B, #$40
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h40, "B=$40 (01000000)", DATA_WIDTH);

    // ORA B ($80 | $40 = $C0, Z=0)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hC0, "ORA B: A=$80 | $40 = $C0", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "ORA B: Z=0 (result non-zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "ORA B: N=1 (bit 7 set)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "ORA B: C=0 (logical ops clear carry)");

    // JNZ TEST8_SUCCESS (should jump when Z=0)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "JNZ (after ORA): Z=0"); 
    $display("SUCCESS: JNZ correctly jumped after logical OR with non-zero result");

    // ======================================================================
    // Test Group 10: JNZ after increment resulting in zero (Z=1)
    // ======================================================================
    $display("\n--- Test Group 10: JNZ after Increment to Zero (Z=1) ---");
    
    // LDI A, #$FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A=$FF (before increment)", DATA_WIDTH);

    // INR A ($FF + 1 = $00, Z=1, but C unaffected)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "INR A: A=$FF+1=$00 (wrap to zero)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "INR A: Z=1 (result is zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "INR A: N=0 (bit 7 clear)");

    // JNZ should NOT jump (Z=1)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "JNZ (after INR zero): Z=1"); 
    $display("SUCCESS: JNZ correctly did NOT jump after increment to zero");

    // JMP TEST9_SUCCESS
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;

    // ======================================================================
    // Test Group 11: JNZ after increment resulting in non-zero (Z=0)
    // ======================================================================
    $display("\n--- Test Group 11: JNZ after Increment to Non-Zero (Z=0) ---");
    
    // LDI A, #$7E
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h7E, "A=$7E (before increment)", DATA_WIDTH);

    // INR A ($7E + 1 = $7F, Z=0)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h7F, "INR A: A=$7E+1=$7F (non-zero result)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "INR A: Z=0 (result non-zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "INR A: N=0 (positive)");

    // JNZ TEST10_SUCCESS (should jump when Z=0)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "JNZ (after INR non-zero): Z=0"); 
    $display("SUCCESS: JNZ correctly jumped after increment to non-zero");

    // ======================================================================
    // Test Group 12: JNZ after decrement resulting in zero (Z=1)
    // ======================================================================
    $display("\n--- Test Group 12: JNZ after Decrement to Zero (Z=1) ---");
    
    // LDI A, #$01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h01, "A=$01 (before decrement)", DATA_WIDTH);

    // DCR A ($01 - 1 = $00, Z=1)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "DCR A: A=$01-1=$00 (zero result)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "DCR A: Z=1 (result is zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "DCR A: N=0 (not negative)");

    // JNZ should NOT jump (Z=1)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "JNZ (after DCR zero): Z=1"); 
    $display("SUCCESS: JNZ correctly did NOT jump after decrement to zero");

    // JMP TEST11_SUCCESS
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;

    // ======================================================================
    // Test Group 13: JNZ after decrement resulting in non-zero (Z=0)
    // ======================================================================
    $display("\n--- Test Group 13: JNZ after Decrement to Non-Zero (Z=0) ---");
    
    // LDI A, #$02
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h02, "A=$02 (before decrement)", DATA_WIDTH);

    // DCR A ($02 - 1 = $01, Z=0)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h01, "DCR A: A=$02-1=$01 (non-zero result)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "DCR A: Z=0 (result non-zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "DCR A: N=0 (positive)");

    // JNZ TEST12_SUCCESS (should jump when Z=0)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "JNZ (after DCR non-zero): Z=0"); 
    $display("SUCCESS: JNZ correctly jumped after decrement to non-zero");

    // ======================================================================
    // Test Group 14: JNZ with alternating bit patterns
    // ======================================================================
    $display("\n--- Test Group 14: JNZ with Alternating Bit Patterns ---");
    
    // LDI A, #$55
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h55, "A=$55 (01010101)", DATA_WIDTH);

    // LDI B, #$AA
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'hAA, "B=$AA (10101010)", DATA_WIDTH);

    // XRA B ($55 ^ $AA = $FF, Z=0)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "XRA B: A=$55 ^ $AA = $FF", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "XRA B: Z=0 (result non-zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "XRA B: N=1 (bit 7 set)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "XRA B: C=0 (logical ops clear carry)");

    // JNZ TEST13_SUCCESS (should jump when Z=0)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "JNZ (alternating patterns): Z=0"); 
    $display("SUCCESS: JNZ correctly handled alternating bit patterns");

    // ======================================================================
    // Test Group 15: Register preservation verification
    // ======================================================================
    $display("\n--- Test Group 15: Register Preservation Test ---");
    
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

    // LDI A, #$42
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h42, "A=$42 (non-zero, Z=0)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "LDI A: Z=0 (non-zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "LDI A: C preserved during load");

    // JNZ PRESERVE_CHECK (preservation test)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h42, "JNZ (preserve): A preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'hBB, "JNZ (preserve): B preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hCC, "JNZ (preserve): C register preserved", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "JNZ (preserve): Zero flag preserved");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "JNZ (preserve): Carry flag preserved");
    $display("SUCCESS: JNZ preserved all uninvolved registers and flags");

    // ======================================================================
    // Test Group 16: Final Success Verification
    // ======================================================================
    $display("\n--- Test Group 16: Final Success Verification ---");
    
    // LDI A, #$FF (success code)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A=$FF (success code)", DATA_WIDTH);

    // STA OUTPUT_PORT_1
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(computer_output, 8'hFF, "Output: $FF (all tests passed)");
    $display("SUCCESS: All JNZ tests completed successfully!");

    // Continue to final instructions
    // JMP SUCCESS_END
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;

    // LDI A, #$FF (final success marker)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A=$FF (final success marker)", DATA_WIDTH);

    // Wait for HLT
    wait(uut.cpu_halt);
    $display("CPU halted - test program completed");
    
    // Visual buffer for waveform inspection
    repeat(5) @(posedge clk);

    $display("\n=== JNZ (Jump if Not Zero) Enhanced Test Summary ===");
    $display("✓ JNZ behavior when zero flag clear (should jump)");
    $display("✓ JNZ behavior when zero flag set (should not jump)");
    $display("✓ JNZ after arithmetic operations (ADD overflow/no overflow)");
    $display("✓ JNZ after subtraction operations (zero/non-zero results)");
    $display("✓ JNZ after logical operations (AND zero, OR non-zero)");
    $display("✓ JNZ after increment/decrement operations (zero/non-zero)");
    $display("✓ JNZ with alternating bit patterns");
    $display("✓ Register preservation during JNZ execution");
    $display("✓ Flag preservation during JNZ execution");
    $display("✓ Comprehensive zero flag state verification");
    $display("JNZ test finished.===========================\n\n");
    $finish;
    // ============================ END TEST ==============================
  
  end

endmodule