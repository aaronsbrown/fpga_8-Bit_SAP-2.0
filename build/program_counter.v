module program_counter (
	clk,
	reset,
	enable,
	load,
	counter_in,
	counter_out
);
	parameter ADDR_WIDTH = 4;
	input wire clk;
	input wire reset;
	input wire enable;
	input wire load;
	input wire [ADDR_WIDTH - 1:0] counter_in;
	output reg [ADDR_WIDTH - 1:0] counter_out;
	always @(posedge clk)
		if (reset)
			counter_out <= {ADDR_WIDTH {1'b0}};
		else if (load)
			counter_out <= counter_in;
		else if (enable)
			counter_out <= counter_out + 1;
endmodule
