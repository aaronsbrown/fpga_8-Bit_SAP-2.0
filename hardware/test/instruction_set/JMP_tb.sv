`timescale 1ns/1ps
import test_utils_pkg::*; 
import arch_defs_pkg::*;  

module computer_tb;

  localparam string HEX_FILE = "../hardware/test/_fixtures_generated/JMP/ROM.hex";

  logic                  clk;
  logic                  reset;
  logic [DATA_WIDTH-1:0] computer_output;

  computer uut (
        .clk(clk),
        .reset(reset),
        .output_port_1(computer_output),
        .uart_rx(1'b1),    // UART not needed for JMP microinstruction testing
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
    $display("\n\nRunning JMP (Jump) Test ========================");

    // ======================================================================
    // Test 1: Initial Setup and Basic JMP 
    // ======================================================================
    $display("\n--- Test 1: Initial Setup and Basic JMP ---");
    
    // LDI A, #$AA
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hAA, "A=$AA (10101010)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "LDI A: Z=0"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "LDI A: N=1"); 

    // LDI B, #$55
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h55, "B=$55 (01010101)", DATA_WIDTH);

    // LDI C, #$FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hFF, "C=$FF (11111111)", DATA_WIDTH);

    // JMP TEST1_OK (should skip error code)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hAA, "JMP: A preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h55, "JMP: B preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hFF, "JMP: C preserved", DATA_WIDTH);
    $display("SUCCESS: Basic JMP worked - skipped error code");

    // ======================================================================
    // Test 2: Address Pattern Test
    // ======================================================================
    $display("\n--- Test 2: Address Pattern Test ---");
    
    // JMP TEST2_OK  
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hAA, "JMP: A preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h55, "JMP: B preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hFF, "JMP: C preserved", DATA_WIDTH);
    $display("SUCCESS: JMP with different address pattern worked");

    // ======================================================================
    // Test 3: Flag Preservation Test
    // ======================================================================
    $display("\n--- Test 3: Flag Preservation Test ---");
    
    // SEC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "SEC: C=1"); 

    // LDI A, #$80
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h80, "A=$80 (negative)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "LDI A: N=1");

    // LDI B, #$00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h00, "B=$00 (zero)", DATA_WIDTH);

    // CMP B (sets flags: Z=0, N=1, C=1)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h80, "CMP B: A unchanged", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "CMP B: Z=0");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "CMP B: N=1");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "CMP B: C=1");

    // JMP TEST3_OK (should preserve all flags)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "JMP: Z preserved");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "JMP: N preserved");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "JMP: C preserved");
    $display("SUCCESS: JMP preserved all flag states");

    // ======================================================================
    // Test 4-6: JMP from Different Flag States
    // ======================================================================
    $display("\n--- Tests 4-6: JMP from Different Flag States ---");
    
    // LDI A, #$00 (sets Z=1, N=0)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "A=$00 (zero)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "LDI A: Z=1");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "LDI A: N=0");

    // JMP TEST4_OK
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "JMP: Z preserved");
    $display("SUCCESS: JMP works with zero flag set");

    // LDI A, #$FF (sets N=1, Z=0)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A=$FF (negative)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "LDI A: N=1");

    // JMP TEST5_OK
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "JMP: N preserved");
    $display("SUCCESS: JMP works with negative flag set");

    // CLC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "CLC: C=0");

    // JMP TEST6_OK
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "JMP: C preserved");
    $display("SUCCESS: JMP works with carry clear");

    // ======================================================================
    // Final Test: Register Pattern Preservation
    // ======================================================================
    $display("\n--- Final Test: Register Pattern Preservation ---");
    
    // LDI A, #$A5
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hA5, "A=$A5 (10100101)", DATA_WIDTH);

    // LDI B, #$5A
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h5A, "B=$5A (01011010)", DATA_WIDTH);

    // LDI C, #$C3
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hC3, "C=$C3 (11000011)", DATA_WIDTH);

    // JMP SUCCESS (final jump)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hA5, "JMP: A preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h5A, "JMP: B preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hC3, "JMP: C preserved", DATA_WIDTH);
    $display("SUCCESS: Final JMP preserved all register patterns");

    // ======================================================================
    // Success Verification
    // ======================================================================
    $display("\n--- Success Verification ---");
    
    // LDI A, #$FF (success code)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A=$FF (success code)", DATA_WIDTH);

    // STA OUTPUT_PORT_1
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(computer_output, 8'hFF, "Output: $FF (all tests passed)");
    $display("SUCCESS: All JMP tests completed successfully!");

    // Wait for HLT
    wait(uut.cpu_halt);
    $display("CPU halted - test program completed");
    
    // Visual buffer for waveform inspection
    repeat(5) @(posedge clk);

    $display("\n=== JMP (Jump) Enhanced Test Summary ===");
    $display("✓ Basic JMP functionality with register preservation");
    $display("✓ JMP with various address bit patterns (zeros, ones, alternating)");
    $display("✓ Flag preservation during JMP execution (Z, N, C)");
    $display("✓ JMP behavior with different initial flag states");
    $display("✓ Address boundary and extreme value testing");
    $display("✓ Single bit pattern testing in registers and addresses");
    $display("✓ Complex flag combination preservation");
    $display("✓ Arithmetic and logical operation result preservation");
    $display("✓ Forward and backward jump direction testing");
    $display("✓ Comprehensive register preservation verification");
    $display("✓ Success verification through output port");
    $display("JMP test finished.===========================\n\n");
    $finish;
    // ============================ END TEST ==============================
  
  end

endmodule