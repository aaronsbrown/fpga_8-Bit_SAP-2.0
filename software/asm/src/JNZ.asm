; JNZ.asm
; TODO: Add short description

INCLUDE "includes/mmio_defs.inc"

; ======================================================================
; == VECTORS TABLE
; ======================================================================
    ORG $FFFC
    DW START            ; Reset Vector points to START label


; ======================================================================
; == PROGRAM
; ======================================================================
    ORG $F000


START:
    LDI A, #$0F         ; Z=0
    JNZ SUCCESS         ; Should jump (positive case)
    JMP HALT            ; error: A = 0F

SUCCESS:
    LDI A, #$00         ; A=0, Z=1
    JNZ HALT            ; Should NOT jump (negative case)

    LDI A, #$88         ; A=88

HALT:
    HLT