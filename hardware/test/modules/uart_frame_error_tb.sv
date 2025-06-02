`timescale 1ns/1ps
import test_utils_pkg::*; 
import arch_defs_pkg::*;  

module computer_tb;

  localparam string HEX_FILE = "../hardware/test/fixtures_generated/uart_frame_error/ROM.hex";

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
  reg [DATA_WIDTH-1:0] computer_output;
  wire stim_serial_data_out;
  reg tb_force_frame_error;
    
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
    .tx_force_frame_error(tb_force_frame_error),
    .tx_strobe_busy(stim_busy_flag),
    .tx_serial_data_out(stim_serial_data_out)
  );


  // =======================================
  // UNIT UNDER TEST
  computer uut (
        .clk(clk),
        .reset(reset),
        .uart_rx(stim_serial_data_out),
        .output_port_1(computer_output)
    );

  //
  task send_uart_byte( input [WORD_SIZE-1:0] byte_to_send, input force_error);
    // --- Sent byte via external Transmitter
      repeat(1) @(negedge clk);
      stim_data_in = byte_to_send; 
      stim_start_strobe = 1'b1; 
      tb_force_frame_error = force_error;

      repeat(1) @(negedge clk);
      stim_start_strobe = 1'b0; 
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
    $display("\n\nRunning UART_FRAME_ERROR test");
    send_uart_byte(8'hDD, 1'b1);

    //repeat(3000) @(posedge clk); 
    wait(uut.u_uart.cmd_clear_frame_error == 1);
    pretty_print_assert_vec(computer_output, 8'hEE, "error_code on output_port_1");

    // visual buffer for waveform
    repeat(100) @(posedge clk);
    
    $display("UART_FRAME_ERROR test finished.===========================\n\n");
    $finish;
  end

endmodule