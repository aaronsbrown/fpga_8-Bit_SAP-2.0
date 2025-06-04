`timescale 1ns/1ps
import test_utils_pkg::*; 
import arch_defs_pkg::*;  

module computer_tb;

  localparam string HEX_FILE = "../hardware/test/fixtures_manual/op_INR_B_prog.hex";

  reg clk;
  reg reset;
  
  computer uut (
        .clk(clk),
        .reset(reset),
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

    // load the hex file into RAM
    $display("--- Loading hex file: %s ---", HEX_FILE);
    safe_readmemh_rom(HEX_FILE);  
    uut.u_rom.dump(); 

    // Apply reset and wait for it to release
    reset_and_wait(0); 

    // --- Execute the instruction ---
    $display("\n\nRunning INR_B instruction test");

    // LDI_A 01 ============================================
    $display("\nLDI_B ============");
    
    $display("BYTE 1");
    repeat (1 + 4) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.opcode, LDI_B, "CHK_MORE_BYTES: cpu.opcode == LDI_B"); 

    $display("BYTE 2");
    repeat (4) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.temp_1_out, 8'h01, "EXECUTE: cpu.temp_1_out = x01"); 

    $display("POST_EXECUTE"); // microsteps + latch cycle
    repeat (1 + 1) @(posedge clk);  #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h01, "Register B", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "cpu.flag_zero_o == 0"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "cpu.flag_negative_o == 0"); 

    // INR_B ============================================
    $display("\nINR_B ============");

    $display("BYTE 1");
    repeat (4 - 1) @(posedge clk);  #0.1; // subtract previous latch cycle
    pretty_print_assert_vec(uut.u_cpu.opcode, INR_B, "CHK_MORE_BYTES: cpu.opcode == INR_B"); 
    
    $display("POST_EXECUTION");
    repeat (2+1) @(posedge clk);  #0.1; // microsteps + latch cycle
    inspect_register(uut.u_cpu.b_out, 8'h02, "Register B", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "cpu.flag_zero_o == 0"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "cpu.flag_negative_o == 0");  
  
    repeat (3) @(posedge clk); #0.1; 
    pretty_print_assert_vec(uut.u_cpu.u_control_unit.opcode, HLT, "HALT: cpu.opcode == HLT"); 
    pretty_print_assert_vec(uut.u_cpu.counter_out, 16'hF004, "HALT: cpu.counter_out == xF004"); 

    run_until_halt(100);

    $display("INR_B test finished.===========================\n\n");
    $finish;
  end

endmodule