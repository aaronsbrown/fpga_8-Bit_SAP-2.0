; SBC_B_AND_C.asm
; Comprehensive test suite for SBC_B and SBC_C instructions
; SBC B: A = A - B - ~Carry (opcode $26), SBC C: A = A - C - ~Carry (opcode $27)
; Tests subtraction with carry/borrow, bit patterns, edge cases, and flag behavior
; SBC affects Z/N based on result, C=1 if no borrow, C=0 if borrow
; AIDEV-NOTE: Enhanced robustness with comprehensive test cases covering all SBC scenarios

INCLUDE "includes/mmio_defs.inc"

; ======================================================================
; == SBC_B AND SBC_C COMPREHENSIVE TEST PROGRAM
; ======================================================================
    ORG $F000

START:
    ; ====================================================================
    ; TEST GROUP 1: SBC_B Basic Operations
    ; ====================================================================
    
    ; ====================================================================
    ; TEST 1: SBC_B with carry clear (C=0, acts as additional borrow)
    ; A=$10, B=$05, C=0 => A=$10-$05-1=$0A, Z=0, N=0, C=1 (no borrow)
    ; ====================================================================
    CLC                 ; Clear carry (C=0, ~C=1, so extra -1)
    LDI A, #$10        ; A = 16 (00010000)
    LDI B, #$05        ; B = 5  (00000101)
    LDI C, #$AA        ; C = preservation test pattern
    SBC B              ; A = $10 - $05 - 1 = $0A, C=1 (no borrow)
    ; Expected: A=$0A, B=$05, C=$AA, Z=0, N=0, C=1

    ; ====================================================================
    ; TEST 2: SBC_B with carry set (C=1, no additional borrow)
    ; A=$10, B=$05, C=1 => A=$10-$05-0=$0B, Z=0, N=0, C=1 (no borrow)
    ; ====================================================================
    SEC                 ; Set carry (C=1, ~C=0, so no extra subtraction)
    LDI A, #$10        ; A = 16 (00010000)
    LDI B, #$05        ; B = 5  (00000101)
    SBC B              ; A = $10 - $05 - 0 = $0B, C=1 (no borrow)
    ; Expected: A=$0B, B=$05, C=$AA, Z=0, N=0, C=1

    ; ====================================================================
    ; TEST 3: SBC_B resulting in zero with carry clear
    ; A=$06, B=$05, C=0 => A=$06-$05-1=$00, Z=1, N=0, C=1 (no borrow)
    ; ====================================================================
    CLC                 ; Clear carry
    LDI A, #$06        ; A = 6   (00000110)
    LDI B, #$05        ; B = 5   (00000101)
    SBC B              ; A = $06 - $05 - 1 = $00, C=1 (no borrow)
    ; Expected: A=$00, B=$05, C=$AA, Z=1, N=0, C=1

    ; ====================================================================
    ; TEST 4: SBC_B with carry clear causing negative result
    ; A=$05, B=$05, C=0 => A=$05-$05-1=$FF, Z=0, N=1, C=0 (borrow)
    ; ====================================================================
    CLC                 ; Clear carry
    LDI A, #$05        ; A = 5   (00000101)
    LDI B, #$05        ; B = 5   (00000101)
    SBC B              ; A = $05 - $05 - 1 = $FF, C=0 (borrow)
    ; Expected: A=$FF, B=$05, C=$AA, Z=0, N=1, C=0

    ; ====================================================================
    ; TEST 5: SBC_B from zero with carry clear (extreme borrow)
    ; A=$00, B=$01, C=0 => A=$00-$01-1=$FE, Z=0, N=1, C=0 (borrow)
    ; ====================================================================
    CLC                 ; Clear carry
    LDI A, #$00        ; A = 0   (00000000)
    LDI B, #$01        ; B = 1   (00000001)
    SBC B              ; A = $00 - $01 - 1 = $FE, C=0 (borrow)
    ; Expected: A=$FE, B=$01, C=$AA, Z=0, N=1, C=0

    ; ====================================================================
    ; TEST 6: SBC_B with alternating patterns and carry set
    ; A=$AA, B=$55, C=1 => A=$AA-$55-0=$55, Z=0, N=0, C=1 (no borrow)
    ; ====================================================================
    SEC                 ; Set carry
    LDI A, #$AA        ; A = 170 (10101010)
    LDI B, #$55        ; B = 85  (01010101)
    SBC B              ; A = $AA - $55 - 0 = $55, C=1 (no borrow)
    ; Expected: A=$55, B=$55, C=$AA, Z=0, N=0, C=1

    ; ====================================================================
    ; TEST 7: SBC_B with alternating patterns and carry clear
    ; A=$AA, B=$55, C=0 => A=$AA-$55-1=$54, Z=0, N=0, C=1 (no borrow)
    ; ====================================================================
    CLC                 ; Clear carry
    LDI A, #$AA        ; A = 170 (10101010)
    LDI B, #$55        ; B = 85  (01010101)
    SBC B              ; A = $AA - $55 - 1 = $54, C=1 (no borrow)
    ; Expected: A=$54, B=$55, C=$AA, Z=0, N=0, C=1

    ; ====================================================================
    ; TEST 8: SBC_B maximum value with carry states
    ; A=$FF, B=$01, C=0 => A=$FF-$01-1=$FD, Z=0, N=1, C=1 (no borrow)
    ; ====================================================================
    CLC                 ; Clear carry
    LDI A, #$FF        ; A = 255 (11111111)
    LDI B, #$01        ; B = 1   (00000001)
    SBC B              ; A = $FF - $01 - 1 = $FD, C=1 (no borrow)
    ; Expected: A=$FD, B=$01, C=$AA, Z=0, N=1, C=1

    ; ====================================================================
    ; TEST GROUP 2: SBC_C Basic Operations
    ; ====================================================================

    ; ====================================================================
    ; TEST 9: SBC_C with carry clear (C=0, acts as additional borrow)
    ; A=$20, B=$BB, C=$08, carry=0 => A=$20-$08-1=$17, Z=0, N=0, C=1 (no borrow)
    ; ====================================================================
    CLC                 ; Clear carry
    LDI A, #$20        ; A = 32  (00100000)
    LDI B, #$BB        ; B = preservation test pattern
    LDI C, #$08        ; C = 8   (00001000)
    SBC C              ; A = $20 - $08 - 1 = $17, C=1 (no borrow)
    ; Expected: A=$17, B=$BB, C=$08, Z=0, N=0, C=1

    ; ====================================================================
    ; TEST 10: SBC_C with carry set (C=1, no additional borrow)
    ; A=$20, B=$BB, C=$08, carry=1 => A=$20-$08-0=$18, Z=0, N=0, C=1 (no borrow)
    ; ====================================================================
    SEC                 ; Set carry
    LDI A, #$20        ; A = 32  (00100000)
    LDI B, #$BB        ; B = preservation test pattern
    LDI C, #$08        ; C = 8   (00001000)
    SBC C              ; A = $20 - $08 - 0 = $18, C=1 (no borrow)
    ; Expected: A=$18, B=$BB, C=$08, Z=0, N=0, C=1

    ; ====================================================================
    ; TEST 11: SBC_C resulting in zero with carry clear
    ; A=$09, B=$BB, C=$08, carry=0 => A=$09-$08-1=$00, Z=1, N=0, C=1 (no borrow)
    ; ====================================================================
    CLC                 ; Clear carry
    LDI A, #$09        ; A = 9   (00001001)
    LDI B, #$BB        ; B = preservation test pattern
    LDI C, #$08        ; C = 8   (00001000)
    SBC C              ; A = $09 - $08 - 1 = $00, C=1 (no borrow)
    ; Expected: A=$00, B=$BB, C=$08, Z=1, N=0, C=1

    ; ====================================================================
    ; TEST 12: SBC_C with carry clear causing negative result
    ; A=$08, B=$BB, C=$08, carry=0 => A=$08-$08-1=$FF, Z=0, N=1, C=0 (borrow)
    ; ====================================================================
    CLC                 ; Clear carry
    LDI A, #$08        ; A = 8   (00001000)
    LDI B, #$BB        ; B = preservation test pattern
    LDI C, #$08        ; C = 8   (00001000)
    SBC C              ; A = $08 - $08 - 1 = $FF, C=0 (borrow)
    ; Expected: A=$FF, B=$BB, C=$08, Z=0, N=1, C=0

    ; ====================================================================
    ; TEST 13: SBC_C from zero with carry clear (extreme borrow)
    ; A=$00, B=$BB, C=$02, carry=0 => A=$00-$02-1=$FD, Z=0, N=1, C=0 (borrow)
    ; ====================================================================
    CLC                 ; Clear carry
    LDI A, #$00        ; A = 0   (00000000)
    LDI B, #$BB        ; B = preservation test pattern
    LDI C, #$02        ; C = 2   (00000010)
    SBC C              ; A = $00 - $02 - 1 = $FD, C=0 (borrow)
    ; Expected: A=$FD, B=$BB, C=$02, Z=0, N=1, C=0

    ; ====================================================================
    ; TEST 14: SBC_C with complex bit patterns
    ; A=$B7, B=$BB, C=$29, carry=1 => A=$B7-$29-0=$8E, Z=0, N=1, C=1 (no borrow)
    ; ====================================================================
    SEC                 ; Set carry
    LDI A, #$B7        ; A = 183 (10110111)
    LDI B, #$BB        ; B = preservation test pattern
    LDI C, #$29        ; C = 41  (00101001)
    SBC C              ; A = $B7 - $29 - 0 = $8E, C=1 (no borrow)
    ; Expected: A=$8E, B=$BB, C=$29, Z=0, N=1, C=1

    ; ====================================================================
    ; TEST 15: SBC_C with complex bit patterns and carry clear
    ; A=$B7, B=$BB, C=$29, carry=0 => A=$B7-$29-1=$8D, Z=0, N=1, C=1 (no borrow)
    ; ====================================================================
    CLC                 ; Clear carry
    LDI A, #$B7        ; A = 183 (10110111)
    LDI B, #$BB        ; B = preservation test pattern
    LDI C, #$29        ; C = 41  (00101001)
    SBC C              ; A = $B7 - $29 - 1 = $8D, C=1 (no borrow)
    ; Expected: A=$8D, B=$BB, C=$29, Z=0, N=1, C=1

    ; ====================================================================
    ; TEST GROUP 3: Edge Cases and Boundary Conditions
    ; ====================================================================

    ; ====================================================================
    ; TEST 16: SBC_B single bit operations
    ; A=$80, B=$01, carry=0 => A=$80-$01-1=$7E, Z=0, N=0, C=1 (no borrow)
    ; ====================================================================
    CLC                 ; Clear carry
    LDI A, #$80        ; A = 128 (10000000)
    LDI B, #$01        ; B = 1   (00000001)
    LDI C, #$CC        ; C = preservation test
    SBC B              ; A = $80 - $01 - 1 = $7E, C=1 (no borrow)
    ; Expected: A=$7E, B=$01, C=$CC, Z=0, N=0, C=1

    ; ====================================================================
    ; TEST 17: SBC_C single bit operations
    ; A=$80, C=$01, carry=0 => A=$80-$01-1=$7E, Z=0, N=0, C=1 (no borrow)
    ; ====================================================================
    CLC                 ; Clear carry
    LDI A, #$80        ; A = 128 (10000000)
    LDI B, #$DD        ; B = preservation test
    LDI C, #$01        ; C = 1   (00000001)
    SBC C              ; A = $80 - $01 - 1 = $7E, C=1 (no borrow)
    ; Expected: A=$7E, B=$DD, C=$01, Z=0, N=0, C=1

    ; ====================================================================
    ; TEST 18: All ones pattern with SBC_B
    ; A=$FF, B=$FF, carry=1 => A=$FF-$FF-0=$00, Z=1, N=0, C=1 (no borrow)
    ; ====================================================================
    SEC                 ; Set carry
    LDI A, #$FF        ; A = 255 (11111111)
    LDI B, #$FF        ; B = 255 (11111111)
    LDI C, #$EE        ; C = preservation test
    SBC B              ; A = $FF - $FF - 0 = $00, C=1 (no borrow)
    ; Expected: A=$00, B=$FF, C=$EE, Z=1, N=0, C=1

    ; ====================================================================
    ; TEST 19: All ones pattern with SBC_C
    ; A=$FF, C=$FF, carry=1 => A=$FF-$FF-0=$00, Z=1, N=0, C=1 (no borrow)
    ; ====================================================================
    SEC                 ; Set carry
    LDI A, #$FF        ; A = 255 (11111111)
    LDI B, #$EE        ; B = preservation test
    LDI C, #$FF        ; C = 255 (11111111)
    SBC C              ; A = $FF - $FF - 0 = $00, C=1 (no borrow)
    ; Expected: A=$00, B=$EE, C=$FF, Z=1, N=0, C=1

    ; ====================================================================
    ; TEST 20: Chain multiple SBC operations
    ; Test cascading borrow behavior: SBC_B followed by SBC_C
    ; ====================================================================
    CLC                 ; Start with clear carry
    LDI A, #$10        ; A = 16
    LDI B, #$08        ; B = 8
    LDI C, #$04        ; C = 4
    SBC B              ; A = $10 - $08 - 1 = $07, C=1
    SBC C              ; A = $07 - $04 - 0 = $03, C=1
    ; Expected: A=$03, B=$08, C=$04, Z=0, N=0, C=1

    ; ====================================================================
    ; TEST 21: Final register preservation verification
    ; Load fresh patterns and verify SBC doesn't affect uninvolved registers
    ; ====================================================================
    SEC                 ; Set carry for final test
    LDI A, #$F0        ; A = 240 (11110000)
    LDI B, #$AA        ; B = test pattern for preservation
    LDI C, #$0F        ; C = 15  (00001111)
    SBC B              ; A = $F0 - $AA - 0 = $46, C=1 (no borrow)
    ; Expected: A=$46, B=$AA, C=$0F, Z=0, N=0, C=1

    ; Load fresh patterns for SBC_C preservation test
    SEC                 ; Set carry
    LDI A, #$E0        ; A = 224 (11100000)
    LDI B, #$55        ; B = test pattern for preservation
    LDI C, #$1F        ; C = 31  (00011111)
    SBC C              ; A = $E0 - $1F - 0 = $C1, C=1 (no borrow)
    ; Expected: A=$C1, B=$55, C=$1F, Z=0, N=1, C=1

    HLT                ; Stop execution