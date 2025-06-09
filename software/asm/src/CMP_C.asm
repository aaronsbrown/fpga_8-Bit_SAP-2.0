; CMP_C.asm
; TODO: Add short description

INCLUDE "includes/mmio_defs.inc"

; ======================================================================
; == PROGRAM
; ======================================================================
    ORG $F000


START:
    LDI A, #$01
    
    LDI C, #$03         ; CMP 1, 3
    CMP C               ; Z=0, N=1, C=0 (borrow occured)
    
    LDI C, #$00         ; CMP 1, 0
    CMP C               ; Z=0, N=0, C=1 (no Corrow occured)
    
    LDI C, #$01         ; CMP 1, 1
    CMP C               ; Z=1, N=0, C=1
    
    HLT