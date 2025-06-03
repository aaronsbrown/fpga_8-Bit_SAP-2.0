; op_SEC.asm
 TODO: Add short description

INCLUDE "includes/mmio_defs.inc"

; === program start ===

    ORG $F000

START:
    LDI A, #$FF
    LDI B, #$FF
    ADD B
    CLC
    HLT