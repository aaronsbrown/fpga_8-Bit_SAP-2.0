; ==============================================================================
; SUB_C Comprehensive Test Program
; ==============================================================================
; Tests the SUB_C instruction (A = A - C) with comprehensive test cases
; including bit patterns, flag behavior, and edge cases
; Based on ISA: SUB C (opcode $25) - A = A - C, affects Z/N/C flags
; C=1 if no borrow, C=0 if borrow occurred
; ==============================================================================

ORG $F000

MAIN:
    ; ==================================================================
    ; TEST 1: Basic subtraction with no borrow (A > C)
    ; A=$10, C=$05 => A=$0B, Z=0, N=0, C=1 (no borrow)
    ; ==================================================================
    LDI A, #$10    ; Load A with $10
    LDI B, #$BB    ; Load B with $BB (register preservation test)
    LDI C, #$05    ; Load C with $05
    SUB C          ; A = A - C = $10 - $05 = $0B
    
    ; ==================================================================
    ; TEST 2: Basic subtraction with borrow (A < C)
    ; A=$05, C=$10 => A=$F5, Z=0, N=1, C=0 (borrow)
    ; ==================================================================
    LDI A, #$05    ; Load A with $05
    LDI B, #$CC    ; Load B with $CC (register preservation test)
    LDI C, #$10    ; Load C with $10
    SUB C          ; A = A - C = $05 - $10 = $F5 (with borrow)

    ; ==================================================================
    ; TEST 3: Subtraction resulting in zero (A == C)
    ; A=$42, C=$42 => A=$00, Z=1, N=0, C=1 (no borrow)
    ; ==================================================================
    LDI A, #$42    ; Load A with $42
    LDI B, #$DD    ; Load B with $DD (register preservation test)
    LDI C, #$42    ; Load C with $42
    SUB C          ; A = A - C = $42 - $42 = $00

    ; ==================================================================
    ; TEST 4: Subtraction from zero (A=0, C>0)
    ; A=$00, C=$01 => A=$FF, Z=0, N=1, C=0 (borrow)
    ; ==================================================================
    LDI A, #$00    ; Load A with $00
    LDI B, #$EE    ; Load B with $EE (register preservation test)
    LDI C, #$01    ; Load C with $01
    SUB C          ; A = A - C = $00 - $01 = $FF (with borrow)

    ; ==================================================================
    ; TEST 5: Maximum value minus one (A=$FF, C=$01)
    ; A=$FF, C=$01 => A=$FE, Z=0, N=1, C=1 (no borrow)
    ; ==================================================================
    LDI A, #$FF    ; Load A with $FF
    LDI B, #$11    ; Load B with $11 (register preservation test)
    LDI C, #$01    ; Load C with $01
    SUB C          ; A = A - C = $FF - $01 = $FE

    ; ==================================================================
    ; TEST 6: Alternating bit patterns (A=$AA, C=$55)
    ; A=$AA, C=$55 => A=$55, Z=0, N=0, C=1 (no borrow)
    ; ==================================================================
    LDI A, #$AA    ; Load A with $AA (10101010)
    LDI B, #$22    ; Load B with $22 (register preservation test)
    LDI C, #$55    ; Load C with $55 (01010101)
    SUB C          ; A = A - C = $AA - $55 = $55

    ; ==================================================================
    ; TEST 7: Reverse alternating with borrow (A=$55, C=$AA)
    ; A=$55, C=$AA => A=$AB, Z=0, N=1, C=0 (borrow)
    ; ==================================================================
    LDI A, #$55    ; Load A with $55 (01010101)
    LDI B, #$33    ; Load B with $33 (register preservation test)
    LDI C, #$AA    ; Load C with $AA (10101010)
    SUB C          ; A = A - C = $55 - $AA = $AB (with borrow)

    ; ==================================================================
    ; TEST 8: Single bit subtraction (MSB test)
    ; A=$80, C=$01 => A=$7F, Z=0, N=0, C=1 (no borrow)
    ; ==================================================================
    LDI A, #$80    ; Load A with $80 (10000000)
    LDI B, #$44    ; Load B with $44 (register preservation test)
    LDI C, #$01    ; Load C with $01 (00000001)
    SUB C          ; A = A - C = $80 - $01 = $7F

    ; ==================================================================
    ; TEST 9: LSB boundary test (A=$01, C=$01)
    ; A=$01, C=$01 => A=$00, Z=1, N=0, C=1 (no borrow)
    ; ==================================================================
    LDI A, #$01    ; Load A with $01
    LDI B, #$55    ; Load B with $55 (register preservation test)
    LDI C, #$01    ; Load C with $01
    SUB C          ; A = A - C = $01 - $01 = $00

    ; ==================================================================
    ; TEST 10: MSB boundary test (A=$80, C=$80)
    ; A=$80, C=$80 => A=$00, Z=1, N=0, C=1 (no borrow)
    ; ==================================================================
    LDI A, #$80    ; Load A with $80 (10000000)
    LDI B, #$66    ; Load B with $66 (register preservation test)
    LDI C, #$80    ; Load C with $80 (10000000)
    SUB C          ; A = A - C = $80 - $80 = $00

    ; ==================================================================
    ; TEST 11: Large subtraction resulting in MSB set
    ; A=$C0, C=$40 => A=$80, Z=0, N=1, C=1 (no borrow)
    ; ==================================================================
    LDI A, #$C0    ; Load A with $C0 (11000000)
    LDI B, #$77    ; Load B with $77 (register preservation test)
    LDI C, #$40    ; Load C with $40 (01000000)
    SUB C          ; A = A - C = $C0 - $40 = $80

    ; ==================================================================
    ; TEST 12: Small numbers subtraction
    ; A=$03, C=$02 => A=$01, Z=0, N=0, C=1 (no borrow)
    ; ==================================================================
    LDI A, #$03    ; Load A with $03
    LDI B, #$88    ; Load B with $88 (register preservation test)
    LDI C, #$02    ; Load C with $02
    SUB C          ; A = A - C = $03 - $02 = $01

    ; ==================================================================
    ; TEST 13: Complex bit pattern 1
    ; A=$B7, C=$29 => A=$8E, Z=0, N=1, C=1 (no borrow)
    ; ==================================================================
    LDI A, #$B7    ; Load A with $B7 (10110111)
    LDI B, #$99    ; Load B with $99 (register preservation test)
    LDI C, #$29    ; Load C with $29 (00101001)
    SUB C          ; A = A - C = $B7 - $29 = $8E

    ; ==================================================================
    ; TEST 14: Complex bit pattern 2 (with borrow)
    ; A=$3C, C=$5E => A=$DE, Z=0, N=1, C=0 (borrow)
    ; ==================================================================
    LDI A, #$3C    ; Load A with $3C (00111100)
    LDI B, #$AA    ; Load B with $AA (register preservation test)
    LDI C, #$5E    ; Load C with $5E (01011110)
    SUB C          ; A = A - C = $3C - $5E = $DE (with borrow)

    ; ==================================================================
    ; TEST 15: Register preservation final check
    ; A=$F0, C=$0F => A=$E1, B=$BB preserved, Z=0, N=1, C=1
    ; ==================================================================
    LDI A, #$F0    ; Load A with $F0 (11110000)
    LDI B, #$BB    ; Load B with $BB (register preservation test)
    LDI C, #$0F    ; Load C with $0F (00001111)
    SUB C          ; A = A - C = $F0 - $0F = $E1

    ; ==================================================================
    ; TEST 16: Edge case - subtract larger from smaller
    ; A=$01, C=$02 => A=$FF, Z=0, N=1, C=0 (borrow)
    ; ==================================================================
    LDI A, #$01    ; Load A with $01
    LDI B, #$CC    ; Load B with $CC (register preservation test)
    LDI C, #$02    ; Load C with $02
    SUB C          ; A = A - C = $01 - $02 = $FF (with borrow)

    ; Program complete - halt
    HLT            ; Halt processor