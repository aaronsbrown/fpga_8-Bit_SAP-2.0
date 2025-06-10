`timescale 1ns/1ps
import test_utils_pkg::*; 
import arch_defs_pkg::*;  

module computer_tb;

  localparam string HEX_FILE = "../hardware/test/fixtures_generated/sta_mmio_integration/ROM.hex";

  logic                  clk;
  logic                  reset;
  logic [DATA_WIDTH-1:0] computer_output;

  computer uut (
        .clk(clk),
        .reset(reset),
        .output_port_1(computer_output),
        .uart_rx(1'b1),     // UART RX tied high (idle)
        .uart_tx()          // UART TX left open
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

    // ============================ BEGIN STA MMIO INTEGRATION TESTS ==============================
    $display("\n=== STA MMIO Integration Test Suite ===");
    $display("Testing STA instruction to MMIO addresses and computer.sv address decoding\n");

    // =================================================================
    // TEST 1: Store to UART_CONFIG_REG ($E000)
    // Assembly: LDI A, #$55; STA UART_CONFIG_REG
    // Expected: Value should appear in UART peripheral config register
    // =================================================================
    $display("--- TEST 1: Store to UART_CONFIG_REG ($E000) ---");
    
    // LDI A, #$55
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h55, "A after LDI A, #$55", DATA_WIDTH);

    // STA UART_CONFIG_REG ($E000)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("STA UART_CONFIG_REG: Store A=$55 to UART config register");
    inspect_register(uut.u_cpu.a_out, 8'h55, "A unchanged after STA to MMIO", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_uart.config_reg, 8'h55, "UART config register contains stored value $55");

    // =================================================================
    // TEST 2: Store to UART_DATA_REG ($E002)
    // Assembly: LDI A, #$48; STA UART_DATA_REG  
    // Expected: Value should appear in UART data register
    // =================================================================
    $display("\n--- TEST 2: Store to UART_DATA_REG ($E002) ---");
    
    // LDI A, #$48 ('H' character)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h48, "A after LDI A, #$48", DATA_WIDTH);

    // STA UART_DATA_REG ($E002)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("STA UART_DATA_REG: Store A=$48 ('H') to UART data register");
    inspect_register(uut.u_cpu.a_out, 8'h48, "A unchanged after STA to MMIO", DATA_WIDTH);
    // Note: UART data register doesn't store value - it triggers transmission

    // =================================================================
    // TEST 3: Store to UART_COMMAND_REG ($E003)
    // Assembly: LDI A, #$01; STA UART_COMMAND_REG
    // Expected: Value should appear in UART command register
    // =================================================================
    $display("\n--- TEST 3: Store to UART_COMMAND_REG ($E003) ---");
    
    // LDI A, #$01 (clear frame error command)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h01, "A after LDI A, #$01", DATA_WIDTH);

    // STA UART_COMMAND_REG ($E003)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("STA UART_COMMAND_REG: Store A=$01 to UART command register");
    inspect_register(uut.u_cpu.a_out, 8'h01, "A unchanged after STA to MMIO", DATA_WIDTH);
    // Note: UART command register executes commands immediately, doesn't store value

    // =================================================================
    // TEST 4: Store to OUTPUT_PORT_1 ($E004) - LED Output
    // Assembly: LDI A, #$AA; STA OUTPUT_PORT_1
    // Expected: Value should appear on LED output port
    // =================================================================
    $display("\n--- TEST 4: Store to OUTPUT_PORT_1 ($E004) - LED pattern $AA ---");
    
    // LDI A, #$AA (10101010 pattern)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hAA, "A after LDI A, #$AA", DATA_WIDTH);

    // STA OUTPUT_PORT_1 ($E004)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("STA OUTPUT_PORT_1: Store A=$AA (10101010b) to LED output");
    inspect_register(uut.u_cpu.a_out, 8'hAA, "A unchanged after STA to MMIO", DATA_WIDTH);
    pretty_print_assert_vec(computer_output, 8'hAA, "LED output port contains pattern $AA (10101010b)");

    // =================================================================
    // TEST 5: Store different pattern to OUTPUT_PORT_1
    // Assembly: LDI A, #$55; STA OUTPUT_PORT_1
    // Expected: LED pattern should change to demonstrate live update
    // =================================================================
    $display("\n--- TEST 5: Change LED pattern to $55 ---");
    
    // LDI A, #$55 (01010101 pattern)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h55, "A after LDI A, #$55", DATA_WIDTH);

    // STA OUTPUT_PORT_1 ($E004)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("STA OUTPUT_PORT_1: Store A=$55 (01010101b) to LED output");
    inspect_register(uut.u_cpu.a_out, 8'h55, "A unchanged after STA to MMIO", DATA_WIDTH);
    pretty_print_assert_vec(computer_output, 8'h55, "LED output port updated to pattern $55 (01010101b)");

    // =================================================================
    // TEST 6: Store to UART_STATUS_REG ($E001) - usually read-only
    // Assembly: LDI A, #$FF; STA UART_STATUS_REG
    // Expected: May be ignored or have side effects depending on implementation
    // =================================================================
    $display("\n--- TEST 6: Store to UART_STATUS_REG ($E001) - read-only test ---");
    
    // LDI A, #$FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A after LDI A, #$FF", DATA_WIDTH);

    // STA UART_STATUS_REG ($E001)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("STA UART_STATUS_REG: Store A=$FF to UART status register (typically read-only)");
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A unchanged after STA to MMIO", DATA_WIDTH);
    // Note: Don't assert status register value since it may be read-only

    // =================================================================
    // TEST 7: Store zero to OUTPUT_PORT_1 (turn off all LEDs)
    // Assembly: LDI A, #$00; STA OUTPUT_PORT_1
    // Expected: All LEDs should turn off
    // =================================================================
    $display("\n--- TEST 7: Turn off all LEDs ($00 to OUTPUT_PORT_1) ---");
    
    // LDI A, #$00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "A after LDI A, #$00", DATA_WIDTH);

    // STA OUTPUT_PORT_1 ($E004)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("STA OUTPUT_PORT_1: Store A=$00 to turn off all LEDs");
    inspect_register(uut.u_cpu.a_out, 8'h00, "A unchanged after STA to MMIO", DATA_WIDTH);
    pretty_print_assert_vec(computer_output, 8'h00, "LED output port cleared to $00 (all LEDs off)");

    // =================================================================
    // TEST 8: Store to multiple UART registers in sequence
    // Assembly: LDI A, #$10; STA UART_CONFIG_REG; LDI A, #$20; STA UART_DATA_REG; LDI A, #$30; STA UART_COMMAND_REG
    // Expected: Each store should reach the correct UART register
    // =================================================================
    $display("\n--- TEST 8: Sequential UART register stores ---");
    
    // LDI A, #$10; STA UART_CONFIG_REG
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h10, "A after LDI A, #$10", DATA_WIDTH);
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("Sequential store 1: A=$10 to UART_CONFIG_REG");
    pretty_print_assert_vec(uut.u_uart.config_reg, 8'h10, "UART config register updated to $10");

    // LDI A, #$20; STA UART_DATA_REG
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h20, "A after LDI A, #$20", DATA_WIDTH);
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("Sequential store 2: A=$20 to UART_DATA_REG");
    // Note: UART data register triggers transmission, doesn't store value

    // LDI A, #$30; STA UART_COMMAND_REG
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h30, "A after LDI A, #$30", DATA_WIDTH);
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("Sequential store 3: A=$30 to UART_COMMAND_REG");
    // Note: UART command register executes commands immediately, doesn't store value

    // =================================================================
    // TEST 9: Register preservation test during MMIO operations
    // Assembly: LDI A, #$FF; LDI B, #$11; LDI C, #$22; STA OUTPUT_PORT_1; STA UART_CONFIG_REG
    // Expected: B and C registers should remain unchanged during MMIO stores
    // =================================================================
    $display("\n--- TEST 9: Register preservation during MMIO operations ---");
    
    // LDI A, #$FF; LDI B, #$11; LDI C, #$22
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A after LDI A, #$FF", DATA_WIDTH);
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h11, "B after LDI B, #$11", DATA_WIDTH);
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h22, "C after LDI C, #$22", DATA_WIDTH);

    // STA OUTPUT_PORT_1; STA UART_CONFIG_REG
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("MMIO store 1: A=$FF to OUTPUT_PORT_1");
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A unchanged after MMIO store", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h11, "B preserved during MMIO store", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'h22, "C preserved during MMIO store", DATA_WIDTH);
    pretty_print_assert_vec(computer_output, 8'hFF, "LED output port updated to $FF");

    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("MMIO store 2: A=$FF to UART_CONFIG_REG");
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A unchanged after MMIO store", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h11, "B preserved during MMIO store", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'h22, "C preserved during MMIO store", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_uart.config_reg, 8'hFF, "UART config register updated to $FF");

    // =================================================================
    // TEST 10: Final LED pattern test
    // Assembly: LDI A, #$F0; STA OUTPUT_PORT_1
    // Expected: Set final recognizable pattern on LEDs
    // =================================================================
    $display("\n--- TEST 10: Final LED pattern test ($F0) ---");
    
    // LDI A, #$F0; STA OUTPUT_PORT_1
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hF0, "A after LDI A, #$F0", DATA_WIDTH);
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    $display("STA OUTPUT_PORT_1: Final LED pattern A=$F0 (11110000b)");
    inspect_register(uut.u_cpu.a_out, 8'hF0, "A unchanged after final MMIO store", DATA_WIDTH);
    pretty_print_assert_vec(computer_output, 8'hF0, "Final LED pattern set to $F0 (11110000b)");

    // =================================================================
    // FINAL: Wait for halt and verify completion
    // =================================================================
    $display("\n--- FINAL: Verifying integration test completion ---");
    
    run_until_halt(30); // Timeout for MMIO integration test
    
    // Final verification - check final register states
    $display("\n=== Final MMIO State Verification ===");
    pretty_print_assert_vec(computer_output, 8'hF0, "Final LED output: $F0");
    pretty_print_assert_vec(uut.u_uart.config_reg, 8'hFF, "Final UART config: $FF");
    // Note: UART data and command registers don't store persistent values
    
    // Visual buffer for waveform inspection
    repeat(2) @(posedge clk);

    $display("STA_MMIO integration test finished.===========================\n\n");
    $finish;
    // ============================ END TEST ==============================
  
  end

endmodule