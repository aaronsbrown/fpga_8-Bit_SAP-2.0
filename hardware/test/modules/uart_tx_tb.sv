`timescale 1ns/1ps

import test_utils_pkg::*;
import arch_defs_pkg::*;

module uart_tx_tb;

    // DUT CONFIG
    localparam DUT_CLOCK_SPEED_HZ = 2_000_000;
    localparam DUT_BAUD_RATE = 9600;
    localparam WORD_SIZE = DATA_WIDTH;
    
    // TB CONFIG
    localparam TB_CLOCK_HALF_PERIOD_NS = 5;
    localparam TB_CLOCK_PERIOD_NS = TB_CLOCK_HALF_PERIOD_NS * 2;
    
    // UART CONFIG
    localparam TX_BITS_IN_FRAME = 1 + WORD_SIZE + 1; // start - data - stop
    localparam SIGNAL_STOP_BIT = 1'b1;
    localparam SIGNAL_START_BIT = 1'b0;
    localparam SIGNAL_IDLE_BIT = 1'b1;

    //DERIVED TIMINGS 
    localparam TB_CYCLES_PER_BIT = DUT_CLOCK_SPEED_HZ / DUT_BAUD_RATE;
    localparam TB_CYCLES_TO_MID_BIT = TB_CYCLES_PER_BIT / 2;
    localparam TB_CYCLES_PER_FRAME = TX_BITS_IN_FRAME * TB_CYCLES_PER_BIT;
    
    // time out for wait signals
    localparam TIMEOUT_CYCLES_BUSY_ACK = 20;
    localparam TIMEOUT_CYCLES_DUT = TB_CYCLES_PER_FRAME * 2;
    

    // testbench signals
    logic clk, reset;
    logic [WORD_SIZE:0] dut_data_in;
    logic dut_start_strobe;

    // DUT outputs
    wire dut_data_out;
    wire dut_busy_flag;

    uart_transmitter #(
        .CLOCK_SPEED(DUT_CLOCK_SPEED_HZ),
        .BAUD_RATE(DUT_BAUD_RATE),
        .WORD_SIZE(WORD_SIZE)
    ) uut (
        .clk(clk),
        .reset(reset),
        
        .tx_parallel_data_in(dut_data_in),
        .tx_strobe_start(dut_start_strobe),

        .tx_strobe_busy(dut_busy_flag),
        .tx_serial_data_out(dut_data_out)
    );

  // --- Clock Generation: 10 ns period ---
  initial begin clk = 0;  forever #TB_CLOCK_HALF_PERIOD_NS clk = ~clk; end

  // ================================
  // -- TASK HELPERS
  // ================================
  
  // input = byte to test
  // apply byte to tx_parallel_in
  // pulse tx_strobe_start
  // wait for "non_busy"
  // validation
  task send_uart_byte( input [WORD_SIZE-1:0] byte_to_send );

    logic expected_serial_bit;
    logic [TX_BITS_IN_FRAME-1:0] frame_to_verify;
    integer cycles_elapsed; 

    frame_to_verify = {SIGNAL_STOP_BIT, byte_to_send, SIGNAL_STOP_BIT};

    // Ensure UART Transmitter is NOT busy before sending byte
    cycles_elapsed = 0;
    while (dut_busy_flag == 1'b1 && cycles_elapsed < TIMEOUT_CYCLES_DUT) begin
      @(posedge clk);
      cycles_elapsed++;
    end
    if(dut_busy_flag == 1'b1) begin
      $display("Timeout (after %0d cycles) waiting for DUT to be IDLE (dut_busy_flag == 0) before sending byte at time %0t", cycles_elapsed, $time);
      return;
    end

    // advance to known clock edge
    @(posedge clk);

    $display("TB: Sending byte %h at time %0t", byte_to_send, $time);
    dut_data_in = byte_to_send;
    
    @(negedge clk);
    dut_start_strobe = 1'b1;
    @(negedge clk);
    dut_start_strobe = 1'b0;
    
    // Ensure UART Transmitter BECOMES busy AFTER initiating send
    
    cycles_elapsed = 0;
    while(dut_busy_flag == 1'b0 && cycles_elapsed < TIMEOUT_CYCLES_BUSY_ACK) begin
      @(posedge clk);
      cycles_elapsed++;
    end
    if(dut_busy_flag == 1'b0) begin
      $display("Timeout (after %0d cycles) waiting for DUT to be BUSY (dut_busy_flag == 1) after initiating send at time %0t", cycles_elapsed, $time);
      return; 
    end

    // Wait for UART Transmitter to FINISH sending byte, and return to IDLE state
    cycles_elapsed = 0;
    while(dut_busy_flag == 1'b1 && cycles_elapsed < TIMEOUT_CYCLES_DUT) begin
      @(posedge clk);
      cycles_elapsed++;
    end
    if(dut_busy_flag == 1'b1) begin
      $display("Timeout (after %0d cycles) waiting for DUT to be IDLE (dut_busy_flag == 0) after finishing byte transmission at time %0t", cycles_elapsed, $time);
      return;  
    end
    
    // advance to known clock edge
    @(posedge clk);

    $display("TB: Finished sending byte %h at time %0t. DUT busy: %b", byte_to_send, $time, dut_busy_flag);
    pretty_print_assert_vec(uut.current_state, S_UART_TX_IDLE,
      "send_uart_byte: current_state = S_UART_TX_IDLE after send");
    pretty_print_assert_vec(uut.tx_strobe_busy, 1'b0, 
      "send_uart_byte: tx_strobe_busy == 0 after send");  

  endtask


  // --- Testbench Stimulus ---
  initial begin

    // Setup waveform dumping
    $dumpfile("waveform.vcd");
    $dumpvars(0, uart_tx_tb); // Dump all signals in this module and below

    dut_start_strobe = 1'b0;
    
    // --- Execute the instruction ---
    $display("\n\nRunning UART_TX test");

    // Apply reset and wait for it to release
    reset_and_wait(10); 
    pretty_print_assert_vec(dut_start_strobe, 1'b0, "tx_start_strobe == 0"); 
    pretty_print_assert_vec(dut_busy_flag, 1'b0, "busy_flag == 0");

    $display("TB: Forcing DUT busy to test first timeout...");
    force uut.i_tx_strobe_busy = 1'b1;
    send_uart_byte(8'hAA);
    release uut.i_tx_strobe_busy;


    send_uart_byte(8'h55); 
    
    repeat(10) @(posedge clk);

    send_uart_byte(8'hF0);


    $display("UART_TX test finished.\n\n");
    $finish;

  end
endmodule