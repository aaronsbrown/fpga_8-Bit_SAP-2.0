; CMP_B.asm
; Tests the CMP B instruction with various values for A and B,
; checking Zero, Negative, and Carry flags.

INCLUDE "includes/mmio_defs.inc"

; ======================================================================
; == PROGRAM
; ======================================================================
    ORG $F000

START:
; Test Group 1: A = $01 (Original Tests)
    LDI A, #$01
    
    LDI B, #$03         ; A=$01, B=$03. A - B = $01 - $03 = $FE.
    CMP B               ; Expected: Z=0, N=1, C=0 (borrow)
    
    LDI B, #$00         ; A=$01, B=$00. A - B = $01 - $00 = $01.
    CMP B               ; Expected: Z=0, N=0, C=1 (no borrow)
    
    LDI B, #$01         ; A=$01, B=$01. A - B = $01 - $01 = $00.
    CMP B               ; Expected: Z=1, N=0, C=1 (no borrow)

; Test Group 2: A = $00
    LDI A, #$00

    LDI B, #$00         ; A=$00, B=$00. A - B = $00 - $00 = $00.
    CMP B               ; Expected: Z=1, N=0, C=1 (no borrow)

    LDI B, #$01         ; A=$00, B=$01. A - B = $00 - $01 = $FF.
    CMP B               ; Expected: Z=0, N=1, C=0 (borrow)

    LDI B, #$FF         ; A=$00, B=$FF. A - B = $00 - $FF = $01.
    CMP B               ; Expected: Z=0, N=0, C=0 (borrow)

; Test Group 3: A = $FF
    LDI A, #$FF

    LDI B, #$FF         ; A=$FF, B=$FF. A - B = $FF - $FF = $00.
    CMP B               ; Expected: Z=1, N=0, C=1 (no borrow)

    LDI B, #$00         ; A=$FF, B=$00. A - B = $FF - $00 = $FF.
    CMP B               ; Expected: Z=0, N=1, C=1 (no borrow)

    LDI B, #$FE         ; A=$FF, B=$FE. A - B = $FF - $FE = $01.
    CMP B               ; Expected: Z=0, N=0, C=1 (no borrow)

; Test Group 4: A = $80 (Negative boundary as unsigned)
    LDI A, #$80

    LDI B, #$00         ; A=$80, B=$00. A - B = $80 - $00 = $80.
    CMP B               ; Expected: Z=0, N=1, C=1 (no borrow)
    
    LDI B, #$7F         ; A=$80, B=$7F. A - B = $80 - $7F = $01.
    CMP B               ; Expected: Z=0, N=0, C=1 (no borrow)

    LDI B, #$80         ; A=$80, B=$80. A - B = $80 - $80 = $00.
    CMP B               ; Expected: Z=1, N=0, C=1 (no borrow)
    
; Test Group 5: A = $7F (Positive boundary as unsigned)
    LDI A, #$7F

    LDI B, #$80         ; A=$7F, B=$80. A - B = $7F - $80 = $FF.
    CMP B               ; Expected: Z=0, N=1, C=0 (borrow)
    
    LDI B, #$7F         ; A=$7F, B=$7F. A - B = $7F - $7F = $00.
    CMP B               ; Expected: Z=1, N=0, C=1 (no borrow)

    HLT