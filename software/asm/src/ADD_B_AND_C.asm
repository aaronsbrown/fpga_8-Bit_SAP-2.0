; ADD_B_AND_C.asm
; Comprehensive test suite for ADD_B and ADD_C instructions
; Tests both operations, edge cases, boundary conditions, and flag behavior

INCLUDE "includes/mmio_defs.inc"

; ======================================================================
; == PROGRAM
; ======================================================================
    ORG $F000

START:
    ; =================================================================
    ; TEST GROUP 1: ADD_B Basic Operations
    ; =================================================================
    
    ; TEST 1: Basic ADD_B with small positive numbers
    ; Expected: A = $10 + $05 = $15 (Z=0, N=0, C=0)
    LDI A, #$10         ; A = $10 (16)
    LDI B, #$05         ; B = $05 (5)
    LDI C, #$AA         ; C = $AA (preservation test - should remain unchanged)
    ADD B               ; A = A + B = $10 + $05 = $15

    ; TEST 2: ADD_B resulting in zero with carry
    ; Expected: A = $FF + $01 = $00 (Z=1, N=0, C=1) - carry from bit 7
    LDI A, #$FF         ; A = $FF (255)
    LDI B, #$01         ; B = $01 (1)
    ADD B               ; A = A + B = $FF + $01 = $00 with carry

    ; TEST 3: ADD_B with both operands having MSB set
    ; Expected: A = $80 + $80 = $00 (Z=1, N=0, C=1) - two MSBs set
    LDI A, #$80         ; A = $80 (128, MSB set)
    LDI B, #$80         ; B = $80 (128, MSB set)
    ADD B               ; A = A + B = $80 + $80 = $00 with carry

    ; TEST 4: ADD_B resulting in negative (MSB set)
    ; Expected: A = $7F + $01 = $80 (Z=0, N=1, C=0) - maximum positive + 1
    LDI A, #$7F         ; A = $7F (127, maximum positive in signed)
    LDI B, #$01         ; B = $01 (1)
    ADD B               ; A = A + B = $7F + $01 = $80 (negative result)

    ; TEST 5: ADD_B alternating bit pattern test
    ; Expected: A = $55 + $AA = $FF (Z=0, N=1, C=0) - complementary patterns
    LDI A, #$55         ; A = $55 (01010101 binary)
    LDI B, #$AA         ; B = $AA (10101010 binary)
    ADD B               ; A = A + B = $55 + $AA = $FF

    ; TEST 6: ADD_B zero plus zero
    ; Expected: A = $00 + $00 = $00 (Z=1, N=0, C=0) - identity operation
    LDI A, #$00         ; A = $00 (0)
    LDI B, #$00         ; B = $00 (0)
    ADD B               ; A = A + B = $00 + $00 = $00

    ; TEST 7: ADD_B single bit test (LSB)
    ; Expected: A = $00 + $01 = $01 (Z=0, N=0, C=0) - LSB only
    LDI A, #$00         ; A = $00 (0)
    LDI B, #$01         ; B = $01 (only LSB set)
    ADD B               ; A = A + B = $00 + $01 = $01

    ; TEST 8: ADD_B single bit test (MSB)
    ; Expected: A = $00 + $80 = $80 (Z=0, N=1, C=0) - MSB only
    LDI A, #$00         ; A = $00 (0)
    LDI B, #$80         ; B = $80 (only MSB set)
    ADD B               ; A = A + B = $00 + $80 = $80

    ; =================================================================
    ; TEST GROUP 2: ADD_C Basic Operations
    ; =================================================================
    
    ; TEST 9: Basic ADD_C with small positive numbers
    ; Expected: A = $08 + $03 = $0B (Z=0, N=0, C=0)
    LDI A, #$08         ; A = $08 (8)
    LDI B, #$BB         ; B = $BB (preservation test)
    LDI C, #$03         ; C = $03 (3)
    ADD C               ; A = A + C = $08 + $03 = $0B

    ; TEST 10: ADD_C resulting in zero with carry
    ; Expected: A = $FE + $02 = $00 (Z=1, N=0, C=1) - wraparound
    LDI A, #$FE         ; A = $FE (254)
    LDI C, #$02         ; C = $02 (2)
    ADD C               ; A = A + C = $FE + $02 = $00 with carry

    ; TEST 11: ADD_C with both operands having MSB set
    ; Expected: A = $C0 + $C0 = $80 (Z=0, N=1, C=1) - both have MSB
    LDI A, #$C0         ; A = $C0 (192, MSB set)
    LDI C, #$C0         ; C = $C0 (192, MSB set)
    ADD C               ; A = A + C = $C0 + $C0 = $80 with carry

    ; TEST 12: ADD_C resulting in negative (MSB set)
    ; Expected: A = $60 + $20 = $80 (Z=0, N=1, C=0) - positive to negative
    LDI A, #$60         ; A = $60 (96)
    LDI C, #$20         ; C = $20 (32)
    ADD C               ; A = A + C = $60 + $20 = $80 (negative result)

    ; TEST 13: ADD_C alternating bit pattern test
    ; Expected: A = $33 + $CC = $FF (Z=0, N=1, C=0) - complementary patterns
    LDI A, #$33         ; A = $33 (00110011 binary)
    LDI C, #$CC         ; C = $CC (11001100 binary)
    ADD C               ; A = A + C = $33 + $CC = $FF

    ; TEST 14: ADD_C with maximum values
    ; Expected: A = $FF + $FF = $FE (Z=0, N=1, C=1) - maximum addition
    LDI A, #$FF         ; A = $FF (255)
    LDI C, #$FF         ; C = $FF (255)
    ADD C               ; A = A + C = $FF + $FF = $FE with carry

    ; =================================================================
    ; TEST GROUP 3: Register Preservation and Edge Cases
    ; =================================================================
    
    ; TEST 15: ADD_B register preservation verification
    ; Expected: A = $20 + $10 = $30, B and C should be preserved
    LDI A, #$20         ; A = $20 (32)
    LDI B, #$10         ; B = $10 (16)
    LDI C, #$DD         ; C = $DD (preservation test)
    ADD B               ; A = A + B = $20 + $10 = $30

    ; TEST 16: ADD_C register preservation verification
    ; Expected: A = $15 + $0A = $1F, B should still be preserved
    LDI A, #$15         ; A = $15 (21)
    ; B should still be $10 from previous test
    LDI C, #$0A         ; C = $0A (10)
    ADD C               ; A = A + C = $15 + $0A = $1F
    
    ; TEST 17: Chain operations - ADD_B followed by ADD_C
    ; Expected: First A = $10 + $05 = $15, then A = $15 + $05 = $1A
    LDI A, #$10         ; A = $10 (16)
    LDI B, #$05         ; B = $05 (5)
    LDI C, #$05         ; C = $05 (5)
    ADD B               ; A = A + B = $10 + $05 = $15
    ADD C               ; A = A + C = $15 + $05 = $1A

    ; =================================================================
    ; FINAL TEST: Halt instruction to end test sequence
    ; =================================================================
    HLT                 ; End of comprehensive test sequence