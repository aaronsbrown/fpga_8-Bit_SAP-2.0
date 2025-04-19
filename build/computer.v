module computer (
	clk,
	reset,
	out_val,
	cpu_flags
);
	reg _sv2v_0;
	input wire clk;
	input wire reset;
	output wire [7:0] out_val;
	output wire [1:0] cpu_flags;
	reg [19:0] control_word = 20'h00000;
	reg [19:0] next_control_word = 20'h00000;
	wire [3:0] opcode;
	wire [3:0] operand;
	wire pc_enable;
	wire [3:0] counter_out;
	wire [3:0] memory_address_out;
	wire [7:0] o_out;
	wire [7:0] a_out;
	wire [7:0] b_out;
	wire [7:0] ir_out;
	wire [7:0] alu_out;
	wire [7:0] ram_out;
	wire [7:0] bus;
	wire load_o;
	wire load_a;
	wire load_b;
	wire load_ir;
	wire load_pc;
	wire load_ram;
	wire load_mar;
	wire oe_a;
	wire oe_alu;
	wire oe_ir;
	wire oe_pc;
	wire oe_ram;
	wire halt;
	wire [1:0] alu_op;
	program_counter #(.ADDR_WIDTH(4)) u_program_counter(
		.clk(clk),
		.reset(reset),
		.enable(pc_enable),
		.load(load_pc),
		.counter_in(bus[3:0]),
		.counter_out(counter_out)
	);
	assign out_val = o_out;
	register_nbit #(.N(8)) u_output_register(
		.clk(clk),
		.reset(reset),
		.load(load_o),
		.data_in(bus),
		.latched_data(o_out)
	);
	register_nbit #(.N(8)) u_register_A(
		.clk(clk),
		.reset(reset),
		.load(load_a),
		.data_in(bus),
		.latched_data(a_out)
	);
	register_nbit #(.N(8)) u_register_B(
		.clk(clk),
		.reset(reset),
		.load(load_b),
		.data_in(bus),
		.latched_data(b_out)
	);
	register_nbit #(.N(4)) u_register_memory_address(
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
	wire flag_zero;
	wire flag_carry;
	alu u_alu(
		.clk(clk),
		.reset(reset),
		.a_in(a_out),
		.b_in(b_out),
		.alu_op(alu_op),
		.result_out(alu_out),
		.zero_flag(flag_zero),
		.carry_flag(flag_carry)
	);
	assign cpu_flags[1] = flag_carry;
	assign cpu_flags[0] = flag_zero;
	ram u_ram(
		.clk(clk),
		.we(load_ram),
		.address(memory_address_out),
		.data_in(bus),
		.data_out(ram_out)
	);
	assign bus = (oe_pc ? counter_out : (oe_ram ? ram_out : (oe_ir ? {4'b0000, operand} : (oe_alu ? alu_out : (oe_a ? a_out : 8'b00000000)))));
	reg [2:0] current_state = 3'd0;
	reg [2:0] next_state = 3'd0;
	reg [3:0] current_step;
	reg [3:0] next_step;
	always @(posedge clk)
		if (reset) begin
			current_state <= 3'd0;
			current_step <= 4'd0;
			control_word <= 20'h00000;
		end
		else begin
			current_state <= next_state;
			current_step <= next_step;
			control_word <= next_control_word;
		end
	reg [19:0] microcode_rom [0:15][0:7];
	always @(*) begin
		if (_sv2v_0)
			;
		next_state = current_state;
		next_step = current_step;
		next_control_word = 20'h00000;
		case (current_state)
			3'd0: next_state = 3'd1;
			3'd1: begin
				next_control_word = 20'h08000;
				next_state = 3'd2;
			end
			3'd2: begin
				next_control_word = 20'h09000;
				next_state = 3'd3;
			end
			3'd3: begin
				next_control_word = 20'h00400;
				next_state = 3'd4;
			end
			3'd4: begin
				next_control_word = 20'h24400;
				next_state = 3'd6;
			end
			3'd6: next_state = 3'd5;
			3'd5: begin
				next_control_word = microcode_rom[opcode][current_step];
				if (next_control_word[19]) begin
					next_state = 3'd7;
					next_step = 4'd0;
				end
				else if (next_control_word[18]) begin
					next_state = 3'd1;
					next_step = 4'd0;
				end
				else
					next_step = current_step + 1;
			end
			3'd7: begin
				next_control_word = 20'h00000;
				next_state = 3'd7;
			end
			default: begin
				next_control_word = 20'h00000;
				next_state = 3'd7;
			end
		endcase
	end
	assign load_o = control_word[0];
	assign load_a = control_word[4];
	assign load_b = control_word[2];
	assign load_ir = control_word[14];
	assign load_pc = control_word[16];
	assign load_mar = control_word[12];
	assign load_ram = control_word[11];
	assign oe_a = control_word[3];
	assign oe_ir = control_word[13];
	assign oe_pc = control_word[15];
	assign oe_alu = control_word[7];
	assign oe_ram = control_word[10];
	assign alu_op = control_word[9-:2];
	assign pc_enable = control_word[17];
	assign halt = control_word[19];
	initial begin
		begin : sv2v_autoblock_1
			reg signed [31:0] i;
			for (i = 0; i < 16; i = i + 1)
				begin : sv2v_autoblock_2
					reg signed [31:0] s;
					for (s = 0; s < 8; s = s + 1)
						microcode_rom[i][s] = 20'h00000;
				end
		end
		microcode_rom[4'b0000][4'd0] = 20'h40000;
		microcode_rom[4'b0001][4'd0] = 20'h02000;
		microcode_rom[4'b0001][4'd1] = 20'h03000;
		microcode_rom[4'b0001][4'd2] = 20'h00400;
		microcode_rom[4'b0001][4'd3] = 20'h40410;
		microcode_rom[4'b0010][4'd0] = 20'h02000;
		microcode_rom[4'b0010][4'd1] = 20'h03000;
		microcode_rom[4'b0010][4'd2] = 20'h00400;
		microcode_rom[4'b0010][4'd3] = 20'h40404;
		microcode_rom[4'b0011][4'd0] = 20'h02000;
		microcode_rom[4'b0011][4'd1] = 20'h03000;
		microcode_rom[4'b0011][4'd2] = 20'h00400;
		microcode_rom[4'b0011][4'd3] = 20'h00404;
		microcode_rom[4'b0011][4'd4] = 20'h00080;
		microcode_rom[4'b0011][4'd5] = 20'h40090;
		microcode_rom[4'b0100][4'd0] = 20'h02000;
		microcode_rom[4'b0100][4'd1] = 20'h03000;
		microcode_rom[4'b0100][4'd2] = 20'h00400;
		microcode_rom[4'b0100][4'd3] = 20'h00404;
		microcode_rom[4'b0100][4'd4] = 20'h00180;
		microcode_rom[4'b0100][4'd5] = 20'h40090;
		microcode_rom[4'b0101][4'd0] = 20'h02000;
		microcode_rom[4'b0101][4'd1] = 20'h03000;
		microcode_rom[4'b0101][4'd2] = 20'h00400;
		microcode_rom[4'b0101][4'd3] = 20'h00404;
		microcode_rom[4'b0101][4'd4] = 20'h00280;
		microcode_rom[4'b0101][4'd5] = 20'h40090;
		microcode_rom[4'b0110][4'd0] = 20'h02000;
		microcode_rom[4'b0110][4'd1] = 20'h03000;
		microcode_rom[4'b0110][4'd2] = 20'h00400;
		microcode_rom[4'b0110][4'd3] = 20'h00404;
		microcode_rom[4'b0110][4'd4] = 20'h00380;
		microcode_rom[4'b0110][4'd5] = 20'h40090;
		microcode_rom[4'b0111][4'd0] = 20'h02000;
		microcode_rom[4'b0111][4'd1] = 20'h03000;
		microcode_rom[4'b0111][4'd2] = 20'h00008;
		microcode_rom[4'b0111][4'd3] = 20'h40808;
		microcode_rom[4'b1000][4'd0] = 20'h02000;
		microcode_rom[4'b1000][4'd1] = 20'h42010;
		microcode_rom[4'b1001][4'd0] = 20'h02000;
		microcode_rom[4'b1001][4'd1] = 20'h52000;
		microcode_rom[4'b1011][4'd0] = 20'h02000;
		microcode_rom[4'b1011][4'd1] = 20'h52040;
		microcode_rom[4'b1010][4'd0] = 20'h02000;
		microcode_rom[4'b1010][4'd1] = 20'h52020;
		microcode_rom[4'b1101][4'd0] = 20'h02000;
		microcode_rom[4'b1101][4'd1] = 20'h03000;
		microcode_rom[4'b1101][4'd2] = 20'h00400;
		microcode_rom[4'b1101][4'd3] = 20'h40401;
		microcode_rom[4'b1110][4'd0] = 20'h00008;
		microcode_rom[4'b1110][4'd1] = 20'h40009;
		microcode_rom[4'b1111][4'd0] = 20'h00000;
		microcode_rom[4'b1111][4'd1] = 20'hc0000;
	end
	initial _sv2v_0 = 0;
endmodule
