; ANI.asm
; Comprehensive test suite for ANI (AND Immediate) instruction
; Tests bit patterns, flag behavior, edge cases, and register preservation
; ANI: A = A & immediate, sets Z/N flags, clears Carry
; AIDEV-NOTE: Enhanced comprehensive test suite with 15 test cases covering edge cases

INCLUDE "../../programs/includes/mmio_defs.inc"

; ======================================================================
; == PROGRAM
; ======================================================================
    ORG $F000

START:
    ; Test 1: Basic AND operation with mixed bits
    ; A=$AA (10101010) & #$F0 (11110000) = $A0 (10100000)
    LDI A, #$AA             ; Load 10101010
    ANI #$F0                ; AND with 11110000, expect $A0, N=1, Z=0, C=0

    ; Test 2: AND with zero (should zero out result)
    ; A=$A0 & #$00 = $00
    ANI #$00                ; AND with 00000000, expect $00, N=0, Z=1, C=0

    ; Test 3: AND with all ones (should preserve A)
    ; First load new value, then AND with $FF
    LDI A, #$55             ; Load 01010101
    ANI #$FF                ; AND with 11111111, expect $55, N=0, Z=0, C=0

    ; Test 4: AND with same value (idempotent)
    ; A=$55 & #$55 = $55
    ANI #$55                ; AND with same value, expect $55, N=0, Z=0, C=0

    ; Test 5: AND with complement (should give zero)
    ; A=$55 (01010101) & #$AA (10101010) = $00
    ANI #$AA                ; AND with complement, expect $00, N=0, Z=1, C=0

    ; Test 6: Test negative flag with high bit set
    ; Load value with bit 7 set, AND to preserve it
    LDI A, #$80             ; Load 10000000 (negative)
    ANI #$FF                ; AND with all ones, expect $80, N=1, Z=0, C=0

    ; Test 7: Clear high bit to test negative flag clearing
    ; A=$80 & #$7F = $00
    ANI #$7F                ; Clear bit 7, expect $00, N=0, Z=1, C=0

    ; Test 8: Pattern isolation test (no bit overlap)
    ; A=$00, load new pattern and test isolation
    LDI A, #$F0             ; Load 11110000
    ANI #$0F                ; AND with 00001111, expect $00, N=0, Z=1, C=0

    ; Test 9: Single bit isolation
    ; A=$00, load all ones and isolate bit 0
    LDI A, #$FF             ; Load 11111111
    ANI #$01                ; Isolate bit 0, expect $01, N=0, Z=0, C=0

    ; Test 10: Multiple bit isolation
    ; A=$01, load new value and isolate specific bits
    LDI A, #$E7             ; Load 11100111
    ANI #$18                ; Isolate bits 3,4, expect $00, N=0, Z=1, C=0

    ; Test 11: Carry flag clearing test (set carry first)
    ; Test that ANI clears carry regardless of input carry state
    SEC                     ; Set carry flag (C=1)
    LDI A, #$3C             ; Load 00111100
    ANI #$C3                ; AND with 11000011, expect $00, N=0, Z=1, C=0 (carry cleared)

    ; Test 12: Register preservation test
    ; Verify B and C registers are not affected by ANI
    LDI B, #$42             ; Load B with test pattern
    LDI C, #$69             ; Load C with test pattern
    LDI A, #$FF             ; Load A
    ANI #$81                ; AND operation, expect $81, B=$42, C=$69 preserved

    ; Test 13: Edge case - alternating pattern preservation
    ; Test specific bit pattern preservation
    LDI A, #$CC             ; Load 11001100
    ANI #$33                ; AND with 00110011, expect $00, N=0, Z=1, C=0

    ; Test 14: Boundary values test
    ; Test with maximum positive value (0x7F)
    LDI A, #$7F             ; Load 01111111 (max positive)
    ANI #$80                ; AND with 10000000, expect $00, N=0, Z=1, C=0

    ; Test 15: Final comprehensive test
    ; Complex pattern to verify all functionality
    LDI A, #$DE             ; Load 11011110
    ANI #$AD                ; AND with 10101101, expect $8C, N=1, Z=0, C=0

    HLT                     ; End of program