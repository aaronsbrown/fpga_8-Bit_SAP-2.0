import arch_defs_pkg::*;

// This module implements a simple microcoded CPU architecture. It includes a program counter, registers, 
// a RAM interface, and a microcode ROM to control the CPU's operations based on opcodes and microsteps.

module cpu (
    input wire  clk,
    input wire  reset, 
    
    // ================= MEMORY BUS INTERFACE =============================
    output wire [ADDR_WIDTH-1:0] mem_address,   // address driven by cpu
    output wire mem_read,                       // read request strobe 
    output wire mem_write,                      // write request strobe
    input  wire [DATA_WIDTH-1:0] mem_data_in,   // data driven *to* cpu 
    output wire [DATA_WIDTH-1:0] mem_data_out,  // data driven *from* cpu
    
    // ================= HALT SIGNAL ================
    output wire halt,
    output wire instr_complete,

    // ================= FLAGS ======================
    output wire flag_zero_o,
    output wire flag_carry_o,
    output wire flag_negative_o,

    // ================= DEBUG SIGNALS ==============
    output wire [DATA_WIDTH-1:0] debug_out_B,
    output wire [DATA_WIDTH-1:0] debug_out_IR,
    output wire [ADDR_WIDTH-1:0] debug_out_PC

);

    
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
    assign mem_data_out = internal_bus; 
    

    // =============== CONNECT FLAGS  ======================
    // =====================================================
    assign flag_zero_o = status_out[STATUS_CPU_ZERO];
    assign flag_carry_o = status_out[STATUS_CPU_CARRY];
    assign flag_negative_o = status_out[STATUS_CPU_NEG];


    // =============== OPCODE  ==============
    // ==============================================================
    logic [DATA_WIDTH-1:0] opcode;
    
    
    // =============== ALU OPERATIONS =====================
    // ====================================================
    logic [3:0] alu_op;
  
   
    // =============== DEFAULT SP ORIGIN ================
    // ===================================================
    logic [ADDR_WIDTH-1:0] default_sp_origin;
    assign default_sp_origin = SP_VECTOR;


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

    // Control signals for SP
    logic load_sp_default_address, sp_inc, sp_dec;

    // Control signals for loading data from the internal_bus into registers
    logic load_a, load_b, load_c, load_tmp, load_ir, load_status, load_sets_zn, load_temp_1, load_temp_2;
    logic load_pc_high_byte, load_pc_low_byte;
    
    // Control signals for outputting data to the internal_bus
    logic oe_a, oe_b, oe_c, oe_temp_1, oe_temp_2, oe_ram, oe_alu, oe_status, oe_pc_low_byte, oe_pc_high_byte;

    // Control signals for ALU src multiplexer
    logic alu_src2_c, alu_src2_temp1;

    // Control signal for Status Reg 
    logic status_src_ram;
    logic clear_carry_flag, set_carry_flag;

    control_word_t control_word = '{default: 0};
    assign load_a = control_word.load_a;
    assign load_b = control_word.load_b;
    assign load_c = control_word.load_c;
    assign load_temp_1 = control_word.load_temp_1;
    assign load_temp_2 = control_word.load_temp_2;
    assign load_ir = control_word.load_ir;
    assign oe_pc_low_byte = control_word.oe_pc_low_byte;
    assign oe_pc_high_byte = control_word.oe_pc_high_byte;
    assign load_pc_low_byte = control_word.load_pc_low_byte;
    assign load_pc_high_byte = control_word.load_pc_high_byte;
    assign load_mar_pc = control_word.load_mar_pc;
    assign load_mar_addr_high = control_word.load_mar_addr_high;
    assign load_mar_addr_low = control_word.load_mar_addr_low;
    assign load_mar_reset_vec_addr_low = control_word.load_mar_reset_vec_addr_low;
    assign load_mar_reset_vec_addr_high = control_word.load_mar_reset_vec_addr_high;
    assign oe_ir = control_word.oe_ir;
    assign oe_pc = control_word.oe_pc;
    assign oe_alu = control_word.oe_alu;
    assign alu_op = control_word.alu_op;
    assign pc_enable = control_word.pc_enable; 
    assign halt = control_word.halt;
    assign load_sets_zn = control_word.load_sets_zn;
    assign oe_a = control_word.oe_a;
    assign oe_b = control_word.oe_b; 
    assign oe_c = control_word.oe_c; 
    assign oe_temp_1 = control_word.oe_temp_1; 
    assign oe_temp_2 = control_word.oe_temp_2;
    assign oe_ram = control_word.oe_ram;
    assign alu_src2_c = control_word.alu_src2_c;
    assign alu_src2_temp1 = control_word.alu_src2_temp1; 
    assign alu_src1_b = control_word.alu_src1_b;
    assign alu_src1_c = control_word.alu_src1_c;
    assign load_sp_default_address = control_word.load_sp_default_address;
    assign sp_inc = control_word.sp_inc;
    assign sp_dec = control_word.sp_dec;
    assign load_mar_sp = control_word.load_mar_sp;
    assign load_status = control_word.load_status;
    assign oe_status = control_word.oe_status;
    assign status_src_ram = control_word.status_src_ram;
    assign set_carry_flag = control_word.set_carry_flag;
    assign clear_carry_flag = control_word.clear_carry_flag; 
    
    
    // =========== BUS INTERFACE and 'internal_bus staging' registers ===============
    // ==============================================================================
    logic [DATA_WIDTH-1:0] internal_bus;
    logic [DATA_WIDTH-1:0] a_out, b_out, c_out, temp_1_out, temp_2_out, alu_out, counter_byte_out, status_out;
    logic [ADDR_WIDTH-1:0] counter_out, stack_pointer_out, mar_out;
    
    // Tri-state bus logic modeled using a priority multiplexer
    assign internal_bus =    
                    (oe_ram)            ? mem_data_in :
                    (oe_alu)            ? alu_out :
                    (oe_a)              ? a_out :
                    (oe_b)              ? b_out :
                    (oe_c)              ? c_out :
                    (oe_temp_1)         ? temp_1_out :
                    (oe_temp_2)         ? temp_2_out :
                    (oe_pc_low_byte)    ? counter_byte_out :
                    (oe_pc_high_byte)   ? counter_byte_out :
                    (oe_status)         ? status_out :
                    { DATA_WIDTH {1'b0} };


    // ================ REGISTER DECLARATIONS ===========
    // ==================================================
    program_counter u_program_counter (
        .clk(clk),
        .reset(reset),
        .enable(pc_enable),
        .output_high_byte(oe_pc_high_byte),
        .output_low_byte(oe_pc_low_byte),
        .load_high_byte(load_pc_high_byte),
        .load_low_byte(load_pc_low_byte),
        .counter_in(internal_bus),
        .counter_out(counter_out),
        .counter_byte_out(counter_byte_out)
    );

    stack_pointer u_stack_pointer (
        .clk(clk),
        .reset(reset),
        .load_initial_address(load_sp_default_address),
        .increment(sp_inc),
        .decrement(sp_dec),
        .address_in(default_sp_origin),
        .address_out(stack_pointer_out)
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

    logic load_mar_addr_high, load_mar_addr_low, load_mar_pc, load_mar_sp,
        load_mar_reset_vec_addr_low, load_mar_reset_vec_addr_high;
    register_memory_address u_register_memory_address (
      .clk(clk),
      .reset(reset),
      .load_pc(load_mar_pc),
      .load_sp(load_mar_sp),
      .load_addr_high(load_mar_addr_high),
      .load_addr_low(load_mar_addr_low),
      .load_reset_vec_addr_low(load_mar_reset_vec_addr_low),
      .load_reset_vec_addr_high(load_mar_reset_vec_addr_high),
      .bus_in(internal_bus),
      .program_counter_in(counter_out),
      .stack_pointer_in(stack_pointer_out),
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
    // (* keep *) logic [DATA_WIDTH-1:0] status_out;
    
    // Flags register to hold the status flags
    // Z: Zero flag, C: Carry flag, N: Negative flag
    
    logic [DATA_WIDTH-1:0] status_reg_source;
    assign status_reg_source = (status_src_ram) ? 
                               internal_bus : 
                               {status_reg_carry_flag, status_reg_neg_flag, status_reg_zero_flag};
    
    register_nbit #( .N(DATA_WIDTH) ) u_register_status (
        .clk(clk),
        .reset(reset),
        .load(load_status),
        .data_in(status_reg_source),
        .latched_data(status_out)
    );

    
    // ================ MAIN COMPONENTS: ALU, CONTROL UNIT, STATUS LOGIC UNIT ================
    // =======================================================================================
    
    // Register an Instruction_Complete pulse
    logic instr_complete_current, instr_complete_next;
    always_ff @(posedge clk) begin 
        if (reset) 
            instr_complete_current <= 1'b0;
        else 
            instr_complete_current <= instr_complete_next;
    end
    assign instr_complete = instr_complete_current;

    control_unit u_control_unit (
        .clk(clk),
        .reset(reset),
        .opcode(opcode),
        .flags(status_out),
        .control_word(control_word),
        .last_microstep(instr_complete_next)
    );

    // ALU source muxes
    logic [DATA_WIDTH-1:0] in_one_src, in_two_src; 
    assign in_one_src = (alu_src1_b) ? b_out :
                        (alu_src1_c) ? c_out :
                        a_out;
    assign in_two_src = (alu_src2_c) ? c_out : 
                        (alu_src2_temp1) ? temp_1_out :
                        b_out;
    
    alu u_alu (
        .clk(clk),
        .reset(reset),
        .in_one(in_one_src),
        .in_two(in_two_src),
        .in_carry(status_out[STATUS_CPU_CARRY]),
        .alu_op(alu_op),
        .latched_result(alu_out),
        .zero_flag(alu_zero_flag),
        .carry_flag(alu_carry_flag),
        .negative_flag(alu_neg_flag)
    );

    logic alu_zero_flag;
    logic alu_carry_flag;
    logic alu_neg_flag;
    logic status_reg_zero_flag, status_reg_neg_flag, status_reg_carry_flag;
    
    status_logic_unit u_status_logic_unit (
        .alu_zero_in(alu_zero_flag),
        .alu_carry_in(alu_carry_flag),
        .alu_negative_in(alu_neg_flag),
        .load_sets_zn_in(load_sets_zn),
        .opcode_in(opcode),
        .temp_1_out_in(temp_1_out),
        .internal_bus_in(internal_bus),
        .alu_op_in(alu_op), 
        .current_status_in(status_out),
        .set_carry_flag_in(set_carry_flag),
        .clear_carry_flag_in(clear_carry_flag),
        .zero_flag_out(status_reg_zero_flag),
        .negative_flag_out(status_reg_neg_flag),
        .carry_flag_out(status_reg_carry_flag)
    );
    
endmodule
