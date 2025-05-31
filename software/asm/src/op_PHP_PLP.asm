; op_PHP_PLP.asm
; Tests basic push and pull of status register to the stack

INCLUDE "includes/mmio_defs.inc"

; --- constants ---

SUCCESS_CODE    EQU $88
ERROR_CODE      EQU $66


    ORG $F000

START_TEST:
    JSR TEST_NEG_FLAG
    JSR TEST_ZERO_FLAG
    JSR TEST_CARRY_FLAG
    HLT

TEST_NEG_FLAG:
    LDI A, #$FF             ; Z = 0; N = 1; C = 0
    PHP                     ; push status
    LDI A, #$00             ;  Z = 1; N = 0; C = 0
    PLP                     ; restore status    
    
    JN LOG_SUCCESS          ; if N = 1, log success and RET
    JMP LOG_ERROR           ; else log error and HLT


TEST_ZERO_FLAG:
    LDI A, #$00             ; Z = 1; N = 0; C = 0
    PHP
    LDI A, #$FF             ; Z = 0; N = 1; C = 0
    PLP
  
    JZ LOG_SUCCESS          ; if Z = 1, log success and RET
    JMP LOG_ERROR           ; else log error and HLT


TEST_CARRY_FLAG:
    LDI A, #$FF             ; Z = 0, N = 1, C = 0
    LDI B, #$01             ; Z = 0, N = 0, C = 0
    ADD B                   ; Z = 1, N = 0, C = 1 => preserve C!!
    
    PHP
    
    LDI A, #$00             ; Z = 1, N = 0, C = 0
    LDI B, #$01             ; Z = 0, N = 0, C = 0
    ADD B                   ; Z = 0, N = =, C = 0

    PLP
    JC LOG_SUCCESS
    JMP LOG_ERROR


LOG_SUCCESS:
    LDI A, #SUCCESS_CODE
    STA OUTPUT_PORT_1    
    RET


LOG_ERROR:
    LDI A, #ERROR_CODE
    STA OUTPUT_PORT_1
    HLT