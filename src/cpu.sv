import arch_defs_pkg::*;

// This module implements a simple microcoded CPU architecture. It includes a program counter, registers, 
// a RAM interface, and a microcode ROM to control the CPU's operations based on opcodes and microsteps.

module cpu (
    input wire  clk,
    input wire  reset, 
    
    // ================= MEMORY BUS INTERFACE ==============
    output wire [ADDR_WIDTH-1:0] mem_address,   // address driven by cpu
    output wire mem_read,                       // read request strobe 
    output wire mem_write,                      // write request strobe
    input  wire [DATA_WIDTH-1:0] mem_data_in,   // data driven *to* cpu 
    output wire [DATA_WIDTH-1:0] mem_data_out,  // data driven *from* cpu
    
    // ================= EXTERNAL OUTPUT REGISTER ========
    output wire load_o,
    output logic oe_ram,                        // OUTM: source is ram
    output logic oe_a,                          // OUTA: source is A register
    output wire [DATA_WIDTH-1:0] a_out_bus,     // output bus from A register

    // ================= HALT SIGNAL ================
    output wire halt,

    // ================= FLAGS ======================
    output wire flag_zero_o,
    output wire flag_carry_o,
    output wire flag_negative_o,

    // ================= DEBUG SIGNALS ==============
    output wire [DATA_WIDTH-1:0] debug_out_B,
    output wire [DATA_WIDTH-1:0] debug_out_IR,
    output wire [ADDR_WIDTH-1:0] debug_out_PC

); // END PORT DEFS

    
    // ================ CONNECT DEBUG SIGNALS ===============
    // ======================================================
    assign debug_out_B = b_out;
    assign debug_out_IR = { opcode, operand };
    assign debug_out_PC = counter_out;


    // =============== CONNECT  RAM INTERFACE ==============
    // =====================================================
    assign mem_read = control_word.oe_ram;
    assign mem_write = control_word.load_ram;
    assign mem_address = mar_out;
    assign mem_data_out = a_out; 
    

    // =============== CONNECT OUTPUT REG  =================
    // =====================================================
    assign load_o = control_word.load_o;
    assign oe_a = control_word.oe_a;
    assign oe_ram = control_word.oe_ram;
    assign a_out_bus = a_out;

    // =============== CONNECT FLAGS  ======================
    // =====================================================
    assign flag_zero_o = flags_out[0];
    assign flag_carry_o = flags_out[1];
    assign flag_negative_o = flags_out[2];


    // =============== MICROCODE STRUCTURAL DEFINITION ==============
    // ==============================================================
    logic [OPCODE_WIDTH-1:0] opcode; 
    logic [OPERAND_WIDTH-1:0] operand; 
    
    
    // =============== ALU OPERATIONS =====================
    // ====================================================
    logic [1:0] alu_op;
  
   
    // =============== CONTROL SIGNALS ===================
    // ===================================================

    // Control signal to enable program counter
    logic pc_enable;

    // Control signals for loading data from the internal_bus into registers
    logic load_a, load_b, load_c, load_tmp, load_ir, load_pc, load_flags, load_sets_zn, load_mar;
    
    // Control signals for outputting data to the internal_bus
    logic oe_b, oe_c, oe_tmp, oe_alu;

    control_word_t control_word = '{default: 0};
    assign load_a = control_word.load_a;
    assign load_b = control_word.load_b;
    assign load_c = control_word.load_c;
    assign load_tmp = control_word.load_tmp;
    assign load_ir = control_word.load_ir;
    assign load_pc = control_word.load_pc;
    assign load_mar = control_word.load_mar;
    assign oe_ir = control_word.oe_ir;
    assign oe_pc = control_word.oe_pc;
    assign oe_alu = control_word.oe_alu;
    assign alu_op = control_word.alu_op;
    assign pc_enable = control_word.pc_enable; 
    assign halt = control_word.halt; 
    assign load_flags = control_word.load_flags;
    assign load_sets_zn = control_word.load_sets_zn; 
    
    
    // ================= BUS INTERFACE and 'internal_bus staging' registers ==================
    // ==============================================================================
    logic [DATA_WIDTH-1:0] internal_bus;
    logic [DATA_WIDTH-1:0] a_out, b_out, c_out, tmp_out, alu_out, mar_out;
    logic [ADDR_WIDTH-1:0] counter_out;
    
    // Tri-state bus logic modeled using a priority multiplexer
    assign internal_bus =    
                    (oe_ram) ? mem_data_in :
                    (oe_alu) ? alu_out :
                    (oe_a)   ? a_out :
                    (oe_b)   ? b_out :
                    (oe_c)   ? c_out :
                    (oe_tmp) ? tmp_out :
                    { DATA_WIDTH {1'b0} };


    // ================ REGISTER DECLARATIONS ===========
    // ==================================================
    logic load_pc_high_byte, load_pc_low_byte;
    program_counter u_program_counter (
        .clk(clk),
        .reset(reset),
        .enable(pc_enable),
        .load_high_byte(load_pc_high_byte),
        .load_low_byte(load_pc_low_byte),
        .counter_in(internal_bus[ADDR_WIDTH-1:0]),
        .counter_out(counter_out)
    );

    
    register_nbit #( .N(DATA_WIDTH) ) u_register_A (
        .clk(clk),
        .reset(reset),
        .load(load_a),
        .data_in(internal_bus),
        .latched_data(a_out)
    );
    
    register_nbit #( .N(DATA_WIDTH) ) u_register_B (
        .clk(clk),
        .reset(reset),
        .load(load_b),
        .data_in(internal_bus),
        .latched_data(b_out)
    );

    register_nbit #( .N(DATA_WIDTH) ) u_register_C (
        .clk(clk),
        .reset(reset),
        .load(load_c),
        .data_in(internal_bus),
        .latched_data(c_out)
    );
    
    register_nbit #( .N(DATA_WIDTH) ) u_register_TMP (
        .clk(clk),
        .reset(reset),
        .load(load_tmp),
        .data_in(internal_bus),
        .latched_data(tmp_out)
    );
    
    // Memory address register for RAM operations
    register_nbit #( .N(ADDR_WIDTH) ) u_register_memory_address (
        .clk(clk),
        .reset(reset),
        .load(load_mar),
        .data_in(counter_out),
        .latched_data(mar_out)
    );

    // Instruction register to hold the current instruction
    register_instruction u_register_instr (
        .clk(clk),
        .reset(reset),
        .load(load_ir),
        .data_in(internal_bus),
        .opcode(opcode),
        .operand(operand)
    );

    // IMPORTANT: Synthesis Optimization Note (Yosys/synth_ice40)
    // Added (* keep *) attribute below because default synthesis optimization
    // was observed to incorrectly alter or remove the flags register logic
    // The (* keep *) prevents Yosys from over-optimizing
    // this critical state-holding element, ensuring correct hardware behavior
    // across different program complexities. The root cause appears to be
    // an optimization that misinterprets the usage scope of the flags when
    // conditional jumps aren't the final instructions using them.
    (* keep *) logic [FLAG_COUNT-1:0] flags_out;
    
    // Flags register to hold the status flags
    // Z: Zero flag, C: Carry flag, N: Negative flag
    register_nbit #( .N(FLAG_COUNT) ) u_register_flags (
        .clk(clk),
        .reset(reset),
        .load(load_flags),
        .data_in( {N_in, C_in, Z_in} ),
        .latched_data(flags_out)
    );

    

    // ================ MAIN COMPONENTS: ALU, CONTROL UNIT ================
    // =========================================================================
    control_unit u_control_unit (
        .clk(clk),
        .reset(reset),
        .opcode(opcode),
        .flags(flags_out),
        .control_word(control_word)
    );
    
    alu u_alu (
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


    // ================================ FLAG LOGIC ===============================
    // ===========================================================================
    logic flag_alu_zero;
    logic flag_alu_carry;
    logic flag_alu_negative;

    // Determine if the LOAD operation resulted in zero or negative
    logic load_data_is_zero, load_data_is_negative;
    always_comb begin
        load_data_is_zero = 1'b0;
        load_data_is_negative = 1'b0;

        if (load_sets_zn) begin
            // We know we executing an operation that sets the flags
            unique case (opcode)
                LDI: begin
                    // LDI sets the flags based on the operand
                    load_data_is_zero = ( operand == {OPERAND_WIDTH{1'b0}} );
                    load_data_is_negative = operand[OPERAND_WIDTH - 1];
                end
                LDA: begin
                    // LDA sets the flags based on the internal_bus
                    load_data_is_zero = ( internal_bus == {DATA_WIDTH{1'b0}} );
                    load_data_is_negative = internal_bus[DATA_WIDTH - 1];
                end
                LDB: begin
                    // LDB sets the flags based on the internal_bus
                    load_data_is_zero = ( internal_bus == {DATA_WIDTH{1'b0}} ) ;
                    load_data_is_negative = internal_bus[DATA_WIDTH - 1];
                end
                default: begin
                    load_data_is_zero = 1'b0;
                    load_data_is_negative = 1'b0;
                end
            endcase
        end
    end


    // Determine if flags should be set based on ALU op or LDI/LDA/LDB
    logic Z_in, N_in, C_in;
    always_comb begin
        Z_in = flag_alu_zero;
        N_in = flag_alu_negative;
        C_in = flag_alu_carry;
        if (load_sets_zn) begin
            Z_in = load_data_is_zero;
            N_in = load_data_is_negative;
            C_in = 1'b0; // Carry flag is not set for LOAD operations
        end
    end
endmodule
