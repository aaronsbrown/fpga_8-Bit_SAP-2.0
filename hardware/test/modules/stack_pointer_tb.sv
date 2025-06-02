`timescale 1ns / 1ps
import test_utils_pkg::*; 
import arch_defs_pkg::*;  


module stack_pointer_tb;
    logic clk;
    logic reset, increment, decrement, load_initial_address;
    logic [ADDR_WIDTH-1:0]     address_in;
    logic [ADDR_WIDTH-1:0]   address_out;

    // Instantiate the DUT
    stack_pointer uut (
        .clk(clk),
        .reset(reset),
        .increment(increment),
        .decrement(decrement),
        .load_initial_address(load_initial_address),
        .address_in(address_in),
        .address_out(address_out)
    );

    initial begin clk = 0; forever #5 clk = ~clk; end

    initial begin

        $dumpfile("waveform.vcd");
        $dumpvars(0, stack_pointer_tb);

        // Initialize control signals
        increment = 0;
        decrement = 0;
        load_initial_address = 0;
        address_in = {DATA_WIDTH{1'b0}};
        address_out = {ADDR_WIDTH{1'b0}};

        $display("\n\nRunning Stack Pointer test");
        
        reset_and_wait(0); 
        pretty_print_assert_vec(address_out, 16'h0000, "Reset SP to x0000");    

        @(negedge clk);
        address_in = 16'h01FF;
        load_initial_address = 1'b1;

        @(posedge clk); #0.1;
        pretty_print_assert_vec(address_out, 16'h01FF, "Initialized SP to x01FF");    

        @(negedge clk);
        load_initial_address = 1'b0;
        decrement = 1'b1;

        @(posedge clk); #0.1;
        pretty_print_assert_vec(address_out, 16'h01FE, "Decremented SP to x01FE");    

        @(negedge clk);
        decrement = 1'b0;
        increment = 1'b1;

        @(posedge clk); #0.1;
        pretty_print_assert_vec(address_out, 16'h01FF, "Incremented SP to x01FF");    

        $display("stack_pointer test finished.===========================\n\n");        
        $finish;
    end

endmodule