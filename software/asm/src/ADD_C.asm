; ADD_C.asm
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
    LDI A, #$0A
    LDI C, #$02
    ADD C               ; A becomes $0A + $02 = $0C (Z=0, N=0, C=0)
    HLT