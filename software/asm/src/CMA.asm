; CMA.asm
; TODO: Add short description

INCLUDE "includes/mmio_defs.inc"

; === constants ===
CONSTANT    EQU $00

; === program start ===

    ORG $F000

START:
    LDI A, #$AA         ; 1010 1010
    SEC                 ; C = 1
    CMA                 ; 0101 0101
    HLT