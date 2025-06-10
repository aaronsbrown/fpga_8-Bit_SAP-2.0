`timescale 1ns/1ps
import test_utils_pkg::*; 
import arch_defs_pkg::*;  

// AIDEV-NOTE: Enhanced CLC testbench with systematic verification of all flag behaviors, register preservation, and comprehensive edge case testing
module computer_tb;

  localparam string HEX_FILE = "../hardware/test/_fixtures_generated/CLC/ROM.hex";

  // CPU-focused signals - no UART needed for microinstruction testing
  logic                  clk;
  logic                  reset;
  logic [DATA_WIDTH-1:0] computer_output;

  computer uut (
        .clk(clk),
        .reset(reset),
        .output_port_1(computer_output),
        .uart_rx(1'b1),     // Tie UART signals to safe values
        .uart_tx()          // Leave unconnected
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

    // ============================ BEGIN CLC INSTRUCTION TEST ==============================
    $display("\n======== CLC (Clear Carry) Instruction Comprehensive Test ========");
    $display("Testing CLC instruction functionality and flag behavior\n");

    // =================================================================
    // TEST 1: Basic CLC functionality - Carry flag should be cleared
    // =================================================================
    $display("--- TEST 1: Basic CLC functionality ---");
    
    // LDI A, #$FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "LDI A,#$FF: Register A", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Flag Z=0 (A=0xFF)"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "Flag N=1 (A=0xFF)");  

    // LDI B, #$01  
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h01, "LDI B,#$01: Register B", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Flag Z=0 (B=0x01)"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "Flag N=0 (B=0x01)");  
 
    // ADD B (0xFF + 0x01 = 0x00 with Carry=1)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "ADD B: Register A (0xFF+0x01=0x00)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "Flag Z=1 (result is zero)"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "Flag N=0 (result not negative)");  
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "Flag C=1 (addition overflow)");  

    // CLC - Clear carry flag
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "CLC: Register A (unchanged)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "CLC: Flag C=0 (carry cleared)");  
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "CLC: Flag Z=1 (preserved)"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "CLC: Flag N=0 (preserved)");  

    // =================================================================
    // TEST 2: CLC with different register values - verify no side effects
    // =================================================================
    $display("\n--- TEST 2: CLC with different register values ---");
    
    // LDI A, #$80
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h80, "LDI A,#$80: Register A", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Flag Z=0 (A=0x80)"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "Flag N=1 (A=0x80)");  

    // LDI B, #$42
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h42, "LDI B,#$42: Register B", DATA_WIDTH);

    // LDI C, #$AA  
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hAA, "LDI C,#$AA: Register C", DATA_WIDTH);

    // SEC - Set carry flag
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "SEC: Flag C=1 (carry set)");  

    // CLC - Clear carry flag, verify registers unchanged
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h80, "CLC: Register A (preserved)", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h42, "CLC: Register B (preserved)", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hAA, "CLC: Register C (preserved)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "CLC: Flag C=0 (carry cleared)");  
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "CLC: Flag Z=0 (preserved)"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "CLC: Flag N=1 (preserved)");  

    // =================================================================
    // TEST 3: CLC when Carry is already 0 - should remain 0
    // =================================================================
    $display("\n--- TEST 3: CLC idempotent behavior (C already 0) ---");
    
    // LDI A, #$55
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h55, "LDI A,#$55: Register A (alternating bits)", DATA_WIDTH);

    // ANI #$55 (0x55 & 0x55 = 0x55, clears carry)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h55, "ANI #$55: Register A (0x55 & 0x55 = 0x55)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "ANI #$55: Flag C=0 (logical op clears C)");  

    // CLC - Clear already clear carry flag  
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h55, "CLC: Register A (unchanged)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "CLC: Flag C=0 (remains cleared)");  

    // =================================================================
    // TEST 4: CLC with Zero flag set - verify Zero flag preservation
    // =================================================================
    $display("\n--- TEST 4: CLC with Zero flag preservation ---");
    
    // LDI A, #$FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "LDI A,#$FF: Register A", DATA_WIDTH);

    // LDI B, #$01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h01, "LDI B,#$01: Register B", DATA_WIDTH);

    // ADD B (0xFF + 0x01 = 0x00 with Carry=1, Zero=1)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "ADD B: Register A (0xFF+0x01=0x00)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "Flag Z=1 (result is zero)"); 
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "Flag C=1 (addition overflow)");  

    // CLC - Clear carry, preserve zero flag
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "CLC: Flag C=0 (carry cleared)");  
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "CLC: Flag Z=1 (zero preserved)"); 

    // =================================================================
    // TEST 5: CLC with Negative flag set - verify Negative flag preservation  
    // =================================================================
    $display("\n--- TEST 5: CLC with Negative flag preservation ---");
    
    // LDI A, #$FE
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFE, "LDI A,#$FE: Register A (negative)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "Flag N=1 (A=0xFE negative)");  

    // SEC - Set carry flag
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "SEC: Flag C=1 (carry set)");  

    // CLC - Clear carry, preserve negative flag
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFE, "CLC: Register A (unchanged)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "CLC: Flag C=0 (carry cleared)");  
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "CLC: Flag N=1 (negative preserved)");  

    // =================================================================
    // TEST 6: Multiple CLC operations - verify consistent behavior
    // =================================================================
    $display("\n--- TEST 6: Multiple successive CLC operations ---");
    
    // SEC - Set carry flag
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "SEC: Flag C=1 (carry set)");  

    // CLC (1st time)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "CLC (1st): Flag C=0 (carry cleared)");  

    // CLC (2nd time) 
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "CLC (2nd): Flag C=0 (remains cleared)");  

    // CLC (3rd time)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "CLC (3rd): Flag C=0 (remains cleared)");  

    // =================================================================
    // TEST 7: CLC with all flags in different states
    // =================================================================
    $display("\n--- TEST 7: CLC with mixed flag states ---");
    
    // LDI A, #$7F
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h7F, "LDI A,#$7F: Register A", DATA_WIDTH);

    // LDI B, #$01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h01, "LDI B,#$01: Register B", DATA_WIDTH);

    // ADD B (0x7F + 0x01 = 0x80, sets Negative=1, clears Carry and Zero)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h80, "ADD B: Register A (0x7F+0x01=0x80)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Flag Z=0 (result not zero)"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "Flag N=1 (result negative)");  
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "Flag C=0 (no overflow)");  

    // SEC - Set carry flag
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "SEC: Flag C=1 (carry set)");  

    // CLC - Clear carry, preserve other flags
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h80, "CLC: Register A (unchanged)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "CLC: Flag C=0 (carry cleared)");  
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "CLC: Flag Z=0 (preserved)"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "CLC: Flag N=1 (preserved)");  

    // =================================================================
    // TEST 8: Register preservation test - verify B and C unchanged
    // =================================================================
    $display("\n--- TEST 8: Final register preservation verification ---");
    
    // LDI A, #$00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "LDI A,#$00: Register A", DATA_WIDTH);

    // LDI B, #$55 (test pattern)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h55, "LDI B,#$55: Register B (test pattern)", DATA_WIDTH);

    // LDI C, #$AA (complementary test pattern)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hAA, "LDI C,#$AA: Register C (test pattern)", DATA_WIDTH);

    // SEC - Set carry flag
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "SEC: Flag C=1 (carry set)");  

    // CLC - Final test: clear carry, verify all registers preserved
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "CLC: Register A=0x00 (preserved)", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h55, "CLC: Register B=0x55 (preserved)", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hAA, "CLC: Register C=0xAA (preserved)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "CLC: Flag C=0 (carry cleared)");  

    // =================================================================
    // FINAL: Wait for halt and verify program completion
    // =================================================================
    $display("\n--- FINAL: Program completion verification ---");
    run_until_halt(50);  // Increased timeout for expanded test suite
    
    // Visual buffer for waveform inspection
    repeat(2) @(posedge clk);

    $display("\n======== CLC Instruction Test Summary ========");
    $display("✓ Basic CLC functionality verified");
    $display("✓ Register preservation confirmed (A, B, C unchanged by CLC)");
    $display("✓ Flag preservation verified (Z, N unaffected by CLC)");
    $display("✓ Carry flag clearing confirmed in all scenarios");
    $display("✓ Idempotent behavior confirmed (CLC on clear carry)");
    $display("✓ Multiple successive CLC operations verified");
    $display("========================================");

    $display("CLC test finished.===========================\n\n");
    $finish;
    // ============================ END TEST ==============================
  
  end

endmodule