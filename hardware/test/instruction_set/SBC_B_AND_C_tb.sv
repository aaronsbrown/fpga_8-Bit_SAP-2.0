`timescale 1ns/1ps
import test_utils_pkg::*; 
import arch_defs_pkg::*;  

module computer_tb;

  localparam string HEX_FILE = "../hardware/test/fixtures_manual/op_SBC_B_AND_C_prog.hex";

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
    $display("\n\nRunning ADD_C instruction test");

    // LDI_A FF ============================================
    $display("\nLDI_A ============");
    
    $display("BYTE 1");
    repeat (1 + 4) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.opcode, LDI_A, "CHK_MORE_BYTES: cpu.opcode == LDI_A"); 

    $display("BYTE 2");
    repeat (4) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.temp_1_out, 8'h01, "EXECUTE: cpu.temp_1_out = x00"); 

    $display("POST_EXECUTE"); // microsteps + latch cycle
    repeat (1 + 1) @(posedge clk);  #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h01, "Register A", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "cpu.flag_zero_o == 0"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "cpu.flag_negative_o == 0"); 

    // LDI_B 01 ============================================
    $display("\nLDI_B ============");
    
    $display("BYTE 1");
    repeat (4 - 1) @(posedge clk);  #0.1; // subtract previous latch cycle
    pretty_print_assert_vec(uut.u_cpu.opcode, LDI_B, "CHK_MORE_BYTES: cpu.opcode == LDI_B"); 

    $display("BYTE 2");
    repeat (4) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.temp_1_out, 8'h01, "EXECUTE: cpu.temp_1_out = x01"); 

    $display("POST_EXECUTE"); // microsteps + latch cycle 
    repeat (1 + 1) @(posedge clk);  #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h01, "Register B", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "cpu.flag_zero_o == 0"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "cpu.flag_negative_o == 0"); 

    // LDI_C 01 ============================================
    $display("\nLDI_C ============");
    
    $display("BYTE 1");
    repeat (4 - 1) @(posedge clk);  #0.1; // subtract previous latch cycle
    pretty_print_assert_vec(uut.u_cpu.opcode, LDI_C, "CHK_MORE_BYTES: cpu.opcode == LDI_C"); 

    $display("BYTE 2");
    repeat (4) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.temp_1_out, 8'hFE, "EXECUTE: cpu.temp_1_out = xFE"); 

    $display("POST_EXECUTE"); // microsteps + latch cycle 
    repeat (1 + 1) @(posedge clk);  #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hFE, "Register C", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "cpu.flag_zero_o == 0"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "cpu.flag_negative_o == 1"); 

    // DCR_A ============================================
    $display("\nDCR_A ============");

    $display("BYTE 1");
    repeat (4 - 1) @(posedge clk);  #0.1; // subtract previous latch cycle
    pretty_print_assert_vec(uut.u_cpu.opcode, SUB_B, "CHK_MORE_BYTES: cpu.opcode == SUB_B"); 
    
    $display("POST_EXECUTION");
    repeat (2+1) @(posedge clk);  #0.1; // microsteps + latch cycle
    inspect_register(uut.u_cpu.a_out, 8'h00, "Register A", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "cpu.flag_zero_o == 1"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "cpu.flag_negative_o == 0");  

    // SBC_B ============================================
    $display("\nSBC_B ============");

    $display("BYTE 1");
    repeat (4 - 1) @(posedge clk);  #0.1; // subtract previous latch cycle
    pretty_print_assert_vec(uut.u_cpu.opcode, SBC_B, "CHK_MORE_BYTES: cpu.opcode == SBC_B"); 
    
    $display("POST_EXECUTION");
    repeat (3+1) @(posedge clk);  #0.1; // microsteps + latch cycle
    inspect_register(uut.u_cpu.a_out, 8'hFF, "Register A", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "cpu.flag_carry_o == 0"); 
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "cpu.flag_zero_o == 0"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "cpu.flag_negative_o == 1");  
  

    // SBC_C ============================================
    $display("\nSBC_C ============");

    $display("BYTE 1");
    repeat (4 - 1) @(posedge clk);  #0.1; // subtract previous latch cycle
    pretty_print_assert_vec(uut.u_cpu.opcode, SBC_C, "CHK_MORE_BYTES: cpu.opcode == SBC_C"); 
    
    $display("POST_EXECUTION");
    repeat (3+1) @(posedge clk);  #0.1; // microsteps + latch cycle
    inspect_register(uut.u_cpu.a_out, 8'h00, "Register A", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "cpu.flag_carry_o == 1"); 
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "cpu.flag_zero_o == 1"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "cpu.flag_negative_o == 0");  

    repeat (3) @(posedge clk); #0.1; 
    pretty_print_assert_vec(uut.u_cpu.u_control_unit.opcode, HLT, "HALT: cpu.opcode == HLT"); 
    pretty_print_assert_vec(uut.u_cpu.counter_out, 16'hF00a, "HALT: cpu.counter_out == xF00a"); 

    $display("ADD_C test finished.===========================\n\n");
    $finish;
  end

endmodule