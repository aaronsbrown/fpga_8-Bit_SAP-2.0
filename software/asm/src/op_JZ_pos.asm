; op_JZ_pos.asm
; Tests jumping to new address upon successful jump condition
INCLUDE "includes/mmio_defs.inc"

; -- CODE --
    ORG $F000

    LDI A, #$FF         ; Ensure Z flag != 0
    LDI A, #$00         ; LDI sets Z flag
    JZ JUMP_TO_ADDRESS
    LDI A, #$11         ; Should NOT reach this line

JUMP_TO_ADDRESS:
    LDI A, #$22         

    HLT                 ; A should equal x22 