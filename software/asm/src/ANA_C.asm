; ANA_C.asm
; Comprehensive test for ANA C instruction (A = A & C)
; Tests AND operation with various bit patterns and edge cases

INCLUDE "includes/mmio_defs.inc"

; ======================================================================
; == PROGRAM
; ======================================================================
    ORG $F000


START:
    ; Test 1: Basic AND operation with mixed bits
    LDI A, #$E1         ; A = 1110 0001
    LDI C, #$FE         ; C = 1111 1110
    ADD C               ; A = A + C = $DF (with carry) - sets up complex bit pattern
    ANA C               ; A = A & C = $DF & $FE = $DE (1101 1110)
    
    ; Test 2: AND with zero (should zero out result)
    LDI C, #$00         ; C = 0000 0000
    ANA C               ; A = A & C = $DE & $00 = $00 (zero result, Z flag set)
    
    ; Test 3: AND with all ones (should preserve A)
    LDI A, #$AA         ; A = 1010 1010 (alternating pattern)
    LDI C, #$FF         ; C = 1111 1111 (all ones)
    ANA C               ; A = A & C = $AA & $FF = $AA (A preserved)
    
    ; Test 4: AND with same value (idempotent operation)
    LDI C, #$AA         ; C = 1010 1010 (same as A)
    ANA C               ; A = A & C = $AA & $AA = $AA (unchanged)
    
    ; Test 5: AND with complement pattern
    LDI C, #$55         ; C = 0101 0101 (complement of A)
    ANA C               ; A = A & C = $AA & $55 = $00 (zero result)
    
    ; Test 6: Test negative flag with high bit set
    LDI A, #$80         ; A = 1000 0000 (minimum negative in 2's complement)
    LDI C, #$FF         ; C = 1111 1111
    ANA C               ; A = A & C = $80 & $FF = $80 (negative flag set)
    
    ; Test 7: Test boundary case - clear high bit
    LDI C, #$7F         ; C = 0111 1111 (mask to clear bit 7)
    ANA C               ; A = A & C = $80 & $7F = $00 (clears negative)
    
    ; Test 8: Pattern isolation test
    LDI A, #$F0         ; A = 1111 0000 (upper nibble set)
    LDI C, #$0F         ; C = 0000 1111 (lower nibble set)
    ANA C               ; A = A & C = $F0 & $0F = $00 (no overlap)
    
    ; Test 9: Single bit isolation
    LDI A, #$FF         ; A = 1111 1111 (all bits set)
    LDI C, #$01         ; C = 0000 0001 (only bit 0 set)
    ANA C               ; A = A & C = $FF & $01 = $01 (isolate bit 0)
    
    ; Test 10: Final verification - preserve register B
    LDI B, #$42         ; B = 0100 0010 (test value)
    LDI A, #$3C         ; A = 0011 1100
    LDI C, #$C3         ; C = 1100 0011
    ANA C               ; A = A & C = $3C & $C3 = $00 (B should be unchanged)
    
    HLT