; op_JNZ_neg.asm
; Tests jumping to new address upon successful jump condition
INCLUDE "includes/uart_defs.inc"

; -- CODE --
    ORG $F000

    LDI_A, #$00     ; Load Reg A with zero value
    JNZ JUMP_SUCCESS
    
    LDI_A, #$11      ; Should reach this line
    JMP HALT

JUMP_SUCCESS:
    LDI_A, #$22      ; Should skip this value

HALT:
    HLT             ; A == x11