`timescale 1ns / 1ps
import test_utils_pkg::*; 


module program_counter_tb;
    logic clk;
    logic reset, enable, load_high_byte, load_low_byte;
    logic [7:0] counter_in;
    logic [15:0] counter_out;

    // Instantiate the DUT
    program_counter uut (
        .clk(clk),
        .reset(reset),
        .enable(enable),
        .load_high_byte(load_high_byte),
        .load_low_byte(load_low_byte),
        .counter_in(counter_in),
        .counter_out(counter_out)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns clock period
    end

    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, program_counter_tb);

        // Initialize control signals
        reset = 1;
        enable = 0;
        load_high_byte = 0;
        load_low_byte = 0;
        counter_in = 0;

        @(posedge clk);
        
        @(negedge clk);
        reset = 0;
        enable = 1;

        @(posedge clk);
        #1
        pretty_print_assert_vec(counter_out, 16'h0001, "Counter is 1");
        
        repeat (3) @(posedge clk);
        #1
        pretty_print_assert_vec(counter_out, 16'h0004, "Counter is 4");
       
        // Load high byte
        @(negedge clk);
        load_high_byte = 1;
        counter_in = 8'h0A; 

        @(posedge clk);
        #1
        pretty_print_assert_vec(counter_out, 16'h0A04, "Counter loaded with high byte: 0x0A");

        // Load low byte            
        @(negedge clk);
        load_high_byte = 0;
        load_low_byte = 1;
        counter_in = 8'hFF; 
        
        @(posedge clk);
        #1
        pretty_print_assert_vec(counter_out, 16'h0AFF, "Counter loaded with low byte: 0xFF");

        @(negedge clk);
        load_low_byte = 0;
        
        @(negedge clk);
        reset = 1;
        
        @(posedge clk);
        #1    
        pretty_print_assert_vec(counter_out, 16'h0000, "Counter is 0 after reset");

        @(posedge clk);
        $display("RAM test complete at time %0t", $time);
        $finish;
    end

endmodule