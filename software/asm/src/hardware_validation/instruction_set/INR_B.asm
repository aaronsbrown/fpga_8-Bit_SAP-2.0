; INR_B.asm
; Comprehensive test suite for INR_B instruction
; Tests edge cases, boundary conditions, and flag behavior
; INR_B: Increment B (B=B+1), affects Z and N flags, C unaffected
; AIDEV-NOTE: Enhanced with 13 comprehensive test cases covering edge cases, flag behavior, and register preservation

INCLUDE "../../programs/includes/mmio_defs.inc"

; ======================================================================
; == PROGRAM
; ======================================================================
    ORG $F000

START:
    ; =================================================================
    ; TEST 1: Basic increment - positive number
    ; Expected: B = $01 + 1 = $02 (Z=0, N=0, C unchanged)
    ; =================================================================
    LDI B, #$01         ; B = $01
    LDI A, #$55         ; A = $55 (preserve test - should remain unchanged)
    LDI C, #$AA         ; C = $AA (preserve test - should remain unchanged) 
    SEC                 ; Set carry flag to test C preservation
    INR B               ; B = B + 1 = $01 + 1 = $02

    ; =================================================================
    ; TEST 2: Increment resulting in zero (overflow from $FF)
    ; Expected: B = $FF + 1 = $00 (Z=1, N=0, C unchanged)
    ; =================================================================
    LDI B, #$FF         ; B = $FF
    INR B               ; B = B + 1 = $FF + 1 = $00 (overflow)

    ; =================================================================
    ; TEST 3: Zero increment
    ; Expected: B = $00 + 1 = $01 (Z=0, N=0, C unchanged)
    ; =================================================================
    LDI B, #$00         ; B = $00
    INR B               ; B = B + 1 = $00 + 1 = $01

    ; =================================================================
    ; TEST 4: Increment from $7F (max positive) to $80 (negative)
    ; Expected: B = $7F + 1 = $80 (Z=0, N=1, C unchanged)
    ; =================================================================
    LDI B, #$7F         ; B = $7F (127, max positive in 2's complement)
    INR B               ; B = B + 1 = $7F + 1 = $80 (becomes negative)

    ; =================================================================
    ; TEST 5: Increment negative value from MSB set
    ; Expected: B = $80 + 1 = $81 (Z=0, N=1, C unchanged)
    ; =================================================================
    LDI B, #$80         ; B = $80 (MSB set, -128 in 2's complement)
    INR B               ; B = B + 1 = $80 + 1 = $81

    ; =================================================================
    ; TEST 6: Increment from $FE to $FF (all ones result)
    ; Expected: B = $FE + 1 = $FF (Z=0, N=1, C unchanged)
    ; =================================================================
    LDI B, #$FE         ; B = $FE
    INR B               ; B = B + 1 = $FE + 1 = $FF (all bits set)

    ; =================================================================
    ; TEST 7: Alternating pattern (0x54) increment
    ; Expected: B = $54 + 1 = $55 (Z=0, N=0, C unchanged)
    ; =================================================================
    LDI B, #$54         ; B = $54 (01010100 binary)
    INR B               ; B = B + 1 = $54 + 1 = $55

    ; =================================================================
    ; TEST 8: Alternating pattern (0xA9) increment
    ; Expected: B = $A9 + 1 = $AA (Z=0, N=1, C unchanged)
    ; =================================================================
    LDI B, #$A9         ; B = $A9 (10101001 binary)
    INR B               ; B = B + 1 = $A9 + 1 = $AA

    ; =================================================================
    ; TEST 9: Increment $7E to $7F (stays positive)
    ; Expected: B = $7E + 1 = $7F (Z=0, N=0, C unchanged)
    ; =================================================================
    LDI B, #$7E         ; B = $7E (126, still positive)
    INR B               ; B = B + 1 = $7E + 1 = $7F

    ; =================================================================
    ; TEST 10: Power of 2 boundary test ($0F + 1)
    ; Expected: B = $0F + 1 = $10 (Z=0, N=0, C unchanged)
    ; =================================================================
    LDI B, #$0F         ; B = $0F (15 decimal)
    INR B               ; B = B + 1 = $0F + 1 = $10

    ; =================================================================
    ; TEST 11: Power of 2 boundary test ($07 + 1)
    ; Expected: B = $07 + 1 = $08 (Z=0, N=0, C unchanged)
    ; =================================================================
    LDI B, #$07         ; B = $07 (7 decimal)
    INR B               ; B = B + 1 = $07 + 1 = $08

    ; =================================================================
    ; TEST 12: Carry flag preservation test with clear flag
    ; Expected: B = $04 + 1 = $05 (Z=0, N=0, C=0 preserved)
    ; =================================================================
    LDI B, #$04         ; B = $04
    CLC                 ; Clear carry flag
    INR B               ; B = B + 1 = $04 + 1 = $05 (C should remain 0)

    ; =================================================================
    ; TEST 13: Register preservation final verification
    ; Expected: B = $02 + 1 = $03, A=$55, C=$AA unchanged from TEST 1
    ; =================================================================
    LDI B, #$02         ; B = $02
    ; A and C should still be $55 and $AA from TEST 1
    INR B               ; B = B + 1 = $02 + 1 = $03

    ; =================================================================
    ; FINAL TEST: Halt instruction to end test sequence
    ; =================================================================
    HLT                 ; End of test sequence