; DCR_B.asm
; Comprehensive test suite for DCR_B instruction
; Tests edge cases, boundary conditions, and flag behavior
; DCR_B: Decrement B (B=B-1), affects Z and N flags, C unaffected
; AIDEV-NOTE: Enhanced with 13 comprehensive test cases covering edge cases, flag behavior, and register preservation

INCLUDE "includes/mmio_defs.inc"

; ======================================================================
; == PROGRAM
; ======================================================================
    ORG $F000

START:
    ; =================================================================
    ; TEST 1: Basic decrement - positive number
    ; Expected: B = $02 - 1 = $01 (Z=0, N=0, C unchanged)
    ; =================================================================
    LDI B, #$02         ; B = $02
    LDI A, #$55         ; A = $55 (preserve test - should remain unchanged)
    LDI C, #$AA         ; C = $AA (preserve test - should remain unchanged) 
    SEC                 ; Set carry flag to test C preservation
    DCR B               ; B = B - 1 = $02 - 1 = $01

    ; =================================================================
    ; TEST 2: Decrement resulting in zero
    ; Expected: B = $01 - 1 = $00 (Z=1, N=0, C unchanged)
    ; =================================================================
    LDI B, #$01         ; B = $01
    DCR B               ; B = B - 1 = $01 - 1 = $00

    ; =================================================================
    ; TEST 3: Decrement zero (underflow to $FF)
    ; Expected: B = $00 - 1 = $FF (Z=0, N=1, C unchanged)
    ; =================================================================
    LDI B, #$00         ; B = $00
    DCR B               ; B = B - 1 = $00 - 1 = $FF (underflow)

    ; =================================================================
    ; TEST 4: Decrement from MSB set to clear negative result
    ; Expected: B = $81 - 1 = $80 (Z=0, N=1, C unchanged)
    ; =================================================================
    LDI B, #$81         ; B = $81 (MSB set, -127 in 2's complement)
    DCR B               ; B = B - 1 = $81 - 1 = $80

    ; =================================================================
    ; TEST 5: Decrement from $80 (most negative) to $7F (positive)
    ; Expected: B = $80 - 1 = $7F (Z=0, N=0, C unchanged)
    ; =================================================================
    LDI B, #$80         ; B = $80 (MSB set, -128 in 2's complement)
    DCR B               ; B = B - 1 = $80 - 1 = $7F (becomes positive)

    ; =================================================================
    ; TEST 6: All ones pattern decrement
    ; Expected: B = $FF - 1 = $FE (Z=0, N=1, C unchanged)
    ; =================================================================
    LDI B, #$FF         ; B = $FF (all bits set)
    DCR B               ; B = B - 1 = $FF - 1 = $FE

    ; =================================================================
    ; TEST 7: Alternating pattern (0x55) decrement
    ; Expected: B = $55 - 1 = $54 (Z=0, N=0, C unchanged)
    ; =================================================================
    LDI B, #$55         ; B = $55 (01010101 binary)
    DCR B               ; B = B - 1 = $55 - 1 = $54

    ; =================================================================
    ; TEST 8: Alternating pattern (0xAA) decrement
    ; Expected: B = $AA - 1 = $A9 (Z=0, N=1, C unchanged)
    ; =================================================================
    LDI B, #$AA         ; B = $AA (10101010 binary)
    DCR B               ; B = B - 1 = $AA - 1 = $A9

    ; =================================================================
    ; TEST 9: Maximum positive 7-bit value decrement
    ; Expected: B = $7F - 1 = $7E (Z=0, N=0, C unchanged)
    ; =================================================================
    LDI B, #$7F         ; B = $7F (127, maximum positive in 2's complement)
    DCR B               ; B = B - 1 = $7F - 1 = $7E

    ; =================================================================
    ; TEST 10: Power of 2 boundary test ($10 = 16)
    ; Expected: B = $10 - 1 = $0F (Z=0, N=0, C unchanged)
    ; =================================================================
    LDI B, #$10         ; B = $10 (16 decimal)
    DCR B               ; B = B - 1 = $10 - 1 = $0F

    ; =================================================================
    ; TEST 11: Power of 2 boundary test ($08 = 8)
    ; Expected: B = $08 - 1 = $07 (Z=0, N=0, C unchanged)
    ; =================================================================
    LDI B, #$08         ; B = $08 (8 decimal)
    DCR B               ; B = B - 1 = $08 - 1 = $07

    ; =================================================================
    ; TEST 12: Carry flag preservation test with clear flag
    ; Expected: B = $05 - 1 = $04 (Z=0, N=0, C=0 preserved)
    ; =================================================================
    LDI B, #$05         ; B = $05
    CLC                 ; Clear carry flag
    DCR B               ; B = B - 1 = $05 - 1 = $04 (C should remain 0)

    ; =================================================================
    ; TEST 13: Register preservation final verification
    ; Expected: B = $03 - 1 = $02, A=$55, C=$AA unchanged from TEST 1
    ; =================================================================
    LDI B, #$03         ; B = $03
    ; A and C should still be $55 and $AA from TEST 1
    DCR B               ; B = B - 1 = $03 - 1 = $02

    ; =================================================================
    ; FINAL TEST: Halt instruction to end test sequence
    ; =================================================================
    HLT                 ; End of test sequence