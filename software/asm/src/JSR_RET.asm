; op_JSR_RET.asm
; Test program for basic subroutine call and return

INCLUDE "includes/mmio_defs.inc"

; ======================================================================
; == PROGRAM
; ======================================================================
    ORG $F000


START:
    LDI A, #$AA
    JSR SUB_1
    ;MOV B, A
    STA OUTPUT_PORT_1   
    HLT

SUB_1:
    LDI A, #$BB
    JSR SUB_2
    RET

SUB_2:
    LDI A, #$CC
    JSR SUB_3
    RET

SUB_3:
    LDI A, #$FF
    RET