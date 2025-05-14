`timescale 1ns/1ps

import test_utils_pkg::*;
import arch_defs_pkg::*;

module uart_tx_tb;

    // testbench signals
    logic clk, reset;
    logic [7:0] dut_data_in;
    logic dut_start_strobe;

    // DUT outputs
    wire dut_data_out;
    wire dut_busy_flag;

    uart_transmitter #(
        .CLOCK_SPEED(200_000)
    ) uut (
        .clk(clk),
        .reset(reset),
        
        .tx_parallel_in_data(dut_data_in),
        .tx_start_strobe(dut_start_strobe),

        .busy_flag(dut_busy_flag),
        .data_out(dut_data_out)
    );

    // --- Clock Generation: 10 ns period ---
  initial begin clk = 0;  forever #5 clk = ~clk; end

  // --- Testbench Stimulus ---
  initial begin

    // Setup waveform dumping
    $dumpfile("waveform.vcd");
    $dumpvars(0, uart_tx_tb); // Dump all signals in this module and below

    // Simulate data on memory bus
    dut_data_in = 8'b10101010;
    dut_start_strobe = 1'b0;
    
    // --- Execute the instruction ---
    $display("\n\nRunning UART_TX test");

    // Apply reset and wait for it to release
    reset_and_wait(10); 
    pretty_print_assert_vec(uut.tx_start_strobe, 1'b0, "tx_start_strobe == 0"); 
    pretty_print_assert_vec(uut.busy_flag, 1'b0, "busy_flag == 0"); 

    repeat(1) @(negedge clk);
    dut_start_strobe = 1'b1;
    pretty_print_assert_vec(uut.current_state, S_UART_TX_IDLE, "current_state == S_UART_TX_IDLE");  
    pretty_print_assert_vec(uut.tx_start_strobe, 1'b1, "tx_start_strobe == 1"); 
    pretty_print_assert_vec(uut.data_out, 1'b1, "data_out == 1"); 
    #01;
    pretty_print_assert_vec(uut.busy_flag, 1'b1, "busy_flag == 1");

    repeat(1) @(posedge clk); #01;
    pretty_print_assert_vec(uut.current_state, S_UART_TX_START, "current_state == S_UART_TX_START");
    pretty_print_assert_vec(uut.data_out, 1'b0, "data_out == 0");
    
    repeat(1) @(negedge clk);
    dut_start_strobe = 1'b0;
    
    repeat(20) @(posedge clk); #01;

    pretty_print_assert_vec(uut.current_state, S_UART_TX_SEND_DATA, "current_state == S_UART_TX_SEND_DATA");
    pretty_print_assert_vec(uut.busy_flag, 1'b1, "busy_flag == 1");
    pretty_print_assert_vec(uut.data_out, 1'b0, "data_out == 0"); // LSB 1010101[0]
    pretty_print_assert_vec(uut.tx_shift_reg, 8'b10101010, "tx_shift_reg == 10101010"); // LSB 1010101[0]


    repeat(20) @(posedge clk); #01;

    pretty_print_assert_vec(uut.current_state, S_UART_TX_SEND_DATA, "current_state == S_UART_TX_SEND_DATA");
    pretty_print_assert_vec(uut.busy_flag, 1'b1, "busy_flag == 1");
    pretty_print_assert_vec(uut.data_out, 1'b1, "data_out == 1"); // LSB 1 + 101010[1]
    pretty_print_assert_vec(uut.tx_shift_reg, 8'b11010101, "tx_shift_reg == 11010101"); 


    repeat(100) @(posedge clk); #01;

    pretty_print_assert_vec(uut.current_state, S_UART_TX_SEND_DATA, "current_state == S_UART_TX_SEND_DATA");
    pretty_print_assert_vec(uut.busy_flag, 1'b1, "busy_flag == 1");
    pretty_print_assert_vec(uut.data_out, 1'b0, "data_out == 0"); // LSB 1111111[0]
    pretty_print_assert_vec(uut.tx_shift_reg, 8'b11111110, "tx_shift_reg == 11111110"); 
    
    repeat(20) @(posedge clk); #01;

    pretty_print_assert_vec(uut.current_state, S_UART_TX_SEND_DATA, "current_state == S_UART_TX_SEND_DATA");
    pretty_print_assert_vec(uut.busy_flag, 1'b1, "busy_flag == 1");
    pretty_print_assert_vec(uut.data_out, 1'b1, "data_out == 1"); // LSB 1111111[0]
    pretty_print_assert_vec(uut.tx_shift_reg, 8'b11111111, "tx_shift_reg == 11111111"); // [1]0101010

    repeat(20) @(posedge clk); #01;

    pretty_print_assert_vec(uut.current_state, S_UART_TX_STOP, "current_state == S_UART_TX_STOP");
    pretty_print_assert_vec(uut.busy_flag, 1'b1, "busy_flag == 1");
    pretty_print_assert_vec(uut.data_out, 1'b1, "data_out == 1");

    repeat(20) @(posedge clk); #01;
    pretty_print_assert_vec(uut.current_state, S_UART_TX_IDLE, "current_state == S_UART_TX_IDLE");
    pretty_print_assert_vec(uut.busy_flag, 1'b0, "busy_flag == 0");
    pretty_print_assert_vec(uut.data_out, 1'b1, "data_out == 1");

    $display("UART_TX test finished.\n\n");
    $finish;

  end
endmodule