`timescale 1ns/1ps
import test_utils_pkg::*; 
import arch_defs_pkg::*;  
// AIDEV-NOTE: Enhanced JZ testbench with comprehensive zero flag scenarios covering all ways Z flag can be set/cleared

module computer_tb;

  localparam string HEX_FILE = "../hardware/test/_fixtures_generated/JZ/ROM.hex";
  localparam int TIMEOUT_CYCLES = 5000;  // Increased timeout for expanded test suite

  logic                  clk;
  logic                  reset;
  logic [DATA_WIDTH-1:0] computer_output;

  computer uut (
        .clk(clk),
        .reset(reset),
        .output_port_1(computer_output),
        .uart_rx(1'b1),    // UART not needed for JZ microinstruction testing
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
    $display("\n\nRunning JZ (Jump if Zero) Enhanced Test ========================");
    $display("Testing JZ instruction: Jump to 16-bit address if Zero flag (Z=1) is set");
    $display("Opcode: $11, Format: JZ address (3 bytes)");
    $display("Flags affected: None (flags preserved during jump)\n");

    // ======================================================================
    // Test Group 1: Initial Register Setup
    // ======================================================================
    $display("\n--- Test Group 1: Initial Register Setup ---");
    
    // LDI A, #$AA
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hAA, "A=$AA (test pattern 10101010)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "LDI A: Z=0 (non-zero value)"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "LDI A: N=1 (bit 7 set)"); 

    // LDI B, #$BB
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'hBB, "B=$BB (test pattern 10111011)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "LDI B: Z=0 (non-zero value)"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "LDI B: N=1 (bit 7 set)"); 

    // LDI C, #$CC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hCC, "C=$CC (test pattern 11001100)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "LDI C: Z=0 (non-zero value)"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "LDI C: N=1 (bit 7 set)"); 

    // ======================================================================
    // Test Group 2: JZ when Zero flag is Clear (Z=0) - Should NOT jump
    // ======================================================================
    $display("\n--- Test Group 2: JZ when Zero Clear (Should NOT Jump) ---");
    
    // JZ FAIL_1 (should NOT jump when Z=0)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "JZ (Z=0): Zero flag still clear"); 
    inspect_register(uut.u_cpu.a_out, 8'hAA, "JZ (Z=0): A preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'hBB, "JZ (Z=0): B preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hCC, "JZ (Z=0): C register preserved", DATA_WIDTH);
    $display("SUCCESS: JZ correctly did NOT jump when zero flag was clear");

    // LDI A, #$01 (success marker)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h01, "A=$01 (success marker for test 2)", DATA_WIDTH);

    // ======================================================================
    // Test Group 3: JZ when Zero flag is Set (Z=1) - Should jump
    // ======================================================================
    $display("\n--- Test Group 3: JZ when Zero Set (Should Jump) ---");
    
    // LDI A, #$00 (sets Z=1)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "A=$00 (zero value sets Z=1)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "LDI A: Z=1 (zero value loaded)"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "LDI A: N=0 (bit 7 clear)"); 

    // JZ TEST3_SUCCESS (should jump when Z=1)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "JZ (Z=1): Zero flag still set after jump"); 
    $display("SUCCESS: JZ correctly jumped when zero flag was set");

    // LDI A, #$02 (success marker)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h02, "A=$02 (success marker for test 3)", DATA_WIDTH);

    // ======================================================================
    // Test Group 4: JZ after arithmetic resulting in zero (AND operation)
    // ======================================================================
    $display("\n--- Test Group 4: JZ after AND Operation Resulting in Zero ---");
    
    // LDI A, #$55
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h55, "A=$55 (01010101)", DATA_WIDTH);

    // LDI B, #$AA
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'hAA, "B=$AA (10101010)", DATA_WIDTH);

    // ANA B ($55 & $AA = $00, Z=1)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "ANA B: A=$55 & $AA = $00", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "ANA B: Z=1 (result is zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "ANA B: N=0 (bit 7 clear)");
    inspect_register(uut.u_cpu.b_out, 8'hAA, "ANA B: B preserved", DATA_WIDTH);

    // JZ TEST4_SUCCESS (should jump when Z=1)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "JZ (after ANA): Z=1"); 
    $display("SUCCESS: JZ correctly jumped after AND operation resulted in zero");

    // LDI A, #$03 (success marker)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h03, "A=$03 (success marker for test 4)", DATA_WIDTH);

    // ======================================================================
    // Test Group 5: JZ after arithmetic resulting in non-zero (OR operation)
    // ======================================================================
    $display("\n--- Test Group 5: JZ after OR Operation Resulting in Non-Zero ---");
    
    // LDI A, #$FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A=$FF (all ones)", DATA_WIDTH);

    // LDI B, #$00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h00, "B=$00 (all zeros)", DATA_WIDTH);

    // ORA B ($FF | $00 = $FF, Z=0)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "ORA B: A=$FF | $00 = $FF", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "ORA B: Z=0 (result non-zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "ORA B: N=1 (bit 7 set)");

    // JZ FAIL_5 (should NOT jump when Z=0)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "JZ (after ORA): Z=0"); 
    $display("SUCCESS: JZ correctly did NOT jump after OR operation resulted in non-zero");

    // LDI A, #$04 (success marker)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h04, "A=$04 (success marker for test 5)", DATA_WIDTH);

    // ======================================================================
    // Test Group 6: JZ after subtraction resulting in zero
    // ======================================================================
    $display("\n--- Test Group 6: JZ after Subtraction Resulting in Zero ---");
    
    // LDI A, #$55
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h55, "A=$55", DATA_WIDTH);

    // LDI B, #$55
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h55, "B=$55 (same as A)", DATA_WIDTH);

    // SUB B ($55 - $55 = $00, Z=1)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "SUB B: A=$55 - $55 = $00", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "SUB B: Z=1 (result is zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "SUB B: N=0 (bit 7 clear)");

    // JZ TEST6_SUCCESS (should jump when Z=1)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "JZ (after SUB zero): Z=1"); 
    $display("SUCCESS: JZ correctly jumped after subtraction resulted in zero");

    // LDI A, #$05 (success marker)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h05, "A=$05 (success marker for test 6)", DATA_WIDTH);

    // ======================================================================
    // Test Group 7: JZ after subtraction resulting in non-zero
    // ======================================================================
    $display("\n--- Test Group 7: JZ after Subtraction Resulting in Non-Zero ---");
    
    // LDI A, #$10
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h10, "A=$10", DATA_WIDTH);

    // LDI B, #$05
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h05, "B=$05", DATA_WIDTH);

    // SUB B ($10 - $05 = $0B, Z=0)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h0B, "SUB B: A=$10 - $05 = $0B", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "SUB B: Z=0 (result non-zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "SUB B: N=0 (bit 7 clear)");

    // JZ FAIL_7 (should NOT jump when Z=0)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "JZ (after SUB non-zero): Z=0"); 
    $display("SUCCESS: JZ correctly did NOT jump after subtraction resulted in non-zero");

    // LDI A, #$06 (success marker)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h06, "A=$06 (success marker for test 7)", DATA_WIDTH);

    // ======================================================================
    // Test Group 8: JZ after increment resulting in zero (wrap around)
    // ======================================================================
    $display("\n--- Test Group 8: JZ after Increment Wrap to Zero ---");
    
    // LDI A, #$FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A=$FF (max unsigned)", DATA_WIDTH);

    // INR A ($FF + 1 = $00, Z=1)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "INR A: A=$FF + 1 = $00 (wrap)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "INR A: Z=1 (result is zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "INR A: N=0 (bit 7 clear)");

    // JZ TEST8_SUCCESS (should jump when Z=1)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "JZ (after INR wrap): Z=1"); 
    $display("SUCCESS: JZ correctly jumped after increment wrapped to zero");

    // LDI A, #$07 (success marker)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h07, "A=$07 (success marker for test 8)", DATA_WIDTH);

    // ======================================================================
    // Test Group 9: JZ after decrement resulting in zero
    // ======================================================================
    $display("\n--- Test Group 9: JZ after Decrement to Zero ---");
    
    // LDI A, #$01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h01, "A=$01", DATA_WIDTH);

    // DCR A ($01 - 1 = $00, Z=1)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "DCR A: A=$01 - 1 = $00", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "DCR A: Z=1 (result is zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "DCR A: N=0 (bit 7 clear)");

    // JZ TEST9_SUCCESS (should jump when Z=1)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "JZ (after DCR): Z=1"); 
    $display("SUCCESS: JZ correctly jumped after decrement resulted in zero");

    // LDI A, #$08 (success marker)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h08, "A=$08 (success marker for test 9)", DATA_WIDTH);

    // ======================================================================
    // Test Group 10: JZ after XOR resulting in zero (same values)
    // ======================================================================
    $display("\n--- Test Group 10: JZ after XOR with Same Values (Results in Zero) ---");
    
    // LDI A, #$33
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h33, "A=$33 (00110011)", DATA_WIDTH);

    // LDI B, #$33
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h33, "B=$33 (same as A)", DATA_WIDTH);

    // XRA B ($33 ^ $33 = $00, Z=1)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "XRA B: A=$33 ^ $33 = $00", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "XRA B: Z=1 (result is zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "XRA B: N=0 (bit 7 clear)");

    // JZ TEST10_SUCCESS (should jump when Z=1)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "JZ (after XRA zero): Z=1"); 
    $display("SUCCESS: JZ correctly jumped after XOR resulted in zero");

    // LDI A, #$09 (success marker)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h09, "A=$09 (success marker for test 10)", DATA_WIDTH);

    // ======================================================================
    // Test Group 11: JZ after complement of $FF (becomes $00)
    // ======================================================================
    $display("\n--- Test Group 11: JZ after Complement Operation ---");
    
    // LDI A, #$FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A=$FF (all ones)", DATA_WIDTH);

    // CMA (A = ~$FF = $00, Z=1)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "CMA: A=~$FF=$00", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "CMA: Z=1 (result is zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "CMA: N=0 (bit 7 clear)");

    // JZ TEST11_SUCCESS (should jump when Z=1)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "JZ (after CMA): Z=1"); 
    $display("SUCCESS: JZ correctly jumped after complement resulted in zero");

    // LDI A, #$0A (success marker)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h0A, "A=$0A (success marker for test 11)", DATA_WIDTH);

    // ======================================================================
    // Test Group 12: JZ preservation of uninvolved registers
    // ======================================================================
    $display("\n--- Test Group 12: Register Preservation Test ---");
    
    // LDI B, #$DD
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'hDD, "B=$DD (test pattern)", DATA_WIDTH);

    // LDI C, #$EE
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hEE, "C=$EE (test pattern)", DATA_WIDTH);

    // LDI A, #$00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "A=$00 (zero for jump)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "LDI A: Z=1 (zero loaded)");

    // JZ TEST12_SUCCESS (should jump and preserve B,C)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "JZ (preserve): A still zero", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'hDD, "JZ (preserve): B preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hEE, "JZ (preserve): C register preserved", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "JZ (preserve): Zero flag preserved");
    $display("SUCCESS: JZ preserved all uninvolved registers");

    // LDI A, #$0B (success marker)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h0B, "A=$0B (success marker for test 12)", DATA_WIDTH);

    // ======================================================================
    // Test Group 13: Final Success Verification
    // ======================================================================
    $display("\n--- Test Group 13: Final Success Verification ---");
    
    // STA OUTPUT_PORT_1
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(computer_output, 8'h0B, "Output: $0B (all tests passed)");
    $display("SUCCESS: All JZ tests completed successfully!");

    // Wait for HLT
    wait(uut.cpu_halt);
    $display("CPU halted - test program completed");
    
    // Visual buffer for waveform inspection
    repeat(5) @(posedge clk);

    $display("\n=== JZ (Jump if Zero) Enhanced Test Summary ===");
    $display("✓ JZ behavior when zero flag clear (should not jump)");
    $display("✓ JZ behavior when zero flag set (should jump)");
    $display("✓ JZ after AND operation resulting in zero");
    $display("✓ JZ after OR operation resulting in non-zero");
    $display("✓ JZ after subtraction operations (zero/non-zero results)");
    $display("✓ JZ after increment/decrement operations");
    $display("✓ JZ after XOR operation with same values");
    $display("✓ JZ after complement operation");
    $display("✓ Register preservation during JZ execution");
    $display("✓ Comprehensive zero flag state verification");
    $display("JZ test finished.===========================\n\n");
    $finish;
    // ============================ END TEST ==============================
  
  end

endmodule