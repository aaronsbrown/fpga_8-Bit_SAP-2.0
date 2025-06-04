; op_RAR.asm
; TODO: Add short description

INCLUDE "includes/mmio_defs.inc"

; === program start ===

    ORG $F000

START:
    LDI A, #%11110000
    RAR
    HLT