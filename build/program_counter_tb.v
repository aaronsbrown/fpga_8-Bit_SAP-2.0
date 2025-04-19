module program_counter_tb;
	reg clk;
	reg reset;
	reg enable;
	reg load;
	reg [3:0] counter_in;
	wire [3:0] counter_out;
	program_counter uut(
		.clk(clk),
		.reset(reset),
		.enable(enable),
		.load(load),
		.counter_in(counter_in),
		.counter_out(counter_out)
	);
	initial begin
		clk = 0;
		forever #(5) clk = ~clk;
	end
	task pretty_print_assert_vec;
		input [31:0] actual;
		input [31:0] expected;
		input [1023:0] msg;
		if (actual !== expected)
			$display("\033[0;31mAssertion Failed: %s. Actual: %0b, Expected: %0b\033[0m", msg, actual, expected);
		else
			$display("\033[0;32mAssertion Passed: %s\033[0m", msg);
	endtask
	initial begin
		$dumpfile("waveform.vcd");
		$dumpvars(0, program_counter_tb);
		reset = 1;
		enable = 0;
		load = 0;
		counter_in = 0;
		@(posedge clk)
			;
		@(negedge clk)
			;
		reset = 0;
		enable = 1;
		@(posedge clk)
			;
		#(1)
			pretty_print_assert_vec(counter_out, 4'b0001, "Counter is 1");
		repeat (3) @(posedge clk)
			;
		#(1)
			pretty_print_assert_vec(counter_out, 4'b0100, "Counter is 4");
		@(negedge clk)
			;
		load = 1;
		counter_in = 4'b1010;
		@(posedge clk)
			;
		#(1)
			pretty_print_assert_vec(counter_out, 4'b1010, "Counter loaded with 10");
		@(negedge clk)
			;
		load = 0;
		@(posedge clk)
			;
		#(1)
			pretty_print_assert_vec(counter_out, 4'b1011, "Counter is 11 after load");
		@(negedge clk)
			;
		reset = 1;
		@(posedge clk)
			;
		#(1)
			pretty_print_assert_vec(counter_out, 4'b0000, "Counter is 0 after reset");
		@(posedge clk)
			;
		$display("RAM test complete at time %0t", $time);
		$finish;
	end
endmodule
