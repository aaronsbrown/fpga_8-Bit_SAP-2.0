module ram_tb;
	reg clk;
	reg we;
	reg oe;
	reg [3:0] address;
	reg [7:0] data_in;
	wire [7:0] data_out;
	ram uut(
		.clk(clk),
		.we(we),
		.oe(oe),
		.address(address),
		.data_in(data_in),
		.data_out(data_out)
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
		$dumpvars(0, ram_tb);
		we = 0;
		oe = 0;
		address = 4'b0000;
		data_in = 8'h00;
		@(posedge clk)
			;
		@(negedge clk)
			;
		address = 4'h3;
		data_in = 8'hab;
		we = 1;
		@(posedge clk)
			;
		@(negedge clk)
			;
		we = 0;
		@(posedge clk)
			;
		@(negedge clk)
			;
		oe = 1;
		@(posedge clk)
			;
		@(posedge clk)
			;
		$display("Read data: %h (expected AB)", data_out);
		pretty_print_assert_vec(data_out, 8'hab, "Data Out is hAB");
		@(negedge clk)
			;
		oe = 0;
		@(posedge clk)
			;
		@(negedge clk)
			;
		address = 4'ha;
		data_in = 8'hcd;
		we = 1;
		@(posedge clk)
			;
		@(negedge clk)
			;
		we = 0;
		@(posedge clk)
			;
		@(negedge clk)
			;
		oe = 1;
		@(posedge clk)
			;
		@(posedge clk)
			;
		$display("Read data: %h (expected CD)", data_out);
		pretty_print_assert_vec(data_out, 8'hcd, "Data Out is hCD");
		@(negedge clk)
			;
		oe = 0;
		$display("RAM test complete at time %0t", $time);
		$finish;
	end
endmodule
