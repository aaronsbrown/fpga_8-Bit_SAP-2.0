`timescale 1ns/1ps
import test_utils_pkg::*; 
import arch_defs_pkg::*;  

module computer_tb;

  localparam string HEX_FILE = "../hardware/test/fixtures_generated/prog_uart_overshoot_error/ROM.hex";

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
  
  
  // =======================================
  // UART TRANSMITTER to generate test stimulus
  logic stim_start_strobe;
  logic [DATA_WIDTH-1:0] stim_data_in;
  logic stim_busy_flag;
  logic stim_serial_data_out;
  logic tb_force_frame_error;
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
    $display("\n\nRunning UART_OVERSHOOT_ERROR test");
    
    // Send byte 1
    $display("TB: Sending 1st byte (0xAB) to DUT.");
    send_uart_byte(8'hAB, 1'b0);

    $display("TB: Waiting for TB UART to finish sending 1st byte (stim_busy_flag == 0)...");
    wait (stim_busy_flag == 0); // stim_busy_flag is the tx_strobe_busy output of testbench's transmitter
    $display("TB: TB UART finished sending 1st byte.");

    // Wait for receiver to signal byte 1 ready for read
    $display("TB: Waiting for DUT's uart_receiver to process 1st byte (rx_strobe_data_ready_level == 1)...");
    wait(uut.u_uart.u_receiver.rx_strobe_data_ready_level == 1);
    $display("TB: DUT's uart_receiver signaled 1st byte is ready. (rx_strobe_data_ready_level is HIGH)");

    // Send byte 2 (prior to CPU read of byte 1)
    $display("TB: Instructing TB UART to send 2nd byte (e.g., 0xBB)...");
    send_uart_byte(8'hBB, 1'b0);
    $display("TB: Sent 2nd byte (0xBB) to DUT. Overrun should occur now.");
 
    wait (stim_busy_flag == 0);
    $display("TB: TB UART finished sending 2nd byte.");
 
    //  Wait for overrun_error_handling via CPU
    $display("TB: Waiting for CPU to detect and handle overrun...");
    wait (uut.u_uart.cmd_clear_overshoot_error == 1);
    pretty_print_assert_vec(computer_output, 8'h66, "overrun_error_code on output_port_1");
    pretty_print_assert_vec(uut.u_uart.status_reg_i[3'd3], 1'b1, "overshoot error bit high while clear command goes high");

    @(posedge clk); #0.01;
    pretty_print_assert_vec(uut.u_uart.status_reg_i[3'd3], 1'b0, "overshoot error bit cleared next cycle");

    
    // visual buffer for waveform
    repeat(100) @(posedge clk);
    
    $display("UART_OVERSHOOT_ERROR test finished.===========================\n\n");
    $finish;
  end

endmodule