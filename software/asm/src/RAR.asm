; RAR.asm - Comprehensive test suite for RAR (Rotate A Right through Carry) instruction
; Tests edge cases, bit patterns, flag behavior, and register preservation
; RAR: Rotate A Right through Carry - Carry becomes bit 7, bit 0 becomes new Carry
; Flags: Z=+/- (set based on result), N=+/- (set based on result), C== (from bit 0)

INCLUDE "includes/mmio_defs.inc"

; ======================================================================
; == PROGRAM: RAR Comprehensive Test Suite
; ======================================================================
    ORG $F000

START:
    ; =================================================================
    ; TEST 1: Basic rotation with carry clear
    ; Input: A = $F0 (%11110000), C = 0
    ; Expected: A = $78 (%01111000), C = 0 (from LSB), Z = 0, N = 0
    ; =================================================================
    CLC                 ; Clear carry flag first
    LDI A, #%11110000   ; Load A with $F0
    RAR                 ; Rotate right: C=0, A=$F0 -> A=$78, C=0
    
    ; =================================================================
    ; TEST 2: Basic rotation with carry set
    ; Input: A = $0F (%00001111), C = 1  
    ; Expected: A = $87 (%10000111), C = 1 (from LSB), Z = 0, N = 1
    ; =================================================================
    SEC                 ; Set carry flag
    LDI A, #%00001111   ; Load A with $0F
    RAR                 ; Rotate right: C=1, A=$0F -> A=$87, C=1
    
    ; =================================================================
    ; TEST 3: Rotation resulting in zero
    ; Input: A = $00 (%00000000), C = 0
    ; Expected: A = $00 (%00000000), C = 0 (from LSB), Z = 1, N = 0
    ; =================================================================
    CLC                 ; Clear carry flag
    LDI A, #%00000000   ; Load A with $00
    RAR                 ; Rotate right: C=0, A=$00 -> A=$00, C=0
    
    ; =================================================================
    ; TEST 4: Rotation with carry into MSB making negative
    ; Input: A = $00 (%00000000), C = 1
    ; Expected: A = $80 (%10000000), C = 0 (from LSB), Z = 0, N = 1
    ; =================================================================
    SEC                 ; Set carry flag
    LDI A, #%00000000   ; Load A with $00
    RAR                 ; Rotate right: C=1, A=$00 -> A=$80, C=0
    
    ; =================================================================
    ; TEST 5: All ones pattern with carry clear
    ; Input: A = $FF (%11111111), C = 0
    ; Expected: A = $7F (%01111111), C = 1 (from LSB), Z = 0, N = 0
    ; =================================================================
    CLC                 ; Clear carry flag
    LDI A, #%11111111   ; Load A with $FF
    RAR                 ; Rotate right: C=0, A=$FF -> A=$7F, C=1
    
    ; =================================================================
    ; TEST 6: All ones pattern with carry set
    ; Input: A = $FF (%11111111), C = 1
    ; Expected: A = $FF (%11111111), C = 1 (from LSB), Z = 0, N = 1
    ; =================================================================
    SEC                 ; Set carry flag
    LDI A, #%11111111   ; Load A with $FF
    RAR                 ; Rotate right: C=1, A=$FF -> A=$FF, C=1
    
    ; =================================================================
    ; TEST 7: Single bit LSB test (bit 0 -> carry)
    ; Input: A = $01 (%00000001), C = 0
    ; Expected: A = $00 (%00000000), C = 1 (from LSB), Z = 1, N = 0
    ; =================================================================
    CLC                 ; Clear carry flag
    LDI A, #%00000001   ; Load A with $01
    RAR                 ; Rotate right: C=0, A=$01 -> A=$00, C=1
    
    ; =================================================================
    ; TEST 8: Single bit MSB test with carry propagation
    ; Input: A = $80 (%10000000), C = 0
    ; Expected: A = $40 (%01000000), C = 0 (from LSB), Z = 0, N = 0
    ; =================================================================
    CLC                 ; Clear carry flag
    LDI A, #%10000000   ; Load A with $80
    RAR                 ; Rotate right: C=0, A=$80 -> A=$40, C=0
    
    ; =================================================================
    ; TEST 9: Alternating pattern test 1
    ; Input: A = $55 (%01010101), C = 0
    ; Expected: A = $2A (%00101010), C = 1 (from LSB), Z = 0, N = 0
    ; =================================================================
    CLC                 ; Clear carry flag
    LDI A, #%01010101   ; Load A with $55
    RAR                 ; Rotate right: C=0, A=$55 -> A=$2A, C=1
    
    ; =================================================================
    ; TEST 10: Alternating pattern test 2
    ; Input: A = $AA (%10101010), C = 1
    ; Expected: A = $D5 (%11010101), C = 0 (from LSB), Z = 0, N = 1
    ; =================================================================
    SEC                 ; Set carry flag
    LDI A, #%10101010   ; Load A with $AA
    RAR                 ; Rotate right: C=1, A=$AA -> A=$D5, C=0
    
    ; =================================================================
    ; TEST 11: Sequential rotation test (multiple RAR operations)
    ; Starting: A = $C3 (%11000011), C = 0
    ; After 1st RAR: A = $61 (%01100001), C = 1
    ; After 2nd RAR: A = $B0 (%10110000), C = 1  
    ; =================================================================
    CLC                 ; Clear carry flag
    LDI A, #%11000011   ; Load A with $C3
    RAR                 ; 1st rotation: C=0, A=$C3 -> A=$61, C=1
    RAR                 ; 2nd rotation: C=1, A=$61 -> A=$B0, C=1
    
    ; =================================================================
    ; TEST 12: Register preservation test
    ; Load B and C with test values, verify they're unchanged after RAR
    ; =================================================================
    LDI B, #$BB         ; Load B with $BB for preservation test
    LDI C, #$CC         ; Load C with $CC for preservation test
    CLC                 ; Clear carry flag
    LDI A, #$42         ; Load A with $42
    RAR                 ; Rotate A: C=0, A=$42 -> A=$21, C=0
    ; B and C should still be $BB and $CC respectively
    
    ; =================================================================
    ; TEST 13: Boundary case - carry cycling test
    ; Rotate through all 8 bits plus carry (9 total positions)
    ; Starting: A = $01, C = 0
    ; =================================================================
    CLC                 ; Clear carry
    LDI A, #$01         ; Start with bit 0 set
    RAR                 ; Pos 1: A=$00, C=1 (bit moved to carry)
    RAR                 ; Pos 2: A=$80, C=0 (carry moved to bit 7)
    RAR                 ; Pos 3: A=$40, C=0
    RAR                 ; Pos 4: A=$20, C=0
    RAR                 ; Pos 5: A=$10, C=0
    RAR                 ; Pos 6: A=$08, C=0
    RAR                 ; Pos 7: A=$04, C=0
    RAR                 ; Pos 8: A=$02, C=0
    RAR                 ; Pos 9: A=$01, C=0 (back to original)
    
    ; =================================================================
    ; TEST 14: Edge case - maximum value transitions
    ; Input: A = $FE (%11111110), C = 1
    ; Expected: A = $FF (%11111111), C = 0, Z = 0, N = 1
    ; =================================================================
    SEC                 ; Set carry flag
    LDI A, #%11111110   ; Load A with $FE
    RAR                 ; Rotate right: C=1, A=$FE -> A=$FF, C=0
    
    ; =================================================================
    ; TEST 15: Final comprehensive test - complex bit pattern
    ; Input: A = $69 (%01101001), C = 1
    ; Expected: A = $B4 (%10110100), C = 1, Z = 0, N = 1
    ; =================================================================
    SEC                 ; Set carry flag
    LDI A, #%01101001   ; Load A with $69
    RAR                 ; Rotate right: C=1, A=$69 -> A=$B4, C=1
    
    HLT                 ; End test suite