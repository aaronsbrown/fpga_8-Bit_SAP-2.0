; CMP_C.asm
; Tests the CMP C instruction with various values for A and C,
; checking Zero, Negative, and Carry flags.
; CMP C performs A - C and sets flags without storing the result.
; AIDEV-NOTE: Enhanced with comprehensive test coverage including boundary values, bit patterns, and register preservation

INCLUDE "includes/mmio_defs.inc"

; ======================================================================
; == PROGRAM
; ======================================================================
    ORG $F000

START:
; Test Group 1: A = $01 (Original Tests)
    LDI A, #$01
    
    LDI C, #$03         ; A=$01, C=$03. A - C = $01 - $03 = $FE.
    CMP C               ; Expected: Z=0, N=1, C=0 (borrow)
    
    LDI C, #$00         ; A=$01, C=$00. A - C = $01 - $00 = $01.
    CMP C               ; Expected: Z=0, N=0, C=1 (no borrow)
    
    LDI C, #$01         ; A=$01, C=$01. A - C = $01 - $01 = $00.
    CMP C               ; Expected: Z=1, N=0, C=1 (no borrow)

; Test Group 2: A = $00 (Zero boundary tests)
    LDI A, #$00
    
    LDI C, #$00         ; A=$00, C=$00. A - C = $00 - $00 = $00.
    CMP C               ; Expected: Z=1, N=0, C=1 (no borrow)
    
    LDI C, #$01         ; A=$00, C=$01. A - C = $00 - $01 = $FF.
    CMP C               ; Expected: Z=0, N=1, C=0 (borrow)
    
    LDI C, #$FF         ; A=$00, C=$FF. A - C = $00 - $FF = $01.
    CMP C               ; Expected: Z=0, N=0, C=0 (borrow)

; Test Group 3: A = $FF (All ones pattern)
    LDI A, #$FF
    
    LDI C, #$FF         ; A=$FF, C=$FF. A - C = $FF - $FF = $00.
    CMP C               ; Expected: Z=1, N=0, C=1 (no borrow)
    
    LDI C, #$00         ; A=$FF, C=$00. A - C = $FF - $00 = $FF.
    CMP C               ; Expected: Z=0, N=1, C=1 (no borrow)
    
    LDI C, #$FE         ; A=$FF, C=$FE. A - C = $FF - $FE = $01.
    CMP C               ; Expected: Z=0, N=0, C=1 (no borrow)

; Test Group 4: A = $80 (Negative boundary as signed)
    LDI A, #$80
    
    LDI C, #$00         ; A=$80, C=$00. A - C = $80 - $00 = $80.
    CMP C               ; Expected: Z=0, N=1, C=1 (no borrow)
    
    LDI C, #$7F         ; A=$80, C=$7F. A - C = $80 - $7F = $01.
    CMP C               ; Expected: Z=0, N=0, C=1 (no borrow)
    
    LDI C, #$80         ; A=$80, C=$80. A - C = $80 - $80 = $00.
    CMP C               ; Expected: Z=1, N=0, C=1 (no borrow)

; Test Group 5: A = $7F (Positive boundary as signed)
    LDI A, #$7F
    
    LDI C, #$80         ; A=$7F, C=$80. A - C = $7F - $80 = $FF.
    CMP C               ; Expected: Z=0, N=1, C=0 (borrow)
    
    LDI C, #$7F         ; A=$7F, C=$7F. A - C = $7F - $7F = $00.
    CMP C               ; Expected: Z=1, N=0, C=1 (no borrow)

; Test Group 6: Alternating bit patterns
    LDI A, #$AA         ; A=$AA (10101010)
    
    LDI C, #$55         ; A=$AA, C=$55. A - C = $AA - $55 = $55.
    CMP C               ; Expected: Z=0, N=0, C=1 (no borrow)
    
    LDI C, #$AA         ; A=$AA, C=$AA. A - C = $AA - $AA = $00.
    CMP C               ; Expected: Z=1, N=0, C=1 (no borrow)

; Test Group 7: Register preservation verification
    ; Set B register to a known value to verify it's not affected
    LDI B, #$42         ; Set B to $42 as a canary value
    
    LDI A, #$10
    LDI C, #$05         ; A=$10, C=$05. A - C = $10 - $05 = $0B.
    CMP C               ; Expected: Z=0, N=0, C=1 (no borrow), B should remain $42
    
    HLT