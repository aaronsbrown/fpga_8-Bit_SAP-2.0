; DCR_C.asm
; Comprehensive test suite for DCR_C instruction
; Tests edge cases, boundary conditions, and flag behavior
; DCR_C: Decrement C (C=C-1), affects Z and N flags, C unaffected
; AIDEV-NOTE: Enhanced with 13 comprehensive test cases covering edge cases, flag behavior, and register preservation

INCLUDE "../../programs/includes/mmio_defs.inc"

; ======================================================================
; == PROGRAM
; ======================================================================
    ORG $F000

START:
    ; =================================================================
    ; TEST 1: Basic decrement - positive number
    ; Expected: C = $02 - 1 = $01 (Z=0, N=0, Carry unchanged)
    ; =================================================================
    LDI C, #$02         ; C = $02
    LDI A, #$33         ; A = $33 (preserve test - should remain unchanged)
    LDI B, #$55         ; B = $55 (preserve test - should remain unchanged)
    SEC                 ; Set carry flag to test Carry preservation
    DCR C               ; C = C - 1 = $02 - 1 = $01

    ; =================================================================
    ; TEST 2: Decrement resulting in zero
    ; Expected: C = $01 - 1 = $00 (Z=1, N=0, Carry unchanged)
    ; =================================================================
    LDI C, #$01         ; C = $01
    DCR C               ; C = C - 1 = $01 - 1 = $00

    ; =================================================================
    ; TEST 3: Decrement zero (underflow to $FF)
    ; Expected: C = $00 - 1 = $FF (Z=0, N=1, Carry unchanged)
    ; =================================================================
    LDI C, #$00         ; C = $00
    DCR C               ; C = C - 1 = $00 - 1 = $FF (underflow)

    ; =================================================================
    ; TEST 4: Decrement from MSB set to clear negative result
    ; Expected: C = $81 - 1 = $80 (Z=0, N=1, Carry unchanged)
    ; =================================================================
    LDI C, #$81         ; C = $81 (MSB set, -127 in 2's complement)
    DCR C               ; C = C - 1 = $81 - 1 = $80

    ; =================================================================
    ; TEST 5: Decrement from $80 (most negative) to $7F (positive)
    ; Expected: C = $80 - 1 = $7F (Z=0, N=0, Carry unchanged)
    ; =================================================================
    LDI C, #$80         ; C = $80 (MSB set, -128 in 2's complement)
    DCR C               ; C = C - 1 = $80 - 1 = $7F (becomes positive)

    ; =================================================================
    ; TEST 6: All ones pattern decrement
    ; Expected: C = $FF - 1 = $FE (Z=0, N=1, Carry unchanged)
    ; =================================================================
    LDI C, #$FF         ; C = $FF (all bits set)
    DCR C               ; C = C - 1 = $FF - 1 = $FE

    ; =================================================================
    ; TEST 7: Alternating pattern (0x55) decrement
    ; Expected: C = $55 - 1 = $54 (Z=0, N=0, Carry unchanged)
    ; =================================================================
    LDI C, #$55         ; C = $55 (01010101 binary)
    DCR C               ; C = C - 1 = $55 - 1 = $54

    ; =================================================================
    ; TEST 8: Alternating pattern (0xAA) decrement
    ; Expected: C = $AA - 1 = $A9 (Z=0, N=1, Carry unchanged)
    ; =================================================================
    LDI C, #$AA         ; C = $AA (10101010 binary)
    DCR C               ; C = C - 1 = $AA - 1 = $A9

    ; =================================================================
    ; TEST 9: Maximum positive 7-bit value decrement
    ; Expected: C = $7F - 1 = $7E (Z=0, N=0, Carry unchanged)
    ; =================================================================
    LDI C, #$7F         ; C = $7F (127, maximum positive in 2's complement)
    DCR C               ; C = C - 1 = $7F - 1 = $7E

    ; =================================================================
    ; TEST 10: Power of 2 boundary test ($10 = 16)
    ; Expected: C = $10 - 1 = $0F (Z=0, N=0, Carry unchanged)
    ; =================================================================
    LDI C, #$10         ; C = $10 (16 decimal)
    DCR C               ; C = C - 1 = $10 - 1 = $0F

    ; =================================================================
    ; TEST 11: Power of 2 boundary test ($08 = 8)
    ; Expected: C = $08 - 1 = $07 (Z=0, N=0, Carry unchanged)
    ; =================================================================
    LDI C, #$08         ; C = $08 (8 decimal)
    DCR C               ; C = C - 1 = $08 - 1 = $07

    ; =================================================================
    ; TEST 12: Carry flag preservation test with clear flag
    ; Expected: C = $05 - 1 = $04 (Z=0, N=0, Carry=0 preserved)
    ; =================================================================
    LDI C, #$05         ; C = $05
    CLC                 ; Clear carry flag
    DCR C               ; C = C - 1 = $05 - 1 = $04 (Carry should remain 0)

    ; =================================================================
    ; TEST 13: Register preservation final verification
    ; Expected: C = $03 - 1 = $02, A=$33, B=$55 unchanged from TEST 1
    ; =================================================================
    LDI C, #$03         ; C = $03
    ; A and B should still be $33 and $55 from TEST 1
    DCR C               ; C = C - 1 = $03 - 1 = $02

    ; =================================================================
    ; FINAL TEST: Halt instruction to end test sequence
    ; =================================================================
    HLT                 ; End of test sequence