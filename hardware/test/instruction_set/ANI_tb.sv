`timescale 1ns/1ps
import test_utils_pkg::*; 
import arch_defs_pkg::*;  

module computer_tb;

  localparam string HEX_FILE = "../hardware/test/fixtures_manual/op_ANI_prog.hex";

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
    $display("\n\nRunning ANI instruction test");

    // LDI A
    $display("BYTE 1");
    repeat (1 + 4) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.opcode, LDI_A, "CHK_MORE_BYTES: cpu.opcode == LDI_A"); 

    $display("BYTE 2");
    repeat (4) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.temp_1_out, 16'hAA, "CHK_MORE_BYTES: cpu.temp_1_out = xAA"); 

    $display("POST_EXECUTION");
    repeat (1 + 1) @(posedge clk);  #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hAA, "Register A", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "cpu.flag_zero_o == 0"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "cpu.flag_negative_o == 1");  
  
    // ANI
    $display("BYTE 1");
    repeat (4 - 1) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.opcode, ANI, "CHK_MORE_BYTES: cpu.opcode == ANI"); 

    $display("BYTE 2");
    repeat (4) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.temp_1_out, 16'hF0, "CHK_MORE_BYTES: cpu.temp_1_out = xF0"); 

    $display("POST_EXECUTION");
    repeat (2 + 1) @(posedge clk);  #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hA0, "Register A", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "cpu.flag_zero_o == 0"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "cpu.flag_negative_o == 1");  
  
    repeat (3) @(posedge clk); #0.1; 
    pretty_print_assert_vec(uut.u_cpu.u_control_unit.opcode, HLT, "HALT: cpu.opcode == HLT"); 
    pretty_print_assert_vec(uut.u_cpu.counter_out, 16'hF005, "HALT: cpu.counter_out == xF005"); 

    run_until_halt(20);

    $display("ANI test finished.===========================\n\n");
    $finish;
  end

endmodule