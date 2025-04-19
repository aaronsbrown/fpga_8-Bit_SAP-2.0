module register_nbit (
	clk,
	reset,
	load,
	data_in,
	latched_data
);
	parameter N = 8;
	input clk;
	input reset;
	input load;
	input [N - 1:0] data_in;
	output reg [N - 1:0] latched_data;
	always @(posedge clk)
		if (reset)
			latched_data <= 4'b0000;
		else if (load)
			latched_data <= data_in;
endmodule
