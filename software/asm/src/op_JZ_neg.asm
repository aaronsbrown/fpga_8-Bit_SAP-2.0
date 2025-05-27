; op_JZ_neg.asm
; Tests continuing sequential execution 
; upon failed jump condition
INCLUDE "includes/mmio_defs.inc"

; -- CODE --
    ORG $F000

    LDI A, #$00         ; Ensure Z flag == 0
    LDI A, #$0F         ; LDI sets Z flag
    JZ JUMP_TO_ADDRESS
    LDI A, #$11         ; Should reach this line
    JMP HALT

JUMP_TO_ADDRESS:
    LDI A, #$22         ; Should SKIP this line

HALT:
    HLT                 ; A should == h11