`timescale 1ns/1ps
import test_utils_pkg::*; 
import arch_defs_pkg::*;  

module computer_tb;

  localparam string HEX_FILE = "../hardware/test/_fixtures_generated/STA/ROM.hex";

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

    // ============================ BEGIN STA COMPREHENSIVE TESTS ==============================
    $display("\n=== STA Comprehensive Test Suite ===");
    $display("Testing STA instruction functionality, edge cases, and flag preservation\n");

    // =================================================================
    // TEST 1: Basic store operation - positive number
    // Assembly: LDI A, #$42; LDI B, #$33; LDI C, #$55; STA $1000
    // Expected: Store A=$42 to address $1000, A/flags unchanged, B/C preserved
    // =================================================================
    $display("--- TEST 1: Basic store operation ($42 to $1000) ---");
    
    // LDI A, #$42
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h42, "A after LDI A, #$42", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z flag clear after LDI A");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N flag clear after LDI A");

    // LDI B, #$33 (preservation test setup)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h33, "B after LDI B, #$33", DATA_WIDTH);

    // LDI C, #$55 (preservation test setup)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h55, "C after LDI C, #$55", DATA_WIDTH);

    // STA $1000: Store A to memory address $1000
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("STA $1000: Store A=$42 to address $1000");
    inspect_register(uut.u_cpu.a_out, 8'h42, "A unchanged after STA", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h33, "B preserved during STA", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'h55, "C preserved during STA", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z flag unchanged by STA");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N flag unchanged by STA");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C flag unchanged by STA");
    // Verify memory content
    pretty_print_assert_vec(uut.u_ram.mem[16'h1000], 8'h42, "Memory[$1000] contains stored value $42");

    // =================================================================
    // TEST 2: Store zero value
    // Assembly: LDI A, #$00; STA $1001
    // Expected: Store A=$00 to address $1001, flags unchanged
    // =================================================================
    $display("\n--- TEST 2: Store zero value ($00 to $1001) ---");
    
    // LDI A, #$00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "A after LDI A, #$00", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "Z=1: zero value loaded");

    // STA $1001: Store A to memory address $1001
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("STA $1001: Store A=$00 to address $1001");
    inspect_register(uut.u_cpu.a_out, 8'h00, "A unchanged after STA", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "Z flag preserved by STA");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N flag unchanged by STA");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C flag unchanged by STA");
    // Verify memory content
    pretty_print_assert_vec(uut.u_ram.mem[16'h1001], 8'h00, "Memory[$1001] contains stored value $00");

    // =================================================================
    // TEST 3: Store negative value (MSB set)
    // Assembly: LDI A, #$80; STA $1002
    // Expected: Store A=$80 to address $1002, flags unchanged
    // =================================================================
    $display("\n--- TEST 3: Store negative value ($80 to $1002) ---");
    
    // LDI A, #$80
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h80, "A after LDI A, #$80", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N=1: negative value loaded");

    // STA $1002: Store A to memory address $1002
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("STA $1002: Store A=$80 to address $1002");
    inspect_register(uut.u_cpu.a_out, 8'h80, "A unchanged after STA", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z flag unchanged by STA");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N flag preserved by STA");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C flag unchanged by STA");
    // Verify memory content
    pretty_print_assert_vec(uut.u_ram.mem[16'h1002], 8'h80, "Memory[$1002] contains stored value $80");

    // =================================================================
    // TEST 4: Store maximum positive value
    // Assembly: LDI A, #$7F; STA $1003
    // Expected: Store A=$7F to address $1003, flags unchanged
    // =================================================================
    $display("\n--- TEST 4: Store maximum positive value ($7F to $1003) ---");
    
    // LDI A, #$7F
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h7F, "A after LDI A, #$7F", DATA_WIDTH);

    // STA $1003: Store A to memory address $1003
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("STA $1003: Store A=$7F to address $1003");
    inspect_register(uut.u_cpu.a_out, 8'h7F, "A unchanged after STA", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z flag unchanged by STA");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N flag unchanged by STA");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C flag unchanged by STA");
    // Verify memory content
    pretty_print_assert_vec(uut.u_ram.mem[16'h1003], 8'h7F, "Memory[$1003] contains stored value $7F");

    // =================================================================
    // TEST 5: Store maximum value (all bits set)
    // Assembly: LDI A, #$FF; STA $1004
    // Expected: Store A=$FF to address $1004, flags unchanged
    // =================================================================
    $display("\n--- TEST 5: Store maximum value ($FF to $1004) ---");
    
    // LDI A, #$FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A after LDI A, #$FF", DATA_WIDTH);

    // STA $1004: Store A to memory address $1004
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("STA $1004: Store A=$FF to address $1004");
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A unchanged after STA", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z flag unchanged by STA");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N flag unchanged by STA");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C flag unchanged by STA");
    // Verify memory content
    pretty_print_assert_vec(uut.u_ram.mem[16'h1004], 8'hFF, "Memory[$1004] contains stored value $FF");

    // =================================================================
    // TEST 6: Store alternating bit pattern
    // Assembly: LDI A, #$55; STA $1005
    // Expected: Store A=$55 to address $1005, flags unchanged
    // =================================================================
    $display("\n--- TEST 6: Store alternating bit pattern ($55 to $1005) ---");
    
    // LDI A, #$55
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h55, "A after LDI A, #$55", DATA_WIDTH);

    // STA $1005: Store A to memory address $1005
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("STA $1005: Store A=$55 (01010101b) to address $1005");
    inspect_register(uut.u_cpu.a_out, 8'h55, "A unchanged after STA", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z flag unchanged by STA");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N flag unchanged by STA");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C flag unchanged by STA");
    // Verify memory content
    pretty_print_assert_vec(uut.u_ram.mem[16'h1005], 8'h55, "Memory[$1005] contains stored value $55");

    // =================================================================
    // TEST 7: Store complementary alternating pattern
    // Assembly: LDI A, #$AA; STA $1006
    // Expected: Store A=$AA to address $1006, flags unchanged
    // =================================================================
    $display("\n--- TEST 7: Store complementary alternating pattern ($AA to $1006) ---");
    
    // LDI A, #$AA
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hAA, "A after LDI A, #$AA", DATA_WIDTH);

    // STA $1006: Store A to memory address $1006
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("STA $1006: Store A=$AA (10101010b) to address $1006");
    inspect_register(uut.u_cpu.a_out, 8'hAA, "A unchanged after STA", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z flag unchanged by STA");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N flag unchanged by STA");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C flag unchanged by STA");
    // Verify memory content
    pretty_print_assert_vec(uut.u_ram.mem[16'h1006], 8'hAA, "Memory[$1006] contains stored value $AA");

    // =================================================================
    // TEST 8: Store single bit set (LSB)
    // Assembly: LDI A, #$01; STA $1007
    // Expected: Store A=$01 to address $1007, flags unchanged
    // =================================================================
    $display("\n--- TEST 8: Store single bit set LSB ($01 to $1007) ---");
    
    // LDI A, #$01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h01, "A after LDI A, #$01", DATA_WIDTH);

    // STA $1007: Store A to memory address $1007
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("STA $1007: Store A=$01 (only LSB set) to address $1007");
    inspect_register(uut.u_cpu.a_out, 8'h01, "A unchanged after STA", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z flag unchanged by STA");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N flag unchanged by STA");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C flag unchanged by STA");
    // Verify memory content
    pretty_print_assert_vec(uut.u_ram.mem[16'h1007], 8'h01, "Memory[$1007] contains stored value $01");

    // =================================================================
    // TEST 9: Store single bit set (MSB)
    // Assembly: LDI A, #$80; STA $1008
    // Expected: Store A=$80 to address $1008, flags unchanged
    // =================================================================
    $display("\n--- TEST 9: Store single bit set MSB ($80 to $1008) ---");
    
    // LDI A, #$80
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h80, "A after LDI A, #$80", DATA_WIDTH);

    // STA $1008: Store A to memory address $1008
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("STA $1008: Store A=$80 (only MSB set) to address $1008");
    inspect_register(uut.u_cpu.a_out, 8'h80, "A unchanged after STA", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z flag unchanged by STA");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N flag unchanged by STA");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C flag unchanged by STA");
    // Verify memory content
    pretty_print_assert_vec(uut.u_ram.mem[16'h1008], 8'h80, "Memory[$1008] contains stored value $80");

    // =================================================================
    // TEST 10: Store to boundary address (low RAM boundary)
    // Assembly: LDI A, #$DE; STA $0000
    // Expected: Store A=$DE to address $0000, flags unchanged
    // =================================================================
    $display("\n--- TEST 10: Store to low RAM boundary ($DE to $0000) ---");
    
    // LDI A, #$DE
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hDE, "A after LDI A, #$DE", DATA_WIDTH);

    // STA $0000: Store A to memory address $0000
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("STA $0000: Store A=$DE to address $0000 (RAM start)");
    inspect_register(uut.u_cpu.a_out, 8'hDE, "A unchanged after STA", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z flag unchanged by STA");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N flag unchanged by STA");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C flag unchanged by STA");
    // Verify memory content
    pretty_print_assert_vec(uut.u_ram.mem[16'h0000], 8'hDE, "Memory[$0000] contains stored value $DE");

    // =================================================================
    // TEST 11: Store to near high RAM boundary
    // Assembly: LDI A, #$AD; STA $1FFE
    // Expected: Store A=$AD to address $1FFE, flags unchanged
    // =================================================================
    $display("\n--- TEST 11: Store to high RAM boundary ($AD to $1FFE) ---");
    
    // LDI A, #$AD
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hAD, "A after LDI A, #$AD", DATA_WIDTH);

    // STA $1FFE: Store A to memory address $1FFE
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("STA $1FFE: Store A=$AD to address $1FFE (near RAM end)");
    inspect_register(uut.u_cpu.a_out, 8'hAD, "A unchanged after STA", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z flag unchanged by STA");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N flag unchanged by STA");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "C flag unchanged by STA");
    // Verify memory content
    pretty_print_assert_vec(uut.u_ram.mem[16'h1FFE], 8'hAD, "Memory[$1FFE] contains stored value $AD");

    // =================================================================
    // TEST 12: Flag preservation test with carry set
    // Assembly: SEC; LDI A, #$C7; STA $1100
    // Expected: Store A=$C7 to address $1100, carry flag remains set
    // =================================================================
    $display("\n--- TEST 12: Flag preservation with carry set ($C7 to $1100) ---");
    
    // SEC: Set carry flag
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C=1: carry flag set by SEC");

    // LDI A, #$C7
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hC7, "A after LDI A, #$C7", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C flag preserved during LDI");

    // STA $1100: Store A to memory address $1100
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("STA $1100: Store A=$C7 to address $1100, carry should remain set");
    inspect_register(uut.u_cpu.a_out, 8'hC7, "A unchanged after STA", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Z flag unchanged by STA");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "N flag unchanged by STA");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C flag preserved by STA");
    // Verify memory content
    pretty_print_assert_vec(uut.u_ram.mem[16'h1100], 8'hC7, "Memory[$1100] contains stored value $C7");

    // =================================================================
    // TEST 13: Flag preservation test with zero flag set
    // Assembly: LDI A, #$00; STA $1101
    // Expected: Store A=$00 to address $1101, zero flag remains set
    // =================================================================
    $display("\n--- TEST 13: Flag preservation with zero flag set ($00 to $1101) ---");
    
    // LDI A, #$00 (sets zero flag)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "A after LDI A, #$00", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "Z=1: zero flag set by LDI");

    // STA $1101: Store A to memory address $1101
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("STA $1101: Store A=$00 to address $1101, zero flag should remain set");
    inspect_register(uut.u_cpu.a_out, 8'h00, "A unchanged after STA", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "Z flag preserved by STA");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "N flag unchanged by STA");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "C flag unchanged by STA");
    // Verify memory content
    pretty_print_assert_vec(uut.u_ram.mem[16'h1101], 8'h00, "Memory[$1101] contains stored value $00");

    // =================================================================
    // TEST 14: Register preservation test
    // Assembly: LDI A, #$F0; LDI B, #$0F; LDI C, #$A5; STA $1200; STA $1201
    // Expected: B and C registers remain unchanged after multiple STA operations
    // =================================================================
    $display("\n--- TEST 14: Register preservation test (multiple STA operations) ---");
    
    // LDI A, #$F0
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hF0, "A after LDI A, #$F0", DATA_WIDTH);

    // LDI B, #$0F
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h0F, "B after LDI B, #$0F", DATA_WIDTH);

    // LDI C, #$A5
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hA5, "C after LDI C, #$A5", DATA_WIDTH);

    // STA $1200: First store operation
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("STA $1200: First store - registers should be preserved");
    inspect_register(uut.u_cpu.a_out, 8'hF0, "A unchanged after first STA", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h0F, "B preserved after first STA", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hA5, "C preserved after first STA", DATA_WIDTH);
    // Verify memory content
    pretty_print_assert_vec(uut.u_ram.mem[16'h1200], 8'hF0, "Memory[$1200] contains stored value $F0");

    // STA $1201: Second store operation  
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("STA $1201: Second store - registers should remain preserved");
    inspect_register(uut.u_cpu.a_out, 8'hF0, "A unchanged after second STA", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h0F, "B preserved after second STA", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hA5, "C preserved after second STA", DATA_WIDTH);
    // Verify memory content
    pretty_print_assert_vec(uut.u_ram.mem[16'h1201], 8'hF0, "Memory[$1201] contains stored value $F0");

    // =================================================================
    // TEST 15: Sequential stores to verify independence
    // Assembly: LDI A, #$11; STA $1300; LDI A, #$22; STA $1301; LDI A, #$33; STA $1302
    // Expected: Each store operates independently without interference
    // =================================================================
    $display("\n--- TEST 15: Sequential stores independence test ---");
    
    // LDI A, #$11
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h11, "A after LDI A, #$11", DATA_WIDTH);

    // STA $1300: Store $11 to $1300
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("STA $1300: Store A=$11 to address $1300");
    pretty_print_assert_vec(uut.u_ram.mem[16'h1300], 8'h11, "Memory[$1300] contains stored value $11");

    // LDI A, #$22
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h22, "A after LDI A, #$22", DATA_WIDTH);

    // STA $1301: Store $22 to $1301
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("STA $1301: Store A=$22 to address $1301");
    pretty_print_assert_vec(uut.u_ram.mem[16'h1301], 8'h22, "Memory[$1301] contains stored value $22");
    // Verify previous storage is still intact
    pretty_print_assert_vec(uut.u_ram.mem[16'h1300], 8'h11, "Memory[$1300] still contains $11");

    // LDI A, #$33
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h33, "A after LDI A, #$33", DATA_WIDTH);

    // STA $1302: Store $33 to $1302
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("STA $1302: Store A=$33 to address $1302");
    pretty_print_assert_vec(uut.u_ram.mem[16'h1302], 8'h33, "Memory[$1302] contains stored value $33");
    // Verify previous storages are still intact
    pretty_print_assert_vec(uut.u_ram.mem[16'h1300], 8'h11, "Memory[$1300] still contains $11");
    pretty_print_assert_vec(uut.u_ram.mem[16'h1301], 8'h22, "Memory[$1301] still contains $22");

    // =================================================================
    // FINAL: Wait for halt and verify completion
    // =================================================================
    $display("\n--- FINAL: Verifying test completion ---");
    
    run_until_halt(50); // Increased timeout for comprehensive test suite
    
    // Final verification - ensure all stored values are correct
    $display("\n=== Final Memory Verification ===");
    pretty_print_assert_vec(uut.u_ram.mem[16'h1000], 8'h42, "Final check: Memory[$1000] = $42");
    pretty_print_assert_vec(uut.u_ram.mem[16'h1001], 8'h00, "Final check: Memory[$1001] = $00");
    pretty_print_assert_vec(uut.u_ram.mem[16'h1002], 8'h80, "Final check: Memory[$1002] = $80");
    pretty_print_assert_vec(uut.u_ram.mem[16'h1003], 8'h7F, "Final check: Memory[$1003] = $7F");
    pretty_print_assert_vec(uut.u_ram.mem[16'h1004], 8'hFF, "Final check: Memory[$1004] = $FF");
    
    // Visual buffer for waveform inspection
    repeat(2) @(posedge clk);

    $display("STA test finished.===========================\n\n");
    $finish;
    // ============================ END TEST ==============================
  
  end

endmodule