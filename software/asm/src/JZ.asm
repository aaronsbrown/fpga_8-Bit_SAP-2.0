; JZ.asm
; TODO: Add short description

INCLUDE "includes/mmio_defs.inc"

; ======================================================================
; == PROGRAM
; ======================================================================
    ORG $F000


START:
    LDI A, #$0F         ; Z=0
    JZ  HALT            ; Should NOT jump (negative case)

    LDI A, #$00         ; Z=1
    JZ SUCCESS          ; Should jump (positive case)
    
    LDI A, #$66         ; A should NEVER equal 66

SUCCESS:
    LDI A, #$88         ; A should equal 88

HALT:
    HLT