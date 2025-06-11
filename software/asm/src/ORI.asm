; ORI (OR A with Immediate) - Comprehensive Test Suite
; Tests the ORI instruction: A = A | immediate
; Opcode: $36, 2-byte instruction
; Flags: Z=+/- (result), N=+/- (result), C=0 (always cleared)

        org $F000

; ==============================================================================
; TEST 1: Basic OR operation - A=$00 | #$FF = $FF
; Expected: A=$FF, Z=0, N=1, C=0
; ==============================================================================
test_1:
        LDI A, #$00         ; Load A with $00
        LDI B, #$FF         ; Load B with $FF (for preservation test)  
        LDI C, #$CC         ; Load C with $CC (for preservation test)
        ORI #$FF            ; A = A | $FF = $00 | $FF = $FF

; ==============================================================================
; TEST 2: Basic OR operation - A=$FF | #$00 = $FF  
; Expected: A=$FF, Z=0, N=1, C=0
; ==============================================================================
test_2:
        LDI A, #$FF         ; Load A with $FF
        LDI B, #$00         ; Load B with $00
        ORI #$00            ; A = A | $00 = $FF | $00 = $FF

; ==============================================================================
; TEST 3: OR operation resulting in zero - A=$00 | #$00 = $00
; Expected: A=$00, Z=1, N=0, C=0
; ==============================================================================
test_3:
        LDI A, #$00         ; Load A with $00
        LDI B, #$00         ; Load B with $00
        ORI #$00            ; A = A | $00 = $00 | $00 = $00

; ==============================================================================
; TEST 4: Alternating pattern 1 - A=$55 | #$AA = $FF
; Expected: A=$FF, Z=0, N=1, C=0
; ==============================================================================
test_4:
        LDI A, #$55         ; Load A with $55 (01010101)
        LDI B, #$AA         ; Load B with $AA (for preservation)
        ORI #$AA            ; A = A | $AA = $55 | $AA = $FF

; ==============================================================================
; TEST 5: Alternating pattern 2 - A=$AA | #$55 = $FF
; Expected: A=$FF, Z=0, N=1, C=0
; ==============================================================================
test_5:
        LDI A, #$AA         ; Load A with $AA (10101010)
        LDI B, #$55         ; Load B with $55 (for preservation)
        ORI #$55            ; A = A | $55 = $AA | $55 = $FF

; ==============================================================================
; TEST 6: Partial overlap - A=$0F | #$F0 = $FF
; Expected: A=$FF, Z=0, N=1, C=0
; ==============================================================================
test_6:
        LDI A, #$0F         ; Load A with $0F (00001111)
        LDI B, #$F0         ; Load B with $F0 (for preservation)
        ORI #$F0            ; A = A | $F0 = $0F | $F0 = $FF

; ==============================================================================
; TEST 7: Single bit operations - A=$01 | #$80 = $81
; Expected: A=$81, Z=0, N=1, C=0
; ==============================================================================
test_7:
        LDI A, #$01         ; Load A with $01 (00000001)
        LDI B, #$80         ; Load B with $80 (for preservation)
        ORI #$80            ; A = A | $80 = $01 | $80 = $81

; ==============================================================================
; TEST 8: Same value OR - A=$42 | #$42 = $42
; Expected: A=$42, Z=0, N=0, C=0
; ==============================================================================
test_8:
        LDI A, #$42         ; Load A with $42 (01000010)
        LDI B, #$42         ; Load B with $42 (for preservation)
        ORI #$42            ; A = A | $42 = $42 | $42 = $42

; ==============================================================================
; TEST 9: Mixed sign bits - A=$C0 | #$30 = $F0
; Expected: A=$F0, Z=0, N=1, C=0
; ==============================================================================
test_9:
        LDI A, #$C0         ; Load A with $C0 (11000000)
        LDI B, #$30         ; Load B with $30 (for preservation)
        ORI #$30            ; A = A | $30 = $C0 | $30 = $F0

; ==============================================================================
; TEST 10: Carry flag clearing test - set carry, then OR
; Expected: A=$7F, Z=0, N=0, C=0 (carry cleared by ORI)
; ==============================================================================
test_10:
        SEC                 ; Set carry flag
        LDI A, #$3F         ; Load A with $3F (00111111)
        LDI B, #$40         ; Load B with $40 (for preservation)
        ORI #$40            ; A = A | $40 = $3F | $40 = $7F, C cleared

