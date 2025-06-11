; ADD_C.asm
; Comprehensive test suite for ADD_C instruction
; Tests edge cases, boundary conditions, and flag behavior

INCLUDE "includes/mmio_defs.inc"

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
    LDI C, #$02         ; C = $02  
    LDI B, #$BB         ; B = $BB (preserve test - should remain unchanged)
    ADD C               ; A = A + C = $01 + $02 = $03

    ; =================================================================
    ; TEST 2: Addition resulting in zero
    ; Expected: A = $FF + $01 = $00 (Z=1, N=0, C=1) - carry from bit 7
    ; =================================================================
    LDI A, #$FF         ; A = $FF (255)
    LDI C, #$01         ; C = $01
    ADD C               ; A = A + C = $FF + $01 = $00 with carry

    ; =================================================================
    ; TEST 3: Addition with carry generation
    ; Expected: A = $80 + $80 = $00 (Z=1, N=0, C=1) - two MSBs set
    ; =================================================================
    LDI A, #$80         ; A = $80 (128, MSB set)
    LDI C, #$80         ; C = $80 (128, MSB set)
    ADD C               ; A = A + C = $80 + $80 = $00 with carry

    ; =================================================================
    ; TEST 4: Addition resulting in negative (MSB set)
    ; Expected: A = $7F + $01 = $80 (Z=0, N=1, C=0) - maximum positive + 1
    ; =================================================================
    LDI A, #$7F         ; A = $7F (127, maximum positive in 2's complement)
    LDI C, #$01         ; C = $01
    ADD C               ; A = A + C = $7F + $01 = $80 (negative result)

    ; =================================================================
    ; TEST 5: Addition with both operands having MSB set
    ; Expected: A = $FF + $FF = $FE (Z=0, N=1, C=1) - two negative numbers
    ; =================================================================
    LDI A, #$FF         ; A = $FF (-1 in 2's complement)
    LDI C, #$FF         ; C = $FF (-1 in 2's complement)
    ADD C               ; A = A + C = $FF + $FF = $FE with carry

    ; =================================================================
    ; TEST 6: Zero plus zero
    ; Expected: A = $00 + $00 = $00 (Z=1, N=0, C=0) - identity operation
    ; =================================================================
    LDI A, #$00         ; A = $00
    LDI C, #$00         ; C = $00
    ADD C               ; A = A + C = $00 + $00 = $00

    ; =================================================================
    ; TEST 7: Alternating bit pattern test
    ; Expected: A = $55 + $AA = $FF (Z=0, N=1, C=0) - complementary patterns
    ; =================================================================
    LDI A, #$55         ; A = $55 (01010101 binary)
    LDI C, #$AA         ; C = $AA (10101010 binary)
    ADD C               ; A = A + C = $55 + $AA = $FF

    ; =================================================================
    ; TEST 8: Single bit test (LSB)
    ; Expected: A = $00 + $01 = $01 (Z=0, N=0, C=0) - LSB only
    ; =================================================================
    LDI A, #$00         ; A = $00
    LDI C, #$01         ; C = $01 (only LSB set)
    ADD C               ; A = A + C = $00 + $01 = $01

    ; =================================================================
    ; TEST 9: Single bit test (MSB)
    ; Expected: A = $00 + $80 = $80 (Z=0, N=1, C=0) - MSB only
    ; =================================================================
    LDI A, #$00         ; A = $00
    LDI C, #$80         ; C = $80 (only MSB set)
    ADD C               ; A = A + C = $00 + $80 = $80

    ; =================================================================
    ; TEST 10: Maximum unsigned addition with carry
    ; Expected: A = $FE + $02 = $00 (Z=1, N=0, C=1) - wraps around
    ; =================================================================
    LDI A, #$FE         ; A = $FE (254)
    LDI C, #$02         ; C = $02
    ADD C               ; A = A + C = $FE + $02 = $00 with carry

    ; =================================================================
    ; TEST 11: Mid-range addition
    ; Expected: A = $40 + $30 = $70 (Z=0, N=0, C=0) - mid-range values
    ; =================================================================
    LDI A, #$40         ; A = $40 (64)
    LDI C, #$30         ; C = $30 (48)
    ADD C               ; A = A + C = $40 + $30 = $70

    ; =================================================================
    ; TEST 12: Register preservation test - verify B register unchanged
    ; Expected: A = $10 + $20 = $30, B should still be $BB from TEST 1
    ; =================================================================
    LDI A, #$10         ; A = $10
    LDI C, #$20         ; C = $20
    ; B should still be $BB from initial setup
    ADD C               ; A = A + C = $10 + $20 = $30

    ; =================================================================
    ; FINAL TEST: Halt instruction to end test sequence
    ; =================================================================
    HLT                 ; End of test sequence