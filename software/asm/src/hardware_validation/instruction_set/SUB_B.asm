; SUB_B.asm
; Comprehensive test suite for SUB_B instruction (A = A - B)
; Tests subtraction with various bit patterns, edge cases, and flag behavior
; SUB_B: opcode $24, affects Z/N based on result, C=1 if no borrow, C=0 if borrow
; AIDEV-NOTE: Enhanced robustness with 16 comprehensive test cases covering all SUB_B scenarios

INCLUDE "../../programs/includes/mmio_defs.inc"

; ======================================================================
; == SUB_B COMPREHENSIVE TEST PROGRAM
; ======================================================================
    ORG $F000

START:
    ; ====================================================================
    ; TEST 1: Basic subtraction with no borrow (A > B)
    ; A=$10, B=$05 => A=$0B, Z=0, N=0, C=1 (no borrow)
    ; ====================================================================
    LDI A, #$10        ; A = 16 (00010000)
    LDI B, #$05        ; B = 5  (00000101)  
    LDI C, #$CC        ; C = preservation test pattern
    SUB B              ; A = $10 - $05 = $0B, C=1 (no borrow)
    ; Expected: A=$0B, B=$05, C=$CC, Z=0, N=0, C=1

    ; ====================================================================
    ; TEST 2: Basic subtraction with borrow (A < B)  
    ; A=$05, B=$10 => A=$F5, Z=0, N=1, C=0 (borrow occurred)
    ; ====================================================================
    LDI A, #$05        ; A = 5   (00000101)
    LDI B, #$10        ; B = 16  (00010000)
    SUB B              ; A = $05 - $10 = $F5, C=0 (borrow)
    ; Expected: A=$F5, B=$10, C=$CC, Z=0, N=1, C=0

    ; ====================================================================
    ; TEST 3: Subtraction resulting in zero (A == B)
    ; A=$42, B=$42 => A=$00, Z=1, N=0, C=1 (no borrow)
    ; ====================================================================
    LDI A, #$42        ; A = 66  (01000010)
    LDI B, #$42        ; B = 66  (01000010)
    SUB B              ; A = $42 - $42 = $00, C=1 (no borrow)
    ; Expected: A=$00, B=$42, C=$CC, Z=1, N=0, C=1

    ; ====================================================================
    ; TEST 4: Subtraction from zero (A=0, B>0)
    ; A=$00, B=$01 => A=$FF, Z=0, N=1, C=0 (borrow)
    ; ====================================================================
    LDI A, #$00        ; A = 0   (00000000)
    LDI B, #$01        ; B = 1   (00000001)
    SUB B              ; A = $00 - $01 = $FF, C=0 (borrow)
    ; Expected: A=$FF, B=$01, C=$CC, Z=0, N=1, C=0

    ; ====================================================================
    ; TEST 5: Maximum value minus one (A=$FF, B=$01)
    ; A=$FF, B=$01 => A=$FE, Z=0, N=1, C=1 (no borrow)
    ; ====================================================================
    LDI A, #$FF        ; A = 255 (11111111)
    LDI B, #$01        ; B = 1   (00000001)
    SUB B              ; A = $FF - $01 = $FE, C=1 (no borrow)
    ; Expected: A=$FE, B=$01, C=$CC, Z=0, N=1, C=1

    ; ====================================================================
    ; TEST 6: Subtraction with alternating bit patterns
    ; A=$AA, B=$55 => A=$55, Z=0, N=0, C=1 (no borrow)
    ; ====================================================================
    LDI A, #$AA        ; A = 170 (10101010)
    LDI B, #$55        ; B = 85  (01010101)
    SUB B              ; A = $AA - $55 = $55, C=1 (no borrow)
    ; Expected: A=$55, B=$55, C=$CC, Z=0, N=0, C=1

    ; ====================================================================
    ; TEST 7: Reverse alternating pattern subtraction
    ; A=$55, B=$AA => A=$AB, Z=0, N=1, C=0 (borrow)
    ; ====================================================================
    LDI A, #$55        ; A = 85  (01010101)
    LDI B, #$AA        ; B = 170 (10101010)
    SUB B              ; A = $55 - $AA = $AB, C=0 (borrow)
    ; Expected: A=$AB, B=$AA, C=$CC, Z=0, N=1, C=0

    ; ====================================================================
    ; TEST 8: Single bit subtraction (MSB test)
    ; A=$80, B=$01 => A=$7F, Z=0, N=0, C=1 (no borrow)
    ; ====================================================================
    LDI A, #$80        ; A = 128 (10000000)
    LDI B, #$01        ; B = 1   (00000001)
    SUB B              ; A = $80 - $01 = $7F, C=1 (no borrow)
    ; Expected: A=$7F, B=$01, C=$CC, Z=0, N=0, C=1

    ; ====================================================================
    ; TEST 9: LSB boundary test (A=$01, B=$01)
    ; A=$01, B=$01 => A=$00, Z=1, N=0, C=1 (no borrow)
    ; ====================================================================
    LDI A, #$01        ; A = 1   (00000001)
    LDI B, #$01        ; B = 1   (00000001)
    SUB B              ; A = $01 - $01 = $00, C=1 (no borrow)
    ; Expected: A=$00, B=$01, C=$CC, Z=1, N=0, C=1

    ; ====================================================================
    ; TEST 10: MSB boundary test (A=$80, B=$80)
    ; A=$80, B=$80 => A=$00, Z=1, N=0, C=1 (no borrow)
    ; ====================================================================
    LDI A, #$80        ; A = 128 (10000000)
    LDI B, #$80        ; B = 128 (10000000)
    SUB B              ; A = $80 - $80 = $00, C=1 (no borrow)
    ; Expected: A=$00, B=$80, C=$CC, Z=1, N=0, C=1

    ; ====================================================================
    ; TEST 11: Large subtraction resulting in positive
    ; A=$C0, B=$40 => A=$80, Z=0, N=1, C=1 (no borrow)
    ; ====================================================================
    LDI A, #$C0        ; A = 192 (11000000)
    LDI B, #$40        ; B = 64  (01000000)
    SUB B              ; A = $C0 - $40 = $80, C=1 (no borrow)
    ; Expected: A=$80, B=$40, C=$CC, Z=0, N=1, C=1

    ; ====================================================================
    ; TEST 12: Small numbers subtraction
    ; A=$03, B=$02 => A=$01, Z=0, N=0, C=1 (no borrow)
    ; ====================================================================
    LDI A, #$03        ; A = 3   (00000011)
    LDI B, #$02        ; B = 2   (00000010)
    SUB B              ; A = $03 - $02 = $01, C=1 (no borrow)
    ; Expected: A=$01, B=$02, C=$CC, Z=0, N=0, C=1

    ; ====================================================================
    ; TEST 13: Complex bit pattern 1
    ; A=$B7, B=$29 => A=$8E, Z=0, N=1, C=1 (no borrow)
    ; ====================================================================
    LDI A, #$B7        ; A = 183 (10110111)
    LDI B, #$29        ; B = 41  (00101001)
    SUB B              ; A = $B7 - $29 = $8E, C=1 (no borrow)
    ; Expected: A=$8E, B=$29, C=$CC, Z=0, N=1, C=1

    ; ====================================================================
    ; TEST 14: Complex bit pattern 2 (with borrow)
    ; A=$3C, B=$5E => A=$DE, Z=0, N=1, C=0 (borrow)
    ; ====================================================================
    LDI A, #$3C        ; A = 60  (00111100)
    LDI B, #$5E        ; B = 94  (01011110)
    SUB B              ; A = $3C - $5E = $DE, C=0 (borrow)
    ; Expected: A=$DE, B=$5E, C=$CC, Z=0, N=1, C=0

    ; ====================================================================
    ; TEST 15: Register preservation final check
    ; Load fresh test patterns and verify SUB_B doesn't affect register C
    ; ====================================================================
    LDI A, #$F0        ; A = 240 (11110000)
    LDI B, #$0F        ; B = 15  (00001111)  
    LDI C, #$AA        ; C = test pattern for preservation
    SUB B              ; A = $F0 - $0F = $E1, C=1 (no borrow)
    ; Expected: A=$E1, B=$0F, C=$AA (preserved), Z=0, N=1, C=1

    ; ====================================================================
    ; TEST 16: Edge case - subtract from one  
    ; A=$01, B=$02 => A=$FF, Z=0, N=1, C=0 (borrow)
    ; ====================================================================
    LDI A, #$01        ; A = 1   (00000001)
    LDI B, #$02        ; B = 2   (00000010)
    SUB B              ; A = $01 - $02 = $FF, C=0 (borrow)
    ; Expected: A=$FF, B=$02, C=$AA, Z=0, N=1, C=0

    HLT                ; Stop execution