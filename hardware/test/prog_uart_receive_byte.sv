`timescale 1ns/1ps
import test_utils_pkg::*; 
import arch_defs_pkg::*;  

module computer_tb;

  localparam string HEX_FILE = "../hardware/test/fixtures_generated/prog_uart_receive_byte/ROM.hex";

  localparam DUT_CLOCK_SPEED_HZ = 2_000_000;
  localparam DUT_BAUD_RATE = 9600;

  defparam uut.u_uart.u_transmitter.CLOCK_SPEED = DUT_CLOCK_SPEED_HZ;
  defparam uut.u_uart.u_transmitter.BAUD_RATE  = DUT_BAUD_RATE;

  defparam uut.u_uart.u_receiver.CLOCK_SPEED = DUT_CLOCK_SPEED_HZ;
  defparam uut.u_uart.u_receiver.BAUD_RATE  = DUT_BAUD_RATE;
  
  // TESTBENCH SIGNALS
  reg clk;
  reg reset;
  wire uut_uart_tx_signal;
  
  // UART TRANSMITTER to generate test stimulus
  logic stim_start_strobe;
  logic [DATA_WIDTH-1:0] stim_data_in;
  logic stim_busy_flag;
  logic stim_serial_data_out;
  uart_transmitter #(
    .CLOCK_SPEED(DUT_CLOCK_SPEED_HZ),
    .BAUD_RATE(DUT_BAUD_RATE),
  ) uart_transmitter (
    .clk(clk),
    .reset(reset),
    .tx_parallel_data_in(stim_data_in),
    .tx_strobe_start(stim_start_strobe),
    .tx_strobe_busy(stim_busy_flag),
    .tx_serial_data_out(stim_serial_data_out)
  );

  // UNIT UNDER TEST
  computer uut (
        .clk(clk),
        .reset(reset),
        .uart_rx(stim_serial_data_out)
    );

  // --- Clock Generation: 10 ns period ---
  initial begin clk = 0;  forever #5 clk = ~clk; end

  // --- Testbench Stimulus ---
  initial begin

    // Setup waveform dumping
    $dumpfile("waveform.vcd");
    $dumpvars(0, computer_tb); // Dump all signals in this module and below

    // Init ram/rom to 00 
    uut.u_rom.init_sim_rom();

    // load the hex file into RAM
    $display("--- Loading hex file: %s ---", HEX_FILE);
    $readmemh(HEX_FILE, uut.u_rom.mem); 
    uut.u_rom.dump(); 

    // Apply reset and wait for it to release
    reset_and_wait(0); 

    // --- Execute the instruction ---
    $display("\n\nRunning UART_RECEIVE_BYTE test");

    repeat(1) @(negedge clk);
    stim_data_in = 8'hB3; // xB3        
    stim_start_strobe = 1'b1; 

    repeat(1) @(negedge clk);
    stim_start_strobe = 1'b0;

    //repeat(3000) @(posedge clk); #01;

    wait( uut.cpu_halt == 1);
    pretty_print_assert_vec(uut.u_cpu.u_register_A.latched_data, 8'hB3, "uart byte latched into Reg A == xB3");    

    $display("UART_RECEIVE_BYTE test finished.\n\n");
    $finish;
  end

endmodule