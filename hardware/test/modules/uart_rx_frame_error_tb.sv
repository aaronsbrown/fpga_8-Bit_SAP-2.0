`timescale 1ns/1ps

import test_utils_pkg::*;
import arch_defs_pkg::*;

module uart_rx_tb;
    
    localparam CLOCK_SPEED = 2_000_000;
    localparam BAUD_RATE = 9600;

    // Shared signals
    logic clk, reset;
    logic tb_force_frame_error;

    // STIMULUS GENERATOR
    logic stim_start_strobe;
    logic [DATA_WIDTH-1:0] stim_data_in;
    logic stim_busy_flag;
    logic stim_serial_data_out;
    uart_transmitter #(
        .CLOCK_SPEED(CLOCK_SPEED),
        .BAUD_RATE(BAUD_RATE)
    ) uart_transmitter (
        .clk(clk),
        .reset(reset),
        .tx_parallel_data_in(stim_data_in),
        .tx_strobe_start(stim_start_strobe),
        .tx_force_frame_error(tb_force_frame_error),
        .tx_strobe_busy(stim_busy_flag),
        .tx_serial_data_out(stim_serial_data_out)
    );


    // DEVICE UNDER TEST
    logic dut_strobe_data_ready;
    logic [1:0] dut_status;
    logic [DATA_WIDTH-1:0] dut_data_out;
    uart_receiver #(
        .CLOCK_SPEED(CLOCK_SPEED),
        .BAUD_RATE(BAUD_RATE)
    ) uut (
        .clk(clk),
        .reset(reset),
        .rx_serial_in_data(stim_serial_data_out),
        .rx_strobe_data_ready_level(dut_strobe_data_ready),
        .rx_parallel_data_out(dut_data_out),
        .rx_status_reg(dut_status)
    );

    // --- Clock Generation: 10 ns period ---
    initial begin clk = 0;  forever #5 clk = ~clk; end

    // --- Testbench Stimulus ---
    initial begin

        // Setup waveform dumping
        $dumpfile("waveform.vcd");
        $dumpvars(0, uart_rx_tb); // Dump all signals in this module and below

        // Initialize test data
        stim_start_strobe = 1'b0;
        // --- Execute the instruction ---
        $display("\n\nRunning UART_RX test");

        // Apply reset and wait for it to release
        reset_and_wait(10); 
        
        repeat(1) @(negedge clk);
        stim_data_in = 8'b10110010; // xB2        
        stim_start_strobe = 1'b1; 
        tb_force_frame_error = 1'b1;

        repeat(1) @(negedge clk);
        stim_start_strobe = 1'b0;

        wait(uut.cmd_flag_frame_error == 1);
        @(posedge clk); #0.1;
        pretty_print_assert_vec(uut.rx_status_reg[0], 1'b1, "status reg reflects frame error");
  

        repeat(10) @(posedge clk);

        $display("UART_RX test finished.\n\n");
        $finish;

  end
endmodule