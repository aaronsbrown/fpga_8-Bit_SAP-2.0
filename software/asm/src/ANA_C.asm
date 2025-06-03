; ANA_C.asm
; TODO: Add short description

INCLUDE "includes/mmio_defs.inc"

; === constants ===
CONSTANT    EQU $00

; === program start ===

    ORG $F000

START:
    LDI A, #$E1         ;     1110 0001
    LDI C, #$FE         ;     1111 1110
    ADD C               ; (1) 1101 1111
    ANA C               ;     1101 1110
    LDI C, #$0          ;     0000 0000
    ANA C               ;     0000 0000
    HLT