; CMA.asm
; Comprehensive test for CMA instruction (Complement Accumulator)
; Tests bitwise complement operation (~A) with various bit patterns and edge cases
; Verifies Zero, Negative, and Carry flag behavior

INCLUDE "includes/mmio_defs.inc"

; ======================================================================
; == PROGRAM
; ======================================================================
    ORG $F000

START:
    ; Test 1: Basic complement with alternating pattern
    LDI A, #$AA         ; A = 1010 1010 (binary)
    SEC                 ; Set carry to verify CMA clears it
    CMA                 ; A = ~A = 0101 0101 = $55, Z=0, N=0, C=0
    
    ; Test 2: Complement result back (should restore original)
    CMA                 ; A = ~A = 1010 1010 = $AA, Z=0, N=1, C=0
    
    ; Test 3: Complement zero (should give all ones)
    LDI A, #$00         ; A = 0000 0000
    SEC                 ; Set carry to test clearing
    CMA                 ; A = ~A = 1111 1111 = $FF, Z=0, N=1, C=0
    
    ; Test 4: Complement all ones (should give zero)
    LDI A, #$FF         ; A = 1111 1111
    SEC                 ; Set carry to test clearing
    CMA                 ; A = ~A = 0000 0000 = $00, Z=1, N=0, C=0
    
    ; Test 5: Test high bit isolation (negative flag boundary)
    LDI A, #$80         ; A = 1000 0000 (high bit set)
    CLC                 ; Clear carry to verify CMA still clears it
    CMA                 ; A = ~A = 0111 1111 = $7F, Z=0, N=0, C=0
    
    ; Test 6: Test low bit isolation
    LDI A, #$01         ; A = 0000 0001 (only low bit set)
    SEC                 ; Set carry to test clearing
    CMA                 ; A = ~A = 1111 1110 = $FE, Z=0, N=1, C=0
    
    ; Test 7: Test nibble pattern (upper nibble)
    LDI A, #$F0         ; A = 1111 0000 (upper nibble set)
    CMA                 ; A = ~A = 0000 1111 = $0F, Z=0, N=0, C=0
    
    ; Test 8: Test nibble pattern (lower nibble)
    LDI A, #$0F         ; A = 0000 1111 (lower nibble set)
    CMA                 ; A = ~A = 1111 0000 = $F0, Z=0, N=1, C=0
    
    ; Test 9: Test checkerboard pattern 1
    LDI A, #$55         ; A = 0101 0101 (checkerboard)
    SEC                 ; Set carry to verify clearing
    CMA                 ; A = ~A = 1010 1010 = $AA, Z=0, N=1, C=0
    
    ; Test 10: Test middle values
    LDI A, #$3C         ; A = 0011 1100 (middle bits set)
    CMA                 ; A = ~A = 1100 0011 = $C3, Z=0, N=1, C=0
    
    ; Test 11: Single bit test (bit 6)
    LDI A, #$40         ; A = 0100 0000 (bit 6 set)
    CMA                 ; A = ~A = 1011 1111 = $BF, Z=0, N=1, C=0
    
    ; Test 12: Register preservation test - verify B and C are unchanged
    LDI B, #$42         ; Load test pattern into B
    LDI C, #$24         ; Load test pattern into C
    LDI A, #$33         ; Load test value into A
    CMA                 ; Complement A, B and C should be preserved
    
    ; Test 13: Final zero test after multiple operations
    LDI A, #$FF         ; A = 1111 1111
    CMA                 ; A = ~A = 0000 0000 = $00, Z=1, N=0, C=0
    
    ; Test 14: Final pattern for verification
    LDI A, #$E7         ; A = 1110 0111 (mixed pattern)
    CMA                 ; A = ~A = 0001 1000 = $18, Z=0, N=0, C=0
    
    HLT                 ; End of test program