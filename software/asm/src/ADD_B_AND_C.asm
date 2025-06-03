; ADD_B_AND_C.asm
; TODO: Add short description

INCLUDE "includes/mmio_defs.inc"

; === constants ===
CONSTANT    EQU $00

; === program start ===

    ORG $F000

START:
    LDI A, #$FF
    LDI B, #$01
    LDI C, #$05
    ADD B
    ADD C
    HLT