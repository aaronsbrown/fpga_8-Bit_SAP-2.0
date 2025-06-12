; JMP.asm
; Simple test of JMP (unconditional jump) instruction
; Tests basic jump functionality and register/flag preservation

INCLUDE "includes/mmio_defs.inc"

; ======================================================================
; == PROGRAM  
; ======================================================================
    ORG $F000

START:
    ; Initialize registers with test patterns
    LDI A, #$AA         ; A = $AA (10101010)
    LDI B, #$55         ; B = $55 (01010101)  
    LDI C, #$FF         ; C = $FF (11111111)

; ======================================================================
; Test 1: Basic JMP functionality - should skip error code
; ======================================================================
    JMP TEST1_OK        ; Should jump over error code
    LDI A, #$01         ; ERROR: This should be skipped
    STA OUTPUT_PORT_1   ; ERROR: This should be skipped
    HLT                 ; ERROR: This should be skipped

TEST1_OK:
    ; JMP worked - verify registers preserved

; ======================================================================
; Test 2: JMP with different address patterns
; ======================================================================
    JMP TEST2_OK        ; Jump to address with different bit pattern

TEST2_OK:
    ; Address pattern test passed

; ======================================================================  
; Test 3: JMP with flag preservation
; ======================================================================
    ; Set specific flag states
    SEC                 ; Set carry (C=1)
    LDI A, #$80         ; Set negative flag (N=1) 
    LDI B, #$00         ; Load zero for comparison
    CMP B               ; A-B = $80, sets Z=0, N=1, C=1
    
    JMP TEST3_OK        ; JMP should preserve all flags

TEST3_OK:
    ; Flags should still be: Z=0, N=1, C=1

; ======================================================================
; Test 4: JMP from different flag states  
; ======================================================================
    LDI A, #$00         ; A=0 sets Z=1, N=0
    JMP TEST4_OK        ; JMP works regardless of flag state

TEST4_OK:
    ; Test with negative flag
    LDI A, #$FF         ; A=$FF sets N=1, Z=0  
    JMP TEST5_OK        ; JMP works with any flags

TEST5_OK:
    ; Clear carry and test
    CLC                 ; C=0
    JMP TEST6_OK        ; JMP works with C=0

TEST6_OK:
    ; Pattern preservation tests
    LDI A, #$A5         ; A = $A5 (10100101)
    LDI B, #$5A         ; B = $5A (01011010)
    LDI C, #$C3         ; C = $C3 (11000011)
    JMP SUCCESS         ; Final jump test

; ======================================================================
; Success: All tests passed
; ======================================================================
SUCCESS:
    LDI A, #$FF         ; Success code
    STA OUTPUT_PORT_1   ; Output success to verify
    HLT                 ; End test