`timescale 1ns/1ps
import test_utils_pkg::*; 
import arch_defs_pkg::*;  

module computer_tb;

  localparam string HEX_FILE = "../hardware/test/fixtures_generated/CMP_B/ROM.hex";

  logic                  clk;
  logic                  reset;
  logic [DATA_WIDTH-1:0] computer_output;
  logic                  uart_rx_tb; // Renamed to avoid conflict if uart_rx is also a wire
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
    $display("\n\nRunning CMP_B test (Extended) ========================");

    // Test Group 1: A = $01 (Original Tests)
    $display("Test Group 1: A = $01");
    // LDI A, #$01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h01, "A=$01", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "LDI A: Z=0"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "LDI A: N=0"); 
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "LDI A: C preserved (assume 0 init)"); 

    // LDI B, #$03
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h03, "B=$03", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "LDI B: Z=0"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "LDI B: N=0"); 
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "LDI B: C preserved"); 

    // CMP B (A=$01, B=$03 -> $FE)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h01, "CMP B (A<B): A preserved", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "CMP B (A<B): Z=0"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "CMP B (A<B): N=1");  
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "CMP B (A<B): C=0 (borrow)");
  
    // LDI B, #$00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h00, "B=$00", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "LDI B: Z=1"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "LDI B: N=0"); 
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "LDI B: C preserved"); 

    // CMP B (A=$01, B=$00 -> $01)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h01, "CMP B (A>B): A preserved", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "CMP B (A>B): Z=0"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "CMP B (A>B): N=0");  
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "CMP B (A>B): C=1 (no borrow)"); 
    
    // LDI B, #$01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h01, "B=$01", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "LDI B: Z=0"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "LDI B: N=0"); 
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "LDI B: C preserved");

    // CMP B (A=$01, B=$01 -> $00)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h01, "CMP B (A==B): A preserved", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "CMP B (A==B): Z=1"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "CMP B (A==B): N=0");  
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "CMP B (A==B): C=1 (no borrow)");
     
    // Test Group 2: A = $00
    $display("Test Group 2: A = $00");
    // LDI A, #$00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "A=$00", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "LDI A: Z=1");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "LDI A: N=0");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "LDI A: C preserved"); // C was 1 from previous CMP

    // LDI B, #$00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h00, "B=$00", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "LDI B: Z=1");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "LDI B: N=0");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "LDI B: C preserved");

    // CMP B (A=$00, B=$00 -> $00)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "CMP B (A==B): A preserved", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "CMP B (A==B): Z=1");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "CMP B (A==B): N=0");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "CMP B (A==B): C=1 (no borrow)");

    // LDI B, #$01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h01, "B=$01", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "LDI B: Z=0");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "LDI B: N=0");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "LDI B: C preserved");

    // CMP B (A=$00, B=$01 -> $FF)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "CMP B (A<B): A preserved", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "CMP B (A<B): Z=0");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "CMP B (A<B): N=1");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "CMP B (A<B): C=0 (borrow)");

    // LDI B, #$FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'hFF, "B=$FF", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "LDI B: Z=0");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "LDI B: N=1");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "LDI B: C preserved");

    // CMP B (A=$00, B=$FF -> $01)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "CMP B (A<B): A preserved", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "CMP B (A<B): Z=0");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "CMP B (A<B): N=0"); // Result is $01
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "CMP B (A<B): C=0 (borrow)");

    // Test Group 3: A = $FF
    $display("Test Group 3: A = $FF");
    // LDI A, #$FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A=$FF", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "LDI A: Z=0");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "LDI A: N=1");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "LDI A: C preserved");

    // LDI B, #$FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'hFF, "B=$FF", DATA_WIDTH);
    // CMP B (A=$FF, B=$FF -> $00)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // CMP B is next
    inspect_register(uut.u_cpu.a_out, 8'hFF, "CMP B (A==B): A preserved", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "CMP B (A==B): Z=1");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "CMP B (A==B): N=0");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "CMP B (A==B): C=1 (no borrow)");

    // LDI B, #$00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h00, "B=$00", DATA_WIDTH);
    // CMP B (A=$FF, B=$00 -> $FF)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // CMP B is next
    inspect_register(uut.u_cpu.a_out, 8'hFF, "CMP B (A>B): A preserved", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "CMP B (A>B): Z=0");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "CMP B (A>B): N=1");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "CMP B (A>B): C=1 (no borrow)");

    // LDI B, #$FE
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'hFE, "B=$FE", DATA_WIDTH);
    // CMP B (A=$FF, B=$FE -> $01)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1; // CMP B is next
    inspect_register(uut.u_cpu.a_out, 8'hFF, "CMP B (A>B): A preserved", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "CMP B (A>B): Z=0");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "CMP B (A>B): N=0");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "CMP B (A>B): C=1 (no borrow)");

    // Test Group 4: A = $80
    $display("Test Group 4: A = $80");
    // LDI A, #$80
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h80, "A=$80", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "LDI A: C preserved"); // C from previous

    // LDI B, #$00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    // CMP B (A=$80, B=$00 -> $80)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h80, "CMP B (A>B): A preserved", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "CMP B (A>B): Z=0");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "CMP B (A>B): N=1");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "CMP B (A>B): C=1 (no borrow)");

    // LDI B, #$7F
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    // CMP B (A=$80, B=$7F -> $01)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h80, "CMP B (A>B): A preserved", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "CMP B (A>B): Z=0");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "CMP B (A>B): N=0");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "CMP B (A>B): C=1 (no borrow)");

    // LDI B, #$80
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    // CMP B (A=$80, B=$80 -> $00)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h80, "CMP B (A==B): A preserved", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "CMP B (A==B): Z=1");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "CMP B (A==B): N=0");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "CMP B (A==B): C=1 (no borrow)");

    // Test Group 5: A = $7F
    $display("Test Group 5: A = $7F");
    // LDI A, #$7F
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h7F, "A=$7F", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "LDI A: C preserved");

    // LDI B, #$80
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    // CMP B (A=$7F, B=$80 -> $FF)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h7F, "CMP B (A<B): A preserved", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "CMP B (A<B): Z=0");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "CMP B (A<B): N=1");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "CMP B (A<B): C=0 (borrow)");

    // LDI B, #$7F
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    // CMP B (A=$7F, B=$7F -> $00)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h7F, "CMP B (A==B): A preserved", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "CMP B (A==B): Z=1");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "CMP B (A==B): N=0");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "CMP B (A==B): C=1 (no borrow)");
     
    // Wait for HLT
    wait(uut.cpu_halt);
    
    // Visual buffer for waveform inspection
    repeat(2) @(posedge clk);

    $display("CMP_B test finished.===========================\n\n");
    $finish;
    // ============================ END TEST ==============================
  
  end

endmodule