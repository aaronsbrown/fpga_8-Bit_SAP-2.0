import arch_defs_pkg::*;

module control_unit (
    input   logic                               clk,
    input   logic                               reset,
    input   opcode_t                            opcode,
    input   logic           [2:0]               flags,
    output  control_word_t                      control_word,
    output  logic                               last_microstep

);


    // ==================================================================================================
    // ======================================== STATE REGISTERS =========================================
    fsm_state_t current_state = S_RESET; // Current microstep in execution
    fsm_state_t next_state = S_RESET; // Next microstep to transition to

    microstep_t current_microstep; // Current microstep in execution
    microstep_t next_microstep; // Next microstep to transition to

    logic cmd_latch_alu_op;
    logic [3:0] current_alu_op;
    logic [3:0] next_alu_op;

    logic [1:0] current_byte_count;
    logic [1:0] next_byte_count;
    logic [1:0] num_operand_bytes;
    

    // ==================================================================================================
    // ======================================== ISA OPCODE <=> NUM OPERANDS =============================
    always_comb begin
        num_operand_bytes = 2'bxx;
        case (opcode)
            NOP, HLT, ADD_B, ADD_C, SUB_B, SUB_C, INR_A, DCR_A,
            ADC_B, ADC_C, SBC_B, SBC_C, ANA_B, ANA_C, ORA_B, ORA_C,
            XRA_B, XRA_C, CMP_B, CMP_C, MOV_AB, MOV_AC, MOV_BA, MOV_BC, 
            MOV_CA, MOV_CB, CMA, INR_B, DCR_B, INR_C, DCR_C, RAR, RAL,
            PHA, PLA, PHP, PLP, RET, SEC, CLC
            : begin
                num_operand_bytes = 2'b00; // No operands
            end
            LDI_A, LDI_B, LDI_C, ANI, ORI, XRI: begin
                num_operand_bytes = 2'b01; // One operand
            end
            JMP, JZ, JNZ, JN, JNN, JC, JNC, LDA, STA, JSR: begin
                num_operand_bytes = 2'b10; // Two operands
            end
            default: begin
                num_operand_bytes = 2'bxx; // Unknown opcode
                if ( opcode != {OPCODE_WIDTH{1'bx}})
                    $display($time, " Warning: Unrecognized Opcode %h in case statement", opcode);
            end
        endcase
    end
    
    
    // ==================================================================================================
    // ======================================== SEQ STATE MANAGEMENT =============================
    // Sequential logic for controlling the CPU's operation based on clock and reset signals
    always_ff @(posedge clk) begin 
        if (reset) begin 
            current_state <= S_RESET;
            current_microstep <= MS0; 
            current_byte_count <= 2'b00; 
            current_alu_op <= ALU_UNDEFINED;
        end else begin 
            current_state <= next_state; 
            current_microstep <= next_microstep; 
            current_byte_count <= next_byte_count; 
            if(cmd_latch_alu_op)
                current_alu_op <= next_alu_op; 
        end
    end

    // ==================================================================================================
    // ======================================== STATE DEFINITION =============================
    // Combinational logic to determine the next state and control word based on the current step
    
    logic check_jump_condition = 1'b0; // Initialize jump condition check
    logic jump_condition_satisfied = 1'b0; // Initialize jump condition satisfied flag
    always_comb begin 

        next_state = current_state;
        next_microstep = current_microstep; 
        next_byte_count = current_byte_count;
        next_alu_op = current_alu_op;
        control_word = '{default: 0, alu_op: ALU_UNDEFINED}; 
        last_microstep = 1'b0;
        cmd_latch_alu_op = 1'b0;


        case (current_state)
            
            S_RESET: begin
                next_state = S_INIT; 
            end
            
            S_INIT: begin
                control_word.load_origin = 1'b1; 
                control_word.load_sp_default_address = 1'b1;
                next_state = S_LATCH_ADDR; 
            end

            S_LATCH_ADDR: begin
                control_word.load_mar_pc = 1'b1; // Load MAR with PC
                next_state = S_READ_BYTE; 
            end 

            S_READ_BYTE: begin
                control_word.oe_ram = 1; 
                next_state = S_LATCH_BYTE; // Read from RAM
            end

            S_LATCH_BYTE: begin
                control_word.oe_ram = 1'b1;
                control_word.pc_enable = 1'b1;

                case (current_byte_count)
                    2'b00: begin
                        control_word.load_ir = 1'b1; // Load instruction register
                    end
                    2'b01: begin
                        control_word.load_temp_1 = 1'b1; // Load first operand into temp_1
                    end
                    2'b10: begin
                        control_word.load_temp_2 = 1'b1; // Load second operand into temp_2
                    end
                    default: begin
                        next_state = S_HALT;
                        next_byte_count = 2'b00;
                        $display($time, " Error: Too many bytes read. Expected %0d, got %0d", num_operand_bytes, current_byte_count);
                    end
                endcase

                next_state = S_CHK_MORE_BYTES; 
                next_byte_count = current_byte_count + 1; 
            end
            
            S_CHK_MORE_BYTES: begin
                if ( current_byte_count > num_operand_bytes ) begin
                    next_state = S_EXECUTE;
                    next_byte_count = 2'b00;
                end else begin
                    next_state = S_LATCH_ADDR;
                end 
            end
            
            S_EXECUTE: begin
                control_word = microcode_rom[opcode][current_microstep]; // Fetch control word from microcode ROM
                
                check_jump_condition = control_word.check_zero     || control_word.check_not_zero     ||
                                       control_word.check_carry    || control_word.check_not_carry    ||
                                       control_word.check_negative || control_word.check_not_negative;
                
                jump_condition_satisfied = (control_word.check_zero && flags[STATUS_CPU_ZERO])         ||
                                           (control_word.check_not_zero && !flags[STATUS_CPU_ZERO])    ||
                                           (control_word.check_carry && flags[STATUS_CPU_CARRY])       ||
                                           (control_word.check_not_carry && !flags[STATUS_CPU_CARRY])  ||
                                           (control_word.check_negative && flags[STATUS_CPU_NEG])      ||
                                           (control_word.check_not_negative && !flags[STATUS_CPU_NEG]);


                // Latch ALU_OP for duration of Exectuion cycle 
                if(current_microstep == MS0) begin
                    cmd_latch_alu_op = 1'b1;
                    next_alu_op = control_word.alu_op;
                end else begin
                    // ensure control word's alu_op reflects the latched alu_op
                    control_word.alu_op = current_alu_op;
                end

                // Derive last_microstep pulse
                last_microstep = control_word.halt || control_word.last_step || (check_jump_condition && !jump_condition_satisfied);

                // HALT
                if (control_word.halt) begin
                    next_state = S_HALT; 
                    next_microstep = MS0; 
               
                // UN/CONDITIONAL BRANCH
                end else if ( check_jump_condition && !jump_condition_satisfied) begin
                   
                   // Don't Jump! Suppress loading PC with new JMP address if conditions aren't met
                   control_word.load_pc_low_byte = 1'b0;
                   control_word.load_pc_high_byte = 1'b0;
                   next_state = S_LATCH_ADDR;
                   next_microstep = MS0; 
                
                // LAST STEP
                end else if (control_word.last_step) begin
                    next_state = S_LATCH_ADDR; 
                    next_microstep = MS0;
                
                // NEXT STEP
                end else begin
                    next_state = S_EXECUTE;
                    next_microstep = current_microstep + 1; // Increment microstep
                end
            end
            
            S_HALT: begin
                control_word = '{default: 0}; // Default control word
                next_state = S_HALT; // Remain in halt state
            end

            default: begin
                control_word = '{default: 0}; // Default control word
                next_state = S_HALT; // Transition to halt state on error
            end
        endcase

        // Important: Ensure alu_op reflects the latched alu_op code
        if (current_microstep != MS0 && current_state == S_EXECUTE)
            control_word.alu_op = current_alu_op;

    end

    // ==================================================================================================
    // ======================================== MICROCODE ROM ===========================================
    control_word_t microcode_rom [MAX_OPCODES][MAX_MICROSTEPS];
    initial begin
        for (int i = 0; i < MAX_OPCODES; i++) begin
            for (int s = 0; s < MAX_MICROSTEPS; s++) begin
                microcode_rom[i][s] = '{default: 0, alu_op: ALU_UNDEFINED}; // Initialize each microstep to zero
            end
        end
        
        // CONTROL FLOW
        microcode_rom[NOP][MS0] = '{default: 0, last_step: 1}; 
        
        microcode_rom[HLT][MS0] = '{default: 0, halt: 1}; 

        // BRANCHING
        microcode_rom[JMP][MS0] = '{default: 0, oe_temp_1: 1, load_pc_low_byte: 1}; 
        microcode_rom[JMP][MS1] = '{default: 0, oe_temp_2: 1, load_pc_high_byte: 1, last_step: 1};

        microcode_rom[JZ][MS0] = '{default: 0, oe_temp_1: 1, load_pc_low_byte: 1, check_zero: 1}; 
        microcode_rom[JZ][MS1] = '{default: 0, oe_temp_2: 1, load_pc_high_byte: 1, last_step: 1};

        microcode_rom[JNZ][MS0] = '{default: 0, oe_temp_1: 1, load_pc_low_byte: 1, check_not_zero: 1}; 
        microcode_rom[JNZ][MS1] = '{default: 0, oe_temp_2: 1, load_pc_high_byte: 1, last_step: 1};

        microcode_rom[JN][MS0] = '{default: 0, oe_temp_1: 1, load_pc_low_byte: 1, check_negative: 1}; 
        microcode_rom[JN][MS1] = '{default: 0, oe_temp_2: 1, load_pc_high_byte: 1, last_step: 1};

        microcode_rom[JNN][MS0] = '{default: 0, oe_temp_1: 1, load_pc_low_byte: 1, check_not_negative: 1}; 
        microcode_rom[JNN][MS1] = '{default: 0, oe_temp_2: 1, load_pc_high_byte: 1, last_step: 1};
        
        microcode_rom[JC][MS0] = '{default: 0, oe_temp_1: 1, load_pc_low_byte: 1, check_carry: 1}; 
        microcode_rom[JC][MS1] = '{default: 0, oe_temp_2: 1, load_pc_high_byte: 1, last_step: 1};

        microcode_rom[JNC][MS0] = '{default: 0, oe_temp_1: 1, load_pc_low_byte: 1, check_not_carry: 1}; 
        microcode_rom[JNC][MS1] = '{default: 0, oe_temp_2: 1, load_pc_high_byte: 1, last_step: 1};

        // SUBROUTINES
        microcode_rom[JSR][MS0] = '{default: 0, load_mar_sp: 1}; 
        microcode_rom[JSR][MS1] = '{default: 0, sp_dec: 1}; 
        microcode_rom[JSR][MS2] = '{default: 0, oe_pc_high_byte: 1};
        microcode_rom[JSR][MS3] = '{default: 0, oe_pc_high_byte: 1, load_ram: 1}; 
        microcode_rom[JSR][MS4] = '{default: 0, load_mar_sp: 1};
        microcode_rom[JSR][MS5] = '{default: 0, sp_dec: 1};
        microcode_rom[JSR][MS6] = '{default: 0, oe_pc_low_byte: 1};
        microcode_rom[JSR][MS7] = '{default: 0, oe_pc_low_byte: 1, load_ram: 1};
        microcode_rom[JSR][MS8] = '{default: 0, oe_temp_1: 1, load_pc_low_byte: 1};
        microcode_rom[JSR][MS9] = '{default: 0, oe_temp_2: 1, load_pc_high_byte: 1, last_step: 1};

        microcode_rom[RET][MS0] = '{default: 0, sp_inc: 1};
        microcode_rom[RET][MS1] = '{default: 0, load_mar_sp: 1};  
        microcode_rom[RET][MS2] = '{default: 0, oe_ram: 1}; 
        microcode_rom[RET][MS3] = '{default: 0, oe_ram: 1, load_pc_low_byte: 1};
        microcode_rom[RET][MS4] = '{default: 0, sp_inc: 1}; 
        microcode_rom[RET][MS5] = '{default: 0, load_mar_sp: 1};  
        microcode_rom[RET][MS6] = '{default: 0, oe_ram: 1};
        microcode_rom[RET][MS7] = '{default: 0, oe_ram: 1, load_pc_high_byte: 1, last_step: 1};
         

        // REG_A ARITH
        microcode_rom[ADD_B][MS0] = '{default: 0, alu_op: ALU_ADD, alu_src2_c: 0};
        microcode_rom[ADD_B][MS1] = '{default: 0, oe_alu: 1, load_a: 1, load_status: 1, last_step: 1};
        
        microcode_rom[ADD_C][MS0] = '{default: 0, alu_op: ALU_ADD, alu_src2_c: 1} ;
        microcode_rom[ADD_C][MS1] = '{default: 0, oe_alu: 1, load_a: 1, load_status: 1, last_step: 1};

        microcode_rom[ADC_B][MS0] = '{default: 0, alu_op: ALU_ADC, alu_src2_c: 0} ;
        microcode_rom[ADC_B][MS1] = '{default: 0, oe_alu: 1, load_a: 1, load_status: 1, last_step: 1};

        microcode_rom[ADC_C][MS0] = '{default: 0, alu_op: ALU_ADC, alu_src2_c: 1} ;
        microcode_rom[ADC_C][MS1] = '{default: 0, oe_alu: 1, load_a: 1, load_status: 1, last_step: 1};  
 
        microcode_rom[SUB_B][MS0] = '{default: 0, alu_op: ALU_SUB, alu_src2_c: 0} ;
        microcode_rom[SUB_B][MS1] = '{default: 0, oe_alu: 1, load_a: 1, load_status: 1, last_step: 1};

        microcode_rom[SUB_C][MS0] = '{default: 0, alu_op: ALU_SUB, alu_src2_c: 1} ;
        microcode_rom[SUB_C][MS1] = '{default: 0, oe_alu: 1, load_a: 1, load_status: 1, last_step: 1};

        microcode_rom[SBC_B][MS0] = '{default: 0, alu_op: ALU_SBC, alu_src2_c: 0} ;
        microcode_rom[SBC_B][MS1] = '{default: 0, oe_alu: 1, load_a: 1, load_status: 1, last_step: 1};

        microcode_rom[SBC_C][MS0] = '{default: 0, alu_op: ALU_SBC, alu_src2_c: 1} ;
        microcode_rom[SBC_C][MS1] = '{default: 0, oe_alu: 1, load_a: 1, load_status: 1, last_step: 1};

        microcode_rom[INR_A][MS0] = '{default: 0, alu_op: ALU_INR};
        microcode_rom[INR_A][MS1] = '{default: 0, oe_alu: 1, load_a: 1, load_status: 1, last_step: 1};
        
        microcode_rom[DCR_A][MS0] = '{default: 0, alu_op: ALU_DCR};
        microcode_rom[DCR_A][MS1] = '{default: 0, oe_alu: 1, load_a: 1, load_status: 1, last_step: 1};

        // LOGICAL 
        microcode_rom[ANA_B][MS0] = '{default: 0, alu_op: ALU_AND};
        microcode_rom[ANA_B][MS1] = '{default: 0, oe_alu: 1, load_a: 1, load_status: 1, last_step: 1};

        microcode_rom[ANA_C][MS0] = '{default: 0, alu_op: ALU_AND, alu_src2_c: 1};
        microcode_rom[ANA_C][MS1] = '{default: 0, oe_alu: 1, load_a: 1, load_status: 1, last_step: 1};

        microcode_rom[ANI][MS0] = '{default: 0, oe_temp_1: 1, alu_op: ALU_AND, alu_src2_temp1: 1};
        microcode_rom[ANI][MS1] = '{default: 0, oe_alu: 1, load_a: 1, load_status: 1, last_step: 1};

        microcode_rom[ORA_B][MS0] = '{default: 0, alu_op: ALU_OR};
        microcode_rom[ORA_B][MS1] = '{default: 0, oe_alu: 1, load_a: 1, load_status: 1, last_step: 1};

        microcode_rom[ORA_C][MS0] = '{default: 0, alu_op: ALU_OR, alu_src2_c: 1};
        microcode_rom[ORA_C][MS1] = '{default: 0, oe_alu: 1, load_a: 1, load_status: 1, last_step: 1};

        microcode_rom[ORI][MS0] = '{default: 0, oe_temp_1: 1, alu_op: ALU_OR, alu_src2_temp1: 1};
        microcode_rom[ORI][MS1] = '{default: 0, oe_alu: 1, load_a: 1, load_status: 1, last_step: 1};

        microcode_rom[XRA_B][MS0] = '{default: 0, alu_op: ALU_XOR};
        microcode_rom[XRA_B][MS1] = '{default: 0, oe_alu: 1, load_a: 1, load_status: 1, last_step: 1};

        microcode_rom[XRA_C][MS0] = '{default: 0, alu_op: ALU_XOR, alu_src2_c: 1};
        microcode_rom[XRA_C][MS1] = '{default: 0, oe_alu: 1, load_a: 1, load_status: 1, last_step: 1};

        microcode_rom[XRI][MS0] = '{default: 0, oe_temp_1: 1, alu_op: ALU_XOR, alu_src2_temp1: 1};
        microcode_rom[XRI][MS1] = '{default: 0, oe_alu: 1, load_a: 1, load_status: 1, last_step: 1};
 
        microcode_rom[CMP_B][MS0] = '{default: 0, alu_op: ALU_SUB, alu_src2_c: 0} ;
        microcode_rom[CMP_B][MS1] = '{default: 0, load_status: 1, last_step: 1};

        microcode_rom[CMP_C][MS0] = '{default: 0, alu_op: ALU_SUB, alu_src2_c: 1} ;
        microcode_rom[CMP_C][MS1] = '{default: 0, load_status: 1, last_step: 1};

        // REG_A MISC / ROT
        microcode_rom[RAR][MS0] = '{default: 0, alu_op: ALU_ROR};
        microcode_rom[RAR][MS1] = '{default: 0}; // allow ALU_OP to latch 
        microcode_rom[RAR][MS2] = '{default: 0, oe_alu: 1, load_a: 1, load_status: 1, last_step: 1}; 
        
        microcode_rom[RAL][MS0] = '{default: 0, alu_op: ALU_ROL};
        microcode_rom[RAL][MS1] = '{default: 0, oe_alu: 1, load_a: 1, load_status: 1, last_step: 1};

        microcode_rom[CMA][MS0] = '{default: 0, alu_op: ALU_INV};
        microcode_rom[CMA][MS1] = '{default: 0, oe_alu: 1, load_a: 1, load_status: 1, last_step: 1}; 

        // REG_B / REG_C
        microcode_rom[INR_B][MS0] = '{default: 0, alu_op: ALU_INR, alu_src1_b: 1};
        microcode_rom[INR_B][MS1] = '{default: 0, oe_alu: 1, load_b: 1, load_status: 1, last_step: 1};
        
        microcode_rom[DCR_B][MS0] = '{default: 0, alu_op: ALU_DCR, alu_src1_b: 1};
        microcode_rom[DCR_B][MS1] = '{default: 0, oe_alu: 1, load_b: 1, load_status: 1, last_step: 1};

        microcode_rom[INR_C][MS0] = '{default: 0, alu_op: ALU_INR, alu_src1_c: 1};
        microcode_rom[INR_C][MS1] = '{default: 0, oe_alu: 1, load_c: 1, load_status: 1, last_step: 1};
        
        microcode_rom[DCR_C][MS0] = '{default: 0, alu_op: ALU_DCR, alu_src1_c: 1};
        microcode_rom[DCR_C][MS1] = '{default: 0, oe_alu: 1, load_c: 1, load_status: 1, last_step: 1};

        // REGISTER MOVES
        microcode_rom[MOV_AB][MS0] = '{default: 0, oe_a: 1, load_b: 1, last_step: 1} ; 
        microcode_rom[MOV_AC][MS0] = '{default: 0, oe_a: 1, load_c: 1, last_step: 1} ; 
        microcode_rom[MOV_BA][MS0] = '{default: 0, oe_b: 1, load_a: 1, last_step: 1} ; 
        microcode_rom[MOV_BC][MS0] = '{default: 0, oe_b: 1, load_c: 1, last_step: 1} ; 
        microcode_rom[MOV_CA][MS0] = '{default: 0, oe_c: 1, load_a: 1, last_step: 1} ; 
        microcode_rom[MOV_CB][MS0] = '{default: 0, oe_c: 1, load_b: 1, last_step: 1} ; 

        // STATUS REG CONTROL
        microcode_rom[SEC][MS0] = '{default: 0, set_carry_flag: 1, load_status: 1, last_step: 1} ;
        microcode_rom[CLC][MS0] = '{default: 0, clear_carry_flag: 1, load_status: 1, last_step: 1} ; 
        

        // STACK: "Empty Descending Stack"; SP initialized to first empty memrory cell in Stack
        microcode_rom[PHA][MS0] = '{default: 0, load_mar_sp: 1} ;
        microcode_rom[PHA][MS1] = '{default: 0, sp_dec: 1} ;  
        microcode_rom[PHA][MS2] = '{default: 0, oe_a: 1} ;  
        microcode_rom[PHA][MS3] = '{default: 0, oe_a: 1, load_ram: 1, last_step: 1} ; 

        microcode_rom[PLA][MS0] = '{default: 0, sp_inc: 1};
        microcode_rom[PLA][MS1] = '{default: 0, load_mar_sp: 1};  
        microcode_rom[PLA][MS2] = '{default: 0, oe_ram: 1};  
        microcode_rom[PLA][MS3] = '{default: 0, oe_ram: 1, load_a: 1, last_step: 1, load_status: 1, load_sets_zn: 1};  

        microcode_rom[PHP][MS0] = '{default: 0, load_mar_sp: 1};
        microcode_rom[PHP][MS1] = '{default: 0, sp_dec: 1};  
        microcode_rom[PHP][MS2] = '{default: 0, oe_status: 1};  
        microcode_rom[PHP][MS3] = '{default: 0, oe_status: 1, load_ram: 1, last_step: 1}; 

        microcode_rom[PLP][MS0] = '{default: 0, sp_inc: 1};
        microcode_rom[PLP][MS1] = '{default: 0, load_mar_sp: 1};  
        microcode_rom[PLP][MS2] = '{default: 0, oe_ram: 1};  
        microcode_rom[PLP][MS3] = '{default: 0, oe_ram: 1, load_status: 1, status_src_ram: 1, last_step: 1};  

        // MEMORY
        microcode_rom[LDA][MS0] = '{default: 0, oe_temp_1: 1}; 
        microcode_rom[LDA][MS1] = '{default: 0, oe_temp_1: 1, load_mar_addr_low: 1}; 
        microcode_rom[LDA][MS2] = '{default: 0, oe_temp_2: 1}; 
        microcode_rom[LDA][MS3] = '{default: 0, oe_temp_2: 1, load_mar_addr_high: 1};
        microcode_rom[LDA][MS4] = '{default: 0, oe_ram: 1};  
        microcode_rom[LDA][MS5] = '{default: 0, oe_ram: 1, load_a: 1, load_status: 1, last_step: 1, load_sets_zn: 1}; 

        microcode_rom[STA][MS0] = '{default: 0, oe_temp_1: 1};
        microcode_rom[STA][MS1] = '{default: 0, oe_temp_1: 1, load_mar_addr_low: 1}; 
        microcode_rom[STA][MS2] = '{default: 0, oe_temp_2: 1}; 
        microcode_rom[STA][MS3] = '{default: 0, oe_temp_2: 1, load_mar_addr_high: 1};
        microcode_rom[STA][MS4] = '{default: 0, oe_a: 1};
        microcode_rom[STA][MS5] = '{default: 0, oe_a: 1, load_ram: 1, last_step: 1};
        
        // IMMEDIATE LOADS
        microcode_rom[LDI_A][MS0] = '{default: 0, oe_temp_1: 1, load_a: 1, load_status: 1, last_step: 1, load_sets_zn: 1}; 
        microcode_rom[LDI_B][MS0] = '{default: 0, oe_temp_1: 1, load_b: 1, load_status: 1, last_step: 1, load_sets_zn: 1}; 
        microcode_rom[LDI_C][MS0] = '{default: 0, oe_temp_1: 1, load_c: 1, load_status: 1, last_step: 1, load_sets_zn: 1}; 

    end

endmodule