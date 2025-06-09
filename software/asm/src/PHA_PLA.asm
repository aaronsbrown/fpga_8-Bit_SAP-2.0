; op_PHA_PLA.asm
; Tests basic push and pull to the stack, plus PLA flag behavior and top-of-stack.

INCLUDE "includes/mmio_defs.inc"

; ======================================================================
; == CONSTANTS
; ======================================================================
TEST_VAL_1      EQU $AA
TEST_VAL_2      EQU $AB
TEST_VAL_3      EQU $AC
TEST_VAL_00     EQU $00
TEST_VAL_80     EQU $80 ; Negative
TEST_VAL_42     EQU $42 ; Non-zero, non-negative
TEST_VAL_EE     EQU $EE ; For stack top test

SUCCESS_CODE    EQU $88

; General error for original 3-level test
ERROR_LIFO_L3   EQU $61 ; Failed level 3 LIFO check
ERROR_LIFO_L2   EQU $62 ; Failed level 2 LIFO check
ERROR_LIFO_L1   EQU $63 ; Failed level 1 LIFO check

; PLA Flag Test Error Codes
ERROR_PLA_Z_VAL EQU $E0 ; PLA Z_Test: Incorrect value pulled
ERROR_PLA_Z_FLAG EQU $E1 ; PLA Z_Test: Z flag not set as expected
ERROR_PLA_Z_C_AFFECTED EQU $E2 ; PLA Z_Test: C flag affected (should have been preserved as 0)
ERROR_PLA_Z_N_AFFECTED EQU $EF ; PLA Z_Test: N flag affected (should have been clear for value $00)

ERROR_PLA_N_VAL EQU $E3 ; PLA N_Test: Incorrect value pulled
ERROR_PLA_N_FLAG EQU $E4 ; PLA N_Test: N flag not set as expected
ERROR_PLA_N_Z_AFFECTED EQU $E5 ; PLA N_Test: Z flag affected (should have been clear)
ERROR_PLA_N_C_AFFECTED EQU $E6 ; PLA N_Test: C flag affected (should have been preserved as 1)

ERROR_PLA_NON_VAL EQU $E7 ; PLA NonNZ_Test: Incorrect value pulled
ERROR_PLA_NON_N_FLAG EQU $E8 ; PLA NonNZ_Test: N flag affected (should have been clear)
ERROR_PLA_NON_Z_FLAG EQU $E9 ; PLA NonNZ_Test: Z flag affected (should have been clear)
ERROR_PLA_NON_C_AFFECTED EQU $EA ; PLA NonNZ_Test: C flag affected (should have been preserved as 0)

ERROR_STACK_TOP_VAL EQU $EB ; Stack top push/pull value failed


; ======================================================================
; == PROGRAM
; ======================================================================
    ORG $F000

START:
; Test 0: Original 3-level LIFO push/pull
; SP starts at $01FF (assumed after reset init)
    LDI A, #TEST_VAL_1
    PHA                     ; Stack: [$AA], SP after: $01FE
    
    LDI A, #TEST_VAL_2
    PHA                     ; Stack: [$AB, $AA], SP after: $01FD

    LDI A, #TEST_VAL_3
    PHA                     ; Stack: [$AC, $AB, $AA], SP after: $01FC

    ; Pull $AC
    PLA                     ; A = $AC, SP after: $01FD
    MOV A, B                ; B = $AC
    LDI A, #TEST_VAL_3      ; A = $AC
    CMP B                   ; Compare A ($AC) with B ($AC). Z=1, C=1
    JNZ LOG_ERROR_LIFO_L3_JMP

    ; Pull $AB
    PLA                     ; A = $AB, SP after: $01FE
    MOV A, B                ; B = $AB
    LDI A, #TEST_VAL_2      ; A = $AB
    CMP B                   ; Compare A ($AB) with B ($AB). Z=1, C=1
    JNZ LOG_ERROR_LIFO_L2_JMP

    ; Pull $AA
    PLA                     ; A = $AA, SP after: $01FF
    MOV A, B                ; B = $AA
    LDI A, #TEST_VAL_1      ; A = $AA
    CMP B                   ; Compare A ($AA) with B ($AA). Z=1, C=1
    JNZ LOG_ERROR_LIFO_L1_JMP
    JMP TEST_PLA_Z          ; Successful LIFO Test, proceed to PLA flag tests

