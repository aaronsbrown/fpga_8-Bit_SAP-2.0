`timescale 1ns/1ps
import test_utils_pkg::*; 
import arch_defs_pkg::*;  

module computer_tb;

  localparam string HEX_FILE = "../hardware/test/fixtures_manual/NOP_prog.hex";

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
    $display("\n\nRunning NOP instruction test");

    // NOP ============================================
    $display("\nNOP ============");

    $display("BYTE 1");
    repeat (4+1) @(posedge clk);  #0.1; // subtract previous latch cycle
    pretty_print_assert_vec(uut.u_cpu.opcode, NOP, "CHK_MORE_BYTES: cpu.opcode == NOP"); 

    repeat (1) @(posedge clk); #0.1; 

    repeat (4) @(posedge clk); #0.1; 
    pretty_print_assert_vec(uut.u_cpu.u_control_unit.opcode, HLT, "HALT: cpu.opcode == HLT"); 
    pretty_print_assert_vec(uut.u_cpu.counter_out, 16'hF002, "HALT: cpu.counter_out == xF002"); 

    // run_until_halt(50); 
    
    $display("NOP test finished.===========================\n\n");
    $finish;
  end

endmodule