; op_JNZ_pos.asm
; Tests jumping to new address upon successful jump condition
INCLUDE "includes/mmio_defs.inc"

; -- CODE --
    ORG $F000

    LDI_A, #$0F     ; Load Reg A with non-zero value
    JNZ JUMP_SUCCESS
    
    LDI_A, #$11      ; Should not reach this line

JUMP_SUCCESS:
    LDI_A, #$22

    HLT             ; A == x22