; DCR_A.asm
; Comprehensive test suite for DCR_A instruction
; Tests edge cases, boundary conditions, and flag behavior
; DCR_A: Decrement A (A=A-1), affects Z and N flags, C unaffected
; AIDEV-NOTE: Enhanced with 13 comprehensive test cases covering edge cases, flag behavior, and register preservation

INCLUDE "includes/mmio_defs.inc"

; ======================================================================
; == PROGRAM
; ======================================================================
    ORG $F000

START:
    ; =================================================================
    ; TEST 1: Basic decrement - positive number
    ; Expected: A = $02 - 1 = $01 (Z=0, N=0, C unchanged)
    ; =================================================================
    LDI A, #$02         ; A = $02
    LDI B, #$55         ; B = $55 (preserve test - should remain unchanged)
    LDI C, #$AA         ; C = $AA (preserve test - should remain unchanged) 
    SEC                 ; Set carry flag to test C preservation
    DCR A               ; A = A - 1 = $02 - 1 = $01

    ; =================================================================
    ; TEST 2: Decrement resulting in zero
    ; Expected: A = $01 - 1 = $00 (Z=1, N=0, C unchanged)
    ; =================================================================
    LDI A, #$01         ; A = $01
    DCR A               ; A = A - 1 = $01 - 1 = $00

    ; =================================================================
    ; TEST 3: Decrement zero (underflow to $FF)
    ; Expected: A = $00 - 1 = $FF (Z=0, N=1, C unchanged)
    ; =================================================================
    LDI A, #$00         ; A = $00
    DCR A               ; A = A - 1 = $00 - 1 = $FF (underflow)

    ; =================================================================
    ; TEST 4: Decrement from MSB set to clear negative result
    ; Expected: A = $81 - 1 = $80 (Z=0, N=1, C unchanged)
    ; =================================================================
    LDI A, #$81         ; A = $81 (MSB set, -127 in 2's complement)
    DCR A               ; A = A - 1 = $81 - 1 = $80

    ; =================================================================
    ; TEST 5: Decrement from $80 (most negative) to $7F (positive)
    ; Expected: A = $80 - 1 = $7F (Z=0, N=0, C unchanged)
    ; =================================================================
    LDI A, #$80         ; A = $80 (MSB set, -128 in 2's complement)
    DCR A               ; A = A - 1 = $80 - 1 = $7F (becomes positive)

    ; =================================================================
    ; TEST 6: All ones pattern decrement
    ; Expected: A = $FF - 1 = $FE (Z=0, N=1, C unchanged)
    ; =================================================================
    LDI A, #$FF         ; A = $FF (all bits set)
    DCR A               ; A = A - 1 = $FF - 1 = $FE

    ; =================================================================
    ; TEST 7: Alternating pattern (0x55) decrement
    ; Expected: A = $55 - 1 = $54 (Z=0, N=0, C unchanged)
    ; =================================================================
    LDI A, #$55         ; A = $55 (01010101 binary)
    DCR A               ; A = A - 1 = $55 - 1 = $54

    ; =================================================================
    ; TEST 8: Alternating pattern (0xAA) decrement
    ; Expected: A = $AA - 1 = $A9 (Z=0, N=1, C unchanged)
    ; =================================================================
    LDI A, #$AA         ; A = $AA (10101010 binary)
    DCR A               ; A = A - 1 = $AA - 1 = $A9

    ; =================================================================
    ; TEST 9: Maximum positive 7-bit value decrement
    ; Expected: A = $7F - 1 = $7E (Z=0, N=0, C unchanged)
    ; =================================================================
    LDI A, #$7F         ; A = $7F (127, maximum positive in 2's complement)
    DCR A               ; A = A - 1 = $7F - 1 = $7E

    ; =================================================================
    ; TEST 10: Power of 2 boundary test ($10 = 16)
    ; Expected: A = $10 - 1 = $0F (Z=0, N=0, C unchanged)
    ; =================================================================
    LDI A, #$10         ; A = $10 (16 decimal)
    DCR A               ; A = A - 1 = $10 - 1 = $0F

    ; =================================================================
    ; TEST 11: Power of 2 boundary test ($08 = 8)
    ; Expected: A = $08 - 1 = $07 (Z=0, N=0, C unchanged)
    ; =================================================================
    LDI A, #$08         ; A = $08 (8 decimal)
    DCR A               ; A = A - 1 = $08 - 1 = $07

    ; =================================================================
    ; TEST 12: Carry flag preservation test with clear flag
    ; Expected: A = $05 - 1 = $04 (Z=0, N=0, C=0 preserved)
    ; =================================================================
    LDI A, #$05         ; A = $05
    CLC                 ; Clear carry flag
    DCR A               ; A = A - 1 = $05 - 1 = $04 (C should remain 0)

    ; =================================================================
    ; TEST 13: Register preservation final verification
    ; Expected: A = $03 - 1 = $02, B=$55, C=$AA unchanged from TEST 1
    ; =================================================================
    LDI A, #$03         ; A = $03
    ; B and C should still be $55 and $AA from TEST 1
    DCR A               ; A = A - 1 = $03 - 1 = $02

    ; =================================================================
    ; FINAL TEST: Halt instruction to end test sequence
    ; =================================================================
    HLT                 ; End of test sequence