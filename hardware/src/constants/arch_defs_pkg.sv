package arch_defs_pkg;

    parameter int DATA_WIDTH = 8;
    parameter int ADDR_WIDTH = 16;
    parameter int FLAG_COUNT = 3;
    
    parameter int RAM_DEPTH  = (1 << ADDR_WIDTH);
    parameter int OPCODE_WIDTH = DATA_WIDTH;
    parameter int OPERAND_WIDTH = DATA_WIDTH;

    parameter int MAX_OPCODES = (1 << OPCODE_WIDTH);
    parameter int MAX_MICROSTEPS = 10;

    parameter RESET_VECTOR = 16'hF000;  // hardcoded reset vector
    parameter SP_VECTOR = 16'h01FF;     // hardcoded sp initialization vector

    parameter STATUS_CPU_ZERO = 0;
    parameter STATUS_CPU_NEG = 1;
    parameter STATUS_CPU_CARRY = 2;

    typedef enum logic [OPCODE_WIDTH-1:0] {
        NOP =   8'h00,  
        HLT =   8'h01,  
        JMP =   8'h10,  
        JZ  =   8'h11,  
        JNZ =   8'h12,  
        JN  =   8'h13, 
        JSR =   8'h18,
        RET =   8'h19, 
        ADD_B = 8'h20,  
        ADD_C = 8'h21,  
        ADC_B = 8'h22,  
        ADC_C = 8'h23,  
        SUB_B = 8'h24,  
        SUB_C = 8'h25,  
        SBC_B = 8'h26,
        SBC_C = 8'h27,
        INR_A = 8'h28,
        DCR_A = 8'h29,
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
        RAL   = 8'h40,
        RAR   = 8'h41,
        CMA   = 8'h42,
        INR_B = 8'h50,
        DCR_B = 8'h51,
        INR_C = 8'h54,
        DCR_C = 8'h55,
        MOV_AB = 8'h60,
        MOV_AC = 8'h61,
        MOV_BA = 8'h62,
        MOV_BC = 8'h63,
        MOV_CA = 8'h64,
        MOV_CB = 8'h65,
        PHA   = 8'h80,
        PLA   = 8'h81,
        LDA   = 8'hA0,  
        STA   = 8'hA1,
        LDI_A = 8'hB0, 
        LDI_B = 8'hB1, 
        LDI_C = 8'hB2  
    } opcode_t;
        
    typedef enum logic [$clog2(MAX_MICROSTEPS)-1:0] {
        ALU_UNDEFINED = 4'bxxxx,
        ALU_ADD = 4'b0000,
        ALU_SUB = 4'b0001,
        ALU_AND = 4'b0010,
        ALU_OR  = 4'b0011,
        ALU_INR = 4'b0100,
        ALU_DCR = 4'b0101,
        ALU_ADC = 4'b0110,
        ALU_SBC = 4'b0111,
        ALU_XOR = 4'b1000,
        ALU_INV = 4'b1001,
        ALU_ROL = 4'b1010,
        ALU_ROR = 4'b1011
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
        MS0, MS1, MS2, MS3, MS4, MS5, MS6, MS7, MS8, MS9
    } microstep_t;

    typedef struct packed {
        logic halt;               
        logic last_step;         
        logic load_origin;
        logic pc_enable;           
        logic oe_pc_low_byte;
        logic oe_pc_high_byte;
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
        logic alu_src1_b;
        logic alu_src1_c;
        logic alu_src2_c;
        logic alu_src2_temp1;       
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
        logic load_sp_default_address;
        logic sp_inc;
        logic sp_dec;
        logic load_mar_sp;
    } control_word_t;

    typedef enum logic [3:0] {
        S_UART_TX_IDLE, S_UART_TX_START, S_UART_TX_SEND_DATA, S_UART_TX_STOP,
        S_UART_RX_IDLE, S_UART_RX_VALIDATE_START, S_UART_RX_READ_DATA, S_UART_RX_STOP
    } uart_fsm_state_t;

    typedef enum logic [1:0] { 
        UART_REG_CONFIG = 2'b00, 
        UART_REG_STATUS = 2'b01, 
        UART_REG_DATA = 2'b10,
        UART_REG_COMMAND = 2'b11
    } uart_reg_offset_e;

endpackage : arch_defs_pkg