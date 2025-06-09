; ADD_B_AND_C.asm
; TODO: Add short description

INCLUDE "includes/mmio_defs.inc"

; ======================================================================
; == CONSTANTS
; ======================================================================
CONSTANT    EQU $00


; ======================================================================
; == PROGRAM
; ======================================================================
    ORG $F000


START:
    LDI A, #$FF
    LDI B, #$01
    LDI C, #$05
    ADD B               ; A becomes $FF + $01 = $00 (Z=1, N=0, C=1)
    ADD C               ; A becomes $00 + $05 = $05 (Z=0, N=0, C=0 - assuming ADD doesn't use prior carry)
    HLT