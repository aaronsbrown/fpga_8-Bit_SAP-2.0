; ADD_B.asm
; Comprehensive test suite for ADD_B instruction
; Tests edge cases, boundary conditions, and flag behavior

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
    ; =================================================================
    ; TEST 1: Basic Addition - Small positive numbers
    ; Expected: A = $01 + $02 = $03 (Z=0, N=0, C=0)
    ; =================================================================
    LDI A, #$01         ; A = $01
    LDI B, #$02         ; B = $02  
    LDI C, #$AA         ; C = $AA (preserve test - should remain unchanged)
    ADD B               ; A = A + B = $01 + $02 = $03

    ; =================================================================
    ; TEST 2: Addition resulting in zero
    ; Expected: A = $FF + $01 = $00 (Z=1, N=0, C=1) - carry from bit 7
    ; =================================================================
    LDI A, #$FF         ; A = $FF (255)
    LDI B, #$01         ; B = $01
    ADD B               ; A = A + B = $FF + $01 = $00 with carry

    ; =================================================================
    ; TEST 3: Addition with carry generation
    ; Expected: A = $80 + $80 = $00 (Z=1, N=0, C=1) - two MSBs set
    ; =================================================================
    LDI A, #$80         ; A = $80 (128, MSB set)
    LDI B, #$80         ; B = $80 (128, MSB set)
    ADD B               ; A = A + B = $80 + $80 = $00 with carry

    ; =================================================================
    ; TEST 4: Addition resulting in negative (MSB set)
    ; Expected: A = $7F + $01 = $80 (Z=0, N=1, C=0) - maximum positive + 1
    ; =================================================================
    LDI A, #$7F         ; A = $7F (127, maximum positive in 2's complement)
    LDI B, #$01         ; B = $01
    ADD B               ; A = A + B = $7F + $01 = $80 (negative result)

    ; =================================================================
    ; TEST 5: Addition with both operands having MSB set
    ; Expected: A = $FF + $FF = $FE (Z=0, N=1, C=1) - two negative numbers
    ; =================================================================
    LDI A, #$FF         ; A = $FF (-1 in 2's complement)
    LDI B, #$FF         ; B = $FF (-1 in 2's complement)
    ADD B               ; A = A + B = $FF + $FF = $FE with carry

    ; =================================================================
    ; TEST 6: Zero plus zero
    ; Expected: A = $00 + $00 = $00 (Z=1, N=0, C=0) - identity operation
    ; =================================================================
    LDI A, #$00         ; A = $00
    LDI B, #$00         ; B = $00
    ADD B               ; A = A + B = $00 + $00 = $00

    ; =================================================================
    ; TEST 7: Alternating bit pattern test
    ; Expected: A = $55 + $AA = $FF (Z=0, N=1, C=0) - complementary patterns
    ; =================================================================
    LDI A, #$55         ; A = $55 (01010101 binary)
    LDI B, #$AA         ; B = $AA (10101010 binary)
    ADD B               ; A = A + B = $55 + $AA = $FF

    ; =================================================================
    ; TEST 8: Single bit test (LSB)
    ; Expected: A = $00 + $01 = $01 (Z=0, N=0, C=0) - LSB only
    ; =================================================================
    LDI A, #$00         ; A = $00
    LDI B, #$01         ; B = $01 (only LSB set)
    ADD B               ; A = A + B = $00 + $01 = $01

    ; =================================================================
    ; TEST 9: Single bit test (MSB)
    ; Expected: A = $00 + $80 = $80 (Z=0, N=1, C=0) - MSB only
    ; =================================================================
    LDI A, #$00         ; A = $00
    LDI B, #$80         ; B = $80 (only MSB set)
    ADD B               ; A = A + B = $00 + $80 = $80

    ; =================================================================
    ; TEST 10: Maximum unsigned addition with carry
    ; Expected: A = $FE + $02 = $00 (Z=1, N=0, C=1) - wraps around
    ; =================================================================
    LDI A, #$FE         ; A = $FE (254)
    LDI B, #$02         ; B = $02
    ADD B               ; A = A + B = $FE + $02 = $00 with carry

    ; =================================================================
    ; TEST 11: Register preservation test - verify C register unchanged
    ; Expected: A = $10 + $20 = $30, C should still be $AA from TEST 1
    ; =================================================================
    LDI A, #$10         ; A = $10
    LDI B, #$20         ; B = $20
    ; C should still be $AA from initial setup
    ADD B               ; A = A + B = $10 + $20 = $30

    ; =================================================================
    ; FINAL TEST: Halt instruction to end test sequence
    ; =================================================================
    HLT                 ; End of test sequence