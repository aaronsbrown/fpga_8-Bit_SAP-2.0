`timescale 1ns/1ps
import test_utils_pkg::*; 
import arch_defs_pkg::*;  

module computer_tb;

  localparam string HEX_FILE = "../hardware/test/fixtures_generated/uart_send_byte/ROM.hex";

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
  
  // UART RECEIVER for asserting Computer UART functionality
  logic uart_rx_data_ready_flag;
  logic [1:0] uart_rx_status_reg;
  logic [DATA_WIDTH-1:0] uart_rx_data_out; 
  uart_receiver #(
    .CLOCK_SPEED(DUT_CLOCK_SPEED_HZ),
    .BAUD_RATE(DUT_BAUD_RATE),
  ) uart_receiver (
    .clk(clk),
    .reset(reset),
    .rx_serial_in_data(uut_uart_tx_signal),
    .rx_strobe_data_ready_level(uart_rx_data_ready_flag),
    .rx_parallel_data_out(uart_rx_data_out),
    .rx_status_reg(uart_rx_status_reg)
  );

  // UNIT UNDER TEST
  computer uut (
        .clk(clk),
        .reset(reset),
        .uart_tx(uut_uart_tx_signal)
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
    safe_readmemh_rom(HEX_FILE);  
    uut.u_rom.dump(); 

    // Apply reset and wait for it to release
    reset_and_wait(0); 

    // --- Execute the instruction ---
    $display("\n\nRunning UART_SEND_BYTE test");

    wait( uart_rx_data_ready_flag == 1);
    pretty_print_assert_vec(uart_rx_data_out, 8'h41, "DESERIALIZED MESSAGE == x41");    

    $display("UART_SEND_BYTE test finished.===========================\n\n");
    $finish;
  end

endmodule