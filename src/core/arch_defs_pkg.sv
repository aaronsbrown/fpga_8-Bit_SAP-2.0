package arch_defs_pkg;

    parameter int DATA_WIDTH = 8;
    parameter int ADDR_WIDTH = 16;
    parameter int FLAG_COUNT = 3;

    parameter int RAM_DEPTH  = (1 << ADDR_WIDTH);
    parameter int OPCODE_WIDTH = DATA_WIDTH;
    parameter int OPERAND_WIDTH = DATA_WIDTH;

    parameter RESET_VECTOR = 16'hF000; // hardcoded reset vector

    typedef enum logic [OPCODE_WIDTH-1:0] {
        NOP =   8'h00,  
        HLT =   8'h01,  // TODO update test to new pattern
        JMP =   8'h10,  // tested
        JZ  =   8'h11,  // tested
        JNZ =   8'h12,  // tested
        JN  =   8'h13,  // tested
        ADD_B = 8'h20,  // tested
        ADD_C = 8'h21,  // tested
        ADC_B = 8'h22,   // tested
        ADC_C = 8'h23,    // tested
        SUB_B = 8'h24,  // tested
        SUB_C = 8'h25,  // tested
        SBC_B = 8'h26,
        SBC_C = 8'h27,
        INR_A = 8'h28,  // tested
        DCR_A = 8'h29,  // tested
        ANA_B = 8'h30,
        ANA_C = 8'h31,
        ANI   = 8'h32,
        ORA_B = 8'h34,
        ORA_C = 8'h35,
        ORI   = 8'h36, 
        XRA_B = 8'h38,
        XRA_C = 8'h39,
        XRI   = 8'h3A,
        CMP_B = 8'h3C,
        CMP_C = 8'h3D,
        MOV_AB = 8'h60,
        MOV_AC = 8'h61,
        MOV_BA = 8'h62,
        MOV_BC = 8'h63,
        MOV_CA = 8'h64,
        MOV_CB = 8'h65,
        LDA   = 8'hA0,  // tested
        LDI_A = 8'hB0,  // tested
        LDI_B = 8'hB1,  // tested
        LDI_C = 8'hB2   // tested
    } opcode_t;
        
    typedef enum logic [3:0] {
        ALU_UNDEFINED = 3'bxx,
        ALU_ADD = 4'b0000,
        ALU_SUB = 4'b0001,
        ALU_AND = 4'b0010,
        ALU_OR  = 4'b0011,
        ALU_INR = 4'b0100,
        ALU_DCR = 4'b0101,
        ALU_ADC = 4'b0110,
        ALU_SBC = 4'b0111,
        ALU_XOR = 4'b1000
    } alu_op_t;

    typedef enum logic [2:0] {
        S_RESET,
        S_INIT,
        S_LATCH_ADDR, 
        S_READ_BYTE,
        S_LATCH_BYTE,
        S_CHK_MORE_BYTES,
        S_EXECUTE,
        S_HALT
    } fsm_state_t;

    typedef enum logic [3:0] {
        MS0, MS1, MS2, MS3, MS4, MS5, MS6, MS7
    } microstep_t;

    typedef struct packed {
        logic halt;               
        logic last_step;         
        logic load_origin;
        logic pc_enable;           
        logic load_pc_low_byte;
        logic load_pc_high_byte;            
        logic oe_pc;              
        logic load_ir;            
        logic oe_ir;              
        logic load_mar_pc;
        logic load_mar_addr_low;
        logic load_mar_addr_high;           
        logic load_ram;           
        logic oe_ram;             
        logic [3:0] alu_op;
        logic alu_src_c;
        logic alu_src_temp1;       
        logic oe_alu;             
        logic load_flags;   
        logic load_sets_zn; 
        logic check_zero; 
        logic check_not_zero;        
        logic check_carry;  
        logic check_negative;  
        logic load_a;             
        logic oe_a;               
        logic load_b;             
        logic oe_b;               
        logic load_c;
        logic oe_c;
        logic load_temp_1;
        logic oe_temp_1;
        logic load_temp_2;
        logic oe_temp_2;
        logic load_o;             

    } control_word_t;

endpackage : arch_defs_pkg