`timescale 1ns/1ps
import test_utils_pkg::*; 
import arch_defs_pkg::*;  
// AIDEV-NOTE: Enhanced testbench with 7 test groups covering comprehensive CMP_C instruction validation

module computer_tb;

  localparam string HEX_FILE = "../hardware/test/_fixtures_generated/CMP_C/ROM.hex";

  logic                  clk;
  logic                  reset;
  logic [DATA_WIDTH-1:0] computer_output;
  logic                  uart_rx_tb; // Renamed to avoid conflict
  logic                  uart_tx_tb; // Renamed for clarity

  computer uut (
        .clk(clk),
        .reset(reset),
        .output_port_1(computer_output),
        .uart_rx(uart_rx_tb),
        .uart_tx(uart_tx_tb) // Corrected wiring
  );

  // --- Clock Generation: 10 ns period ---
  initial begin clk = 0;  forever #5 clk = ~clk; end

  // --- Testbench Stimulus ---
  initial begin
    uart_rx_tb = 1'b1; // Default UART RX to idle

    // Setup waveform dumping
    $dumpfile("waveform.vcd");
    $dumpvars(0, computer_tb); // Dump all signals in this module and below

    // Init ram/rom to 00 
    uut.u_ram.init_sim_ram();
    uut.u_rom.init_sim_rom();

    // load the hex files into ROM
    $display("--- Loading hex file: %s ---", HEX_FILE);
    safe_readmemh_rom(HEX_FILE); 

    // Print ROM content     
    uut.u_rom.dump(); 

    // Apply reset and wait for it to release
    reset_and_wait(0); 

    // ============================ BEGIN TEST ==============================
    $display("\n\nRunning CMP_C test (Extended) ========================");

    // Test Group 1: A = $01 (Original Tests)
    $display("Test Group 1: A = $01");
    // LDI A, #$01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h01, "A=$01", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "LDI A: Z=0"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "LDI A: N=0"); 
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "LDI A: C preserved (assume 0 init)"); 

    // LDI C, #$03
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h03, "C=$03", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "LDI C: Z=0"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "LDI C: N=0"); 
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "LDI C: C preserved"); 

    // CMP C (A=$01, C=$03 -> $FE)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h01, "CMP C (A<C): A preserved", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "CMP C (A<C): Z=0 ($01-$03=$FE)"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "CMP C (A<C): N=1 ($FE is negative)");  
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "CMP C (A<C): C=0 (borrow occurred)");
  
    // LDI C, #$00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h00, "C=$00", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "LDI C: Z=1"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "LDI C: N=0"); 
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "LDI C: C preserved"); 

    // CMP C (A=$01, C=$00 -> $01)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h01, "CMP C (A>C): A preserved", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "CMP C (A>C): Z=0 ($01-$00=$01)"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "CMP C (A>C): N=0 ($01 is positive)");  
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "CMP C (A>C): C=1 (no borrow)"); 
    
    // LDI C, #$01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h01, "C=$01", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "LDI C: Z=0"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "LDI C: N=0"); 
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "LDI C: C preserved");

    // CMP C (A=$01, C=$01 -> $00)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h01, "CMP C (A==C): A preserved", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "CMP C (A==C): Z=1 ($01-$01=$00)"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "CMP C (A==C): N=0 ($00 is positive)");  
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "CMP C (A==C): C=1 (no borrow)");
     
    // Test Group 2: A = $00
    $display("Test Group 2: A = $00");
    // LDI A, #$00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "A=$00", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "LDI A: Z=1");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "LDI A: N=0");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "LDI A: C preserved"); // C was 1 from previous CMP

    // LDI C, #$00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h00, "C=$00", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "LDI C: Z=1");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "LDI C: N=0");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "LDI C: C preserved");

    // CMP C (A=$00, C=$00 -> $00)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "CMP C (A==C): A preserved", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "CMP C (A==C): Z=1 ($00-$00=$00)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "CMP C (A==C): N=0 ($00 is positive)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "CMP C (A==C): C=1 (no borrow)");

    // LDI C, #$01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h01, "C=$01", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "LDI C: Z=0");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "LDI C: N=0");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "LDI C: C preserved");

    // CMP C (A=$00, C=$01 -> $FF)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "CMP C (A<C): A preserved", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "CMP C (A<C): Z=0 ($00-$01=$FF)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "CMP C (A<C): N=1 ($FF is negative)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "CMP C (A<C): C=0 (borrow occurred)");

    // LDI C, #$FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hFF, "C=$FF", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "LDI C: Z=0");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "LDI C: N=1");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "LDI C: C preserved");

    // CMP C (A=$00, C=$FF -> $01)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "CMP C (A<C): A preserved", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "CMP C (A<C): Z=0 ($00-$FF=$01)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "CMP C (A<C): N=0 ($01 is positive)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "CMP C (A<C): C=0 (borrow occurred)");

    // Test Group 3: A = $FF
    $display("Test Group 3: A = $FF");
    // LDI A, #$FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A=$FF", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "LDI A: Z=0");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "LDI A: N=1");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "LDI A: C preserved");

    // LDI C, #$FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hFF, "C=$FF", DATA_WIDTH);
    // CMP C (A=$FF, C=$FF -> $00)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // CMP C is next
    inspect_register(uut.u_cpu.a_out, 8'hFF, "CMP C (A==C): A preserved", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "CMP C (A==C): Z=1 ($FF-$FF=$00)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "CMP C (A==C): N=0 ($00 is positive)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "CMP C (A==C): C=1 (no borrow)");

    // LDI C, #$00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h00, "C=$00", DATA_WIDTH);
    // CMP C (A=$FF, C=$00 -> $FF)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // CMP C is next
    inspect_register(uut.u_cpu.a_out, 8'hFF, "CMP C (A>C): A preserved", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "CMP C (A>C): Z=0 ($FF-$00=$FF)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "CMP C (A>C): N=1 ($FF is negative)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "CMP C (A>C): C=1 (no borrow)");

    // LDI C, #$FE
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hFE, "C=$FE", DATA_WIDTH);
    // CMP C (A=$FF, C=$FE -> $01)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // CMP C is next
    inspect_register(uut.u_cpu.a_out, 8'hFF, "CMP C (A>C): A preserved", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "CMP C (A>C): Z=0 ($FF-$FE=$01)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "CMP C (A>C): N=0 ($01 is positive)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "CMP C (A>C): C=1 (no borrow)");

    // Test Group 4: A = $80
    $display("Test Group 4: A = $80");
    // LDI A, #$80
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h80, "A=$80", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "LDI A: C preserved"); // C from previous

    // LDI C, #$00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    // CMP C (A=$80, C=$00 -> $80)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h80, "CMP C (A>C): A preserved", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "CMP C (A>C): Z=0 ($80-$00=$80)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "CMP C (A>C): N=1 ($80 is negative)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "CMP C (A>C): C=1 (no borrow)");

    // LDI C, #$7F
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    // CMP C (A=$80, C=$7F -> $01)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h80, "CMP C (A>C): A preserved", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "CMP C (A>C): Z=0 ($80-$7F=$01)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "CMP C (A>C): N=0 ($01 is positive)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "CMP C (A>C): C=1 (no borrow)");

    // LDI C, #$80
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    // CMP C (A=$80, C=$80 -> $00)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h80, "CMP C (A==C): A preserved", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "CMP C (A==C): Z=1 ($80-$80=$00)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "CMP C (A==C): N=0 ($00 is positive)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "CMP C (A==C): C=1 (no borrow)");

    // Test Group 5: A = $7F
    $display("Test Group 5: A = $7F");
    // LDI A, #$7F
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h7F, "A=$7F", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "LDI A: C preserved");

    // LDI C, #$80
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    // CMP C (A=$7F, C=$80 -> $FF)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h7F, "CMP C (A<C): A preserved", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "CMP C (A<C): Z=0 ($7F-$80=$FF)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "CMP C (A<C): N=1 ($FF is negative)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "CMP C (A<C): C=0 (borrow occurred)");

    // LDI C, #$7F
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    // CMP C (A=$7F, C=$7F -> $00)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h7F, "CMP C (A==C): A preserved", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "CMP C (A==C): Z=1 ($7F-$7F=$00)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "CMP C (A==C): N=0 ($00 is positive)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "CMP C (A==C): C=1 (no borrow)");

    // Test Group 6: Alternating bit patterns
    $display("Test Group 6: Alternating bit patterns");
    // LDI A, #$AA
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hAA, "A=$AA", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "LDI A: C preserved");

    // LDI C, #$55
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    // CMP C (A=$AA, C=$55 -> $55)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hAA, "CMP C ($AA-$55): A preserved", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "CMP C ($AA-$55): Z=0 (result=$55)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "CMP C ($AA-$55): N=0 ($55 is positive)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "CMP C ($AA-$55): C=1 (no borrow)");

    // LDI C, #$AA
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    // CMP C (A=$AA, C=$AA -> $00)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hAA, "CMP C ($AA-$AA): A preserved", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "CMP C ($AA-$AA): Z=1 (result=$00)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "CMP C ($AA-$AA): N=0 ($00 is positive)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "CMP C ($AA-$AA): C=1 (no borrow)");

    // Test Group 7: Register preservation verification
    $display("Test Group 7: Register preservation verification");
    // LDI B, #$42
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h42, "B=$42 (canary value)", DATA_WIDTH);

    // LDI A, #$10
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h10, "A=$10", DATA_WIDTH);

    // LDI C, #$05
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    // CMP C (A=$10, C=$05 -> $0B)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h10, "CMP C ($10-$05): A preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h42, "CMP C: B register preserved", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "CMP C ($10-$05): Z=0 (result=$0B)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "CMP C ($10-$05): N=0 ($0B is positive)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "CMP C ($10-$05): C=1 (no borrow)");
    
    // Wait for HLT
    wait(uut.cpu_halt);
    
    // Visual buffer for waveform inspection
    repeat(2) @(posedge clk);

    $display("CMP_C test finished.===========================\n\n");
    $finish;
    // ============================ END TEST ==============================
  
  end

endmodule