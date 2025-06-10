`timescale 1ns/1ps
import test_utils_pkg::*; 
import arch_defs_pkg::*;  

module computer_tb;

  localparam string HEX_FILE = "../hardware/test/_fixtures_generated/SEC/ROM.hex";

  logic                  clk;
  logic                  reset;
  logic [DATA_WIDTH-1:0] computer_output;

  computer uut (
        .clk(clk),
        .reset(reset),
        .output_port_1(computer_output)
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

    // ============================ BEGIN TEST ==============================
    $display("\n\nRunning SEC (Set Carry) comprehensive test ========================");

    // ================================================================
    // TEST 1: Basic SEC functionality - Carry flag clear to set
    // CLC, LDI A, #$00, SEC
    // ================================================================
    $display("\n--- TEST 1: Basic SEC functionality ---");
    
    // After CLC instruction
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "After CLC: Carry flag cleared");
    
    // After LDI A, #$00 instruction  
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "After LDI A, #$00: Register A", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "After LDI A, #$00: Zero flag set (A=0)"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "After LDI A, #$00: Negative flag clear (A>=0)");  
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "After LDI A, #$00: Carry flag unchanged");
    
    // After SEC instruction
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "After SEC: Register A unchanged", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "After SEC: Carry flag set");
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "After SEC: Zero flag unchanged"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "After SEC: Negative flag unchanged");

    // ================================================================
    // TEST 2: SEC with different accumulator values ($FF)
    // LDI A, #$FF, SEC
    // ================================================================
    $display("\n--- TEST 2: SEC with accumulator = $FF ---");
    
    // After LDI A, #$FF instruction
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "After LDI A, #$FF: Register A", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "After LDI A, #$FF: Zero flag clear (A≠0)"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "After LDI A, #$FF: Negative flag set (A<0)");  
    
    // After SEC instruction
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "After SEC: Register A unchanged ($FF)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "After SEC: Carry flag set");
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "After SEC: Zero flag unchanged"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "After SEC: Negative flag unchanged");

    // ================================================================
    // TEST 3: SEC with positive value ($7F)
    // LDI A, #$7F, SEC
    // ================================================================
    $display("\n--- TEST 3: SEC with accumulator = $7F ---");
    
    // After LDI A, #$7F instruction
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h7F, "After LDI A, #$7F: Register A", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "After LDI A, #$7F: Zero flag clear (A≠0)"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "After LDI A, #$7F: Negative flag clear (A>=0)");  
    
    // After SEC instruction
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h7F, "After SEC: Register A unchanged ($7F)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "After SEC: Carry flag set");
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "After SEC: Zero flag unchanged"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "After SEC: Negative flag unchanged");

    // ================================================================
    // TEST 4: SEC when carry already set
    // SEC (carry already 1)
    // ================================================================
    $display("\n--- TEST 4: SEC when carry already set ---");
    
    // After SEC instruction (carry already set)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h7F, "After SEC: Register A unchanged ($7F)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "After SEC: Carry flag remains set");
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "After SEC: Zero flag unchanged"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "After SEC: Negative flag unchanged");

    // ================================================================
    // TEST 5: Toggle behavior - CLC then SEC
    // CLC, SEC  
    // ================================================================
    $display("\n--- TEST 5: Toggle behavior (CLC then SEC) ---");
    
    // After CLC instruction
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "After CLC: Carry flag cleared");
    
    // After SEC instruction
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h7F, "After SEC: Register A unchanged ($7F)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "After SEC: Carry flag set");
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "After SEC: Zero flag unchanged"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "After SEC: Negative flag unchanged");

    // ================================================================
    // TEST 6: Register preservation test
    // LDI B, #$AA, LDI C, #$55, LDI A, #$33, SEC
    // ================================================================
    $display("\n--- TEST 6: Register preservation test ---");
    
    // After LDI B, #$AA
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'hAA, "After LDI B, #$AA: Register B", DATA_WIDTH);
    
    // After LDI C, #$55
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h55, "After LDI C, #$55: Register C", DATA_WIDTH);
    
    // After LDI A, #$33
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h33, "After LDI A, #$33: Register A", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "After LDI A, #$33: Zero flag clear (A≠0)"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "After LDI A, #$33: Negative flag clear (A>=0)");  
    
    // After SEC instruction - verify all registers preserved
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h33, "After SEC: Register A preserved ($33)", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'hAA, "After SEC: Register B preserved ($AA)", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'h55, "After SEC: Register C preserved ($55)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "After SEC: Carry flag set");
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "After SEC: Zero flag unchanged"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "After SEC: Negative flag unchanged");

    // ================================================================
    // TEST 7: SEC with alternating bit pattern ($A5)
    // LDI A, #$A5, SEC
    // ================================================================
    $display("\n--- TEST 7: SEC with alternating pattern ($A5 = 10100101b) ---");
    
    // After LDI A, #$A5
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hA5, "After LDI A, #$A5: Register A", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "After LDI A, #$A5: Zero flag clear (A≠0)"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "After LDI A, #$A5: Negative flag set (A<0)");  
    
    // After SEC instruction
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hA5, "After SEC: Register A unchanged ($A5)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "After SEC: Carry flag set");
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "After SEC: Zero flag unchanged"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "After SEC: Negative flag unchanged");

    // ================================================================
    // TEST 8a: SEC with single bit pattern ($01)
    // LDI A, #$01, SEC
    // ================================================================
    $display("\n--- TEST 8a: SEC with single bit pattern ($01 = 00000001b) ---");
    
    // After LDI A, #$01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h01, "After LDI A, #$01: Register A", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "After LDI A, #$01: Zero flag clear (A≠0)"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "After LDI A, #$01: Negative flag clear (A>=0)");  
    
    // After SEC instruction
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h01, "After SEC: Register A unchanged ($01)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "After SEC: Carry flag set");
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "After SEC: Zero flag unchanged"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "After SEC: Negative flag unchanged");

    // ================================================================
    // TEST 8b: SEC with single bit pattern ($80)
    // LDI A, #$80, SEC
    // ================================================================
    $display("\n--- TEST 8b: SEC with single bit pattern ($80 = 10000000b) ---");
    
    // After LDI A, #$80
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h80, "After LDI A, #$80: Register A", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "After LDI A, #$80: Zero flag clear (A≠0)"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "After LDI A, #$80: Negative flag set (A<0)");  
    
    // After SEC instruction
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h80, "After SEC: Register A unchanged ($80)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "After SEC: Carry flag set");
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "After SEC: Zero flag unchanged"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "After SEC: Negative flag unchanged");

    // ================================================================
    // TEST 9: Final state verification
    // LDI A, #$42, CLC, SEC
    // ================================================================
    $display("\n--- TEST 9: Final state verification ---");
    
    // After LDI A, #$42
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h42, "After LDI A, #$42: Register A", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "After LDI A, #$42: Zero flag clear (A≠0)"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "After LDI A, #$42: Negative flag clear (A>=0)");  
    
    // After CLC instruction
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "After CLC: Carry flag cleared");
    
    // After final SEC instruction
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h42, "After final SEC: Register A unchanged ($42)", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'hAA, "After final SEC: Register B preserved ($AA)", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'h55, "After final SEC: Register C preserved ($55)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "After final SEC: Carry flag set");
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "After final SEC: Zero flag unchanged"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "After final SEC: Negative flag unchanged");

    // ================================================================
    // HALT verification
    // ================================================================
    $display("\n--- HALT verification ---");
    run_until_halt(50);  // Increased timeout for expanded test suite
    $display("CPU successfully halted after comprehensive SEC testing");
    
    // Visual buffer for waveform inspection
    repeat(2) @(posedge clk);

    $display("SEC test finished.===========================\n\n");
    $finish;
    // ============================ END TEST ==============================
  
  end

endmodule