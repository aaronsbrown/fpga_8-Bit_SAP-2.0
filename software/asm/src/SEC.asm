; SEC.asm
; TODO: Add short description

INCLUDE "includes/mmio_defs.inc"

; === constants ===
CONSTANT    EQU $00

; === program start ===

    ORG $F000

START:
    LDI A, #$00
    SEC 
    HLT