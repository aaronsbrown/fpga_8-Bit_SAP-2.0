; DCR_C.asm
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
    LDI C, #$05
    DCR C
    HLT