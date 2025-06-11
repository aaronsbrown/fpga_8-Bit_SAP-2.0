; LDI_C.asm
; Comprehensive test suite for LDI C (Load C register with immediate) instruction
; Tests bit patterns, edge cases, boundary conditions, and flag behavior
; AIDEV-NOTE: Enhanced comprehensive test suite covering all LDI_C edge cases based on LDI_B pattern

INCLUDE "includes/mmio_defs.inc"

; ======================================================================
; == PROGRAM
; ======================================================================
    ORG $F000

START:
    ; ==================================================================
    ; Test Group 1: Basic Bit Pattern Tests
    ; ==================================================================
    
    ; Test 1: Load zero value (should set Z=1, N=0, C=unchanged)
    LDI C, #$00         ; C = $00 (all zeros)
    
    ; Test 2: Load all ones pattern (should set Z=0, N=1, C=unchanged)  
    LDI C, #$FF         ; C = $FF (all ones)
    
    ; Test 3: Load positive maximum (should set Z=0, N=0, C=unchanged)
    LDI C, #$7F         ; C = $7F (01111111 - max positive in signed)
    
    ; Test 4: Load negative minimum (should set Z=0, N=1, C=unchanged)
    LDI C, #$80         ; C = $80 (10000000 - min negative in signed)
    
    ; ==================================================================
    ; Test Group 2: Alternating Patterns 
    ; ==================================================================
    
    ; Test 5: Alternating pattern 1 (should set Z=0, N=0, C=unchanged)
    LDI C, #$55         ; C = $55 (01010101)
    
    ; Test 6: Alternating pattern 2 (should set Z=0, N=1, C=unchanged)
    LDI C, #$AA         ; C = $AA (10101010)
    
    ; ==================================================================
    ; Test Group 3: Single Bit Tests
    ; ==================================================================
    
    ; Test 7: Single LSB set (should set Z=0, N=0, C=unchanged)
    LDI C, #$01         ; C = $01 (00000001)
    
    ; Test 8: Single MSB set (should set Z=0, N=1, C=unchanged)
    LDI C, #$80         ; C = $80 (10000000)
    
    ; Test 9: Single middle bit set (should set Z=0, N=0, C=unchanged)
    LDI C, #$10         ; C = $10 (00010000)
    
    ; ==================================================================
    ; Test Group 4: Edge Case Values
    ; ==================================================================
    
    ; Test 10: One less than max (should set Z=0, N=1, C=unchanged)
    LDI C, #$FE         ; C = $FE (11111110)
    
    ; Test 11: One more than zero (should set Z=0, N=0, C=unchanged)
    LDI C, #$01         ; C = $01 (00000001)
    
    ; Test 12: Mid-range value (should set Z=0, N=0, C=unchanged)
    LDI C, #$42         ; C = $42 (01000010)
    
    ; ==================================================================
    ; Test Group 5: Carry Flag Preservation Tests
    ; ==================================================================
    
    ; Test 13: LDI_C with carry clear (C should remain 0)
    CLC                 ; Clear carry flag
    LDI C, #$CC         ; C = $CC, carry should remain 0
    
    ; Test 14: LDI_C with carry set (C should remain 1)
    SEC                 ; Set carry flag  
    LDI C, #$33         ; C = $33, carry should remain 1
    
    ; ==================================================================
    ; Test Group 6: Register Preservation Tests
    ; ==================================================================
    
    ; Test 15: Set up other registers, verify LDI_C doesn't affect them
    LDI A, #$AA         ; A = $AA (test pattern)
    LDI B, #$BB         ; B = $BB (test pattern)
    CLC                 ; Clear carry
    LDI C, #$CC         ; C = $CC, A and B should be preserved
    
    ; ==================================================================
    ; Test Group 7: Multiple Sequential Operations
    ; ==================================================================
    
    ; Test 16: Sequential LDI_C operations
    LDI C, #$11         ; C = $11
    LDI C, #$22         ; C = $22 (overwrites previous)
    LDI C, #$33         ; C = $33 (overwrites previous)
    
    ; ==================================================================
    ; Test Group 8: Boundary Value Analysis
    ; ==================================================================
    
    ; Test 17: Powers of 2 patterns
    LDI C, #$02         ; C = $02 (00000010)
    LDI C, #$04         ; C = $04 (00000100) 
    LDI C, #$08         ; C = $08 (00001000)
    LDI C, #$20         ; C = $20 (00100000)
    LDI C, #$40         ; C = $40 (01000000)
    
    ; ==================================================================
    ; Test Group 9: Complex Bit Patterns
    ; ==================================================================
    
    ; Test 18: Complex patterns for thorough testing
    LDI C, #$69         ; C = $69 (01101001)
    LDI C, #$96         ; C = $96 (10010110)
    LDI C, #$C3         ; C = $C3 (11000011)
    LDI C, #$3C         ; C = $3C (00111100)
    
    ; ==================================================================
    ; Test Group 10: Final Comprehensive Test
    ; ==================================================================
    
    ; Test 19: Final test with register preservation check
    LDI A, #$DE         ; A = $DE (preserve test)
    LDI B, #$AD         ; B = $AD (preserve test)
    SEC                 ; Set carry (preserve test)
    LDI C, #$BE         ; C = $BE, other registers/flags preserved
    LDI C, #$EF         ; C = $EF (final test pattern)
    
    ; Test 20: Zero flag test (ensure it's properly set)
    LDI C, #$00         ; C = $00 (should set zero flag)
    
    HLT                 ; Halt processor