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

    // Control signals for explicit set or clear of Carry flag
    input logic                  set_carry_flag_in,
    input logic                  clear_carry_flag_in,

    // Outputs: Final calculated flag values
    output logic                 zero_flag_out,
    output logic                 negative_flag_out,
    output logic                 carry_flag_out
);

    // Internal wires for intermediate calculations
    logic loaded_data_is_zero;
    logic loaded_data_is_neg;

    // Combinational logic for load operations that set Z/N flags
    // Determine if data loaded from RAM or immediately is <= 0
    always_comb begin
        loaded_data_is_zero = 1'b0;
        loaded_data_is_neg = 1'b0;

        if (load_sets_zn_in) begin
            unique case (opcode_in)
                LDI_A, LDI_B, LDI_C: begin
                    loaded_data_is_zero = (temp_1_out_in == {DATA_WIDTH{1'b0}});
                    loaded_data_is_neg = temp_1_out_in[DATA_WIDTH - 1];
                end
                LDA, PLA: begin
                    loaded_data_is_zero = (internal_bus_in == {DATA_WIDTH{1'b0}});
                    loaded_data_is_neg = internal_bus_in[DATA_WIDTH - 1];
                end
                default: begin
                    // Default to 0 for unknown load-setting opcodes (shouldn't happen if `load_sets_zn_in` is correct)
                end
            endcase
        end
    end

    // Combinational logic to determine the final flags to be loaded into the status register
    always_comb begin
        
        // Default flags to current state from status register
        zero_flag_out = current_status_in[STATUS_CPU_ZERO];
        negative_flag_out = current_status_in[STATUS_CPU_NEG];
        carry_flag_out = current_status_in[STATUS_CPU_CARRY];

        // Now set flags based on specific criteria
        // Case 1: Load operations set Z, N flags; preserve C
        // Op list: LDA, PLA, LDI => all set "load_sets_zn" control bit
        if(load_sets_zn_in) begin
            zero_flag_out = loaded_data_is_zero;
            negative_flag_out = loaded_data_is_neg;
        end else if (!set_carry_flag_in && !clear_carry_flag_in) begin
            // AIDEV-NOTE: Only process ALU operations when not doing explicit flag operations (SEC/CLC)
            unique case (alu_op_in)
                
                // Case 1: ALU Operations that set Z, N; preserve C 
                ALU_INR, ALU_DCR: begin
                    zero_flag_out = alu_zero_in;
                    negative_flag_out = alu_negative_in;                    
                end

                default: begin
                    zero_flag_out = alu_zero_in;
                    negative_flag_out = alu_negative_in;
                    carry_flag_out = alu_carry_in;  
                end
            endcase
        end

        //Special Case: Explict set/clear of C
        //Op list: SEC, SLC
        if (set_carry_flag_in) begin
            carry_flag_out = 1'b1;
        end else if (clear_carry_flag_in) begin
            carry_flag_out = 1'b0;
        end
    end

endmodule