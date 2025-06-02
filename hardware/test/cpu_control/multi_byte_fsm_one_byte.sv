`timescale 1ns/1ps
import test_utils_pkg::*; 
import arch_defs_pkg::*;  

module computer_tb;

  localparam string HEX_FILE = "../hardware/test/fixtures_manual/op_HLT_prog.hex";

  reg clk;
  reg reset;


  computer uut (
        .clk(clk),
        .reset(reset),
    );

  // --- Clock Generation ---
  initial begin
    clk = 0;
    forever #5 clk = ~clk; // 10ns clock period (5ns low, 5ns high)
  end

  // --- Testbench Stimulus ---
  initial begin

    // Setup waveform dumping
    $dumpfile("waveform.vcd");
    $dumpvars(0, computer_tb); // Dump all signals in this module and below

    // Init ram to 00 
    uut.u_ram.init_sim_ram();
    uut.u_rom.init_sim_rom();

    // load the hex file into RAM
    $display("--- Loading hex file: %s ---", HEX_FILE);
    $readmemh(HEX_FILE, uut.u_rom.mem); 
    uut.u_rom.dump(); 

    // Apply reset and wait for it to release
    reset_and_wait(0); 

    // --- Execute the HLT instruction ---
    $display("Running HLT instruction");

    repeat (3) @(posedge clk); // Wait for 20 clock cycles
    #0.1;
    pretty_print_assert_vec(uut.u_cpu.mem_read, 1'b1, "Memory read signal active during S_READ_BYTE");

    repeat (2) @(posedge clk); // Wait for 10 clock cycles
    #0.1; 
    pretty_print_assert_vec(uut.u_cpu.u_register_instr.latched_data, HLT, "OPCODE == HLT during S_READ_BYTE");
    

    repeat (1) @(posedge clk); // Wait for 50 clock cycles
    #0.1;
    pretty_print_assert_vec(uut.cpu_halt, 1'b1, "Halt signal active during S_EXECUTE");
    
    repeat (10) @(posedge clk); // Wait for 10 more clock cycles

    inspect_register(uut.u_cpu.u_program_counter.counter_out, 16'hF001, "PC after HLT", ADDR_WIDTH);
    inspect_register(uut.u_cpu.u_control_unit.current_state, S_HALT, "S_HALT after HLT", 3);
    $display("HLT test finished.===========================\n\n");
    $finish;
  end

endmodule