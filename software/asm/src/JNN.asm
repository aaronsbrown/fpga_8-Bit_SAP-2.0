; JNN.asm - Jump if Not Negative (N=0) Essential Test
; Tests JNN instruction: Opcode $14, Jump to address if Negative flag is clear (N=0)
; 
; Essential Test Strategy:
; 1. JNN when N=1 (should NOT jump)
; 2. JNN when N=0 (should jump)  
; 3. JNN after arithmetic setting N=0
; 4. JNN after arithmetic setting N=1
; 5. Register preservation during jumps

INCLUDE "includes/mmio_defs.inc"

; ======================================================================
; == PROGRAM START
; ======================================================================
    ORG $F000

START:
    ; ======================================================================
    ; Test 1: Setup test patterns and verify JNN when N=1 (should NOT jump)
    ; ======================================================================
    
    LDI A, #$AA     ; A = $AA (10101010) - sets N=1 (negative)
    LDI B, #$BB     ; B = $BB - test pattern
    LDI C, #$CC     ; C = $CC - test pattern
    
    ; JNN should NOT jump when N=1
    JNN FAIL_TEST1  ; Should NOT jump since N=1 from LDI A, #$AA
    
    ; SUCCESS: JNN correctly did NOT jump when N=1
    JMP TEST2

FAIL_TEST1:
    ; ERROR: JNN jumped when it shouldn't have (N=1)
    LDI A, #$E1
    STA OUTPUT_PORT_1
    HLT

    ; ======================================================================
    ; Test 2: JNN when N=0 (should jump)
    ; ======================================================================
    
TEST2:
    LDI A, #$7F     ; A = $7F (01111111) - positive, sets N=0
    
    JNN TEST2_SUCCESS ; Should jump when N=0
    
    ; ERROR: JNN did not jump when it should have (N=0)
    LDI A, #$E2
    STA OUTPUT_PORT_1
    HLT

TEST2_SUCCESS:
    ; SUCCESS: JNN correctly jumped when N=0
    JMP TEST3

    ; ======================================================================
    ; Test 3: JNN after SUB resulting in positive (N=0)
    ; ======================================================================
    
TEST3:
    LDI A, #$20     ; A = $20 (32)
    LDI B, #$10     ; B = $10 (16)
    SUB B           ; A = $20 - $10 = $10 (positive), sets N=0
    
    JNN TEST3_SUCCESS ; Should jump when N=0 from positive SUB result
    
    ; ERROR: JNN did not jump after positive SUB
    LDI A, #$E3
    STA OUTPUT_PORT_1
    HLT

TEST3_SUCCESS:
    ; SUCCESS: JNN correctly jumped after positive SUB result
    JMP TEST4

    ; ======================================================================
    ; Test 4: JNN after SUB resulting in negative (N=1)
    ; ======================================================================
    
TEST4:
    LDI A, #$05     ; A = $05 (5)
    LDI B, #$15     ; B = $15 (21)
    SUB B           ; A = $05 - $15 = $F0 (negative), sets N=1
    
    JNN FAIL_TEST4  ; Should NOT jump when N=1
    
    ; SUCCESS: JNN correctly did NOT jump when N=1
    JMP TEST5

FAIL_TEST4:
    ; ERROR: JNN jumped when it shouldn't have (N=1 from negative SUB)
    LDI A, #$E4
    STA OUTPUT_PORT_1
    HLT

    ; ======================================================================
    ; Test 5: JNN after logical AND resulting in zero (N=0)
    ; ======================================================================
    
TEST5:
    LDI A, #$AA     ; A = $AA (10101010)
    LDI B, #$55     ; B = $55 (01010101)
    ANA B           ; A = $AA & $55 = $00, sets N=0, Z=1
    
    JNN TEST5_SUCCESS ; Should jump when N=0 from logical AND
    
    ; ERROR: JNN did not jump after logical AND
    LDI A, #$E5
    STA OUTPUT_PORT_1
    HLT

TEST5_SUCCESS:
    ; SUCCESS: JNN correctly jumped after logical AND cleared N
    JMP TEST6

    ; ======================================================================
    ; Test 6: JNN after logical OR resulting in negative (N=1)
    ; ======================================================================
    
TEST6:
    LDI A, #$80     ; A = $80 (10000000)
    LDI B, #$40     ; B = $40 (01000000)
    ORA B           ; A = $80 | $40 = $C0 (negative), sets N=1
    
    JNN FAIL_TEST6  ; Should NOT jump when N=1
    
    ; SUCCESS: JNN correctly did NOT jump when N=1
    JMP TEST7

FAIL_TEST6:
    ; ERROR: JNN jumped when it shouldn't have (N=1 from OR)
    LDI A, #$E6
    STA OUTPUT_PORT_1
    HLT

    ; ======================================================================
    ; Test 7: JNN after increment to zero (N=0)
    ; ======================================================================
    
TEST7:
    LDI A, #$FF     ; A = $FF (255, negative)
    INR A           ; A = $FF + 1 = $00 (zero), sets N=0, Z=1
    
    JNN TEST7_SUCCESS ; Should jump when N=0 from increment to zero
    
    ; ERROR: JNN did not jump after increment to zero
    LDI A, #$E7
    STA OUTPUT_PORT_1
    HLT

TEST7_SUCCESS:
    ; SUCCESS: JNN correctly jumped after increment to zero
    JMP TEST8

    ; ======================================================================
    ; Test 8: Register preservation test
    ; ======================================================================
    
TEST8:
    LDI A, #$33     ; A = $33 (positive), N=0
    LDI B, #$44     ; B = $44
    LDI C, #$55     ; C = $55
    
    ; JNN should jump and preserve all register values
    JNN PRESERVE_CHECK ; Should jump when N=0
    
    ; ERROR: JNN did not jump for preservation test
    LDI A, #$E8
    STA OUTPUT_PORT_1
    HLT

PRESERVE_CHECK:
    ; SUCCESS: All tests completed successfully
    LDI A, #$FF     ; Success code: all tests passed
    STA OUTPUT_PORT_1 ; Output success to port
    
    HLT             ; End test program

; ======================================================================
; Error handling - should not reach here in normal execution
; ======================================================================
END_ERROR:
    LDI A, #$00     ; General error code
    STA OUTPUT_PORT_1
    HLT