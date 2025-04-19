module alu (
	clk,
	reset,
	a_in,
	b_in,
	alu_op,
	result_out,
	zero_flag,
	carry_flag,
	negative_flag
);
	input wire clk;
	input wire reset;
	input wire [7:0] a_in;
	input wire [7:0] b_in;
	input wire [1:0] alu_op;
	output reg [7:0] result_out;
	output reg zero_flag;
	output reg carry_flag;
	output reg negative_flag;
	always @(posedge clk or posedge reset)
		if (reset) begin
			result_out <= 8'b00000000;
			carry_flag <= 1'b0;
			zero_flag <= 1'b0;
		end
		else begin
			case (alu_op)
				2'b00: {carry_flag, result_out} <= a_in + b_in;
				2'b01: {carry_flag, result_out} <= a_in - b_in;
				2'b10: begin
					result_out <= a_in & b_in;
					carry_flag <= 1'b0;
				end
				2'b11: begin
					result_out <= a_in | b_in;
					carry_flag <= 1'b0;
				end
				default: begin
					result_out <= 8'b00000000;
					carry_flag <= 1'b0;
				end
			endcase
			zero_flag <= result_out == 8'b00000000;
			negative_flag <= result_out[7];
		end
endmodule
