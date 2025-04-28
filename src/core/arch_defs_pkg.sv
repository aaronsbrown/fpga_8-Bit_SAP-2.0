package arch_defs_pkg;

    parameter int DATA_WIDTH = 8;
    parameter int ADDR_WIDTH = 16;
    parameter int FLAG_COUNT = 3;

    parameter int RAM_DEPTH  = (1 << ADDR_WIDTH);
    parameter int OPCODE_WIDTH = DATA_WIDTH;
    parameter int OPERAND_WIDTH = DATA_WIDTH;

    parameter RESET_VECTOR = 16'hF000; // hardcoded reset vector

    typedef enum logic [OPCODE_WIDTH-1:0] {
        NOP =   8'h00,  // TODO test
        HLT =   8'h01,  // TODO update test to new pattern
        JMP =   8'h10,  // tested
        JZ  =   8'h11,  // TODO TEST
        JNZ =   8'h12,  // TODO TEST
        JN  =   8'h13,  // TODO TEST
        LDA =   8'hA0,  // tested
        LDI_A = 8'hB0,  // tested
        LDI_B = 8'hB1,  // tested
        LDI_C = 8'hB2   // tested
    } opcode_t;
        
    typedef enum logic [1:0] {
        ALU_ADD = 2'b00,
        ALU_SUB = 2'b01,
        ALU_AND = 2'b10,
        ALU_OR  = 2'b11
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
        logic [1:0] alu_op;       
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