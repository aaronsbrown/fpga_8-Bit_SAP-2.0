; SEC.asm
; TODO: Add short description

INCLUDE "includes/mmio_defs.inc"

; ======================================================================
; == PROGRAM
; ======================================================================
    ORG $F000


START:
    LDI A, #$00
    SEC 
    HLT