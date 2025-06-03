; ADD_B.asm
; TODO: Add short description

INCLUDE "includes/mmio_defs.inc"


; === program start ===

    ORG $F000

START:
    LDI A, #$01
    LDI B, #$F4
    ADD B
    HLT