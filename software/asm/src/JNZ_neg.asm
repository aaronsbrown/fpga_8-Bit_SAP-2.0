; op_JNZ_neg.asm
; Tests jumping to new address upon successful jump condition
INCLUDE "includes/mmio_defs.inc"

; ======================================================================
; == VECTORS TABLE
; ======================================================================
    ORG $FFFC
    DW START           ; Reset Vector points to START label


; ======================================================================
; == PROGRAM
; ======================================================================
    ORG $F000


START:
    LDI_A, #$00     ; Load Reg A with zero value
    JNZ JUMP_SUCCESS
    
    LDI_A, #$11      ; Should reach this line
    JMP HALT

JUMP_SUCCESS:
    LDI_A, #$22      ; Should skip this value

HALT:
    HLT             ; A == x11