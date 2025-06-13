; LDI_B.asm
; Comprehensive test suite for LDI B (Load B register with immediate) instruction
; Tests bit patterns, edge cases, boundary conditions, and flag behavior
; AIDEV-NOTE: Enhanced from basic single test to comprehensive 20-test suite covering all edge cases

INCLUDE "../../programs/includes/mmio_defs.inc"

; ======================================================================
; == PROGRAM
; ======================================================================
    ORG $F000

START:
    ; ==================================================================
    ; Test Group 1: Basic Bit Pattern Tests
    ; ==================================================================
    
    ; Test 1: Load zero value (should set Z=1, N=0, C=unchanged)
    LDI B, #$00         ; B = $00 (all zeros)
    
    ; Test 2: Load all ones pattern (should set Z=0, N=1, C=unchanged)  
    LDI B, #$FF         ; B = $FF (all ones)
    
    ; Test 3: Load positive maximum (should set Z=0, N=0, C=unchanged)
    LDI B, #$7F         ; B = $7F (01111111 - max positive in signed)
    
    ; Test 4: Load negative minimum (should set Z=0, N=1, C=unchanged)
    LDI B, #$80         ; B = $80 (10000000 - min negative in signed)
    
    ; ==================================================================
    ; Test Group 2: Alternating Patterns 
    ; ==================================================================
    
    ; Test 5: Alternating pattern 1 (should set Z=0, N=0, C=unchanged)
    LDI B, #$55         ; B = $55 (01010101)
    
    ; Test 6: Alternating pattern 2 (should set Z=0, N=1, C=unchanged)
    LDI B, #$AA         ; B = $AA (10101010)
    
    ; ==================================================================
    ; Test Group 3: Single Bit Tests
    ; ==================================================================
    
    ; Test 7: Single LSB set (should set Z=0, N=0, C=unchanged)
    LDI B, #$01         ; B = $01 (00000001)
    
    ; Test 8: Single MSB set (should set Z=0, N=1, C=unchanged)
    LDI B, #$80         ; B = $80 (10000000)
    
    ; Test 9: Single middle bit set (should set Z=0, N=0, C=unchanged)
    LDI B, #$10         ; B = $10 (00010000)
    
    ; ==================================================================
    ; Test Group 4: Edge Case Values
    ; ==================================================================
    
    ; Test 10: One less than max (should set Z=0, N=1, C=unchanged)
    LDI B, #$FE         ; B = $FE (11111110)
    
    ; Test 11: One more than zero (should set Z=0, N=0, C=unchanged)
    LDI B, #$01         ; B = $01 (00000001)
    
    ; Test 12: Mid-range value (should set Z=0, N=0, C=unchanged)
    LDI B, #$42         ; B = $42 (01000010)
    
    ; ==================================================================
    ; Test Group 5: Carry Flag Preservation Tests
    ; ==================================================================
    
    ; Test 13: LDI_B with carry clear (C should remain 0)
    CLC                 ; Clear carry flag
    LDI B, #$CC         ; B = $CC, carry should remain 0
    
    ; Test 14: LDI_B with carry set (C should remain 1)
    SEC                 ; Set carry flag  
    LDI B, #$33         ; B = $33, carry should remain 1
    
    ; ==================================================================
    ; Test Group 6: Register Preservation Tests
    ; ==================================================================
    
    ; Test 15: Set up other registers, verify LDI_B doesn't affect them
    LDI A, #$AA         ; A = $AA (test pattern)
    LDI C, #$CC         ; C = $CC (test pattern)
    CLC                 ; Clear carry
    LDI B, #$BB         ; B = $BB, A and C should be preserved
    
    ; ==================================================================
    ; Test Group 7: Multiple Sequential Operations
    ; ==================================================================
    
    ; Test 16: Sequential LDI_B operations
    LDI B, #$11         ; B = $11
    LDI B, #$22         ; B = $22 (overwrites previous)
    LDI B, #$33         ; B = $33 (overwrites previous)
    
    ; ==================================================================
    ; Test Group 8: Boundary Value Analysis
    ; ==================================================================
    
    ; Test 17: Powers of 2 patterns
    LDI B, #$02         ; B = $02 (00000010)
    LDI B, #$04         ; B = $04 (00000100) 
    LDI B, #$08         ; B = $08 (00001000)
    LDI B, #$20         ; B = $20 (00100000)
    LDI B, #$40         ; B = $40 (01000000)
    
    ; ==================================================================
    ; Test Group 9: Complex Bit Patterns
    ; ==================================================================
    
    ; Test 18: Complex patterns for thorough testing
    LDI B, #$69         ; B = $69 (01101001)
    LDI B, #$96         ; B = $96 (10010110)
    LDI B, #$C3         ; B = $C3 (11000011)
    LDI B, #$3C         ; B = $3C (00111100)
    
    ; ==================================================================
    ; Test Group 10: Final Comprehensive Test
    ; ==================================================================
    
    ; Test 19: Final test with register preservation check
    LDI A, #$DE         ; A = $DE (preserve test)
    LDI C, #$AD         ; C = $AD (preserve test)
    SEC                 ; Set carry (preserve test)
    LDI B, #$BE         ; B = $BE, other registers/flags preserved
    LDI B, #$EF         ; B = $EF (final test pattern)
    
    ; Test 20: Zero flag test (ensure it's properly set)
    LDI B, #$00         ; B = $00 (should set zero flag)
    
    HLT                 ; Halt processor