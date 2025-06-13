; INR_C.asm
; Comprehensive test suite for INR_C instruction
; Tests edge cases, boundary conditions, and flag behavior
; INR_C: Increment C (C=C+1), affects Z and N flags, C unaffected
; AIDEV-NOTE: Enhanced with 13 comprehensive test cases covering edge cases, flag behavior, and register preservation

INCLUDE "../../programs/includes/mmio_defs.inc"

; ======================================================================
; == PROGRAM
; ======================================================================
    ORG $F000

START:
    ; =================================================================
    ; TEST 1: Basic increment - positive number
    ; Expected: C = $01 + 1 = $02 (Z=0, N=0, Carry unchanged)
    ; =================================================================
    LDI C, #$01         ; C = $01
    LDI A, #$55         ; A = $55 (preserve test - should remain unchanged)
    LDI B, #$AA         ; B = $AA (preserve test - should remain unchanged) 
    SEC                 ; Set carry flag to test preservation
    INR C               ; C = C + 1 = $01 + 1 = $02

    ; =================================================================
    ; TEST 2: Increment resulting in zero (overflow from $FF)
    ; Expected: C = $FF + 1 = $00 (Z=1, N=0, Carry unchanged)
    ; =================================================================
    LDI C, #$FF         ; C = $FF
    INR C               ; C = C + 1 = $FF + 1 = $00 (overflow)

    ; =================================================================
    ; TEST 3: Zero increment
    ; Expected: C = $00 + 1 = $01 (Z=0, N=0, Carry unchanged)
    ; =================================================================
    LDI C, #$00         ; C = $00
    INR C               ; C = C + 1 = $00 + 1 = $01

    ; =================================================================
    ; TEST 4: Increment from $7F (max positive) to $80 (negative)
    ; Expected: C = $7F + 1 = $80 (Z=0, N=1, Carry unchanged)
    ; =================================================================
    LDI C, #$7F         ; C = $7F (127, max positive in 2's complement)
    INR C               ; C = C + 1 = $7F + 1 = $80 (becomes negative)

    ; =================================================================
    ; TEST 5: Increment negative value from MSB set
    ; Expected: C = $80 + 1 = $81 (Z=0, N=1, Carry unchanged)
    ; =================================================================
    LDI C, #$80         ; C = $80 (MSB set, -128 in 2's complement)
    INR C               ; C = C + 1 = $80 + 1 = $81

    ; =================================================================
    ; TEST 6: Increment from $FE to $FF (all ones result)
    ; Expected: C = $FE + 1 = $FF (Z=0, N=1, Carry unchanged)
    ; =================================================================
    LDI C, #$FE         ; C = $FE
    INR C               ; C = C + 1 = $FE + 1 = $FF (all bits set)

    ; =================================================================
    ; TEST 7: Alternating pattern (0x54) increment
    ; Expected: C = $54 + 1 = $55 (Z=0, N=0, Carry unchanged)
    ; =================================================================
    LDI C, #$54         ; C = $54 (01010100 binary)
    INR C               ; C = C + 1 = $54 + 1 = $55

    ; =================================================================
    ; TEST 8: Alternating pattern (0xA9) increment
    ; Expected: C = $A9 + 1 = $AA (Z=0, N=1, Carry unchanged)
    ; =================================================================
    LDI C, #$A9         ; C = $A9 (10101001 binary)
    INR C               ; C = C + 1 = $A9 + 1 = $AA

    ; =================================================================
    ; TEST 9: Increment $7E to $7F (stays positive)
    ; Expected: C = $7E + 1 = $7F (Z=0, N=0, Carry unchanged)
    ; =================================================================
    LDI C, #$7E         ; C = $7E (126, still positive)
    INR C               ; C = C + 1 = $7E + 1 = $7F

    ; =================================================================
    ; TEST 10: Power of 2 boundary test ($0F + 1)
    ; Expected: C = $0F + 1 = $10 (Z=0, N=0, Carry unchanged)
    ; =================================================================
    LDI C, #$0F         ; C = $0F (15 decimal)
    INR C               ; C = C + 1 = $0F + 1 = $10

    ; =================================================================
    ; TEST 11: Power of 2 boundary test ($07 + 1)
    ; Expected: C = $07 + 1 = $08 (Z=0, N=0, Carry unchanged)
    ; =================================================================
    LDI C, #$07         ; C = $07 (7 decimal)
    INR C               ; C = C + 1 = $07 + 1 = $08

    ; =================================================================
    ; TEST 12: Carry flag preservation test with clear flag
    ; Expected: C = $04 + 1 = $05 (Z=0, N=0, Carry=0 preserved)
    ; =================================================================
    LDI C, #$04         ; C = $04
    CLC                 ; Clear carry flag
    INR C               ; C = C + 1 = $04 + 1 = $05 (Carry should remain 0)

    ; =================================================================
    ; TEST 13: Register preservation final verification
    ; Expected: C = $02 + 1 = $03, A=$55, B=$AA unchanged from TEST 1
    ; =================================================================
    LDI C, #$02         ; C = $02
    ; A and B should still be $55 and $AA from TEST 1
    INR C               ; C = C + 1 = $02 + 1 = $03

    ; =================================================================
    ; FINAL TEST: Halt instruction to end test sequence
    ; =================================================================
    HLT                 ; End of test sequence