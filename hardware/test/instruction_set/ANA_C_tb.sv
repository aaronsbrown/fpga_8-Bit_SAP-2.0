`timescale 1ns/1ps
import test_utils_pkg::*; 
import arch_defs_pkg::*;  

module computer_tb;

  localparam string HEX_FILE = "../hardware/test/fixtures_generated/ANA_C/ROM.hex";

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
    $display("\n\n=== ANA_C Comprehensive Microinstruction Test Suite ===");
    $display("Testing AND operation: A = A & C with 10 different test cases");
    $display("Covers edge cases, bit patterns, and flag behavior");

    // Test 1: Basic AND operation with mixed bits
    $display("\n--- Test 1: Basic AND with mixed bits ---");
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // LDI A, #$E1
    inspect_register(uut.u_cpu.a_out, 8'hE1, "T1: A=$E1", DATA_WIDTH);
    
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // LDI C, #$FE
    inspect_register(uut.u_cpu.c_out, 8'hFE, "T1: C=$FE", DATA_WIDTH);
    
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // ADD C
    inspect_register(uut.u_cpu.a_out, 8'hDF, "T1: A after ADD", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "T1: Carry set by ADD");
    
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // ANA C
    inspect_register(uut.u_cpu.a_out, 8'hDE, "T1: A=$DF&$FE=$DE", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "T1: Non-zero result");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "T1: Negative result");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "T1: ANA clears carry");

    // Test 2: AND with zero (should zero out result)
    $display("\n--- Test 2: AND with zero ---");
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // LDI C, #$00
    inspect_register(uut.u_cpu.c_out, 8'h00, "T2: C=$00", DATA_WIDTH);
    
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // ANA C
    inspect_register(uut.u_cpu.a_out, 8'h00, "T2: A=$DE&$00=$00", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "T2: Zero flag set");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "T2: Negative cleared");

    // Test 3: AND with all ones (should preserve A)
    $display("\n--- Test 3: AND with all ones ---");
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // LDI A, #$AA
    inspect_register(uut.u_cpu.a_out, 8'hAA, "T3: A=$AA", DATA_WIDTH);
    
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // LDI C, #$FF
    inspect_register(uut.u_cpu.c_out, 8'hFF, "T3: C=$FF", DATA_WIDTH);
    
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // ANA C
    inspect_register(uut.u_cpu.a_out, 8'hAA, "T3: A=$AA&$FF=$AA", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "T3: Non-zero result");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "T3: Negative (bit 7 set)");

    // Test 4: AND with same value (idempotent)
    $display("\n--- Test 4: Idempotent AND ---");
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // LDI C, #$AA
    inspect_register(uut.u_cpu.c_out, 8'hAA, "T4: C=$AA", DATA_WIDTH);
    
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // ANA C
    inspect_register(uut.u_cpu.a_out, 8'hAA, "T4: A=$AA&$AA=$AA", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "T4: Non-zero result");

    // Test 5: AND with complement (should give zero)
    $display("\n--- Test 5: AND with complement ---");
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // LDI C, #$55
    inspect_register(uut.u_cpu.c_out, 8'h55, "T5: C=$55", DATA_WIDTH);
    
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // ANA C
    inspect_register(uut.u_cpu.a_out, 8'h00, "T5: A=$AA&$55=$00", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "T5: Zero result");

    // Test 6: Negative flag test
    $display("\n--- Test 6: Negative flag test ---");
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // LDI A, #$80
    inspect_register(uut.u_cpu.a_out, 8'h80, "T6: A=$80", DATA_WIDTH);
    
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // LDI C, #$FF
    inspect_register(uut.u_cpu.c_out, 8'hFF, "T6: C=$FF", DATA_WIDTH);
    
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // ANA C
    inspect_register(uut.u_cpu.a_out, 8'h80, "T6: A=$80&$FF=$80", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "T6: Negative flag set");

    // Test 7: Clear high bit
    $display("\n--- Test 7: Clear high bit ---");
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // LDI C, #$7F
    inspect_register(uut.u_cpu.c_out, 8'h7F, "T7: C=$7F", DATA_WIDTH);
    
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // ANA C
    inspect_register(uut.u_cpu.a_out, 8'h00, "T7: A=$80&$7F=$00", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "T7: Negative cleared");

    // Test 8: Pattern isolation
    $display("\n--- Test 8: Pattern isolation ---");
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // LDI A, #$F0
    inspect_register(uut.u_cpu.a_out, 8'hF0, "T8: A=$F0", DATA_WIDTH);
    
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // LDI C, #$0F
    inspect_register(uut.u_cpu.c_out, 8'h0F, "T8: C=$0F", DATA_WIDTH);
    
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // ANA C
    inspect_register(uut.u_cpu.a_out, 8'h00, "T8: A=$F0&$0F=$00", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "T8: No bit overlap");

    // Test 9: Single bit isolation
    $display("\n--- Test 9: Single bit isolation ---");
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // LDI A, #$FF
    inspect_register(uut.u_cpu.a_out, 8'hFF, "T9: A=$FF", DATA_WIDTH);
    
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // LDI C, #$01
    inspect_register(uut.u_cpu.c_out, 8'h01, "T9: C=$01", DATA_WIDTH);
    
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // ANA C
    inspect_register(uut.u_cpu.a_out, 8'h01, "T9: A=$FF&$01=$01", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "T9: Bit 0 isolated");

    // Test 10: Register preservation test
    $display("\n--- Test 10: Register preservation ---");
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // LDI B, #$42
    inspect_register(uut.u_cpu.b_out, 8'h42, "T10: B=$42", DATA_WIDTH);
    
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // LDI A, #$3C
    inspect_register(uut.u_cpu.a_out, 8'h3C, "T10: A=$3C", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h42, "T10: B preserved", DATA_WIDTH);
    
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // LDI C, #$C3
    inspect_register(uut.u_cpu.c_out, 8'hC3, "T10: C=$C3", DATA_WIDTH);
    
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // ANA C
    inspect_register(uut.u_cpu.a_out, 8'h00, "T10: A=$3C&$C3=$00", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h42, "T10: B still preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hC3, "T10: C unchanged by ANA", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "T10: Final zero result");
    
    $display("\n--- Verifying CPU halt ---");
    run_until_halt(50); // Increased timeout for more instructions
    
    // Vizual buffer for waveform inspection
    repeat(2) @(posedge clk);

    $display("ANA_C test finished.===========================\n\n");
    $finish;
    // ============================ END TEST ==============================
  
  end

endmodule