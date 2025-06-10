`timescale 1ns/1ps
import test_utils_pkg::*; 
import arch_defs_pkg::*;  

module computer_tb;

  localparam string HEX_FILE = "../hardware/test/fixtures_generated/JSR_RET/ROM.hex";

  logic                  clk;
  logic                  reset;
  logic [DATA_WIDTH-1:0] computer_output;
  
  // Stack pointer tracking variables
  logic [15:0] initial_sp, sp_after_first_call, sp_at_deepest, final_sp, sp_deep_nest;

  computer uut (
        .clk(clk),
        .reset(reset),
        .output_port_1(computer_output)
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
    $display("\n\nRunning JSR/RET (Subroutine Call/Return) comprehensive test ========================");

    // ================================================================
    // TEST 1: Basic JSR/RET functionality
    // LDI A, #$01; LDI B, #$AA; LDI C, #$55; JSR BASIC_SUB; LDI A, #$02
    // ================================================================
    $display("\n--- TEST 1: Basic JSR/RET functionality ---");
    
    // After LDI A, #$01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h01, "After LDI A, #$01: Register A", DATA_WIDTH);
    
    // After LDI B, #$AA
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'hAA, "After LDI B, #$AA: Register B", DATA_WIDTH);
    
    // After LDI C, #$55
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h55, "After LDI C, #$55: Register C", DATA_WIDTH);
    
    // After JSR BASIC_SUB (should execute subroutine and return)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // JSR instruction
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // LDI A, #$BB in subroutine
    inspect_register(uut.u_cpu.a_out, 8'hBB, "In BASIC_SUB: Register A modified", DATA_WIDTH);
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // RET instruction
    
    // After LDI A, #$02 (back in main)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h02, "After return: Register A", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'hAA, "After return: Register B preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'h55, "After return: Register C preserved", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "JSR/RET: Zero flag unaffected"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "JSR/RET: Negative flag unaffected");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "JSR/RET: Carry flag unaffected");

    // ================================================================
    // TEST 2: Nested subroutine calls (3 levels deep)
    // LDI A, #$03; JSR NESTED_SUB1; LDI A, #$04
    // ================================================================
    $display("\n--- TEST 2: Nested subroutine calls (3 levels) ---");
    
    // After LDI A, #$03
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h03, "Before nested calls: Register A", DATA_WIDTH);
    
    // Navigate through nested calls
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // JSR NESTED_SUB1
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // LDI A, #$C1 in SUB1
    inspect_register(uut.u_cpu.a_out, 8'hC1, "In NESTED_SUB1: Register A", DATA_WIDTH);
    
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // JSR NESTED_SUB2
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // LDI A, #$C2 in SUB2
    inspect_register(uut.u_cpu.a_out, 8'hC2, "In NESTED_SUB2: Register A", DATA_WIDTH);
    
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // JSR NESTED_SUB3
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // LDI A, #$C3 in SUB3
    inspect_register(uut.u_cpu.a_out, 8'hC3, "In NESTED_SUB3: Register A", DATA_WIDTH);
    
    // Return path through nested calls
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // RET from SUB3
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // LDI A, #$C2 restore in SUB2
    inspect_register(uut.u_cpu.a_out, 8'hC2, "Back in NESTED_SUB2: Register A restored", DATA_WIDTH);
    
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // RET from SUB2
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // LDI A, #$C1 restore in SUB1
    inspect_register(uut.u_cpu.a_out, 8'hC1, "Back in NESTED_SUB1: Register A restored", DATA_WIDTH);
    
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // RET from SUB1
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // LDI A, #$04 in main
    inspect_register(uut.u_cpu.a_out, 8'h04, "After nested returns: Register A", DATA_WIDTH);

    // ================================================================
    // TEST 3: Register preservation across calls
    // LDI A, #$11; LDI B, #$22; LDI C, #$33; JSR PRESERVE_TEST
    // ================================================================
    $display("\n--- TEST 3: Register preservation test ---");
    
    // Set up test values
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // LDI A, #$11
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // LDI B, #$22
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // LDI C, #$33
    
    // Verify initial values
    inspect_register(uut.u_cpu.a_out, 8'h11, "Before PRESERVE_TEST: Register A", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h22, "Before PRESERVE_TEST: Register B", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'h33, "Before PRESERVE_TEST: Register C", DATA_WIDTH);
    
    // Note: PRESERVE_TEST modifies registers but JSR/RET should preserve context
    // This test verifies the subroutine executes and returns properly
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // JSR PRESERVE_TEST
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // LDI A, #$99 in subroutine
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // LDI B, #$88 in subroutine
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // LDI C, #$77 in subroutine
    inspect_register(uut.u_cpu.a_out, 8'h99, "In PRESERVE_TEST: Register A modified", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h88, "In PRESERVE_TEST: Register B modified", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'h77, "In PRESERVE_TEST: Register C modified", DATA_WIDTH);
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // RET

    // ================================================================
    // TEST 4: Multiple sequential calls
    // LDI A, #$05; JSR INCREMENT_SUB (x3)
    // ================================================================
    $display("\n--- TEST 4: Multiple sequential calls ---");
    
    // After LDI A, #$05
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h05, "Before increments: Register A", DATA_WIDTH);
    
    // First increment: $05 -> $06
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // JSR INCREMENT_SUB
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // INR A
    inspect_register(uut.u_cpu.a_out, 8'h06, "In INCREMENT_SUB #1: Register A incremented", DATA_WIDTH);
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // RET
    
    // Second increment: $06 -> $07
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // JSR INCREMENT_SUB
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // INR A
    inspect_register(uut.u_cpu.a_out, 8'h07, "In INCREMENT_SUB #2: Register A incremented", DATA_WIDTH);
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // RET
    
    // Third increment: $07 -> $08
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // JSR INCREMENT_SUB
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // INR A
    inspect_register(uut.u_cpu.a_out, 8'h08, "In INCREMENT_SUB #3: Register A incremented", DATA_WIDTH);
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // RET

    // ================================================================
    // TEST 5: Stack pointer behavior test
    // LDI A, #$10; JSR STACK_TEST; LDI A, #$20
    // ================================================================
    $display("\n--- TEST 5: Stack behavior test ---");
    
    // Initial stack pointer value (should be at $01FF initially)
    initial_sp = uut.u_cpu.u_stack_pointer.stack_pointer_out;
    $display("Initial stack pointer: $%04X", initial_sp);
    
    // After LDI A, #$10
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h10, "Before STACK_TEST: Register A", DATA_WIDTH);
    
    // Navigate through nested stack operations
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // JSR STACK_TEST
    sp_after_first_call = uut.u_cpu.u_stack_pointer.stack_pointer_out;
    $display("Stack pointer after JSR STACK_TEST: $%04X (should be decreased by 2)", sp_after_first_call);
    
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // JSR STACK_HELPER1
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // JSR STACK_HELPER2
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // LDI A, #$DD
    inspect_register(uut.u_cpu.a_out, 8'hDD, "In STACK_HELPER2: Register A", DATA_WIDTH);
    sp_at_deepest = uut.u_cpu.u_stack_pointer.stack_pointer_out;
    $display("Stack pointer at deepest level: $%04X", sp_at_deepest);
    
    // Return through all levels
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // RET from HELPER2
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // RET from HELPER1
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // RET from STACK_TEST
    
    final_sp = uut.u_cpu.u_stack_pointer.stack_pointer_out;
    $display("Stack pointer after all returns: $%04X (should match initial)", final_sp);
    pretty_print_assert_vec(final_sp, initial_sp, "Stack pointer restored to initial value");
    
    // After LDI A, #$20
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h20, "After STACK_TEST: Register A", DATA_WIDTH);

    // ================================================================
    // TEST 6: Deep nesting test (5 levels)
    // LDI A, #$06; JSR DEEP_SUB1; LDI A, #$07
    // ================================================================
    $display("\n--- TEST 6: Deep nesting test (5 levels) ---");
    
    // After LDI A, #$06
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h06, "Before deep nesting: Register A", DATA_WIDTH);
    
    // Navigate through 5 levels of calls
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // JSR DEEP_SUB1
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // LDI A, #$D1
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // JSR DEEP_SUB2
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // LDI A, #$D2
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // JSR DEEP_SUB3
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // LDI A, #$D3
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // JSR DEEP_SUB4
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // LDI A, #$D4
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // JSR DEEP_SUB5
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // LDI A, #$D5
    
    inspect_register(uut.u_cpu.a_out, 8'hD5, "At deepest level (DEEP_SUB5): Register A", DATA_WIDTH);
    sp_deep_nest = uut.u_cpu.u_stack_pointer.stack_pointer_out;
    $display("Stack pointer at 5-level deep: $%04X", sp_deep_nest);
    
    // Return through all 5 levels
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // RET from SUB5
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // RET from SUB4
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // RET from SUB3
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // RET from SUB2
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // RET from SUB1
    
    // After LDI A, #$07 (back in main)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h07, "After deep nesting returns: Register A", DATA_WIDTH);

    // ================================================================
    // FINAL STATE verification
    // LDI A, #$FF; STA OUTPUT_PORT_1
    // ================================================================
    $display("\n--- FINAL STATE verification ---");
    
    // After LDI A, #$FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "Final state: Register A", DATA_WIDTH);
    
    // After STA OUTPUT_PORT_1
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(computer_output, 8'hFF, "Final output port", DATA_WIDTH);

    // ================================================================
    // HALT verification
    // ================================================================
    $display("\n--- HALT verification ---");
    run_until_halt(100);  // Increased timeout for complex test suite
    $display("CPU successfully halted after comprehensive JSR/RET testing");
    
    // Visual buffer for waveform inspection
    repeat(2) @(posedge clk);

    $display("JSR_RET test finished.===========================\n\n");
    $finish;
    // ============================ END TEST ==============================
  
  end

endmodule