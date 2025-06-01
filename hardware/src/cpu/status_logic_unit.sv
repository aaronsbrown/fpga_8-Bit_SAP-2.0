import arch_defs_pkg::*;

module status_logic_unit (
    
    // Inputs:
    // Raw flag outputs from the ALU
    input logic                  alu_zero_in,
    input logic                  alu_carry_in,
    input logic                  alu_negative_in,

    // Control signal indicating if flags should be set by a LOAD operation
    input logic                  load_sets_zn_in,

    // Opcode to differentiate between different LOAD operations
    input opcode_t               opcode_in,

    // Data sources for LOAD operations
    input logic [DATA_WIDTH-1:0] temp_1_out_in,   // For LDI_A, LDI_B, LDI_C
    input logic [DATA_WIDTH-1:0] internal_bus_in, // For LDA, PLA

    // Current ALU operation being performed (from control unit)
    input logic [3:0]            alu_op_in,

    // Current status register value (needed for INR/DCR to maintain carry)
    input logic [DATA_WIDTH-1:0] current_status_in,

    // Outputs: Final calculated flag values
    output logic                 zero_flag_out,
    output logic                 negative_flag_out,
    output logic                 carry_flag_out
);

    // Internal wires for intermediate calculations
    logic load_data_is_zero_w;
    logic load_data_is_negative_w;

    // Combinational logic for load operations that set Z/N flags
    always_comb begin
        load_data_is_zero_w = 1'b0;
        load_data_is_negative_w = 1'b0;

        if (load_sets_zn_in) begin
            unique case (opcode_in)
                LDI_A, LDI_B, LDI_C: begin
                    load_data_is_zero_w = (temp_1_out_in == {DATA_WIDTH{1'b0}});
                    load_data_is_negative_w = temp_1_out_in[DATA_WIDTH - 1];
                end
                LDA, PLA: begin
                    load_data_is_zero_w = (internal_bus_in == {DATA_WIDTH{1'b0}});
                    load_data_is_negative_w = internal_bus_in[DATA_WIDTH - 1];
                end
                default: begin
                    // Default to 0 for unknown load-setting opcodes (shouldn't happen if `load_sets_zn_in` is correct)
                end
            endcase
        end
    end

    // Combinational logic to determine the final flags to be loaded into the status register
    always_comb begin
        // Default to ALU's output flags
        zero_flag_out = alu_zero_in;
        negative_flag_out = alu_negative_in;
        carry_flag_out = alu_carry_in;

        // Override if flags are set by a LOAD operation
        if (load_sets_zn_in) begin
            zero_flag_out = load_data_is_zero_w;
            negative_flag_out = load_data_is_negative_w;
            carry_flag_out = 1'b0; // Carry flag is always cleared for LOAD operations
        end
        // Special handling for INR/DCR which preserve the carry flag
        else if (alu_op_in == ALU_INR || alu_op_in == ALU_DCR) begin
            carry_flag_out = current_status_in[STATUS_CPU_CARRY]; // Maintain previous carry flag
        end
    end

endmodule