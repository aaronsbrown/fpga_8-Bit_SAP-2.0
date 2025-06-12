`timescale 1ns/1ps
import test_utils_pkg::*; 
import arch_defs_pkg::*;  
// AIDEV-NOTE: Enhanced JNC testbench with 17 test groups covering comprehensive carry flag scenarios

module computer_tb;

  localparam string HEX_FILE = "../hardware/test/_fixtures_generated/JNC/ROM.hex";

  logic                  clk;
  logic                  reset;
  logic [DATA_WIDTH-1:0] computer_output;

  computer uut (
        .clk(clk),
        .reset(reset),
        .output_port_1(computer_output),
        .uart_rx(1'b1),    // UART not needed for JNC microinstruction testing
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
    $display("\n\nRunning JNC (Jump if Not Carry) Enhanced Test ========================");
    $display("Testing JNC instruction: Jump to 16-bit address if Carry flag (C=0) is clear");
    $display("Opcode: $16, Format: JNC address (3 bytes)");
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
    // Test Group 2: JNC when Carry is Clear (C=0) - Should jump
    // ======================================================================
    $display("\n--- Test Group 2: JNC when Carry Clear (Should Jump) ---");
    
    // CLC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "CLC: C=0 (explicitly cleared)"); 
    inspect_register(uut.u_cpu.a_out, 8'hAA, "CLC: A preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'hBB, "CLC: B preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hCC, "CLC: C register preserved", DATA_WIDTH);

    // JNC TEST1_SUCCESS (should jump when C=0)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "JNC (C=0): Carry still clear"); 
    inspect_register(uut.u_cpu.a_out, 8'hAA, "JNC (C=0): A preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'hBB, "JNC (C=0): B preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hCC, "JNC (C=0): C register preserved", DATA_WIDTH);
    $display("SUCCESS: JNC correctly jumped when carry was clear");

    // ======================================================================
    // Test Group 3: JNC when Carry is Set (C=1) - Should NOT jump
    // ======================================================================
    $display("\n--- Test Group 3: JNC when Carry Set (Should NOT Jump) ---");
    
    // SEC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "SEC: C=1 (explicitly set)"); 
    inspect_register(uut.u_cpu.a_out, 8'hAA, "SEC: A preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'hBB, "SEC: B preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hCC, "SEC: C register preserved", DATA_WIDTH);

    // JNC TEST2_FAIL (should NOT jump when C=1)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "JNC (C=1): Carry still set"); 
    inspect_register(uut.u_cpu.a_out, 8'hAA, "JNC (C=1): A preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'hBB, "JNC (C=1): B preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hCC, "JNC (C=1): C register preserved", DATA_WIDTH);
    $display("SUCCESS: JNC correctly did NOT jump when carry was set");

    // JMP TEST3_SETUP
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;

    // ======================================================================
    // Test Group 4: JNC after ADD with no overflow (C=0)
    // ======================================================================
    $display("\n--- Test Group 4: JNC after ADD with No Overflow (C=0) ---");
    
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
    inspect_register(uut.u_cpu.b_out, 8'h01, "ADD B: B preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hCC, "ADD B: C register preserved", DATA_WIDTH);

    // JNC TEST3_SUCCESS (should jump when C=0)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "JNC (after ADD no overflow): C=0"); 
    $display("SUCCESS: JNC correctly jumped after ADD with no overflow");

    // ======================================================================
    // Test Group 5: JNC after ADD with overflow (C=1)
    // ======================================================================
    $display("\n--- Test Group 5: JNC after ADD with Overflow (C=1) ---");
    
    // LDI A, #$FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A=$FF (max unsigned)", DATA_WIDTH);

    // LDI B, #$01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h01, "B=$01", DATA_WIDTH);

    // ADD B ($FF + $01 = $00, C=1 overflow)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "ADD B: A=$FF+$01=$00 (overflow)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "ADD B: Z=1 (result is zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "ADD B: N=0 (bit 7 clear)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "ADD B: C=1 (overflow occurred)");

    // JNC TEST4_FAIL (should NOT jump when C=1)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "JNC (after ADD overflow): C=1"); 
    $display("SUCCESS: JNC correctly did NOT jump after ADD overflow");

    // JMP TEST5_SETUP
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;

    // ======================================================================
    // Test Group 6: JNC after SUB with borrow (C=0)
    // ======================================================================
    $display("\n--- Test Group 6: JNC after SUB with Borrow (C=0) ---");
    
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

    // JNC TEST5_SUCCESS (should jump when C=0 from borrow)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "JNC (after SUB borrow): C=0"); 
    $display("SUCCESS: JNC correctly jumped after SUB with borrow");

    // ======================================================================
    // Test Group 7: JNC after SUB with no borrow (C=1)
    // ======================================================================
    $display("\n--- Test Group 7: JNC after SUB with No Borrow (C=1) ---");
    
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

    // JNC TEST6_FAIL (should NOT jump when C=1)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "JNC (after SUB no borrow): C=1"); 
    $display("SUCCESS: JNC correctly did NOT jump after SUB with no borrow");

    // JMP TEST7_SETUP
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;

    // ======================================================================
    // Test Group 8: JNC after logical AND (clears carry)
    // ======================================================================
    $display("\n--- Test Group 8: JNC after Logical AND (C=0) ---");
    
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

    // JNC TEST7_SUCCESS (should jump when C=0)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "JNC (after ANA): C=0"); 
    $display("SUCCESS: JNC correctly jumped after logical AND cleared carry");

    // ======================================================================
    // Test Group 9: JNC after logical OR (clears carry)
    // ======================================================================
    $display("\n--- Test Group 9: JNC after Logical OR (C=0) ---");
    
    // SEC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "SEC: C=1 (set before OR)");

    // LDI A, #$00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "A=$00 (all zeros)", DATA_WIDTH);

    // LDI B, #$FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'hFF, "B=$FF (all ones)", DATA_WIDTH);

    // ORA B ($00 | $FF = $FF, C=0 logical ops clear carry)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "ORA B: A=$00 | $FF = $FF", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "ORA B: Z=0 (result non-zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "ORA B: N=1 (bit 7 set)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "ORA B: C=0 (logical ops clear carry)");

    // JNC TEST8_SUCCESS (should jump when C=0)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "JNC (after ORA): C=0"); 
    $display("SUCCESS: JNC correctly jumped after logical OR cleared carry");

    // ======================================================================
    // Test Group 10: JNC after logical XOR (clears carry)
    // ======================================================================
    $display("\n--- Test Group 10: JNC after Logical XOR (C=0) ---");
    
    // SEC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "SEC: C=1 (set before XOR)");

    // LDI A, #$F0
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hF0, "A=$F0 (11110000)", DATA_WIDTH);

    // LDI B, #$0F
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h0F, "B=$0F (00001111)", DATA_WIDTH);

    // XRA B ($F0 ^ $0F = $FF, C=0 logical ops clear carry)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "XRA B: A=$F0 ^ $0F = $FF", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "XRA B: Z=0 (result non-zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "XRA B: N=1 (bit 7 set)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "XRA B: C=0 (logical ops clear carry)");

    // JNC TEST9_SUCCESS (should jump when C=0)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "JNC (after XRA): C=0"); 
    $display("SUCCESS: JNC correctly jumped after logical XOR cleared carry");

    // ======================================================================
    // Test Group 11: JNC after rotate operations (carry from rotation)
    // ======================================================================
    $display("\n--- Test Group 11: JNC after Rotate Operation (Clears Carry) ---");
    
    // SEC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "SEC: C=1 (set before rotate)");

    // LDI A, #$80
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h80, "A=$80 (10000000)", DATA_WIDTH);

    // RAR (rotate A right: bit 0 -> carry, carry -> bit 7)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hC0, "RAR: A=$80->$C0 (C=1 rotated to bit 7)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "RAR: Z=0 (result non-zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "RAR: N=1 (bit 7 set)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "RAR: C=0 (bit 0 was 0 rotated to carry)");

    // JNC TEST10_SUCCESS (should jump when C=0 from rotation)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "JNC (after RAR clears carry): C=0"); 
    $display("SUCCESS: JNC correctly jumped after rotate cleared carry");

    // ======================================================================
    // Test Group 12: JNC when rotate sets carry (should not jump)
    // ======================================================================
    $display("\n--- Test Group 12: JNC when Rotate Sets Carry (Should NOT Jump) ---");
    
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

    // JNC TEST11_FAIL (should NOT jump when C=1)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "JNC (after RAR sets carry): C=1"); 
    $display("SUCCESS: JNC correctly did NOT jump when rotate set carry");

    // JMP TEST12_SETUP
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;

    // ======================================================================
    // Test Group 13: JNC after increment (carry unaffected)
    // ======================================================================
    $display("\n--- Test Group 13: JNC after Increment (Carry Unaffected) ---");
    
    // CLC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "CLC: C=0 (clear before INR)");

    // LDI A, #$FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A=$FF (before increment)", DATA_WIDTH);

    // INR A ($FF + 1 = $00, but C should remain unchanged)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "INR A: A=$FF+1=$00 (wrap)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "INR A: Z=1 (result is zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "INR A: N=0 (bit 7 clear)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "INR A: C=0 (unchanged by INR)");

    // JNC TEST12_SUCCESS (should jump - carry unchanged by INR)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "JNC (after INR): C=0 (unchanged)"); 
    $display("SUCCESS: JNC correctly jumped - INR did not affect carry");

    // Test decrement as well
    // SEC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "SEC: C=1 (set before DCR)");

    // LDI A, #$00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "A=$00 (before decrement)", DATA_WIDTH);

    // DCR A ($00 - 1 = $FF, but C should remain unchanged)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "DCR A: A=$00-1=$FF (wrap)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "DCR A: Z=0 (result non-zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "DCR A: N=1 (bit 7 set)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "DCR A: C=1 (unchanged by DCR)");

    // JNC TEST12_FAIL (should NOT jump - carry unchanged by DCR)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "JNC (after DCR): C=1 (unchanged)"); 
    $display("SUCCESS: JNC correctly did NOT jump - DCR did not affect carry");

    // JMP TEST13_SETUP
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;

    // ======================================================================
    // Test Group 14: JNC with alternating bit patterns
    // ======================================================================
    $display("\n--- Test Group 14: JNC with Alternating Bit Patterns ---");
    
    // LDI A, #$55
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h55, "A=$55 (01010101)", DATA_WIDTH);

    // LDI B, #$AA
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'hAA, "B=$AA (10101010)", DATA_WIDTH);

    // ANA B ($55 & $AA = $00, C=0)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "ANA B: A=$55 & $AA = $00", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "ANA B: Z=1 (result is zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "ANA B: C=0 (logical ops clear carry)");

    // JNC TEST13_SUCCESS (should jump when C=0)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "JNC (alternating patterns): C=0"); 
    $display("SUCCESS: JNC correctly handled alternating bit patterns");

    // ======================================================================
    // Test Group 15: JNC after complement operation
    // ======================================================================
    $display("\n--- Test Group 15: JNC after Complement Operation ---");
    
    // SEC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "SEC: C=1 (set before CMA)");

    // LDI A, #$F0
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hF0, "A=$F0 (11110000)", DATA_WIDTH);

    // CMA (A = ~$F0 = $0F, C=0 CMA clears carry)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h0F, "CMA: A=~$F0=$0F", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "CMA: Z=0 (result non-zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "CMA: N=0 (bit 7 clear)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "CMA: C=0 (CMA clears carry)");

    // JNC TEST14_SUCCESS (should jump when C=0)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "JNC (after CMA): C=0"); 
    $display("SUCCESS: JNC correctly jumped after complement cleared carry");

    // ======================================================================
    // Test Group 16: Final Register Preservation Test
    // ======================================================================
    $display("\n--- Test Group 16: Final Register Preservation Test ---");
    
    // LDI A, #$AA
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hAA, "A=$AA (final test pattern)", DATA_WIDTH);

    // LDI B, #$BB
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'hBB, "B=$BB (final test pattern)", DATA_WIDTH);

    // LDI C, #$CC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hCC, "C=$CC (final test pattern)", DATA_WIDTH);

    // CLC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "CLC: C=0 (clear for final jump)");

    // JNC PRESERVE_CHECK (final preservation test)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hAA, "JNC (final): A preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'hBB, "JNC (final): B preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hCC, "JNC (final): C register preserved", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "JNC (final): Carry flag preserved");
    $display("SUCCESS: JNC preserved all uninvolved registers");

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
    $display("SUCCESS: All JNC tests completed successfully!");

    // Wait for HLT
    wait(uut.cpu_halt);
    $display("CPU halted - test program completed");
    
    // Visual buffer for waveform inspection
    repeat(5) @(posedge clk);

    $display("\n=== JNC (Jump if Not Carry) Enhanced Test Summary ===");
    $display("✓ JNC behavior when carry clear (should jump)");
    $display("✓ JNC behavior when carry set (should not jump)");
    $display("✓ JNC after arithmetic operations (overflow/no overflow)");
    $display("✓ JNC after subtraction operations (borrow/no borrow)");
    $display("✓ JNC after logical operations (carry always cleared)");
    $display("✓ JNC after rotate operations (carry from bit rotation)");
    $display("✓ JNC after increment/decrement (carry unaffected)");
    $display("✓ JNC with alternating bit patterns");
    $display("✓ JNC after complement operation (carry cleared)");
    $display("✓ Register preservation during JNC execution");
    $display("✓ Comprehensive flag state verification");
    $display("JNC test finished.===========================\n\n");
    $finish;
    // ============================ END TEST ==============================
  
  end

endmodule