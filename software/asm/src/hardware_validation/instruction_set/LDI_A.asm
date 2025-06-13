INCLUDE "../../programs/includes/mmio_defs.inc"

; ======================================================================
; == PROGRAM
; ======================================================================
    ORG $F000


START:
    LDI A, #$F5         ; LDI A with direct hex immediate
    HLT                ; Halt