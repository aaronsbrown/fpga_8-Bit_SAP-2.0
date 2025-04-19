module ram (
	clk,
	we,
	address,
	data_in,
	data_out
);
	input wire clk;
	input wire we;
	input wire [3:0] address;
	input wire [7:0] data_in;
	output reg [7:0] data_out;
	reg [127:0] ram = 128'h1f4ee086e09000000000000000000a0f;
	always @(posedge clk) begin
		if (we)
			ram[(15 - address) * 8+:8] <= data_in;
		data_out <= ram[(15 - address) * 8+:8];
	end
	integer i;
	initial begin
		$display("Initializing RAM from program.hex");
		for (i = 0; i < 16; i = i + 1)
			$display("RAM[%0d] = %02h", i, ram[(15 - i) * 8+:8]);
	end
endmodule