; Test 1: PLA sets Z flag (for $00), N clear, preserves C flag (initially C=0)
TEST_PLA_Z:
    CLC                     ; Setup: C=0.
    LDI A, #TEST_VAL_00     ; Value to push: $00. LDI preserves C. C=0.
    PHA                     ; Push $00. PHA preserves C. C=0.
    LDI A, #$FF             ; Corrupt A. LDI preserves C. C=0.
    PLA                     ; Pull $00. A=$00. PLA should set Z=1, N=0. PLA should preserve C. Expect C=0.

    ; Check C flag (expected: C=0)
    JC LOG_ERROR_PLA_Z_C_AFFECTED_JMP ; If C=1 here, PLA failed to preserve C=0.

    ; Check Z flag (expected: Z=1 for value $00)
    JNZ LOG_ERROR_PLA_Z_FLAG_JMP ; If Z=0 here, PLA failed to set Z=1.

    ; Check N flag (expected: N=0 for value $00)
    JN LOG_ERROR_PLA_Z_N_AFFECTED_JMP_LABEL ; If N=1 here, PLA failed to set N=0.

    ; Check pulled value
    MOV A, B                ; B = actual pulled value ($00)
    LDI A, #TEST_VAL_00     ; A = expected value ($00)
    XRA B                   ; A = expected ^ actual. If equal, A=$00 (Z=1). XRA clears C.
    JNZ LOG_ERROR_PLA_Z_VAL_JMP ; If A is not $00, values were different.
    JMP TEST_PLA_N          ; Passed Test 1. (SP is $01FF)

; Test 2: PLA sets N flag (for $80), Z clear, preserves C flag (initially C=1)
TEST_PLA_N:
    SEC                     ; Setup: C=1.
    LDI A, #TEST_VAL_80     ; Value to push: $80. LDI preserves C. C=1.
    PHA                     ; Push $80. PHA preserves C. C=1.
    LDI A, #$00             ; Corrupt A. LDI preserves C. C=1.
    PLA                     ; Pull $80. A=$80. PLA should set N=1, Z=0. PLA should preserve C. Expect C=1.

    ; Check C flag (expected: C=1)
    JNC LOG_ERROR_PLA_N_C_AFFECTED_JMP ; If C=0 here, PLA failed to preserve C=1.

    ; Check N flag (expected: N=1 for value $80)
    JNN LOG_ERROR_PLA_N_FLAG_JMP ; If N=0 here, PLA failed to set N=1.

    ; Check Z flag (expected: Z=0 for value $80)
    JZ LOG_ERROR_PLA_N_Z_AFFECTED_JMP ; If Z=1 here, PLA failed to clear Z=0.

    ; Check pulled value
    MOV A, B                ; B = actual pulled value ($80)
    LDI A, #TEST_VAL_80     ; A = expected value ($80)
    XRA B                   ; A = expected ^ actual. If equal, A=$00 (Z=1). XRA clears C.
    JNZ LOG_ERROR_PLA_N_VAL_JMP ; If A is not $00, values were different.
    JMP TEST_PLA_NON_NZ     ; Passed Test 2. (SP is $01FF)

; Test 3: PLA clears N, Z flags (for $42), preserves C flag (initially C=0)
TEST_PLA_NON_NZ:
    CLC                     ; Setup: C=0.
    LDI A, #TEST_VAL_42     ; Value to push: $42. LDI preserves C. C=0.
    PHA                     ; Push $42. PHA preserves C. C=0.
    LDI A, #$FF             ; Corrupt A. LDI preserves C. C=0.
    PLA                     ; Pull $42. A=$42. PLA should set N=0, Z=0. PLA should preserve C. Expect C=0.

    ; Check C flag (expected: C=0)
    JC LOG_ERROR_PLA_NON_C_AFFECTED_JMP ; If C=1 here, PLA failed to preserve C=0.

    ; Check N flag (expected: N=0 for value $42)
    JN LOG_ERROR_PLA_NON_N_FLAG_JMP ; If N=1 here, PLA failed to clear N=0.

    ; Check Z flag (expected: Z=0 for value $42)
    JZ LOG_ERROR_PLA_NON_Z_FLAG_JMP ; If Z=1 here, PLA failed to clear Z=0.

    ; Check pulled value
    MOV A, B                ; B = actual pulled value ($42)
    LDI A, #TEST_VAL_42     ; A = expected value ($42)
    XRA B                   ; A = expected ^ actual. If equal, A=$00 (Z=1). XRA clears C.
    JNZ LOG_ERROR_PLA_NON_VAL_JMP ; If A is not $00, values were different.
    JMP TEST_STACK_TOP      ; Passed Test 3. (SP is $01FF)

