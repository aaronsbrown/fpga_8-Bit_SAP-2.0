; RAL.asm - Comprehensive test suite for RAL (Rotate A Left through Carry) instruction
; Tests edge cases, bit patterns, flag behavior, and register preservation
; RAL: Rotate A Left through Carry - bit 7 becomes new Carry, Carry becomes bit 0
; Flags: Z=+/- (set based on result), N=+/- (set based on result), C== (from bit 7)

INCLUDE "../../programs/includes/mmio_defs.inc"

; ======================================================================
; == PROGRAM: RAL Comprehensive Test Suite
; ======================================================================
    ORG $F000

START:
    ; =================================================================
    ; TEST 1: Basic rotation with carry clear
    ; Input: A = $0F (%00001111), C = 0
    ; Expected: A = $1E (%00011110), C = 0 (from MSB), Z = 0, N = 0
    ; =================================================================
    CLC                 ; Clear carry flag first
    LDI A, #%00001111   ; Load A with $0F
    RAL                 ; Rotate left: C=0, A=$0F -> A=$1E, C=0
    
    ; =================================================================
    ; TEST 2: Basic rotation with carry set
    ; Input: A = $F0 (%11110000), C = 1  
    ; Expected: A = $E1 (%11100001), C = 1 (from MSB), Z = 0, N = 1
    ; =================================================================
    SEC                 ; Set carry flag
    LDI A, #%11110000   ; Load A with $F0
    RAL                 ; Rotate left: C=1, A=$F0 -> A=$E1, C=1
    
    ; =================================================================
    ; TEST 3: Rotation resulting in zero
    ; Input: A = $00 (%00000000), C = 0
    ; Expected: A = $00 (%00000000), C = 0 (from MSB), Z = 1, N = 0
    ; =================================================================
    CLC                 ; Clear carry flag
    LDI A, #%00000000   ; Load A with $00
    RAL                 ; Rotate left: C=0, A=$00 -> A=$00, C=0
    
    ; =================================================================
    ; TEST 4: Rotation with carry into LSB  
    ; Input: A = $00 (%00000000), C = 1
    ; Expected: A = $01 (%00000001), C = 0 (from MSB), Z = 0, N = 0
    ; =================================================================
    SEC                 ; Set carry flag
    LDI A, #%00000000   ; Load A with $00
    RAL                 ; Rotate left: C=1, A=$00 -> A=$01, C=0
    
    ; =================================================================
    ; TEST 5: All ones pattern with carry clear
    ; Input: A = $FF (%11111111), C = 0
    ; Expected: A = $FE (%11111110), C = 1 (from MSB), Z = 0, N = 1
    ; =================================================================
    CLC                 ; Clear carry flag
    LDI A, #%11111111   ; Load A with $FF
    RAL                 ; Rotate left: C=0, A=$FF -> A=$FE, C=1
    
    ; =================================================================
    ; TEST 6: All ones pattern with carry set
    ; Input: A = $FF (%11111111), C = 1
    ; Expected: A = $FF (%11111111), C = 1 (from MSB), Z = 0, N = 1
    ; =================================================================
    SEC                 ; Set carry flag
    LDI A, #%11111111   ; Load A with $FF
    RAL                 ; Rotate left: C=1, A=$FF -> A=$FF, C=1
    
    ; =================================================================
    ; TEST 7: Single bit MSB test (bit 7 -> carry)
    ; Input: A = $80 (%10000000), C = 0
    ; Expected: A = $00 (%00000000), C = 1 (from MSB), Z = 1, N = 0
    ; =================================================================
    CLC                 ; Clear carry flag
    LDI A, #%10000000   ; Load A with $80
    RAL                 ; Rotate left: C=0, A=$80 -> A=$00, C=1
    
    ; =================================================================
    ; TEST 8: Single bit LSB test with carry propagation
    ; Input: A = $01 (%00000001), C = 0
    ; Expected: A = $02 (%00000010), C = 0 (from MSB), Z = 0, N = 0
    ; =================================================================
    CLC                 ; Clear carry flag
    LDI A, #%00000001   ; Load A with $01
    RAL                 ; Rotate left: C=0, A=$01 -> A=$02, C=0
    
    ; =================================================================
    ; TEST 9: Alternating pattern test 1
    ; Input: A = $55 (%01010101), C = 0
    ; Expected: A = $AA (%10101010), C = 0 (from MSB), Z = 0, N = 1
    ; =================================================================
    CLC                 ; Clear carry flag
    LDI A, #%01010101   ; Load A with $55
    RAL                 ; Rotate left: C=0, A=$55 -> A=$AA, C=0
    
    ; =================================================================
    ; TEST 10: Alternating pattern test 2
    ; Input: A = $AA (%10101010), C = 1
    ; Expected: A = $55 (%01010101), C = 1 (from MSB), Z = 0, N = 0
    ; =================================================================
    SEC                 ; Set carry flag
    LDI A, #%10101010   ; Load A with $AA
    RAL                 ; Rotate left: C=1, A=$AA -> A=$55, C=1
    
    ; =================================================================
    ; TEST 11: Sequential rotation test (multiple RAL operations)
    ; Starting: A = $C3 (%11000011), C = 0
    ; After 1st RAL: A = $86 (%10000110), C = 1
    ; After 2nd RAL: A = $0D (%00001101), C = 1  
    ; =================================================================
    CLC                 ; Clear carry flag
    LDI A, #%11000011   ; Load A with $C3
    RAL                 ; 1st rotation: C=0, A=$C3 -> A=$86, C=1
    RAL                 ; 2nd rotation: C=1, A=$86 -> A=$0D, C=1
    
    ; =================================================================
    ; TEST 12: Register preservation test
    ; Load B and C with test values, verify they're unchanged after RAL
    ; =================================================================
    LDI B, #$BB         ; Load B with $BB for preservation test
    LDI C, #$CC         ; Load C with $CC for preservation test
    CLC                 ; Clear carry flag
    LDI A, #$42         ; Load A with $42
    RAL                 ; Rotate A: C=0, A=$42 -> A=$84, C=0
    ; B and C should still be $BB and $CC respectively
    
    ; =================================================================
    ; TEST 13: Boundary case - carry cycling test
    ; Rotate through all 8 bits plus carry (9 total positions)
    ; Starting: A = $80, C = 0
    ; =================================================================
    CLC                 ; Clear carry
    LDI A, #$80         ; Start with bit 7 set
    RAL                 ; Pos 1: A=$00, C=1 (bit moved to carry)
    RAL                 ; Pos 2: A=$01, C=0 (carry moved to bit 0)
    RAL                 ; Pos 3: A=$02, C=0
    RAL                 ; Pos 4: A=$04, C=0
    RAL                 ; Pos 5: A=$08, C=0
    RAL                 ; Pos 6: A=$10, C=0
    RAL                 ; Pos 7: A=$20, C=0
    RAL                 ; Pos 8: A=$40, C=0
    RAL                 ; Pos 9: A=$80, C=0 (back to original)
    
    ; =================================================================
    ; TEST 14: Edge case - maximum value transitions
    ; Input: A = $7F (%01111111), C = 1
    ; Expected: A = $FF (%11111111), C = 0, Z = 0, N = 1
    ; =================================================================
    SEC                 ; Set carry flag
    LDI A, #%01111111   ; Load A with $7F
    RAL                 ; Rotate left: C=1, A=$7F -> A=$FF, C=0
    
    ; =================================================================
    ; TEST 15: Final comprehensive test - complex bit pattern
    ; Input: A = $96 (%10010110), C = 1
    ; Expected: A = $2D (%00101101), C = 1, Z = 0, N = 0
    ; =================================================================
    SEC                 ; Set carry flag
    LDI A, #%10010110   ; Load A with $96
    RAL                 ; Rotate left: C=1, A=$96 -> A=$2D, C=1
    
    HLT                 ; End test suite