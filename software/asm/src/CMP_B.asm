; CMP_B.asm
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
    
    LDI B, #$03         ; CMP 1, 3
    CMP B               ; Z=0, N=1, C=0 (borrow occured)
    
    LDI B, #$00         ; CMP 1, 0
    CMP B               ; Z=0, N=0, C=1 (no borrow occured)
    
    LDI B, #$01         ; CMP 1, 1
    CMP B               ; Z=1, N=0, C=1
    
    HLT