`timescale 1ns/1ps
import test_utils_pkg::*; 
import arch_defs_pkg::*;  

module computer_tb;

  localparam string HEX_FILE = "../hardware/test/fixtures_generated/JZ_neg/ROM.hex";

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
    $readmemh(HEX_FILE, uut.u_rom.mem); 
    uut.u_rom.dump(); 

    // Apply reset and wait for it to release
    reset_and_wait(0); 

    // --- Execute the instruction ---
    $display("\n\nRunning JZ (neg condition) instruction test");

    // LDI_A 00============================================
    $display("\nLDI_A 00 ============");
    
    $display("BYTE 1");
    repeat (1 + 4) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.opcode, LDI_A, "CHK_MORE_BYTES: cpu.opcode == LDI_A"); 

    $display("BYTE 2");
    repeat (4) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.temp_1_out, 8'h00, "EXECUTE: cpu.temp_1_out = x00"); 

    $display("POST_EXECUTE");
    repeat (1 + 1) @(posedge clk);  #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "Register A", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "cpu.flag_zero_o == 1"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "cpu.flag_negative_o == 0"); 

    // LDI_A 0F ============================================
    $display("\nLDI_A 0F ============");
    
    $display("BYTE 1");
    repeat (3) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.opcode, LDI_A, "CHK_MORE_BYTES: cpu.opcode == LDI_A"); 

    $display("BYTE 2");
    repeat (4) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.temp_1_out, 8'h0F, "EXECUTE: cpu.temp_1_out = x0F"); 

    $display("POST_EXECUTE");
    repeat (1 + 1) @(posedge clk);  #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h0F, "Register A", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "cpu.flag_zero_o == 0"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "cpu.flag_negative_o == 0");  


    // JZ ============================================
    $display("\nJZ ============");
    
    $display("BYTE 1");
    repeat (3) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.opcode, JZ, "CHK_MORE_BYTES: cpu.opcode == JZ"); 

    $display("BYTE 2");
    repeat (4) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.temp_1_out, 8'h0C, "CHK_MORE_BYTES: cpu.temp_1_out = x0C"); 

    $display("BYTE 3");
    repeat (4) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.temp_2_out, 8'hF0, "CHK_MORE_BYTES: cpu.temp_2_out = xF0"); 
    pretty_print_assert_vec(uut.u_cpu.counter_out, 16'hF007, "CHK_MORE_BYTES: cpu.counter_out = xF007"); 

    $display("POST_EXECUTE");
    repeat (2) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.counter_out, 16'hF007, "cpu.counter_out = xF007"); 
  
    // LDI_A 11 ============================================
    $display("\nLDI_A 11 ============");
    
    $display("BYTE 1");
    repeat (4) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.opcode, LDI_A, "CHK_MORE_BYTES: cpu.opcode == LDI_A"); 

    $display("BYTE 2");
    repeat (4) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.temp_1_out, 8'h11, "EXECUTE: cpu.temp_1_out = x11"); 

    $display("POST_EXECUTE");
    repeat (1 + 1) @(posedge clk);  #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h11, "Register A", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "cpu.flag_zero_o == 0"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "cpu.flag_negative_o == 0");

    // JMP ============================================
    $display("\nJMP ============");
    
    $display("BYTE 1");
    repeat (3) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.opcode, JMP, "CHK_MORE_BYTES: cpu.opcode == JMP"); 

    $display("BYTE 2");
    repeat (4) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.temp_1_out, 8'h0E, "CHK_MORE_BYTES: cpu.temp_1_out = x0E"); 

    $display("BYTE 3");
    repeat (4) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.temp_2_out, 8'hF0, "CHK_MORE_BYTES: cpu.temp_2_out = xF0"); 
    pretty_print_assert_vec(uut.u_cpu.counter_out, 16'hF00E, "CHK_MORE_BYTES: cpu.counter_out = xF00E"); 

    $display("POST_EXECUTE");
    repeat (2) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.counter_out, 16'hF00E, "cpu.counter_out = xF00E"); 
  
    // HLT ============================================
    $display("\nHLT ============"); 
    repeat (3) @(posedge clk); #0.1; 
    pretty_print_assert_vec(uut.u_cpu.u_control_unit.opcode, HLT, "HALT: cpu.opcode == HLT"); 
    pretty_print_assert_vec(uut.u_cpu.counter_out, 16'hF00F, "HALT: cpu.counter_out == xF00F"); 
    inspect_register(uut.u_cpu.a_out, 8'h11, "Register A", DATA_WIDTH);
    
    run_until_halt(10);

    $display("JZ test finished.===========================\n\n");
    $finish;
  end

endmodule