module clock_divider (
	reset,
	clk_in,
	clk_out
);
	parameter DIV_FACTOR = 50000000;
	input wire reset;
	input wire clk_in;
	output reg clk_out;
	reg [32:0] counter;
	always @(posedge clk_in)
		if (reset) begin
			counter <= 0;
			clk_out <= 0;
		end
		else begin
			counter <= counter + 1;
			if (counter == (DIV_FACTOR - 1)) begin
				clk_out <= ~clk_out;
				counter <= 0;
			end
		end
endmodule
module alu (
	clk,
	reset,
	a_in,
	b_in,
	alu_op,
	latched_result,
	zero_flag,
	carry_flag,
	negative_flag
);
	reg _sv2v_0;
	input wire clk;
	input wire reset;
	localparam signed [31:0] arch_defs_pkg_DATA_WIDTH = 8;
	input wire [7:0] a_in;
	input wire [7:0] b_in;
	input wire [1:0] alu_op;
	output reg [7:0] latched_result;
	output wire zero_flag;
	output wire carry_flag;
	output wire negative_flag;
	reg [arch_defs_pkg_DATA_WIDTH:0] comb_arith_result_i;
	reg [7:0] comp_logic_result_i;
	reg comb_carry_out_i;
	reg [7:0] comb_result_final_i;
	always @(*) begin
		if (_sv2v_0)
			;
		comb_arith_result_i = {9 {1'b0}};
		comp_logic_result_i = {arch_defs_pkg_DATA_WIDTH {1'b0}};
		comb_carry_out_i = 1'b0;
		comb_result_final_i = {arch_defs_pkg_DATA_WIDTH {1'b0}};
		case (alu_op)
			2'b00: comb_arith_result_i = {1'b0, a_in} + {1'b0, b_in};
			2'b01: comb_arith_result_i = ({1'b0, a_in} + {1'b0, ~b_in}) + {{arch_defs_pkg_DATA_WIDTH {1'b0}}, 1'b1};
			2'b10: comp_logic_result_i = a_in & b_in;
			2'b11: comp_logic_result_i = a_in | b_in;
			default:
				;
		endcase
		if ((alu_op == 2'b00) || (alu_op == 2'b01)) begin
			comb_carry_out_i = comb_arith_result_i[arch_defs_pkg_DATA_WIDTH];
			comb_result_final_i = comb_arith_result_i[7:0];
		end
		else begin
			comb_carry_out_i = 1'b0;
			comb_result_final_i = comp_logic_result_i;
		end
	end
	assign carry_flag = comb_carry_out_i;
	assign zero_flag = comb_result_final_i == {arch_defs_pkg_DATA_WIDTH {1'b0}};
	assign negative_flag = comb_result_final_i[7];
	always @(posedge clk)
		if (reset)
			latched_result <= {arch_defs_pkg_DATA_WIDTH {1'b0}};
		else
			latched_result <= comb_result_final_i;
	initial _sv2v_0 = 0;
endmodule
module program_counter (
	clk,
	reset,
	enable,
	load,
	counter_in,
	counter_out
);
	input wire clk;
	input wire reset;
	input wire enable;
	input wire load;
	localparam signed [31:0] arch_defs_pkg_ADDR_WIDTH = 4;
	input wire [3:0] counter_in;
	output reg [3:0] counter_out;
	always @(posedge clk)
		if (reset)
			counter_out <= {arch_defs_pkg_ADDR_WIDTH {1'b0}};
		else if (load)
			counter_out <= counter_in;
		else if (enable)
			counter_out <= counter_out + 1;
endmodule
module ram (
	clk,
	we,
	address,
	data_in,
	data_out
);
	input wire clk;
	input wire we;
	localparam signed [31:0] arch_defs_pkg_ADDR_WIDTH = 4;
	input wire [3:0] address;
	localparam signed [31:0] arch_defs_pkg_DATA_WIDTH = 8;
	input wire [7:0] data_in;
	output wire [7:0] data_out;
	localparam signed [31:0] arch_defs_pkg_RAM_DEPTH = 16;
	reg [7:0] mem [0:15];
	reg [7:0] data_out_i;
	always @(posedge clk) begin
		if (we)
			mem[address] <= data_in;
		data_out_i <= mem[address];
	end
	assign data_out = data_out_i;
	task dump;
		integer j;
		begin
			$display("--- RAM Content Dump ---");
			for (j = 0; j < arch_defs_pkg_RAM_DEPTH; j = j + 1)
				$display("RAM[%0d] = %02h", j, mem[j]);
			$display("--- End RAM Dump ---");
		end
	endtask
	initial $readmemh("../fixture/default_program_synth.hex", mem);
endmodule
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
	localparam signed [31:0] arch_defs_pkg_DATA_WIDTH = 8;
	input wire [7:0] data_in;
	localparam signed [31:0] arch_defs_pkg_OPCODE_WIDTH = 4;
	output wire [3:0] opcode;
	localparam signed [31:0] arch_defs_pkg_OPERAND_WIDTH = arch_defs_pkg_DATA_WIDTH - arch_defs_pkg_OPCODE_WIDTH;
	output wire [arch_defs_pkg_OPERAND_WIDTH - 1:0] operand;
	reg [(arch_defs_pkg_OPCODE_WIDTH + arch_defs_pkg_OPERAND_WIDTH) - 1:0] instruction;
	function automatic [(arch_defs_pkg_OPCODE_WIDTH + arch_defs_pkg_OPERAND_WIDTH) - 1:0] sv2v_cast_A6704;
		input reg [(arch_defs_pkg_OPCODE_WIDTH + arch_defs_pkg_OPERAND_WIDTH) - 1:0] inp;
		sv2v_cast_A6704 = inp;
	endfunction
	always @(posedge clk)
		if (reset)
			instruction <= 1'sb0;
		else if (load)
			instruction <= sv2v_cast_A6704(data_in);
	assign opcode = instruction[arch_defs_pkg_OPCODE_WIDTH + (arch_defs_pkg_OPERAND_WIDTH - 1)-:((arch_defs_pkg_OPERAND_WIDTH + 3) >= (arch_defs_pkg_OPERAND_WIDTH + 0) ? ((arch_defs_pkg_OPCODE_WIDTH + (arch_defs_pkg_OPERAND_WIDTH - 1)) - (arch_defs_pkg_OPERAND_WIDTH + 0)) + 1 : ((arch_defs_pkg_OPERAND_WIDTH + 0) - (arch_defs_pkg_OPCODE_WIDTH + (arch_defs_pkg_OPERAND_WIDTH - 1))) + 1)];
	assign operand = instruction[arch_defs_pkg_OPERAND_WIDTH - 1-:arch_defs_pkg_OPERAND_WIDTH];
endmodule
module register_nbit (
	clk,
	reset,
	load,
	data_in,
	latched_data
);
	localparam signed [31:0] arch_defs_pkg_DATA_WIDTH = 8;
	parameter N = arch_defs_pkg_DATA_WIDTH;
	input clk;
	input reset;
	input load;
	input [N - 1:0] data_in;
	output reg [N - 1:0] latched_data;
	always @(posedge clk)
		if (reset)
			latched_data <= {N {1'b0}};
		else if (load)
			latched_data <= data_in;
endmodule
module control_unit (
	clk,
	reset,
	opcode,
	flags,
	control_word
);
	reg _sv2v_0;
	input wire clk;
	input wire reset;
	localparam signed [31:0] arch_defs_pkg_OPCODE_WIDTH = 4;
	input wire [3:0] opcode;
	input wire [2:0] flags;
	output reg [22:0] control_word;
	reg [2:0] current_state = 3'd0;
	reg [2:0] next_state = 3'd0;
	reg [3:0] current_step;
	reg [3:0] next_step;
	always @(posedge clk)
		if (reset) begin
			current_state <= 3'd0;
			current_step <= 4'd0;
		end
		else begin
			current_state <= next_state;
			current_step <= next_step;
		end
	reg check_jump_condition = 1'b0;
	reg jump_condition_satisfied = 1'b0;
	reg [22:0] microcode_rom [0:15][0:7];
	always @(*) begin
		if (_sv2v_0)
			;
		next_state = current_state;
		next_step = current_step;
		control_word = 23'h000000;
		case (current_state)
			3'd0: next_state = 3'd1;
			3'd1: begin
				control_word = 23'h040000;
				next_state = 3'd2;
			end
			3'd2: begin
				control_word = 23'h048000;
				next_state = 3'd3;
			end
			3'd3: begin
				control_word = 23'h002000;
				next_state = 3'd4;
			end
			3'd4: begin
				control_word = 23'h122000;
				next_state = 3'd6;
			end
			3'd6: next_state = 3'd5;
			3'd5: begin
				control_word = microcode_rom[opcode][current_step];
				check_jump_condition = (control_word[7] || control_word[6]) || control_word[5];
				jump_condition_satisfied = ((control_word[7] && flags[0]) || (control_word[6] && flags[1])) || (control_word[5] && flags[2]);
				if (control_word[22]) begin
					next_state = 3'd7;
					next_step = 4'd0;
				end
				else if (check_jump_condition && !jump_condition_satisfied) begin
					control_word[19] = 1'b0;
					next_state = 3'd1;
					next_step = 4'd0;
				end
				else if (control_word[21]) begin
					next_state = 3'd1;
					next_step = 4'd0;
				end
				else
					next_step = current_step + 1;
			end
			3'd7: begin
				control_word = 23'h000000;
				next_state = 3'd7;
			end
			default: begin
				control_word = 23'h000000;
				next_state = 3'd7;
			end
		endcase
	end
	function automatic [3:0] sv2v_cast_953D0;
		input reg [3:0] inp;
		sv2v_cast_953D0 = inp;
	endfunction
	initial begin
		begin : sv2v_autoblock_1
			reg signed [31:0] i;
			for (i = 0; i < 16; i = i + 1)
				begin : sv2v_autoblock_2
					reg signed [31:0] s;
					for (s = 0; s < 8; s = s + 1)
						microcode_rom[i][s] = 23'h000000;
				end
		end
		microcode_rom[sv2v_cast_953D0(4'b0000)][4'd0] = 23'h200000;
		microcode_rom[sv2v_cast_953D0(4'b0001)][4'd0] = 23'h010000;
		microcode_rom[sv2v_cast_953D0(4'b0001)][4'd1] = 23'h018000;
		microcode_rom[sv2v_cast_953D0(4'b0001)][4'd2] = 23'h002000;
		microcode_rom[sv2v_cast_953D0(4'b0001)][4'd3] = 23'h202310;
		microcode_rom[sv2v_cast_953D0(4'b0010)][4'd0] = 23'h010000;
		microcode_rom[sv2v_cast_953D0(4'b0010)][4'd1] = 23'h018000;
		microcode_rom[sv2v_cast_953D0(4'b0010)][4'd2] = 23'h002000;
		microcode_rom[sv2v_cast_953D0(4'b0010)][4'd3] = 23'h202304;
		microcode_rom[sv2v_cast_953D0(4'b0011)][4'd0] = 23'h010000;
		microcode_rom[sv2v_cast_953D0(4'b0011)][4'd1] = 23'h018000;
		microcode_rom[sv2v_cast_953D0(4'b0011)][4'd2] = 23'h002000;
		microcode_rom[sv2v_cast_953D0(4'b0011)][4'd3] = 23'h002004;
		microcode_rom[sv2v_cast_953D0(4'b0011)][4'd4] = 23'h000600;
		microcode_rom[sv2v_cast_953D0(4'b0011)][4'd5] = 23'h200410;
		microcode_rom[sv2v_cast_953D0(4'b0100)][4'd0] = 23'h010000;
		microcode_rom[sv2v_cast_953D0(4'b0100)][4'd1] = 23'h018000;
		microcode_rom[sv2v_cast_953D0(4'b0100)][4'd2] = 23'h002000;
		microcode_rom[sv2v_cast_953D0(4'b0100)][4'd3] = 23'h002004;
		microcode_rom[sv2v_cast_953D0(4'b0100)][4'd4] = 23'h000e00;
		microcode_rom[sv2v_cast_953D0(4'b0100)][4'd5] = 23'h200410;
		microcode_rom[sv2v_cast_953D0(4'b0101)][4'd0] = 23'h010000;
		microcode_rom[sv2v_cast_953D0(4'b0101)][4'd1] = 23'h018000;
		microcode_rom[sv2v_cast_953D0(4'b0101)][4'd2] = 23'h002000;
		microcode_rom[sv2v_cast_953D0(4'b0101)][4'd3] = 23'h002004;
		microcode_rom[sv2v_cast_953D0(4'b0101)][4'd4] = 23'h001600;
		microcode_rom[sv2v_cast_953D0(4'b0101)][4'd5] = 23'h200410;
		microcode_rom[sv2v_cast_953D0(4'b0110)][4'd0] = 23'h010000;
		microcode_rom[sv2v_cast_953D0(4'b0110)][4'd1] = 23'h018000;
		microcode_rom[sv2v_cast_953D0(4'b0110)][4'd2] = 23'h002000;
		microcode_rom[sv2v_cast_953D0(4'b0110)][4'd3] = 23'h002004;
		microcode_rom[sv2v_cast_953D0(4'b0110)][4'd4] = 23'h001e00;
		microcode_rom[sv2v_cast_953D0(4'b0110)][4'd5] = 23'h200410;
		microcode_rom[sv2v_cast_953D0(4'b0111)][4'd0] = 23'h010000;
		microcode_rom[sv2v_cast_953D0(4'b0111)][4'd1] = 23'h018000;
		microcode_rom[sv2v_cast_953D0(4'b0111)][4'd2] = 23'h000008;
		microcode_rom[sv2v_cast_953D0(4'b0111)][4'd3] = 23'h204008;
		microcode_rom[sv2v_cast_953D0(4'b1000)][4'd0] = 23'h010000;
		microcode_rom[sv2v_cast_953D0(4'b1000)][4'd1] = 23'h210310;
		microcode_rom[sv2v_cast_953D0(4'b1001)][4'd0] = 23'h010000;
		microcode_rom[sv2v_cast_953D0(4'b1001)][4'd1] = 23'h290000;
		microcode_rom[sv2v_cast_953D0(4'b1010)][4'd0] = 23'h010000;
		microcode_rom[sv2v_cast_953D0(4'b1010)][4'd1] = 23'h290040;
		microcode_rom[sv2v_cast_953D0(4'b1011)][4'd0] = 23'h010000;
		microcode_rom[sv2v_cast_953D0(4'b1011)][4'd1] = 23'h290080;
		microcode_rom[sv2v_cast_953D0(4'b1100)][4'd0] = 23'h010000;
		microcode_rom[sv2v_cast_953D0(4'b1100)][4'd1] = 23'h290020;
		microcode_rom[sv2v_cast_953D0(4'b1101)][4'd0] = 23'h010000;
		microcode_rom[sv2v_cast_953D0(4'b1101)][4'd1] = 23'h018000;
		microcode_rom[sv2v_cast_953D0(4'b1101)][4'd2] = 23'h002000;
		microcode_rom[sv2v_cast_953D0(4'b1101)][4'd3] = 23'h202001;
		microcode_rom[sv2v_cast_953D0(4'b1110)][4'd0] = 23'h000008;
		microcode_rom[sv2v_cast_953D0(4'b1110)][4'd1] = 23'h200009;
		microcode_rom[sv2v_cast_953D0(4'b1111)][4'd0] = 23'h000000;
		microcode_rom[sv2v_cast_953D0(4'b1111)][4'd1] = 23'h600000;
	end
	initial _sv2v_0 = 0;
endmodule
module computer (
	clk,
	reset,
	out_val,
	flag_zero_o,
	flag_carry_o,
	flag_negative_o,
	debug_out_B,
	debug_out_IR,
	debug_out_PC
);
	reg _sv2v_0;
	input wire clk;
	input wire reset;
	localparam signed [31:0] arch_defs_pkg_DATA_WIDTH = 8;
	output wire [7:0] out_val;
	output wire flag_zero_o;
	output wire flag_carry_o;
	output wire flag_negative_o;
	output wire [7:0] debug_out_B;
	output wire [7:0] debug_out_IR;
	localparam signed [31:0] arch_defs_pkg_ADDR_WIDTH = 4;
	output wire [3:0] debug_out_PC;
	wire [7:0] b_out;
	assign debug_out_B = b_out;
	localparam signed [31:0] arch_defs_pkg_OPCODE_WIDTH = 4;
	wire [3:0] opcode;
	localparam signed [31:0] arch_defs_pkg_OPERAND_WIDTH = arch_defs_pkg_DATA_WIDTH - arch_defs_pkg_OPCODE_WIDTH;
	wire [arch_defs_pkg_OPERAND_WIDTH - 1:0] operand;
	assign debug_out_IR = {opcode, operand};
	wire [7:0] counter_out;
	assign debug_out_PC = counter_out;
	wire [1:0] alu_op;
	reg [22:0] control_word = 23'h000000;
	wire halt;
	wire pc_enable;
	wire load_o;
	wire load_a;
	wire load_b;
	wire load_ir;
	wire load_pc;
	wire load_flags;
	wire load_sets_zn;
	wire load_ram;
	wire load_mar;
	wire oe_a;
	wire oe_alu;
	wire oe_ir;
	wire oe_pc;
	wire oe_ram;
	wire [7:0] bus;
	wire [7:0] o_out;
	wire [7:0] a_out;
	wire [7:0] alu_out;
	wire [7:0] ram_out;
	wire [7:0] memory_address_out;
	assign bus = (oe_pc ? {{arch_defs_pkg_DATA_WIDTH - arch_defs_pkg_ADDR_WIDTH {1'b0}}, counter_out} : (oe_ram ? ram_out : (oe_ir ? {{arch_defs_pkg_DATA_WIDTH - arch_defs_pkg_OPERAND_WIDTH {1'b0}}, operand} : (oe_alu ? alu_out : (oe_a ? a_out : {arch_defs_pkg_DATA_WIDTH {1'b0}})))));
	program_counter u_program_counter(
		.clk(clk),
		.reset(reset),
		.enable(pc_enable),
		.load(load_pc),
		.counter_in(bus[3:0]),
		.counter_out(counter_out)
	);
	register_nbit #(.N(arch_defs_pkg_DATA_WIDTH)) u_register_OUT(
		.clk(clk),
		.reset(reset),
		.load(load_o),
		.data_in(bus),
		.latched_data(o_out)
	);
	assign out_val = o_out;
	register_nbit #(.N(arch_defs_pkg_DATA_WIDTH)) u_register_A(
		.clk(clk),
		.reset(reset),
		.load(load_a),
		.data_in(bus),
		.latched_data(a_out)
	);
	register_nbit #(.N(arch_defs_pkg_DATA_WIDTH)) u_register_B(
		.clk(clk),
		.reset(reset),
		.load(load_b),
		.data_in(bus),
		.latched_data(b_out)
	);
	register_nbit #(.N(arch_defs_pkg_ADDR_WIDTH)) u_register_memory_address(
		.clk(clk),
		.reset(reset),
		.load(load_mar),
		.data_in(bus[3:0]),
		.latched_data(memory_address_out)
	);
	register_instruction u_register_instr(
		.clk(clk),
		.reset(reset),
		.load(load_ir),
		.data_in(bus),
		.opcode(opcode),
		.operand(operand)
	);
	localparam signed [31:0] arch_defs_pkg_FLAG_COUNT = 3;
	(* keep *) wire [2:0] flags_out;
	reg C_in;
	reg N_in;
	reg Z_in;
	register_nbit #(.N(arch_defs_pkg_FLAG_COUNT)) u_register_flags(
		.clk(clk),
		.reset(reset),
		.load(load_flags),
		.data_in({N_in, C_in, Z_in}),
		.latched_data(flags_out)
	);
	assign flag_zero_o = flags_out[0];
	assign flag_carry_o = flags_out[1];
	assign flag_negative_o = flags_out[2];
	wire [23:1] sv2v_tmp_u_control_unit_control_word;
	always @(*) control_word = sv2v_tmp_u_control_unit_control_word;
	control_unit u_control_unit(
		.clk(clk),
		.reset(reset),
		.opcode(opcode),
		.flags(flags_out),
		.control_word(sv2v_tmp_u_control_unit_control_word)
	);
	assign load_o = control_word[0];
	assign load_a = control_word[4];
	assign load_b = control_word[2];
	assign load_ir = control_word[17];
	assign load_pc = control_word[19];
	assign load_mar = control_word[15];
	assign load_ram = control_word[14];
	assign oe_a = control_word[3];
	assign oe_ir = control_word[16];
	assign oe_pc = control_word[18];
	assign oe_alu = control_word[10];
	assign oe_ram = control_word[13];
	assign alu_op = control_word[12-:2];
	assign pc_enable = control_word[20];
	assign halt = control_word[22];
	assign load_flags = control_word[9];
	assign load_sets_zn = control_word[8];
	wire flag_alu_carry;
	wire flag_alu_negative;
	wire flag_alu_zero;
	alu u_alu(
		.clk(clk),
		.reset(reset),
		.a_in(a_out),
		.b_in(b_out),
		.alu_op(alu_op),
		.latched_result(alu_out),
		.zero_flag(flag_alu_zero),
		.carry_flag(flag_alu_carry),
		.negative_flag(flag_alu_negative)
	);
	ram u_ram(
		.clk(clk),
		.we(load_ram),
		.address(memory_address_out),
		.data_in(bus),
		.data_out(ram_out)
	);
	reg load_data_is_zero;
	reg load_data_is_negative;
	function automatic [3:0] sv2v_cast_953D0;
		input reg [3:0] inp;
		sv2v_cast_953D0 = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		load_data_is_zero = 1'b0;
		load_data_is_negative = 1'b0;
		if (load_sets_zn)
			(* full_case, parallel_case *)
			case (opcode)
				sv2v_cast_953D0(4'b1000): begin
					load_data_is_zero = operand == {arch_defs_pkg_OPERAND_WIDTH {1'b0}};
					load_data_is_negative = operand[arch_defs_pkg_OPERAND_WIDTH - 1];
				end
				sv2v_cast_953D0(4'b0001): begin
					load_data_is_zero = bus == {arch_defs_pkg_DATA_WIDTH {1'b0}};
					load_data_is_negative = bus[7];
				end
				sv2v_cast_953D0(4'b0010): begin
					load_data_is_zero = bus == {arch_defs_pkg_DATA_WIDTH {1'b0}};
					load_data_is_negative = bus[7];
				end
				default: begin
					load_data_is_zero = 1'b0;
					load_data_is_negative = 1'b0;
				end
			endcase
	end
	always @(*) begin
		if (_sv2v_0)
			;
		Z_in = flag_alu_zero;
		N_in = flag_alu_negative;
		C_in = flag_alu_carry;
		if (load_sets_zn) begin
			Z_in = load_data_is_zero;
			N_in = load_data_is_negative;
			C_in = 1'b0;
		end
	end
	initial _sv2v_0 = 0;
endmodule
module computer_tb;
	localparam HEX_FILE = "../fixture/Flags_Reg_test_load_instructions.hex";
	localparam EXPECTED_FINAL_OUTPUT = 8'h01;
	reg clk;
	reg reset;
	localparam signed [31:0] arch_defs_pkg_DATA_WIDTH = 8;
	wire [7:0] out_val;
	wire flag_zero_o;
	wire flag_carry_o;
	wire flag_negative_o;
	computer uut(
		.clk(clk),
		.reset(reset),
		.out_val(out_val),
		.flag_zero_o(flag_zero_o),
		.flag_carry_o(flag_carry_o),
		.flag_negative_o(flag_negative_o)
	);
	initial begin
		clk = 0;
		forever #(5) clk = ~clk;
	end
	localparam signed [31:0] arch_defs_pkg_ADDR_WIDTH = 4;
	task test_utils_pkg_inspect_register;
		input [31:0] actual;
		input [31:0] expected;
		input string name;
		input reg signed [31:0] expected_width;
		reg [31:0] mask;
		begin
			mask = (expected_width == 32 ? 32'hffffffff : (32'h00000001 << expected_width) - 1);
			if ((actual & mask) !== (expected & mask))
				$display("\033[0;31mAssertion Failed: %s (%0d bits). Actual: %h, Expected: %h\033[0m", name, expected_width, actual & mask, expected & mask);
			else
				$display("\033[0;32mAssertion Passed: %s (%0d bits) = %h\033[0m", name, expected_width, actual & mask);
		end
	endtask
	task test_utils_pkg_pretty_print_assert_vec;
		input [31:0] actual;
		input [31:0] expected;
		input string msg;
		if (actual !== expected)
			$display("\033[0;31mAssertion Failed: %s. Actual: %h, Expected: %h\033[0m", msg, actual, expected);
		else
			$display("\033[0;32mAssertion Passed: %s\033[0m", msg);
	endtask
	task test_utils_pkg_reset_and_wait;
		input reg signed [31:0] cycles;
		begin
			reset = 1;
			@(posedge clk)
				;
			@(negedge clk)
				;
			reset = 0;
			repeat (cycles) @(posedge clk)
				;
		end
	endtask
	task test_utils_pkg_run_until_halt;
		input reg signed [31:0] max_cycles;
		reg signed [31:0] cycle;
		reg [0:1] _sv2v_jump;
		begin
			_sv2v_jump = 2'b00;
			cycle = 0;
			while ((cycle < max_cycles) && (_sv2v_jump < 2'b10)) begin
				_sv2v_jump = 2'b00;
				#(1ps)
					;
				if (uut.halt == 1) begin
					$display("HALT signal detected high at start of cycle %0d.", cycle + 1);
					_sv2v_jump = 2'b10;
				end
				if (_sv2v_jump == 2'b00) begin
					@(posedge clk)
						;
					cycle = cycle + 1;
				end
			end
			if (_sv2v_jump != 2'b11)
				_sv2v_jump = 2'b00;
			if (_sv2v_jump == 2'b00) begin
				#(1ps)
					;
				if ((uut.halt == 0) && (cycle >= max_cycles)) begin
					$display("\033[0;31mSimulation timed out. HALT signal not asserted after %0d cycles.\033[0m", cycle);
					$display("Error [%0t] /Users/aaronbrown/Documents/Code/2_Ben_Eater_FPGA/test/test_utilities_pkg.sv:61:9 - computer_tb.test_utils_pkg_run_until_halt.<unnamed_block>.<unnamed_block>\n msg: ", $time, "Simulation timed out.");
					$finish;
				end
				else
					$display("\033[0;32mSimulation run completed (halt detected or max cycles reached while potentially halting). Cycles run: %0d\033[0m", cycle);
			end
		end
	endtask
	initial begin
		$dumpfile("waveform.vcd");
		$dumpvars(0, computer_tb);
		$display("--- Loading hex file: %s ---", HEX_FILE);
		$readmemh(HEX_FILE, uut.u_ram.mem);
		uut.u_ram.dump;
		test_utils_pkg_reset_and_wait(0);
		$display("Running LDI #0");
		repeat (8) @(posedge clk)
			;
		#(0.1)
			;
		test_utils_pkg_inspect_register(uut.u_register_A.latched_data, 8'h00, "A", arch_defs_pkg_DATA_WIDTH);
		test_utils_pkg_pretty_print_assert_vec(flag_negative_o, 1'b0, "N after LDI #0");
		test_utils_pkg_pretty_print_assert_vec(flag_carry_o, 1'b0, "C after LDI #0");
		test_utils_pkg_pretty_print_assert_vec(flag_zero_o, 1'b1, "Z after LDI #0");
		test_utils_pkg_inspect_register(uut.u_program_counter.counter_out, 8'h01, "PC", arch_defs_pkg_ADDR_WIDTH);
		$display("Running LDI #8");
		repeat (7) @(posedge clk)
			;
		#(0.1)
			;
		test_utils_pkg_inspect_register(uut.u_register_A.latched_data, 8'h08, "A", arch_defs_pkg_DATA_WIDTH);
		test_utils_pkg_pretty_print_assert_vec(flag_negative_o, 1'b1, "N after LDI #8");
		test_utils_pkg_pretty_print_assert_vec(flag_carry_o, 1'b0, "C after LDI #8");
		test_utils_pkg_pretty_print_assert_vec(flag_zero_o, 1'b0, "Z after LDI #8");
		test_utils_pkg_inspect_register(uut.u_program_counter.counter_out, 8'h02, "PC", arch_defs_pkg_ADDR_WIDTH);
		$display("Running STA 0xE");
		repeat (9) @(posedge clk)
			;
		#(0.1)
			;
		test_utils_pkg_inspect_register(uut.u_ram.mem[14], 8'h08, "RAM[E]", arch_defs_pkg_DATA_WIDTH);
		test_utils_pkg_pretty_print_assert_vec(flag_negative_o, 1'b1, "N after STA (no change)");
		test_utils_pkg_pretty_print_assert_vec(flag_carry_o, 1'b0, "C after STA (no change)");
		test_utils_pkg_pretty_print_assert_vec(flag_zero_o, 1'b0, "Z after STA (no change)");
		test_utils_pkg_inspect_register(uut.u_program_counter.counter_out, 8'h03, "PC", arch_defs_pkg_ADDR_WIDTH);
		$display("Running LDI #0xF");
		repeat (7) @(posedge clk)
			;
		#(0.1)
			;
		test_utils_pkg_inspect_register(uut.u_register_A.latched_data, 8'h0f, "A", arch_defs_pkg_DATA_WIDTH);
		test_utils_pkg_pretty_print_assert_vec(flag_negative_o, 1'b1, "N after LDI #F");
		test_utils_pkg_pretty_print_assert_vec(flag_carry_o, 1'b0, "C after LDI #F");
		test_utils_pkg_pretty_print_assert_vec(flag_zero_o, 1'b0, "Z after LDI #F");
		test_utils_pkg_inspect_register(uut.u_program_counter.counter_out, 8'h04, "PC", arch_defs_pkg_ADDR_WIDTH);
		$display("Running STA 0xF");
		repeat (9) @(posedge clk)
			;
		#(0.1)
			;
		test_utils_pkg_inspect_register(uut.u_ram.mem[15], 8'h0f, "RAM[F]", arch_defs_pkg_DATA_WIDTH);
		test_utils_pkg_pretty_print_assert_vec(flag_negative_o, 1'b1, "N after STA (no change)");
		test_utils_pkg_pretty_print_assert_vec(flag_carry_o, 1'b0, "C after STA (no change)");
		test_utils_pkg_pretty_print_assert_vec(flag_zero_o, 1'b0, "Z after STA (no change)");
		test_utils_pkg_inspect_register(uut.u_program_counter.counter_out, 8'h05, "PC", arch_defs_pkg_ADDR_WIDTH);
		$display("Running LDA 0xE");
		repeat (9) @(posedge clk)
			;
		#(0.1)
			;
		test_utils_pkg_inspect_register(uut.u_register_A.latched_data, 8'h08, "A", arch_defs_pkg_DATA_WIDTH);
		test_utils_pkg_pretty_print_assert_vec(flag_negative_o, 1'b0, "N after LDA 0xE");
		test_utils_pkg_pretty_print_assert_vec(flag_carry_o, 1'b0, "C after LDA 0xE");
		test_utils_pkg_pretty_print_assert_vec(flag_zero_o, 1'b0, "Z after LDA 0xE");
		test_utils_pkg_inspect_register(uut.u_program_counter.counter_out, 8'h06, "PC", arch_defs_pkg_ADDR_WIDTH);
		$display("Running LDB 0xF");
		repeat (9) @(posedge clk)
			;
		#(0.1)
			;
		test_utils_pkg_inspect_register(uut.u_register_B.latched_data, 8'h0f, "B", arch_defs_pkg_DATA_WIDTH);
		test_utils_pkg_pretty_print_assert_vec(flag_negative_o, 1'b0, "N after LDB 0xF");
		test_utils_pkg_pretty_print_assert_vec(flag_carry_o, 1'b0, "C after LDB 0xF");
		test_utils_pkg_pretty_print_assert_vec(flag_zero_o, 1'b0, "Z after LDB 0xF");
		test_utils_pkg_inspect_register(uut.u_program_counter.counter_out, 8'h07, "PC", arch_defs_pkg_ADDR_WIDTH);
		$display("Running LDI #1");
		repeat (7) @(posedge clk)
			;
		#(0.1)
			;
		test_utils_pkg_inspect_register(uut.u_register_A.latched_data, 8'h01, "A", arch_defs_pkg_DATA_WIDTH);
		test_utils_pkg_pretty_print_assert_vec(flag_negative_o, 1'b0, "N after LDI #1");
		test_utils_pkg_pretty_print_assert_vec(flag_carry_o, 1'b0, "C after LDI #1");
		test_utils_pkg_pretty_print_assert_vec(flag_zero_o, 1'b0, "Z after LDI #1");
		test_utils_pkg_inspect_register(uut.u_program_counter.counter_out, 8'h08, "PC", arch_defs_pkg_ADDR_WIDTH);
		$display("Running OUTA");
		repeat (7) @(posedge clk)
			;
		#(0.1)
			;
		test_utils_pkg_inspect_register(uut.u_register_OUT.latched_data, EXPECTED_FINAL_OUTPUT, "O after OUTA", arch_defs_pkg_DATA_WIDTH);
		test_utils_pkg_inspect_register(uut.u_program_counter.counter_out, 8'h09, "PC", arch_defs_pkg_ADDR_WIDTH);
		$display("Running HLT");
		test_utils_pkg_run_until_halt(50);
		#(0.1)
			;
		$display("@%0t: Checking state after Halt", $time);
		test_utils_pkg_pretty_print_assert_vec(uut.halt, 1'b1, "Halt signal active");
		test_utils_pkg_inspect_register(uut.u_program_counter.counter_out, 8'h0a, "Final PC", arch_defs_pkg_ADDR_WIDTH);
		test_utils_pkg_inspect_register(uut.u_register_OUT.latched_data, EXPECTED_FINAL_OUTPUT, "Final Output", arch_defs_pkg_DATA_WIDTH);
		$display("\033[0;32mLoad Flags test completed successfully.\033[0m");
		$finish;
	end
endmodule
