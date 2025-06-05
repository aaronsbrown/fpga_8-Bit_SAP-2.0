`timescale 1ns/1ps
import test_utils_pkg::*; 
import arch_defs_pkg::*;  

module computer_tb;

  localparam string HEX_FILE = "../hardware/test/fixtures_generated/JNZ/ROM.hex";

  logic                  clk;
  logic                  reset;
  logic [DATA_WIDTH-1:0] computer_output;
  logic                  uart_rx;
  logic                  uart_tx;

  computer uut (
        .clk(clk),
        .reset(reset),
        .output_port_1(computer_output),
        .uart_rx(uart_rx),
        .uart_tx(uart_rx)
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
    $display("\n\nRunning JNZ test ========================");

    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h0F, "Register A", DATA_WIDTH);

    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h0F, "Register A", DATA_WIDTH);

    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "Register A", DATA_WIDTH);

    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "Register A", DATA_WIDTH);

    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h88, "Register A", DATA_WIDTH);

    run_until_halt(20);
    
    // Vizual buffer for waveform inspection
    repeat(2) @(posedge clk);

    $display("JNZ test finished.===========================\n\n");
    $finish;
    // ============================ END TEST ==============================
  
  end

endmodule