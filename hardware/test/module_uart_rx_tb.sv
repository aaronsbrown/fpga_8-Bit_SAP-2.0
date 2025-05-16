`timescale 1ns/1ps

import test_utils_pkg::*;
import arch_defs_pkg::*;

module uart_rx_tb;

    // testbench signals
    logic clk, reset;

    logic dut_serial_in;

    uart_receiver #(
        .CLOCK_SPEED(2_000_000)
    ) uut (
        .clk(clk),
        .reset(reset),
        .rx_serial_in_data(dut_serial_in)
    );

    // --- Clock Generation: 10 ns period ---
    initial begin clk = 0;  forever #5 clk = ~clk; end

    // --- Testbench Stimulus ---
    initial begin

        // Setup waveform dumping
        $dumpfile("waveform.vcd");
        $dumpvars(0, uart_rx_tb); // Dump all signals in this module and below

        // --- Execute the instruction ---
        $display("\n\nRunning UART_RX test");

        dut_serial_in = 1'b1;

        // Apply reset and wait for it to release
        reset_and_wait(10); 
        
        repeat(1) @(negedge clk);
        dut_serial_in = 1'b0; 

        repeat(2000) @(posedge clk); #01;

        

        $display("UART_TX test finished.\n\n");
        $finish;

  end
endmodule