; op_PHA_PLA.asm
; Tests basic push and pull to the stack

INCLUDE "includes/mmio_defs.inc"

; --- constants ---
TEST_VAL_1      EQU $AA
TEST_VAL_2      EQU $AB
TEST_VAL_3      EQU $AC
SUCCESS_CODE    EQU $88
ERROR_CODE      EQU $66


    ORG $F000

START_TEST:

    LDI A, #TEST_VAL_1
    PHA 
    
    LDI A, #TEST_VAL_2
    PHA

    LDI A, #TEST_VAL_3
    PHA

    PLA
    MOV A, B
    LDI A, #TEST_VAL_3
    CMP B
    JZ  VAL_3_SUCCESS
    JMP LOG_ERROR

VAL_3_SUCCESS:
    PLA
    MOV A, B
    LDI A, #TEST_VAL_2
    CMP B
    JZ VAL_2_SUCCESS
    JMP LOG_ERROR

VAL_2_SUCCESS:
    PLA
    MOV A, B
    LDI A, #TEST_VAL_1
    CMP B
    JNZ LOG_ERROR

LOG_SUCCESS:
    LDI A, #SUCCESS_CODE
    STA OUTPUT_PORT_1    
    HLT

LOG_ERROR:
    LDI A, #ERROR_CODE
    STA OUTPUT_PORT_1
    HLT