; Test 4: Stack operation at initial top ($01FF)
TEST_STACK_TOP:
    LDI A, #TEST_VAL_EE     ; A = $EE
    PHA                     ; Push $EE to $01FF. SP=$01FE.
    LDI A, #$00             ; Corrupt A
    PLA                     ; Pull $EE from $01FF. A=$EE. SP=$01FF.
                            ; Flags from PLA: Z=0, N=1 (for $EE), C preserved.

    ; Check pulled value
    MOV A, B                ; B = $EE
    LDI A, #TEST_VAL_EE     ; A = $EE
    XRA B                   ; A = $EE ^ $EE = $00. Z=1.
    JNZ LOG_ERROR_STACK_TOP_VAL_JMP
    JMP LOG_SUCCESS         ; Passed Test 4 and all previous tests.


LOG_SUCCESS:
    LDI A, #SUCCESS_CODE
    STA OUTPUT_PORT_1    
    HLT

; --- Error Handlers ---
LOG_ERROR_LIFO_L3_JMP:
    LDI A, #ERROR_LIFO_L3
    JMP LOG_ERROR_HALT
LOG_ERROR_LIFO_L2_JMP:
    LDI A, #ERROR_LIFO_L2
    JMP LOG_ERROR_HALT
LOG_ERROR_LIFO_L1_JMP:
    LDI A, #ERROR_LIFO_L1
    JMP LOG_ERROR_HALT

LOG_ERROR_PLA_Z_C_AFFECTED_JMP:
    LDI A, #ERROR_PLA_Z_C_AFFECTED
    JMP LOG_ERROR_HALT
LOG_ERROR_PLA_Z_FLAG_JMP:
    LDI A, #ERROR_PLA_Z_FLAG
    JMP LOG_ERROR_HALT
LOG_ERROR_PLA_Z_N_AFFECTED_JMP_LABEL: ; Label for JN in Test 1
    LDI A, #ERROR_PLA_Z_N_AFFECTED
    JMP LOG_ERROR_HALT
LOG_ERROR_PLA_Z_VAL_JMP:
    LDI A, #ERROR_PLA_Z_VAL
    JMP LOG_ERROR_HALT

LOG_ERROR_PLA_N_C_AFFECTED_JMP:
    LDI A, #ERROR_PLA_N_C_AFFECTED
    JMP LOG_ERROR_HALT
LOG_ERROR_PLA_N_FLAG_JMP:
    LDI A, #ERROR_PLA_N_FLAG
    JMP LOG_ERROR_HALT
LOG_ERROR_PLA_N_Z_AFFECTED_JMP:
    LDI A, #ERROR_PLA_N_Z_AFFECTED
    JMP LOG_ERROR_HALT
LOG_ERROR_PLA_N_VAL_JMP:
    LDI A, #ERROR_PLA_N_VAL
    JMP LOG_ERROR_HALT

LOG_ERROR_PLA_NON_C_AFFECTED_JMP:
    LDI A, #ERROR_PLA_NON_C_AFFECTED
    JMP LOG_ERROR_HALT
LOG_ERROR_PLA_NON_N_FLAG_JMP:
    LDI A, #ERROR_PLA_NON_N_FLAG
    JMP LOG_ERROR_HALT
LOG_ERROR_PLA_NON_Z_FLAG_JMP:
    LDI A, #ERROR_PLA_NON_Z_FLAG
    JMP LOG_ERROR_HALT
LOG_ERROR_PLA_NON_VAL_JMP:
    LDI A, #ERROR_PLA_NON_VAL
    JMP LOG_ERROR_HALT

LOG_ERROR_STACK_TOP_VAL_JMP:
    LDI A, #ERROR_STACK_TOP_VAL
    JMP LOG_ERROR_HALT

LOG_ERROR_HALT:
    STA OUTPUT_PORT_1
    HLT