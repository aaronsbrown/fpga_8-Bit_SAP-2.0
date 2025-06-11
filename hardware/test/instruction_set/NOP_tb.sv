`timescale 1ns/1ps
import test_utils_pkg::*; 
import arch_defs_pkg::*;  

module computer_tb;

  localparam string HEX_FILE = "../hardware/test/_fixtures_generated/NOP/ROM.hex";

  logic                  clk;
  logic                  reset;
  logic [DATA_WIDTH-1:0] computer_output;

  computer uut (
        .clk(clk),
        .reset(reset),
        .output_port_1(computer_output),
        .uart_rx(1'b1),     // UART not used in this test - tie high
        .uart_tx()          // UART not used in this test - leave open
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

    // ============================ BEGIN NOP TESTS ==============================
    $display("\n=== NOP (No Operation) Test Suite ===");
    $display("Testing NOP instruction: should not modify any registers or flags\n");

    // =================================================================
    // TEST 1: Basic NOP with test pattern
    // Assembly: LDI A,#$AA; LDI B,#$55; LDI C,#$FF; SEC; NOP
    // Expected: All registers and flags unchanged after NOP
    // =================================================================
    $display("--- TEST 1: Basic NOP with test pattern ---");
    
    // LDI A, #$AA
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hAA, "A after LDI A, #$AA", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "LDI A: Z=0 (non-zero result)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "LDI A: N=1 (bit 7 set)");

    // LDI B, #$55
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h55, "B after LDI B, #$55", DATA_WIDTH);

    // LDI C, #$FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hFF, "C after LDI C, #$FF", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "LDI C: Z=0 (non-zero result)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "LDI C: N=1 (bit 7 set)");

    // SEC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "SEC: C=1 (carry set)");

    // NOP - should change nothing
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("NOP: Verifying no state changes");
    inspect_register(uut.u_cpu.a_out, 8'hAA, "NOP: A preserved ($AA)", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h55, "NOP: B preserved ($55)", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hFF, "NOP: C preserved ($FF)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "NOP: Z preserved (0)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "NOP: N preserved (1)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "NOP: C preserved (1)");

    // =================================================================
    // TEST 2: NOP with different pattern and flag state
    // Assembly: LDI A,#$00; LDI B,#$42; LDI C,#$84; CLC; NOP
    // Expected: All registers and flags unchanged after NOP
    // =================================================================
    $display("\n--- TEST 2: NOP with different pattern and flag state ---");
    
    // LDI A, #$00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "A after LDI A, #$00", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "LDI A: Z=1 (zero result)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "LDI A: N=0 (bit 7 clear)");

    // LDI B, #$42
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h42, "B after LDI B, #$42", DATA_WIDTH);

    // LDI C, #$84
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h84, "C after LDI C, #$84", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "LDI C: Z=0 (non-zero result)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "LDI C: N=1 (bit 7 set)");

    // CLC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "CLC: C=0 (carry cleared)");

    // NOP - should change nothing
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("NOP: Verifying no state changes");
    inspect_register(uut.u_cpu.a_out, 8'h00, "NOP: A preserved ($00)", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h42, "NOP: B preserved ($42)", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'h84, "NOP: C preserved ($84)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "NOP: Z preserved (0)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "NOP: N preserved (1)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "NOP: C preserved (0)");

    // =================================================================
    // TEST 3: Multiple NOPs in sequence
    // Assembly: LDI A,#$F0; LDI B,#$0F; LDI C,#$77; NOP; NOP; NOP
    // Expected: All registers preserved through multiple NOPs
    // =================================================================
    $display("\n--- TEST 3: Multiple NOPs in sequence ---");
    
    // LDI A, #$F0
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hF0, "A after LDI A, #$F0", DATA_WIDTH);

    // LDI B, #$0F
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h0F, "B after LDI B, #$0F", DATA_WIDTH);

    // LDI C, #$77
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h77, "C after LDI C, #$77", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "LDI C: Z=0 (non-zero result)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "LDI C: N=0 (bit 7 clear)");

    // 1st NOP
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("1st NOP: Verifying no state changes");
    inspect_register(uut.u_cpu.a_out, 8'hF0, "1st NOP: A preserved ($F0)", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h0F, "1st NOP: B preserved ($0F)", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'h77, "1st NOP: C preserved ($77)", DATA_WIDTH);

    // 2nd NOP
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("2nd NOP: Verifying no state changes");
    inspect_register(uut.u_cpu.a_out, 8'hF0, "2nd NOP: A preserved ($F0)", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h0F, "2nd NOP: B preserved ($0F)", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'h77, "2nd NOP: C preserved ($77)", DATA_WIDTH);

    // 3rd NOP
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("3rd NOP: Verifying no state changes");
    inspect_register(uut.u_cpu.a_out, 8'hF0, "3rd NOP: A preserved ($F0)", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h0F, "3rd NOP: B preserved ($0F)", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'h77, "3rd NOP: C preserved ($77)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "3rd NOP: Z preserved (0)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "3rd NOP: N preserved (0)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "3rd NOP: C preserved (0)");

    // =================================================================
    // Final verification - check test completion signal
    // =================================================================
    $display("\n--- Final verification ---");
    
    // LDI A, #$FF (success code)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A=$FF (success code)", DATA_WIDTH);

    // STA OUTPUT_PORT_1
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(computer_output, 8'hFF, "Output: $FF (test success)");

    // =================================================================
    // HALT verification - ensure CPU properly stops
    // =================================================================
    $display("\n--- Verifying HALT instruction ---");
    run_until_halt(50);  // Timeout appropriate for simple test
    $display("CPU halted successfully");
    
    // Visual buffer for waveform inspection
    repeat(5) @(posedge clk);

    $display("NOP test finished.===========================\n\n");
    $display("All NOP test cases passed successfully!");
    $display("- Verified NOP preserves all register values (A, B, C)");
    $display("- Verified NOP preserves all flag states (Z, N, C)");
    $display("- Tested multiple consecutive NOPs");
    $display("- Confirmed NOP performs no operation as expected");
    $finish;
    // ============================ END TEST ==============================
  
  end

endmodule