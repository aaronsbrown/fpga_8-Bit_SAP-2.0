`timescale 1ns/1ps
import test_utils_pkg::*;
import arch_defs_pkg::*;

module computer_tb; // Renamed module to avoid conflict if needed

  localparam string HEX_FILE = "../fixture/JN.hex"; // Use the new hex file
  localparam EXPECTED_FINAL_OUTPUT = 8'h05; // Success code

  // --- Standard Testbench Setup ---
  reg clk;
  reg reset;
  wire [DATA_WIDTH-1:0] out_val;
  wire flag_zero_o, flag_carry_o, flag_negative_o;

  computer uut ( // Instantiate the top-level 'computer'
        .clk(clk),
        .reset(reset),
        .register_OUT(out_val), // Connect to the final output port of 'computer'
        .cpu_flag_zero_o(flag_zero_o),
        .cpu_flag_carry_o(flag_carry_o),
        .cpu_flag_negative_o(flag_negative_o)
  );

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end
  // --- End Standard Setup ---

  // Testbench stimulus
  initial begin

    $dumpfile("waveform.vcd");
    $dumpvars(0, computer_tb); // Dump all signals in this testbench module

    $display("--- Loading hex file: %s ---", HEX_FILE);
    $readmemh(HEX_FILE, uut.u_ram.mem); // Access RAM via uut.u_ram
    uut.u_ram.dump();

    reset_and_wait(0); // Apply reset

    // --- Execute LDI #8 (Addr 0, Ends Cycle 7) ---
    $display("Running LDI #8 (Sets N=1)");
    repeat(7+1) @(posedge clk); // Wait until after state settles
    #0.1;
    inspect_register(uut.u_cpu.u_register_A.latched_data, 8'h08, "After LDI #8: A", DATA_WIDTH);
    pretty_print_assert_vec(flag_negative_o, 1'b1, "After LDI #8: N Flag");
    inspect_register(uut.u_cpu.u_program_counter.counter_out, 8'h01, "After LDI #8: PC", ADDR_WIDTH);

    // --- Execute JN 0x6 (Addr 1, Ends Cycle 14) ---
    $display("Running JN 0x6 (Should Jump because N=1)");
    repeat(7) @(posedge clk);
    #0.1;
    inspect_register(uut.u_cpu.u_program_counter.counter_out, 8'h06, "After JN 0x6: PC (Jump Taken)", ADDR_WIDTH); // PC is now 0x6
    inspect_register(uut.u_cpu.u_register_A.latched_data, 8'h08, "After JN 0x6: A (Unchanged)", DATA_WIDTH);
    pretty_print_assert_vec(flag_negative_o, 1'b1, "After JN 0x6: N Flag (Unchanged)");

    // --- Execute LDI #4 (Addr 6, Ends Cycle 21) ---
    $display("Running LDI #4 (Sets N=0)");
    repeat(7) @(posedge clk);
    #0.1;
    inspect_register(uut.u_cpu.u_register_A.latched_data, 8'h04, "After LDI #4: A", DATA_WIDTH);
    pretty_print_assert_vec(flag_negative_o, 1'b0, "After LDI #4: N Flag"); // N is now 0
    inspect_register(uut.u_cpu.u_program_counter.counter_out, 8'h07, "After LDI #4: PC", ADDR_WIDTH);

    // --- Execute JN 0xC (Addr 7, Ends Cycle 28) ---
    $display("Running JN 0xC (Should NOT Jump because N=0)");
    repeat(7) @(posedge clk);
    #0.1;
    inspect_register(uut.u_cpu.u_program_counter.counter_out, 8'h08, "After JN 0xC: PC (No Jump)", ADDR_WIDTH); // PC increments normally to 0x8
    inspect_register(uut.u_cpu.u_register_A.latched_data, 8'h04, "After JN 0xC: A (Unchanged)", DATA_WIDTH);
    pretty_print_assert_vec(flag_negative_o, 1'b0, "After JN 0xC: N Flag (Unchanged)");

    // --- Execute LDI #5 (Addr 8, Ends Cycle 35) ---
    $display("Running LDI #5 (Success value)");
    repeat(7) @(posedge clk);
    #0.1;
    inspect_register(uut.u_cpu.u_register_A.latched_data, 8'h05, "After LDI #5: A", DATA_WIDTH);
    pretty_print_assert_vec(flag_negative_o, 1'b0, "After LDI #5: N Flag");
    inspect_register(uut.u_cpu.u_program_counter.counter_out, 8'h09, "After LDI #5: PC", ADDR_WIDTH);

    // --- Execute OUTA (Addr 9, Ends Cycle 42) ---
    $display("Running OUTA");
    repeat(7) @(posedge clk);
    #0.1;
    // Check the final output register, connected via 'out_val' wire
    inspect_register(out_val, EXPECTED_FINAL_OUTPUT, "After OUTA: Output Register O", DATA_WIDTH);
    inspect_register(uut.u_cpu.u_program_counter.counter_out, 8'h0A, "After OUTA: PC", ADDR_WIDTH);

    // --- Execute HLT (Addr A, Ends Cycle 49) ---
    $display("Running HLT");
    // Use run_until_halt, but provide path to halt signal inside cpu core
    run_until_halt(50); // Assuming halt is output/accessible

    // --- Final Checks After Halt ---
    #0.1; $display("@%0t: Checking state after Halt", $time);
    pretty_print_assert_vec(uut.u_cpu.halt, 1'b1, "Halt signal active"); // Check internal halt signal
    inspect_register(uut.u_cpu.u_program_counter.counter_out, 8'h0B, "Final PC", ADDR_WIDTH); // PC increments during HLT fetch
    inspect_register(uut.u_cpu.u_register_A.latched_data, 8'h05, "Final Register A", DATA_WIDTH);
    inspect_register(out_val, EXPECTED_FINAL_OUTPUT, "Final Output Register O", DATA_WIDTH);

    $display("\033[0;32mJN instruction test (Revised) completed successfully.\033[0m");
    $finish;
  end
endmodule