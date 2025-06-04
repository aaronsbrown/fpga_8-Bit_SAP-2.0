`timescale 1ns/1ps
import test_utils_pkg::*; 
import arch_defs_pkg::*;  

module computer_tb;

  localparam string HEX_FILE = "../hardware/test/fixtures_generated/JZ_pos/ROM.hex";

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
    uut.u_rom.init_sim_rom();

    // load the hex file into RAM
    $display("--- Loading hex file: %s ---", HEX_FILE);
    safe_readmemh_rom(HEX_FILE);  
    uut.u_rom.dump(); 

    // Apply reset and wait for it to release
    reset_and_wait(0); 

    // --- Execute the instruction ---
    $display("\n\nRunning JZ instruction test: Positive Case");

    // LDI_A FF============================================
    $display("\nLDI_A FF ============");
    
    $display("BYTE 1");
    repeat (1 + 4) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.opcode, LDI_A, "CHK_MORE_BYTES: cpu.opcode == LDI_A"); 

    $display("BYTE 2");
    repeat (4) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.temp_1_out, 8'hFF, "EXECUTE: cpu.temp_1_out = xFF"); 

    $display("POST_EXECUTE");
    repeat (1 + 1) @(posedge clk);  #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "Register A", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "cpu.flag_zero_o == 0"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "cpu.flag_negative_o == 1"); 

    // LDI_A 00 ============================================
    $display("\nLDI_A 00 ============");
    
    $display("BYTE 1");
    repeat (3) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.opcode, LDI_A, "CHK_MORE_BYTES: cpu.opcode == LDI_A"); 

    $display("BYTE 2");
    repeat (4) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.temp_1_out, 8'h00, "EXECUTE: cpu.temp_1_out = x00"); 

    $display("POST_EXECUTE");
    repeat (1 + 1) @(posedge clk);  #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "Register A", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "cpu.flag_zero_o == 1"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "cpu.flag_negative_o == 0");  


    // JZ ============================================
    $display("\nJZ ============");
    
    $display("BYTE 1");
    repeat (3) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.opcode, JZ, "CHK_MORE_BYTES: cpu.opcode == JZ"); 

    $display("BYTE 2");
    repeat (4) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.temp_1_out, 8'h09, "CHK_MORE_BYTES: cpu.temp_1_out = x09"); 

    $display("BYTE 3");
    repeat (4) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.temp_2_out, 8'hF0, "CHK_MORE_BYTES: cpu.temp_2_out = xF0"); 
    pretty_print_assert_vec(uut.u_cpu.counter_out, 16'hF007, "CHK_MORE_BYTES: cpu.counter_out = xF007"); 

    $display("POST_EXECUTE");
    repeat (2) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.counter_out, 16'hF009, "cpu.counter_out = xF009"); 
  
    // LDI_A 22 ============================================
    $display("\nLDI_A 22 ============");
    
    $display("BYTE 1");
    repeat (4) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.opcode, LDI_A, "CHK_MORE_BYTES: cpu.opcode == LDI_A"); 

    $display("BYTE 2");
    repeat (4) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.temp_1_out, 8'h22, "EXECUTE: cpu.temp_1_out = x22"); 

    $display("POST_EXECUTE");
    repeat (1 + 1) @(posedge clk);  #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h22, "Register A", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "cpu.flag_zero_o == 0"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "cpu.flag_negative_o == 0");

    $display("\nHLT ============"); 
    repeat (3) @(posedge clk); #0.1; 
    pretty_print_assert_vec(uut.u_cpu.u_control_unit.opcode, HLT, "HALT: cpu.opcode == HLT"); 
    pretty_print_assert_vec(uut.u_cpu.counter_out, 16'hF00C, "HALT: cpu.counter_out == xF00C"); 
    inspect_register(uut.u_cpu.a_out, 8'h22, "Register A", DATA_WIDTH);
    
    run_until_halt(100);

    $display("JZ test finished.===========================\n\n");
    $finish;
  end

endmodule