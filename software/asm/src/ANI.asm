; ANI.asm
; TODO: Add short description

INCLUDE "includes/mmio_defs.inc"

; === constants ===
CONSTANT    EQU $00

; === program start ===

    ORG $F000

START:
    LDI A, #$AA             ;1010 1010
    ANI #$F0                ;1010 0000
    HLT