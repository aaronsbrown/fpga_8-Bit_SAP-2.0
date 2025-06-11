; ANA_B.asm
; Comprehensive test for ANA B instruction (A = A & B)
; Tests AND operation with various bit patterns and edge cases

INCLUDE "includes/mmio_defs.inc"

; ======================================================================
; == PROGRAM  
; ======================================================================
    ORG $F000


START:
    ; Test 1: Basic AND operation with mixed bits
    LDI A, #$E1         ; A = 1110 0001
    LDI B, #$FE         ; B = 1111 1110
    ADD B               ; A = A + B = $DF (with carry) - sets up complex bit pattern
    ANA B               ; A = A & B = $DF & $FE = $DE (1101 1110)
    
    ; Test 2: AND with zero (should zero out result)
    LDI B, #$00         ; B = 0000 0000
    ANA B               ; A = A & B = $DE & $00 = $00 (zero result, Z flag set)
    
    ; Test 3: AND with all ones (should preserve A)
    LDI A, #$AA         ; A = 1010 1010 (alternating pattern)
    LDI B, #$FF         ; B = 1111 1111 (all ones)
    ANA B               ; A = A & B = $AA & $FF = $AA (A preserved)
    
    ; Test 4: AND with same value (idempotent operation)
    LDI B, #$AA         ; B = 1010 1010 (same as A)
    ANA B               ; A = A & B = $AA & $AA = $AA (unchanged)
    
    ; Test 5: AND with complement pattern
    LDI B, #$55         ; B = 0101 0101 (complement of A)
    ANA B               ; A = A & B = $AA & $55 = $00 (zero result)
    
    ; Test 6: Test negative flag with high bit set
    LDI A, #$80         ; A = 1000 0000 (minimum negative in 2's complement)
    LDI B, #$FF         ; B = 1111 1111
    ANA B               ; A = A & B = $80 & $FF = $80 (negative flag set)
    
    ; Test 7: Test boundary case - clear high bit
    LDI B, #$7F         ; B = 0111 1111 (mask to clear bit 7)
    ANA B               ; A = A & B = $80 & $7F = $00 (clears negative)
    
    ; Test 8: Pattern isolation test
    LDI A, #$F0         ; A = 1111 0000 (upper nibble set)
    LDI B, #$0F         ; B = 0000 1111 (lower nibble set)
    ANA B               ; A = A & B = $F0 & $0F = $00 (no overlap)
    
    ; Test 9: Single bit isolation  
    LDI A, #$FF         ; A = 1111 1111 (all bits set)
    LDI B, #$01         ; B = 0000 0001 (only bit 0 set)
    ANA B               ; A = A & B = $FF & $01 = $01 (isolate bit 0)
    
    ; Test 10: Carry flag preservation test with pre-existing carry
    SEC                 ; Set carry flag to 1 
    LDI A, #$3C         ; A = 0011 1100
    LDI B, #$C3         ; B = 1100 0011
    ANA B               ; A = A & B = $3C & $C3 = $00 (ANA should clear carry to 0)
    
    ; Test 11: Register preservation test - ensure C register is not affected
    LDI C, #$42         ; C = 0100 0010 (test value)
    LDI A, #$87         ; A = 1000 0111
    LDI B, #$78         ; B = 0111 1000
    ANA B               ; A = A & B = $87 & $78 = $00 (C should be unchanged)
    
    ; Test 12: Edge case - all zeros
    LDI A, #$00         ; A = 0000 0000
    LDI B, #$00         ; B = 0000 0000  
    ANA B               ; A = A & B = $00 & $00 = $00 (zero result)

    HLT