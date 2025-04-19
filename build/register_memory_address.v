module memory_address_register (
	clk,
	reset,
	data_in,
	data_out
);
	input wire clk;
	input wire reset;
	input wire [7:0] data_in;
	output wire [7:0] data_out;
endmodule
