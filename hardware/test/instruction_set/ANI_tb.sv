`timescale 1ns/1ps
import test_utils_pkg::*; 
import arch_defs_pkg::*;  

// AIDEV-NOTE: Enhanced ANI testbench with 15 comprehensive test cases, systematic verification
module computer_tb;

  localparam string HEX_FILE = "../hardware/test/_fixtures_generated/ANI/ROM.hex";

  logic                  clk;
  logic                  reset;
  logic [DATA_WIDTH-1:0] computer_output;

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
    $display("\n\n=== ANI Comprehensive Microinstruction Test Suite ===");
    $display("Testing AND Immediate operation: A = A & immediate with 15 different test cases");
    $display("Covers edge cases, bit patterns, flag behavior, and register preservation");

    // Test 1: Basic AND operation with mixed bits
    $display("\n--- Test 1: Basic AND with mixed bits ---");
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // LDI A, #$AA
    inspect_register(uut.u_cpu.a_out, 8'hAA, "T1: A=$AA", DATA_WIDTH);
    
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // ANI #$F0
    inspect_register(uut.u_cpu.a_out, 8'hA0, "T1: A=$AA&$F0=$A0", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "T1: Non-zero result");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "T1: Negative result (bit 7 set)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "T1: ANI clears carry");

    // Test 2: AND with zero (should zero out result)
    $display("\n--- Test 2: AND with zero ---");
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // ANI #$00
    inspect_register(uut.u_cpu.a_out, 8'h00, "T2: A=$A0&$00=$00", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "T2: Zero flag set");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "T2: Negative cleared");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "T2: Carry still cleared");

    // Test 3: AND with all ones (should preserve A)
    $display("\n--- Test 3: AND with all ones ---");
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // LDI A, #$55
    inspect_register(uut.u_cpu.a_out, 8'h55, "T3: A=$55", DATA_WIDTH);
    
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // ANI #$FF
    inspect_register(uut.u_cpu.a_out, 8'h55, "T3: A=$55&$FF=$55", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "T3: Non-zero result");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "T3: Positive result");

    // Test 4: AND with same value (idempotent)
    $display("\n--- Test 4: Idempotent AND ---");
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // ANI #$55
    inspect_register(uut.u_cpu.a_out, 8'h55, "T4: A=$55&$55=$55", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "T4: Non-zero result");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "T4: Positive result");

    // Test 5: AND with complement (should give zero)
    $display("\n--- Test 5: AND with complement ---");
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // ANI #$AA
    inspect_register(uut.u_cpu.a_out, 8'h00, "T5: A=$55&$AA=$00", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "T5: Zero result");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "T5: Negative cleared");

    // Test 6: Test negative flag with high bit set
    $display("\n--- Test 6: Negative flag test ---");
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // LDI A, #$80
    inspect_register(uut.u_cpu.a_out, 8'h80, "T6: A=$80", DATA_WIDTH);
    
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // ANI #$FF
    inspect_register(uut.u_cpu.a_out, 8'h80, "T6: A=$80&$FF=$80", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "T6: Negative flag set");
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "T6: Non-zero result");

    // Test 7: Clear high bit to test negative flag clearing
    $display("\n--- Test 7: Clear high bit ---");
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // ANI #$7F
    inspect_register(uut.u_cpu.a_out, 8'h00, "T7: A=$80&$7F=$00", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "T7: Negative cleared");
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "T7: Zero result");

    // Test 8: Pattern isolation test (no bit overlap)
    $display("\n--- Test 8: Pattern isolation ---");
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // LDI A, #$F0
    inspect_register(uut.u_cpu.a_out, 8'hF0, "T8: A=$F0", DATA_WIDTH);
    
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // ANI #$0F
    inspect_register(uut.u_cpu.a_out, 8'h00, "T8: A=$F0&$0F=$00", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "T8: No bit overlap");

    // Test 9: Single bit isolation
    $display("\n--- Test 9: Single bit isolation ---");
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // LDI A, #$FF
    inspect_register(uut.u_cpu.a_out, 8'hFF, "T9: A=$FF", DATA_WIDTH);
    
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // ANI #$01
    inspect_register(uut.u_cpu.a_out, 8'h01, "T9: A=$FF&$01=$01", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "T9: Bit 0 isolated");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "T9: Positive result");

    // Test 10: Multiple bit isolation
    $display("\n--- Test 10: Multiple bit isolation ---");
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // LDI A, #$E7
    inspect_register(uut.u_cpu.a_out, 8'hE7, "T10: A=$E7", DATA_WIDTH);
    
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // ANI #$18
    inspect_register(uut.u_cpu.a_out, 8'h00, "T10: A=$E7&$18=$00", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "T10: Zero result");

    // Test 11: Carry flag clearing test
    $display("\n--- Test 11: Carry flag clearing test ---");
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // SEC
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "T11: Carry set by SEC");
    
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // LDI A, #$3C
    inspect_register(uut.u_cpu.a_out, 8'h3C, "T11: A=$3C", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "T11: Carry preserved by LDI");
    
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // ANI #$C3
    inspect_register(uut.u_cpu.a_out, 8'h00, "T11: A=$3C&$C3=$00", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "T11: ANI clears carry");
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "T11: Zero result");

    // Test 12: Register preservation test
    $display("\n--- Test 12: Register preservation ---");
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // LDI B, #$42
    inspect_register(uut.u_cpu.b_out, 8'h42, "T12: B=$42", DATA_WIDTH);
    
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // LDI C, #$69
    inspect_register(uut.u_cpu.c_out, 8'h69, "T12: C=$69", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h42, "T12: B preserved", DATA_WIDTH);
    
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // LDI A, #$FF
    inspect_register(uut.u_cpu.a_out, 8'hFF, "T12: A=$FF", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h42, "T12: B still preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'h69, "T12: C still preserved", DATA_WIDTH);
    
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // ANI #$81
    inspect_register(uut.u_cpu.a_out, 8'h81, "T12: A=$FF&$81=$81", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h42, "T12: B unchanged by ANI", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'h69, "T12: C unchanged by ANI", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "T12: Negative result");

    // Test 13: Edge case - alternating pattern preservation
    $display("\n--- Test 13: Alternating pattern test ---");
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // LDI A, #$CC
    inspect_register(uut.u_cpu.a_out, 8'hCC, "T13: A=$CC", DATA_WIDTH);
    
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // ANI #$33
    inspect_register(uut.u_cpu.a_out, 8'h00, "T13: A=$CC&$33=$00", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "T13: Zero result");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "T13: Negative cleared");

    // Test 14: Boundary values test
    $display("\n--- Test 14: Boundary values test ---");
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // LDI A, #$7F
    inspect_register(uut.u_cpu.a_out, 8'h7F, "T14: A=$7F (max positive)", DATA_WIDTH);
    
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // ANI #$80
    inspect_register(uut.u_cpu.a_out, 8'h00, "T14: A=$7F&$80=$00", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "T14: Zero result");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "T14: Negative cleared");

    // Test 15: Final comprehensive test
    $display("\n--- Test 15: Final comprehensive test ---");
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // LDI A, #$DE
    inspect_register(uut.u_cpu.a_out, 8'hDE, "T15: A=$DE", DATA_WIDTH);
    
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // ANI #$AD
    inspect_register(uut.u_cpu.a_out, 8'h8C, "T15: A=$DE&$AD=$8C", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "T15: Non-zero result");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "T15: Negative result");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "T15: Carry cleared");
    
    $display("\n--- Verifying CPU halt ---");
    run_until_halt(80); // Increased timeout for expanded test suite
    
    // Vizual buffer for waveform inspection
    repeat(2) @(posedge clk);

    $display("ANI test finished.===========================\n\n");
    $finish;
    // ============================ END TEST ==============================
  
  end

endmodule