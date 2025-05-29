// SYMBOL TABLE from ASM log
// UART_CONTROL_REG' -> 0xE000
// INFO:   'UART_STATUS_REG' -> 0xE001
// INFO:   'UART_DATA_REG' -> 0xE002
// INFO:   'MASK_TX_BUFFER_EMPTY' -> 0x0001
// INFO:   'MASK_RX_DATA_READY' -> 0x0002
// INFO:   'MASK_ERROR_FRAME' -> 0x0004
// INFO:   'MASK_ERROR_OVERSHOOT' -> 0x0008
// INFO:   'START_ECHO' -> 0xF000
// INFO:   'RX_POLL_LOOP' -> 0xF000
// INFO:   'TX_POLL_LOOP' -> 0xF00C

`timescale 1ns/1ps
import test_utils_pkg::*; 
import arch_defs_pkg::*;  

module computer_tb;

  localparam string HEX_FILE = "../hardware/test/fixtures_generated/prog_uart_echo_error_handling/ROM.hex";

  localparam DUT_CLOCK_SPEED_HZ = 2_000_000;
  localparam DUT_BAUD_RATE = 9600;
  localparam WORD_SIZE = DATA_WIDTH;

  defparam uut.u_uart.u_transmitter.CLOCK_SPEED = DUT_CLOCK_SPEED_HZ;
  defparam uut.u_uart.u_transmitter.BAUD_RATE  = DUT_BAUD_RATE;

  defparam uut.u_uart.u_receiver.CLOCK_SPEED = DUT_CLOCK_SPEED_HZ;
  defparam uut.u_uart.u_receiver.BAUD_RATE  = DUT_BAUD_RATE;
  
  // =======================================
  // TESTBENCH SIGNALS
  reg clk;
  reg reset;
  wire computer_uart_tx_signal;
  reg tb_read_data_ack_pulse;
  
  // =======================================
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


  // =======================================
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
    .rx_serial_in_data(computer_uart_tx_signal),
    .cpu_read_data_ack_pulse(tb_read_data_ack_pulse),
    .rx_strobe_data_ready_level(uart_rx_data_ready_flag),
    .rx_parallel_data_out(uart_rx_data_out),
    .rx_status_reg(uart_rx_status_reg)
  );


  // =======================================
  // UNIT UNDER TEST
  computer uut (
        .clk(clk),
        .reset(reset),
        .uart_tx(computer_uart_tx_signal),
        .uart_rx(stim_serial_data_out)
    );

  //
  task send_uart_byte( input [WORD_SIZE-1:0] byte_to_send);
    // --- Sent byte via external Transmitter
      repeat(1) @(negedge clk);
      stim_data_in = byte_to_send; 
      stim_start_strobe = 1'b1; 

      repeat(1) @(negedge clk);
      stim_start_strobe = 1'b0; 
  endtask

  task read_and_assert_uart_byte(input [WORD_SIZE-1:0] expected_value, input string msg);
      wait( uart_rx_data_ready_flag == 1);
      pretty_print_assert_vec(uart_rx_data_out, expected_value, msg);    
    
      @(negedge clk); 
      tb_read_data_ack_pulse = 1'b1;
      @(negedge clk);
      tb_read_data_ack_pulse = 1'b0; 
  endtask 

  // =======================================
  // TEST BENCH SIM CODE

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
    $display("\n\nRunning UART_ECHO test");

    send_uart_byte(8'hB7); 
    read_and_assert_uart_byte(8'hB7, "DESERIALIZED MESSAGE == xB7");
    
    send_uart_byte(8'hC7); 
    read_and_assert_uart_byte(8'hC7, "DESERIALIZED MESSAGE == xC7");

    send_uart_byte(8'hFF); 
    read_and_assert_uart_byte(8'hFF, "DESERIALIZED MESSAGE == xFF");

    // visual buffer for waveform
    repeat(100) @(posedge clk);
    
    $display("UART_ECHO test finished.\n\n");
    $finish;
  end

endmodule