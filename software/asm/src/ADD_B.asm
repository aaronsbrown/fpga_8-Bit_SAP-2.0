; ADD_B.asm
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
    LDI A, #$01
    LDI B, #$F4
    ADD B               ; A becomes $01 + $F4 = $F5 (Z=0, N=1, C=0)
    HLT