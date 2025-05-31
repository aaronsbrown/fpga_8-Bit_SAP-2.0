; op_JSR_RET.asm
; Test program for basic subroutine call and return

INCLUDE "includes/mmio_defs.inc"

;--- constants ---

    ORG $F000

START_TEST:

    LDI A, #$AA
    JSR UPDATE_B
    MOV B, A
    STA OUTPUT_PORT_1   
    HLT

UPDATE_B:
    LDI B, #$BB
    RET