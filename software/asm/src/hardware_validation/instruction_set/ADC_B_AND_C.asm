; ADC_B_AND_C.asm
; Comprehensive test suite for ADC_B and ADC_C instructions
; ADC B: A = A + B + Carry (opcode $22), ADC C: A = A + C + Carry (opcode $23)
; Tests addition with carry, bit patterns, edge cases, and flag behavior
; ADC affects Z/N based on result, C=1 if carry generated
; AIDEV-NOTE: Enhanced robustness with comprehensive test cases covering all ADC scenarios

INCLUDE "../../programs/includes/mmio_defs.inc"

; ======================================================================
; == ADC_B AND ADC_C COMPREHENSIVE TEST PROGRAM
; ======================================================================
    ORG $F000

START:
    ; ====================================================================
    ; TEST GROUP 1: ADC_B Basic Operations
    ; ====================================================================
    
    ; ====================================================================
    ; TEST 1: ADC_B with carry clear (C=0, no additional addition)
    ; A=$10, B=$05, C=0 => A=$10+$05+0=$15, Z=0, N=0, C=0 (no carry)
    ; ====================================================================
    CLC                 ; Clear carry (C=0, so no extra +1)
    LDI A, #$10        ; A = 16 (00010000)
    LDI B, #$05        ; B = 5  (00000101)
    LDI C, #$AA        ; C = preservation test pattern
    ADC B              ; A = $10 + $05 + 0 = $15, C=0 (no carry)
    ; Expected: A=$15, B=$05, C=$AA, Z=0, N=0, C=0

    ; ====================================================================
    ; TEST 2: ADC_B with carry set (C=1, adds additional 1)
    ; A=$10, B=$05, C=1 => A=$10+$05+1=$16, Z=0, N=0, C=0 (no carry)
    ; ====================================================================
    SEC                 ; Set carry (C=1, so extra +1)
    LDI A, #$10        ; A = 16 (00010000)
    LDI B, #$05        ; B = 5  (00000101)
    ADC B              ; A = $10 + $05 + 1 = $16, C=0 (no carry)
    ; Expected: A=$16, B=$05, C=$AA, Z=0, N=0, C=0

    ; ====================================================================
    ; TEST 3: ADC_B resulting in zero with carry clear
    ; A=$00, B=$00, C=0 => A=$00+$00+0=$00, Z=1, N=0, C=0 (no carry)
    ; ====================================================================
    CLC                 ; Clear carry
    LDI A, #$00        ; A = 0   (00000000)
    LDI B, #$00        ; B = 0   (00000000)
    ADC B              ; A = $00 + $00 + 0 = $00, C=0 (no carry)
    ; Expected: A=$00, B=$00, C=$AA, Z=1, N=0, C=0

    ; ====================================================================
    ; TEST 4: ADC_B with carry producing overflow/wrap
    ; A=$FF, B=$01, C=0 => A=$FF+$01+0=$00, Z=1, N=0, C=1 (carry generated)
    ; ====================================================================
    CLC                 ; Clear carry
    LDI A, #$FF        ; A = 255 (11111111)
    LDI B, #$01        ; B = 1   (00000001)
    ADC B              ; A = $FF + $01 + 0 = $00, C=1 (carry generated)
    ; Expected: A=$00, B=$01, C=$AA, Z=1, N=0, C=1

    ; ====================================================================
    ; TEST 5: ADC_B with carry set causing overflow
    ; A=$FF, B=$00, C=1 => A=$FF+$00+1=$00, Z=1, N=0, C=1 (carry generated)
    ; ====================================================================
    SEC                 ; Set carry
    LDI A, #$FF        ; A = 255 (11111111)
    LDI B, #$00        ; B = 0   (00000000)
    ADC B              ; A = $FF + $00 + 1 = $00, C=1 (carry generated)
    ; Expected: A=$00, B=$00, C=$AA, Z=1, N=0, C=1

    ; ====================================================================
    ; TEST 6: ADC_B producing negative result
    ; A=$80, B=$7F, C=0 => A=$80+$7F+0=$FF, Z=0, N=1, C=0 (no carry)
    ; ====================================================================
    CLC                 ; Clear carry
    LDI A, #$80        ; A = 128 (10000000)
    LDI B, #$7F        ; B = 127 (01111111)
    ADC B              ; A = $80 + $7F + 0 = $FF, C=0 (no carry)
    ; Expected: A=$FF, B=$7F, C=$AA, Z=0, N=1, C=0

    ; ====================================================================
    ; TEST 7: ADC_B with alternating patterns and carry clear
    ; A=$55, B=$AA, C=0 => A=$55+$AA+0=$FF, Z=0, N=1, C=0 (no carry)
    ; ====================================================================
    CLC                 ; Clear carry
    LDI A, #$55        ; A = 85  (01010101)
    LDI B, #$AA        ; B = 170 (10101010)
    ADC B              ; A = $55 + $AA + 0 = $FF, C=0 (no carry)
    ; Expected: A=$FF, B=$AA, C=$AA, Z=0, N=1, C=0

    ; ====================================================================
    ; TEST 8: ADC_B with alternating patterns and carry set
    ; A=$55, B=$AA, C=1 => A=$55+$AA+1=$00, Z=1, N=0, C=1 (carry generated)
    ; ====================================================================
    SEC                 ; Set carry
    LDI A, #$55        ; A = 85  (01010101)
    LDI B, #$AA        ; B = 170 (10101010)
    ADC B              ; A = $55 + $AA + 1 = $00, C=1 (carry generated)
    ; Expected: A=$00, B=$AA, C=$AA, Z=1, N=0, C=1

    ; ====================================================================
    ; TEST GROUP 2: ADC_C Basic Operations
    ; ====================================================================

    ; ====================================================================
    ; TEST 9: ADC_C with carry clear (C=0, no additional addition)
    ; A=$20, B=$BB, C=$08, carry=0 => A=$20+$08+0=$28, Z=0, N=0, C=0 (no carry)
    ; ====================================================================
    CLC                 ; Clear carry
    LDI A, #$20        ; A = 32  (00100000)
    LDI B, #$BB        ; B = preservation test pattern
    LDI C, #$08        ; C = 8   (00001000)
    ADC C              ; A = $20 + $08 + 0 = $28, C=0 (no carry)
    ; Expected: A=$28, B=$BB, C=$08, Z=0, N=0, C=0

    ; ====================================================================
    ; TEST 10: ADC_C with carry set (C=1, adds additional 1)
    ; A=$20, B=$BB, C=$08, carry=1 => A=$20+$08+1=$29, Z=0, N=0, C=0 (no carry)
    ; ====================================================================
    SEC                 ; Set carry
    LDI A, #$20        ; A = 32  (00100000)
    LDI B, #$BB        ; B = preservation test pattern
    LDI C, #$08        ; C = 8   (00001000)
    ADC C              ; A = $20 + $08 + 1 = $29, C=0 (no carry)
    ; Expected: A=$29, B=$BB, C=$08, Z=0, N=0, C=0

    ; ====================================================================
    ; TEST 11: ADC_C resulting in zero with carry clear
    ; A=$00, B=$BB, C=$00, carry=0 => A=$00+$00+0=$00, Z=1, N=0, C=0 (no carry)
    ; ====================================================================
    CLC                 ; Clear carry
    LDI A, #$00        ; A = 0   (00000000)
    LDI B, #$BB        ; B = preservation test pattern
    LDI C, #$00        ; C = 0   (00000000)
    ADC C              ; A = $00 + $00 + 0 = $00, C=0 (no carry)
    ; Expected: A=$00, B=$BB, C=$00, Z=1, N=0, C=0

    ; ====================================================================
    ; TEST 12: ADC_C with carry producing overflow
    ; A=$FE, B=$BB, C=$01, carry=1 => A=$FE+$01+1=$00, Z=1, N=0, C=1 (carry generated)
    ; ====================================================================
    SEC                 ; Set carry
    LDI A, #$FE        ; A = 254 (11111110)
    LDI B, #$BB        ; B = preservation test pattern
    LDI C, #$01        ; C = 1   (00000001)
    ADC C              ; A = $FE + $01 + 1 = $00, C=1 (carry generated)
    ; Expected: A=$00, B=$BB, C=$01, Z=1, N=0, C=1

    ; ====================================================================
    ; TEST 13: ADC_C producing negative result
    ; A=$70, B=$BB, C=$70, carry=0 => A=$70+$70+0=$E0, Z=0, N=1, C=0 (no carry)
    ; ====================================================================
    CLC                 ; Clear carry
    LDI A, #$70        ; A = 112 (01110000)
    LDI B, #$BB        ; B = preservation test pattern
    LDI C, #$70        ; C = 112 (01110000)
    ADC C              ; A = $70 + $70 + 0 = $E0, C=0 (no carry)
    ; Expected: A=$E0, B=$BB, C=$70, Z=0, N=1, C=0

    ; ====================================================================
    ; TEST 14: ADC_C with complex bit patterns
    ; A=$B7, B=$BB, C=$29, carry=0 => A=$B7+$29+0=$E0, Z=0, N=1, C=0 (no carry)
    ; ====================================================================
    CLC                 ; Clear carry
    LDI A, #$B7        ; A = 183 (10110111)
    LDI B, #$BB        ; B = preservation test pattern
    LDI C, #$29        ; C = 41  (00101001)
    ADC C              ; A = $B7 + $29 + 0 = $E0, C=0 (no carry)
    ; Expected: A=$E0, B=$BB, C=$29, Z=0, N=1, C=0

    ; ====================================================================
    ; TEST 15: ADC_C with complex bit patterns and carry set
    ; A=$B7, B=$BB, C=$29, carry=1 => A=$B7+$29+1=$E1, Z=0, N=1, C=0 (no carry)
    ; ====================================================================
    SEC                 ; Set carry
    LDI A, #$B7        ; A = 183 (10110111)
    LDI B, #$BB        ; B = preservation test pattern
    LDI C, #$29        ; C = 41  (00101001)
    ADC C              ; A = $B7 + $29 + 1 = $E1, C=0 (no carry)
    ; Expected: A=$E1, B=$BB, C=$29, Z=0, N=1, C=0

    ; ====================================================================
    ; TEST GROUP 3: Edge Cases and Boundary Conditions
    ; ====================================================================

    ; ====================================================================
    ; TEST 16: ADC_B single bit operations
    ; A=$01, B=$01, carry=0 => A=$01+$01+0=$02, Z=0, N=0, C=0 (no carry)
    ; ====================================================================
    CLC                 ; Clear carry
    LDI A, #$01        ; A = 1   (00000001)
    LDI B, #$01        ; B = 1   (00000001)
    LDI C, #$CC        ; C = preservation test
    ADC B              ; A = $01 + $01 + 0 = $02, C=0 (no carry)
    ; Expected: A=$02, B=$01, C=$CC, Z=0, N=0, C=0

    ; ====================================================================
    ; TEST 17: ADC_C MSB operations with carry propagation
    ; A=$80, C=$80, carry=1 => A=$80+$80+1=$01, Z=0, N=0, C=1 (carry generated)
    ; ====================================================================
    SEC                 ; Set carry
    LDI A, #$80        ; A = 128 (10000000)
    LDI B, #$DD        ; B = preservation test
    LDI C, #$80        ; C = 128 (10000000)
    ADC C              ; A = $80 + $80 + 1 = $01, C=1 (carry generated)
    ; Expected: A=$01, B=$DD, C=$80, Z=0, N=0, C=1

    ; ====================================================================
    ; TEST 18: All ones pattern with ADC_B
    ; A=$FF, B=$00, carry=0 => A=$FF+$00+0=$FF, Z=0, N=1, C=0 (no carry)
    ; ====================================================================
    CLC                 ; Clear carry
    LDI A, #$FF        ; A = 255 (11111111)
    LDI B, #$00        ; B = 0   (00000000)
    LDI C, #$EE        ; C = preservation test
    ADC B              ; A = $FF + $00 + 0 = $FF, C=0 (no carry)
    ; Expected: A=$FF, B=$00, C=$EE, Z=0, N=1, C=0

    ; ====================================================================
    ; TEST 19: All ones pattern with ADC_C and carry set
    ; A=$FE, C=$00, carry=1 => A=$FE+$00+1=$FF, Z=0, N=1, C=0 (no carry)
    ; ====================================================================
    SEC                 ; Set carry
    LDI A, #$FE        ; A = 254 (11111110)
    LDI B, #$EE        ; B = preservation test
    LDI C, #$00        ; C = 0   (00000000)
    ADC C              ; A = $FE + $00 + 1 = $FF, C=0 (no carry)
    ; Expected: A=$FF, B=$EE, C=$00, Z=0, N=1, C=0

    ; ====================================================================
    ; TEST 20: Chain multiple ADC operations
    ; Test cascading carry behavior: ADC_B followed by ADC_C
    ; ====================================================================
    CLC                 ; Start with clear carry
    LDI A, #$FE        ; A = 254
    LDI B, #$01        ; B = 1
    LDI C, #$01        ; C = 1
    ADC B              ; A = $FE + $01 + 0 = $FF, C=0
    ADC C              ; A = $FF + $01 + 0 = $00, C=1
    ; Expected: A=$00, B=$01, C=$01, Z=1, N=0, C=1

    ; ====================================================================
    ; TEST 21: Final register preservation verification
    ; Load fresh patterns and verify ADC doesn't affect uninvolved registers
    ; ====================================================================
    SEC                 ; Set carry for final test
    LDI A, #$0F        ; A = 15  (00001111)
    LDI B, #$AA        ; B = test pattern for preservation
    LDI C, #$F0        ; C = 240 (11110000)
    ADC B              ; A = $0F + $AA + 1 = $BA, C=0 (no carry)
    ; Expected: A=$BA, B=$AA, C=$F0, Z=0, N=1, C=0

    ; Load fresh patterns for ADC_C preservation test
    SEC                 ; Set carry
    LDI A, #$30        ; A = 48  (00110000)
    LDI B, #$55        ; B = test pattern for preservation
    LDI C, #$0C        ; C = 12  (00001100)
    ADC C              ; A = $30 + $0C + 1 = $3D, C=0 (no carry)
    ; Expected: A=$3D, B=$55, C=$0C, Z=0, N=0, C=0

    HLT                ; Stop execution