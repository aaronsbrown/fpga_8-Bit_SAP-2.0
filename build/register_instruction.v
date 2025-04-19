module register_instruction (
	clk,
	reset,
	load,
	data_in,
	opcode,
	operand
);
	input wire clk;
	input wire reset;
	input wire load;
	input wire [7:0] data_in;
	output wire [3:0] opcode;
	output wire [3:0] operand;
	reg [7:0] instruction;
	always @(posedge clk)
		if (reset)
			instruction <= 1'sb0;
		else if (load)
			instruction <= data_in;
	assign opcode = instruction[7-:4];
	assign operand = instruction[3-:4];
endmodule
