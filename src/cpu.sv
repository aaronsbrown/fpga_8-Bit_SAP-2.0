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
    assign debug_out_IR = opcode;
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
    assign flag_zero_o = flags_reg_out[0];
    assign flag_carry_o = flags_reg_out[1];
    assign flag_negative_o = flags_reg_out[2];


    // =============== OPCODE  ==============
    // ==============================================================
    logic [DATA_WIDTH-1:0] opcode; // TODO remove wire for direct connection
    
    
    // =============== ALU OPERATIONS =====================
    // ====================================================
    logic [3:0] alu_op;
  
   
    // =============== DEFAULT ROM ORIGIN ================
    // ===================================================
    logic [ADDR_WIDTH-1:0] default_rom_origin;
    assign default_rom_origin = RESET_VECTOR;


    // =============== CONTROL SIGNALS ===================
    // ===================================================

    // =======================================================================
    // Intermediate Wires for Control Signals - Icarus Verilog v12 Workaround
    // =======================================================================
    // NOTE: Ideally, struct members from 'control_word' would be connected
    // directly to submodule ports below (e.g., .load(control_word.load_a)).
    // However, Icarus Verilog v12 (as of testing) has issues resolving
    // hierarchical references directly into struct members when they are
    // passed as arguments to tasks (like assertion tasks) in the testbench,
    // often leading to elaboration errors (e.g., "failed assertion sr.path_tail.empty()").
    //
    // To work around this limitation and allow testbenches to directly assert
    // on individual control signals using simpler hierarchical paths (e.g.,
    // uut.u_cpu.load_a), we explicitly declare intermediate wires here and
    // assign the corresponding control_word members to them. This makes the
    // CPU module more verbose but simplifies testbench assertions and avoids
    // the iverilog elaboration error. If using a different simulator or a
    // future iverilog version that resolves this, this section could potentially
    // be removed, and direct connections could be used.
    // =======================================================================


    // Control signal to enable program counter
    logic pc_enable;

    // Control signals for loading data from the internal_bus into registers
    logic load_a, load_b, load_c, load_tmp, load_ir, load_flags, load_sets_zn, load_temp_1, load_temp_2;
    logic load_pc_high_byte, load_pc_low_byte, load_origin;
    
    // Control signals for outputting data to the internal_bus
    logic oe_b, oe_c, oe_temp_1, oe_temp_2, oe_alu;

    // Control signals for ALU src multiplexer
    logic alu_src_c;

    control_word_t control_word = '{default: 0};
    assign load_a = control_word.load_a;
    assign load_b = control_word.load_b;
    assign load_c = control_word.load_c;
    assign load_temp_1 = control_word.load_temp_1;
    assign load_temp_2 = control_word.load_temp_2;
    assign load_ir = control_word.load_ir;
    assign load_origin = control_word.load_origin;
    assign load_pc_low_byte = control_word.load_pc_low_byte;
    assign load_pc_high_byte = control_word.load_pc_high_byte;
    assign load_mar_pc = control_word.load_mar_pc;
    assign load_mar_addr_high = control_word.load_mar_addr_high;
    assign load_mar_addr_low = control_word.load_mar_addr_low;
    assign oe_ir = control_word.oe_ir;
    assign oe_pc = control_word.oe_pc;
    assign oe_alu = control_word.oe_alu;
    assign alu_op = control_word.alu_op;
    assign pc_enable = control_word.pc_enable; 
    assign halt = control_word.halt; 
    assign load_flags = control_word.load_flags;
    assign load_sets_zn = control_word.load_sets_zn;
    assign oe_b = control_word.oe_b; 
    assign oe_c = control_word.oe_c; 
    assign oe_temp_1 = control_word.oe_temp_1; 
    assign oe_temp_2 = control_word.oe_temp_2;
    assign alu_src_c = control_word.alu_src_c; 
    
    
    // ================= BUS INTERFACE and 'internal_bus staging' registers ==================
    // ==============================================================================
    logic [DATA_WIDTH-1:0] internal_bus;
    logic [DATA_WIDTH-1:0] a_out, b_out, c_out, temp_1_out, temp_2_out, alu_out;
    logic [ADDR_WIDTH-1:0] counter_out, mar_out;
    
    // Tri-state bus logic modeled using a priority multiplexer
    assign internal_bus =    
                    (oe_ram) ? mem_data_in :
                    (oe_alu) ? alu_out :
                    (oe_a)   ? a_out :
                    (oe_b)   ? b_out :
                    (oe_c)   ? c_out :
                    (oe_temp_1) ? temp_1_out :
                    (oe_temp_2) ? temp_2_out :
                    { DATA_WIDTH {1'b0} };


    // ================ REGISTER DECLARATIONS ===========
    // ==================================================
    program_counter u_program_counter (
        .clk(clk),
        .reset(reset),
        .enable(pc_enable),
        .load_origin(load_origin),
        .load_high_byte(load_pc_high_byte),
        .load_low_byte(load_pc_low_byte),
        .origin_address(default_rom_origin),
        .counter_in(internal_bus),
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
    
    register_nbit #( .N(DATA_WIDTH) ) u_register_TEMP_1 (
        .clk(clk),
        .reset(reset),
        .load(load_temp_1),
        .data_in(internal_bus),
        .latched_data(temp_1_out)
    );
    
    register_nbit #( .N(DATA_WIDTH) ) u_register_TEMP_2 (
        .clk(clk),
        .reset(reset),
        .load(load_temp_2),
        .data_in(internal_bus),
        .latched_data(temp_2_out)
    );

    logic load_mar_addr_high, load_mar_addr_low, load_mar_pc;
    register_memory_address u_register_memory_address (
      .clk(clk),
      .reset(reset),
      .load_pc(load_mar_pc),
      .load_addr_high(load_mar_addr_high),
      .load_addr_low(load_mar_addr_low),
      .bus_in(internal_bus),
      .program_counter_in(counter_out),
      .address_out(mar_out)
    );   

    register_nbit #( .N(DATA_WIDTH) ) u_register_instr (
        .clk(clk),
        .reset(reset),
        .load(load_ir),
        .data_in(internal_bus),
        .latched_data(opcode)
    );


    // IMPORTANT: Synthesis Optimization Note (Yosys/synth_ice40)
    // Added (* keep *) attribute below because default synthesis optimization
    // was observed to incorrectly alter or remove the flags register logic
    // The (* keep *) prevents Yosys from over-optimizing
    // this critical state-holding element, ensuring correct hardware behavior
    // across different program complexities. The root cause appears to be
    // an optimization that misinterprets the usage scope of the flags when
    // conditional jumps aren't the final instructions using them.
    (* keep *) logic [FLAG_COUNT-1:0] flags_reg_out;
    
    // Flags register to hold the status flags
    // Z: Zero flag, C: Carry flag, N: Negative flag
    register_nbit #( .N(FLAG_COUNT) ) u_register_flags (
        .clk(clk),
        .reset(reset),
        .load(load_flags),
        .data_in( {N_in_w, C_in_w, Z_in_w} ),
        .latched_data(flags_reg_out)
    );

    

    // ================ MAIN COMPONENTS: ALU, CONTROL UNIT ================
    // =========================================================================
    control_unit u_control_unit (
        .clk(clk),
        .reset(reset),
        .opcode(opcode),
        .flags(flags_reg_out),
        .control_word(control_word)
    );

    logic [DATA_WIDTH-1:0] b_in_src; 
    assign b_in_src = (alu_src_c) ? c_out : b_out;
    alu u_alu (
        .clk(clk),
        .reset(reset),
        .in_one(a_out),
        .in_two(b_in_src),
        .in_carry(flags_reg_out[1]),
        .alu_op(alu_op),
        .latched_result(alu_out),
        .zero_flag(alu_zero_out_w),
        .carry_flag(alu_carry_out_w),
        .negative_flag(alu_negative_out_w)
    );


    // ================================ FLAG LOGIC ===============================
    // ===========================================================================
    logic alu_zero_out_w;
    logic alu_carry_out_w;
    logic alu_negative_out_w;

    // Determine if the LOAD operation resulted in zero or negative
    logic load_data_is_zero_w, load_data_is_negative_w;
    always_comb begin
        load_data_is_zero_w = 1'b0;
        load_data_is_negative_w = 1'b0;

        if (load_sets_zn) begin
            // We know we executing an operation that sets the flags
            unique case (opcode)
                LDI_A, LDI_B, LDI_C: begin
                    // LDI sets the flags based on the operand
                    load_data_is_zero_w = ( temp_1_out == {DATA_WIDTH{1'b0}} );
                    load_data_is_negative_w = temp_1_out[DATA_WIDTH - 1];
                end
                LDA: begin
                    // LDA sets the flags based on the internal_bus
                    load_data_is_zero_w = ( internal_bus == {DATA_WIDTH{1'b0}} );
                    load_data_is_negative_w = internal_bus[DATA_WIDTH - 1];
                end
                default: begin
                    load_data_is_zero_w = 1'b0;
                    load_data_is_negative_w = 1'b0;
                end
            endcase
        end
    end


    // Determine if flags should be set based on ALU op or LDI/LDA/LDB
    logic Z_in_w, N_in_w, C_in_w;
    always_comb begin
        
        // Default to current ALU_OP outputs
        Z_in_w = alu_zero_out_w;
        N_in_w = alu_negative_out_w;
        C_in_w = alu_carry_out_w;
        
        if (load_sets_zn) begin
            Z_in_w = load_data_is_zero_w;
            N_in_w = load_data_is_negative_w;
            C_in_w = 1'b0; // Carry flag is not set for LOAD operations
        end else if ( alu_op == ALU_INR || alu_op == ALU_DCR ) begin
            C_in_w = flags_reg_out[1];
        end
    end
endmodule
