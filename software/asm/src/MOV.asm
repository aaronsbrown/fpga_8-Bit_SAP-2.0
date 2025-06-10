; MOV.asm
; Comprehensive test for all MOV register-to-register instructions
; Tests edge cases, bit patterns, and flag preservation

INCLUDE "includes/mmio_defs.inc"

; ======================================================================
; == PROGRAM
; ======================================================================
    ORG $F000

START:
    ; ==================== TEST SECTION 1: Basic MOV Operations ====================
    ; Test all six MOV instructions with basic values
    
    ; Initialize registers with distinct values
    LDI A, $AA      ; A = 0xAA (10101010) - alternating pattern
    LDI B, $55      ; B = 0x55 (01010101) - inverse alternating pattern  
    LDI C, $FF      ; C = 0xFF (11111111) - all ones
    
    ; Test MOV A,B: B should become 0xAA
    MOV A, B        ; B = A = 0xAA
    
    ; Test MOV A,C: C should become 0xAA  
    MOV A, C        ; C = A = 0xAA
    
    ; Reload C with different value for next test
    LDI C, $33      ; C = 0x33 (00110011)
    
    ; Test MOV B,A: A should become 0xAA (B was set to 0xAA above)
    MOV B, A        ; A = B = 0xAA
    
    ; Test MOV B,C: C should become 0xAA
    MOV B, C        ; C = B = 0xAA
    
    ; Reload B with different value for next test
    LDI B, $77      ; B = 0x77 (01110111)
    
    ; Test MOV C,A: A should become 0xAA (C was set to 0xAA above)
    MOV C, A        ; A = C = 0xAA
    
    ; Test MOV C,B: B should become 0xAA
    MOV C, B        ; B = C = 0xAA

    ; ==================== TEST SECTION 2: Edge Case Values ====================
    ; Test with boundary values: 0x00, 0xFF, 0x80 (sign bit), 0x01, 0x7F
    
    ; Test with zero values
    LDI A, $00      ; A = 0x00 (all zeros)
    LDI B, $FF      ; B = 0xFF  
    MOV A, B        ; B = A = 0x00 (zero transfer)
    
    ; Test with 0xFF (all ones)  
    LDI A, $FF      ; A = 0xFF (all ones)
    LDI C, $00      ; C = 0x00
    MOV A, C        ; C = A = 0xFF (all ones transfer)
    
    ; Test with 0x80 (sign bit set, largest negative in signed interpretation)
    LDI A, $80      ; A = 0x80 (10000000)
    LDI B, $00      ; B = 0x00
    MOV A, B        ; B = A = 0x80 (sign bit transfer)
    
    ; Test with 0x7F (largest positive in signed interpretation)
    LDI A, $7F      ; A = 0x7F (01111111)  
    LDI C, $00      ; C = 0x00
    MOV A, C        ; C = A = 0x7F (max positive transfer)
    
    ; Test with 0x01 (minimum non-zero)
    LDI A, $01      ; A = 0x01 (00000001)
    LDI B, $FF      ; B = 0xFF
    MOV A, B        ; B = A = 0x01 (single bit transfer)

    ; ==================== TEST SECTION 3: Bit Pattern Variations ====================
    ; Test various bit patterns to ensure proper data transfer
    
    ; Alternating patterns
    LDI A, $AA      ; A = 0xAA (10101010)
    LDI B, $55      ; B = 0x55 (01010101)  
    MOV A, B        ; B = A = 0xAA
    MOV B, A        ; A = B = 0xAA (round trip test)
    
    ; Nibble patterns
    LDI A, $0F      ; A = 0x0F (00001111) - low nibble set
    LDI C, $F0      ; C = 0xF0 (11110000) - high nibble set
    MOV A, C        ; C = A = 0x0F
    MOV C, A        ; A = C = 0x0F (round trip test)
    
    ; Single bit patterns
    LDI A, $01      ; A = 0x01 (bit 0 set)
    LDI B, $80      ; B = 0x80 (bit 7 set)
    MOV A, B        ; B = A = 0x01 (LSB transfer)
    MOV B, A        ; A = B = 0x01 (round trip test)

    ; ==================== TEST SECTION 4: Flag Preservation Tests ====================
    ; Verify that MOV instructions do not affect processor flags
    
    ; Set up known flag states
    SEC             ; Set carry flag (C = 1)
    LDI A, $80      ; Load negative value to set N flag, clear Z flag
    ; At this point: C=1, N=1, Z=0
    
    ; Test that MOV preserves flags
    LDI B, $7F      ; B = 0x7F (positive value)
    MOV B, A        ; A = B = 0x7F, but flags should NOT change
    ; Flags should still be: C=1, N=1, Z=0 (preserved from before MOV)
    
    ; Another flag preservation test
    CLC             ; Clear carry flag (C = 0)  
    LDI A, $00      ; Load zero to set Z flag, clear N flag
    ; At this point: C=0, N=0, Z=1
    
    LDI C, $FF      ; C = 0xFF (negative value)
    MOV C, A        ; A = C = 0xFF, but flags should NOT change
    ; Flags should still be: C=0, N=0, Z=1 (preserved from before MOV)

    ; ==================== TEST SECTION 5: Register Preservation Tests ====================
    ; Verify that MOV only affects source and destination registers
    
    ; Load all registers with known values
    LDI A, $11      ; A = 0x11
    LDI B, $22      ; B = 0x22  
    LDI C, $33      ; C = 0x33
    
    ; Test MOV A,B preserves C
    MOV A, B        ; B = A = 0x11, C should remain 0x33
    
    ; Test MOV A,C preserves B  
    MOV A, C        ; C = A = 0x11, B should remain 0x11
    
    ; Test MOV B,C preserves A
    MOV B, C        ; C = B = 0x11, A should remain 0x11

    ; ==================== TEST SECTION 6: Chained MOV Operations ====================
    ; Test sequences of MOV operations
    
    ; Initialize with distinct values
    LDI A, $A1      ; A = 0xA1
    LDI B, $B2      ; B = 0xB2
    LDI C, $C3      ; C = 0xC3
    
    ; Chain: A -> B -> C -> A (circular transfer)
    MOV A, B        ; B = A = 0xA1
    MOV B, C        ; C = B = 0xA1  
    MOV C, A        ; A = C = 0xA1
    ; Result: A=0xA1, B=0xA1, C=0xA1
    
    ; Test reverse chain: C -> B -> A
    LDI A, $1A      ; A = 0x1A
    LDI B, $2B      ; B = 0x2B
    LDI C, $3C      ; C = 0x3C
    
    MOV C, B        ; B = C = 0x3C
    MOV B, A        ; A = B = 0x3C
    ; Result: A=0x3C, B=0x3C, C=0x3C

    ; ==================== END OF TESTS ====================
    HLT             ; Halt processor