; ==============================================================================
; TEST 11: All zeros except LSB - A=$01 | #$00 = $01
; Expected: A=$01, Z=0, N=0, C=0
; ==============================================================================
test_11:
        LDI A, #$01         ; Load A with $01 (00000001)
        LDI B, #$00         ; Load B with $00 (for preservation)
        ORI #$00            ; A = A | $00 = $01 | $00 = $01

; ==============================================================================
; TEST 12: All zeros except MSB - A=$80 | #$00 = $80
; Expected: A=$80, Z=0, N=1, C=0
; ==============================================================================
test_12:
        LDI A, #$80         ; Load A with $80 (10000000)
        LDI B, #$00         ; Load B with $00 (for preservation)
        ORI #$00            ; A = A | $00 = $80 | $00 = $80

; ==============================================================================
; TEST 13: Complex bit pattern - A=$69 | #$96 = $FF
; Expected: A=$FF, Z=0, N=1, C=0
; ==============================================================================
test_13:
        LDI A, #$69         ; Load A with $69 (01101001)
        LDI B, #$96         ; Load B with $96 (for preservation)
        ORI #$96            ; A = A | $96 = $69 | $96 = $FF

; ==============================================================================
; TEST 14: Subset pattern - A=$0C | #$03 = $0F
; Expected: A=$0F, Z=0, N=0, C=0
; ==============================================================================
test_14:
        LDI A, #$0C         ; Load A with $0C (00001100)
        LDI B, #$03         ; Load B with $03 (for preservation)
        ORI #$03            ; A = A | $03 = $0C | $03 = $0F

; ==============================================================================
; TEST 15: Edge case - maximum positive | minimum positive = $7F
; Expected: A=$7F, Z=0, N=0, C=0
; ==============================================================================
test_15:
        LDI A, #$7F         ; Load A with $7F (01111111)
        LDI B, #$01         ; Load B with $01 (for preservation)
        ORI #$01            ; A = A | $01 = $7F | $01 = $7F

; ==============================================================================
; TEST 16: Register preservation test - A=$3C | #$5A = $7E
; Expected: B=$5A, C=$A5 preserved, A=$7E
; ==============================================================================
test_16:
        LDI A, #$3C         ; Load A with $3C (00111100)
        LDI B, #$5A         ; Load B with $5A (01011010)
        LDI C, #$A5         ; Load C with $A5 (10100101)
        ORI #$5A            ; A = A | $5A = $3C | $5A = $7E

; ==============================================================================
; TEST 17: All bits set except one - A=$FE | #$01 = $FF
; Expected: A=$FF, Z=0, N=1, C=0
; ==============================================================================
test_17:
        LDI A, #$FE         ; Load A with $FE (11111110)
        LDI B, #$01         ; Load B with $01 (for preservation)
        ORI #$01            ; A = A | $01 = $FE | $01 = $FF

; ==============================================================================
; TEST 18: Sequential OR operations to verify no side effects
; A=$01 -> A=$03 -> A=$07 -> A=$0F
; ==============================================================================
test_18:
        LDI A, #$01         ; Load A with $01
        LDI B, #$02         ; Load B with $02
        ORI #$02            ; A = A | $02 = $01 | $02 = $03
        
        LDI B, #$04         ; Load B with $04  
        ORI #$04            ; A = A | $04 = $03 | $04 = $07
        
        LDI B, #$08         ; Load B with $08
        ORI #$08            ; A = A | $08 = $07 | $08 = $0F

; ==============================================================================
; TEST 19: Boundary value testing - A=$7F | #$80 = $FF
; Expected: A=$FF, Z=0, N=1, C=0
; ==============================================================================
test_19:
        LDI A, #$7F         ; Load A with $7F (01111111)
        LDI B, #$80         ; Load B with $80 (for preservation)
        ORI #$80            ; A = A | $80 = $7F | $80 = $FF

; ==============================================================================
; TEST 20: Final flag state verification - SEC then A=$00 | #$00 = $00
; Expected: A=$00, Z=1, N=0, C=0 (carry cleared even when set before)
; ==============================================================================
test_20:
        SEC                 ; Set carry flag  
        LDI A, #$00         ; Load A with $00 (00000000)
        LDI B, #$00         ; Load B with $00 (for preservation)
        ORI #$00            ; A = A | $00 = $00 | $00 = $00, C cleared

; ==============================================================================
; End of test - HALT
; ==============================================================================
        HLT                 ; Stop execution