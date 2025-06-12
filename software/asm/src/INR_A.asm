; INR_A.asm
; Comprehensive test suite for INR_A instruction
; Tests edge cases, boundary conditions, and flag behavior
; INR_A: Increment A (A=A+1), affects Z and N flags, C unaffected
; AIDEV-NOTE: Enhanced with 13 comprehensive test cases covering edge cases, flag behavior, and register preservation

INCLUDE "includes/mmio_defs.inc"

; ======================================================================
; == PROGRAM
; ======================================================================
    ORG $F000

START:
    ; =================================================================
    ; TEST 1: Basic increment - positive number
    ; Expected: A = $01 + 1 = $02 (Z=0, N=0, C unchanged)
    ; =================================================================
    LDI A, #$01         ; A = $01
    LDI B, #$55         ; B = $55 (preserve test - should remain unchanged)
    LDI C, #$AA         ; C = $AA (preserve test - should remain unchanged) 
    SEC                 ; Set carry flag to test C preservation
    INR A               ; A = A + 1 = $01 + 1 = $02

    ; =================================================================
    ; TEST 2: Increment resulting in zero (overflow from $FF)
    ; Expected: A = $FF + 1 = $00 (Z=1, N=0, C unchanged)
    ; =================================================================
    LDI A, #$FF         ; A = $FF
    INR A               ; A = A + 1 = $FF + 1 = $00 (overflow)

    ; =================================================================
    ; TEST 3: Zero increment
    ; Expected: A = $00 + 1 = $01 (Z=0, N=0, C unchanged)
    ; =================================================================
    LDI A, #$00         ; A = $00
    INR A               ; A = A + 1 = $00 + 1 = $01

    ; =================================================================
    ; TEST 4: Increment from $7F (max positive) to $80 (negative)
    ; Expected: A = $7F + 1 = $80 (Z=0, N=1, C unchanged)
    ; =================================================================
    LDI A, #$7F         ; A = $7F (127, max positive in 2's complement)
    INR A               ; A = A + 1 = $7F + 1 = $80 (becomes negative)

    ; =================================================================
    ; TEST 5: Increment negative value from MSB set
    ; Expected: A = $80 + 1 = $81 (Z=0, N=1, C unchanged)
    ; =================================================================
    LDI A, #$80         ; A = $80 (MSB set, -128 in 2's complement)
    INR A               ; A = A + 1 = $80 + 1 = $81

    ; =================================================================
    ; TEST 6: Increment from $FE to $FF (all ones result)
    ; Expected: A = $FE + 1 = $FF (Z=0, N=1, C unchanged)
    ; =================================================================
    LDI A, #$FE         ; A = $FE
    INR A               ; A = A + 1 = $FE + 1 = $FF (all bits set)

    ; =================================================================
    ; TEST 7: Alternating pattern (0x54) increment
    ; Expected: A = $54 + 1 = $55 (Z=0, N=0, C unchanged)
    ; =================================================================
    LDI A, #$54         ; A = $54 (01010100 binary)
    INR A               ; A = A + 1 = $54 + 1 = $55

    ; =================================================================
    ; TEST 8: Alternating pattern (0xA9) increment
    ; Expected: A = $A9 + 1 = $AA (Z=0, N=1, C unchanged)
    ; =================================================================
    LDI A, #$A9         ; A = $A9 (10101001 binary)
    INR A               ; A = A + 1 = $A9 + 1 = $AA

    ; =================================================================
    ; TEST 9: Increment $7E to $7F (stays positive)
    ; Expected: A = $7E + 1 = $7F (Z=0, N=0, C unchanged)
    ; =================================================================
    LDI A, #$7E         ; A = $7E (126, still positive)
    INR A               ; A = A + 1 = $7E + 1 = $7F

    ; =================================================================
    ; TEST 10: Power of 2 boundary test ($0F + 1)
    ; Expected: A = $0F + 1 = $10 (Z=0, N=0, C unchanged)
    ; =================================================================
    LDI A, #$0F         ; A = $0F (15 decimal)
    INR A               ; A = A + 1 = $0F + 1 = $10

    ; =================================================================
    ; TEST 11: Power of 2 boundary test ($07 + 1)
    ; Expected: A = $07 + 1 = $08 (Z=0, N=0, C unchanged)
    ; =================================================================
    LDI A, #$07         ; A = $07 (7 decimal)
    INR A               ; A = A + 1 = $07 + 1 = $08

    ; =================================================================
    ; TEST 12: Carry flag preservation test with clear flag
    ; Expected: A = $04 + 1 = $05 (Z=0, N=0, C=0 preserved)
    ; =================================================================
    LDI A, #$04         ; A = $04
    CLC                 ; Clear carry flag
    INR A               ; A = A + 1 = $04 + 1 = $05 (C should remain 0)

    ; =================================================================
    ; TEST 13: Register preservation final verification
    ; Expected: A = $02 + 1 = $03, B=$55, C=$AA unchanged from TEST 1
    ; =================================================================
    LDI A, #$02         ; A = $02
    ; B and C should still be $55 and $AA from TEST 1
    INR A               ; A = A + 1 = $02 + 1 = $03

    ; =================================================================
    ; FINAL TEST: Halt instruction to end test sequence
    ; =================================================================
    HLT                 ; End of test sequence