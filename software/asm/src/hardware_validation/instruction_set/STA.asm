; STA.asm  
; Comprehensive test suite for STA instruction
; Tests edge cases, boundary conditions, and flag behavior

INCLUDE "../../programs/includes/mmio_defs.inc"

; ======================================================================
; == PROGRAM
; ======================================================================
    ORG $F000

START:
    ; =================================================================
    ; TEST 1: Basic store operation - positive number
    ; Expected: Store A=$42 to address $1000, verify A and flags unchanged
    ; =================================================================
    LDI A, #$42         ; A = $42 (test value)
    LDI B, #$33         ; B = $33 (preserve test - should remain unchanged)
    LDI C, #$55         ; C = $55 (preserve test - should remain unchanged)
    STA $1000           ; Store A to memory address $1000

    ; =================================================================
    ; TEST 2: Store zero value
    ; Expected: Store A=$00 to address $1001, verify flags unchanged
    ; =================================================================
    LDI A, #$00         ; A = $00 (zero value)
    STA $1001           ; Store A to memory address $1001

    ; =================================================================
    ; TEST 3: Store negative value (MSB set)
    ; Expected: Store A=$80 to address $1002, verify flags unchanged
    ; =================================================================
    LDI A, #$80         ; A = $80 (MSB set, negative in 2's complement)
    STA $1002           ; Store A to memory address $1002

    ; =================================================================
    ; TEST 4: Store maximum positive value
    ; Expected: Store A=$7F to address $1003, verify flags unchanged
    ; =================================================================
    LDI A, #$7F         ; A = $7F (maximum positive in 2's complement)
    STA $1003           ; Store A to memory address $1003

    ; =================================================================
    ; TEST 5: Store maximum value (all bits set)
    ; Expected: Store A=$FF to address $1004, verify flags unchanged
    ; =================================================================
    LDI A, #$FF         ; A = $FF (all bits set)
    STA $1004           ; Store A to memory address $1004

    ; =================================================================
    ; TEST 6: Store alternating bit pattern
    ; Expected: Store A=$55 to address $1005, verify flags unchanged
    ; =================================================================
    LDI A, #$55         ; A = $55 (01010101 binary)
    STA $1005           ; Store A to memory address $1005

    ; =================================================================
    ; TEST 7: Store complementary alternating pattern
    ; Expected: Store A=$AA to address $1006, verify flags unchanged
    ; =================================================================
    LDI A, #$AA         ; A = $AA (10101010 binary)
    STA $1006           ; Store A to memory address $1006

    ; =================================================================
    ; TEST 8: Store single bit set (LSB)
    ; Expected: Store A=$01 to address $1007, verify flags unchanged
    ; =================================================================
    LDI A, #$01         ; A = $01 (only LSB set)
    STA $1007           ; Store A to memory address $1007

    ; =================================================================
    ; TEST 9: Store single bit set (MSB)
    ; Expected: Store A=$80 to address $1008, verify flags unchanged
    ; =================================================================
    LDI A, #$80         ; A = $80 (only MSB set)
    STA $1008           ; Store A to memory address $1008

    ; =================================================================
    ; TEST 10: Store to boundary address (low RAM boundary)
    ; Expected: Store A=$DE to address $0000, verify flags unchanged
    ; =================================================================
    LDI A, #$DE         ; A = $DE (test value)
    STA $0000           ; Store A to memory address $0000 (start of RAM)

    ; =================================================================
    ; TEST 11: Store to near high RAM boundary  
    ; Expected: Store A=$AD to address $1FFE, verify flags unchanged
    ; =================================================================
    LDI A, #$AD         ; A = $AD (test value)
    STA $1FFE           ; Store A to memory address $1FFE (near end of RAM)

    ; =================================================================
    ; TEST 12: Flag preservation test with carry set
    ; Set carry flag, then perform STA - carry should remain set
    ; =================================================================
    SEC                 ; Set carry flag (C=1)
    LDI A, #$C7         ; A = $C7 (test value)
    STA $1100           ; Store A to memory - carry flag should remain set

    ; =================================================================
    ; TEST 13: Flag preservation test with zero flag set  
    ; Load zero to set zero flag, then perform STA - zero flag should remain set
    ; =================================================================
    LDI A, #$00         ; A = $00 (sets zero flag Z=1)
    STA $1101           ; Store A to memory - zero flag should remain set

    ; =================================================================
    ; TEST 14: Register preservation test
    ; Verify B and C registers remain unchanged after multiple STA operations
    ; =================================================================
    LDI A, #$F0         ; A = $F0 (test value) 
    LDI B, #$0F         ; B = $0F (should be preserved)
    LDI C, #$A5         ; C = $A5 (should be preserved)
    STA $1200           ; Store A to memory
    STA $1201           ; Store A to memory again
    ; B and C should still be $0F and $A5 respectively

    ; =================================================================
    ; TEST 15: Sequential stores to verify independence
    ; Expected: Each store operates independently without interference
    ; =================================================================
    LDI A, #$11         ; A = $11
    STA $1300           ; Store $11 to $1300
    LDI A, #$22         ; A = $22
    STA $1301           ; Store $22 to $1301
    LDI A, #$33         ; A = $33  
    STA $1302           ; Store $33 to $1302

    ; =================================================================
    ; FINAL TEST: Halt instruction to end test sequence
    ; =================================================================
    HLT                 ; End of test sequence