; JNZ.asm
; Enhanced comprehensive test for JNZ (Jump if Not Zero) instruction
; Tests JNZ behavior with various zero/non-zero flag conditions and register preservation

INCLUDE "../../programs/includes/mmio_defs.inc"

; ======================================================================
; == PROGRAM
; ======================================================================
    ORG $F000

START:
    ; ======================================================================
    ; Test Group 1: Initial Register Setup
    ; ======================================================================
    LDI A, #$AA        ; Load test pattern into A (Z=0, N=1)
    LDI B, #$BB        ; Load test pattern into B (Z=0, N=1) 
    LDI C, #$CC        ; Load test pattern into C (Z=0, N=1)

    ; ======================================================================
    ; Test Group 2: JNZ when Zero flag is clear (Z=0) - Should jump
    ; ======================================================================
    LDI A, #$7F        ; Load positive non-zero value (Z=0, N=0)
    JNZ TEST1_SUCCESS  ; Should jump when Z=0
    JMP ERROR_HANDLER  ; Should not reach here

TEST1_SUCCESS:
    ; ======================================================================
    ; Test Group 3: JNZ when Zero flag is set (Z=1) - Should NOT jump
    ; ======================================================================
    LDI A, #$00        ; Load zero value (Z=1, N=0)
    JNZ ERROR_HANDLER  ; Should NOT jump when Z=1
    JMP TEST2_SUCCESS  ; Continue to next test

TEST2_SUCCESS:
    ; ======================================================================
    ; Test Group 4: JNZ after arithmetic resulting in zero (Z=1)
    ; ======================================================================
    LDI A, #$FF        ; Load A with $FF
    LDI B, #$01        ; Load B with $01
    ADD B              ; $FF + $01 = $00 (overflow, Z=1, C=1)
    JNZ ERROR_HANDLER  ; Should NOT jump when result is zero
    JMP TEST3_SUCCESS

TEST3_SUCCESS:
    ; ======================================================================
    ; Test Group 5: JNZ after arithmetic resulting in non-zero (Z=0)
    ; ======================================================================
    LDI A, #$7F        ; Load A with $7F
    LDI B, #$01        ; Load B with $01
    ADD B              ; $7F + $01 = $80 (no overflow, Z=0, N=1)
    JNZ TEST4_SUCCESS  ; Should jump when result is non-zero
    JMP ERROR_HANDLER

TEST4_SUCCESS:
    ; ======================================================================
    ; Test Group 6: JNZ after subtraction resulting in zero (Z=1)
    ; ======================================================================
    LDI A, #$10        ; Load A with $10
    LDI B, #$10        ; Load B with $10
    SUB B              ; $10 - $10 = $00 (Z=1, N=0, C=1)
    JNZ ERROR_HANDLER  ; Should NOT jump when result is zero
    JMP TEST5_SUCCESS

TEST5_SUCCESS:
    ; ======================================================================
    ; Test Group 7: JNZ after subtraction resulting in non-zero (Z=0)
    ; ======================================================================
    LDI A, #$20        ; Load A with $20
    LDI B, #$05        ; Load B with $05
    SUB B              ; $20 - $05 = $1B (Z=0, N=0, C=1)
    JNZ TEST6_SUCCESS  ; Should jump when result is non-zero
    JMP ERROR_HANDLER

TEST6_SUCCESS:
    ; ======================================================================
    ; Test Group 8: JNZ after logical AND resulting in zero (Z=1)
    ; ======================================================================
    LDI A, #$AA        ; Load A with $AA (10101010)
    LDI B, #$55        ; Load B with $55 (01010101)
    ANA B              ; $AA & $55 = $00 (Z=1, N=0, C=0)
    JNZ ERROR_HANDLER  ; Should NOT jump when result is zero
    JMP TEST7_SUCCESS

TEST7_SUCCESS:
    ; ======================================================================
    ; Test Group 9: JNZ after logical OR resulting in non-zero (Z=0)
    ; ======================================================================
    LDI A, #$80        ; Load A with $80 (10000000)
    LDI B, #$40        ; Load B with $40 (01000000)
    ORA B              ; $80 | $40 = $C0 (Z=0, N=1, C=0)
    JNZ TEST8_SUCCESS  ; Should jump when result is non-zero
    JMP ERROR_HANDLER

TEST8_SUCCESS:
    ; ======================================================================
    ; Test Group 10: JNZ after increment resulting in zero (Z=1)
    ; ======================================================================
    LDI A, #$FF        ; Load A with $FF
    INR A              ; $FF + 1 = $00 (Z=1, N=0, C unaffected)
    JNZ ERROR_HANDLER  ; Should NOT jump when result is zero
    JMP TEST9_SUCCESS

TEST9_SUCCESS:
    ; ======================================================================
    ; Test Group 11: JNZ after increment resulting in non-zero (Z=0)
    ; ======================================================================
    LDI A, #$7E        ; Load A with $7E
    INR A              ; $7E + 1 = $7F (Z=0, N=0, C unaffected)
    JNZ TEST10_SUCCESS ; Should jump when result is non-zero
    JMP ERROR_HANDLER

TEST10_SUCCESS:
    ; ======================================================================
    ; Test Group 12: JNZ after decrement resulting in zero (Z=1)
    ; ======================================================================
    LDI A, #$01        ; Load A with $01
    DCR A              ; $01 - 1 = $00 (Z=1, N=0, C unaffected)
    JNZ ERROR_HANDLER  ; Should NOT jump when result is zero
    JMP TEST11_SUCCESS

TEST11_SUCCESS:
    ; ======================================================================
    ; Test Group 13: JNZ after decrement resulting in non-zero (Z=0)
    ; ======================================================================
    LDI A, #$02        ; Load A with $02
    DCR A              ; $02 - 1 = $01 (Z=0, N=0, C unaffected)
    JNZ TEST12_SUCCESS ; Should jump when result is non-zero
    JMP ERROR_HANDLER

TEST12_SUCCESS:
    ; ======================================================================
    ; Test Group 14: JNZ with alternating bit patterns
    ; ======================================================================
    LDI A, #$55        ; Load A with $55 (01010101)
    LDI B, #$AA        ; Load B with $AA (10101010)
    XRA B              ; $55 ^ $AA = $FF (Z=0, N=1, C=0)
    JNZ TEST13_SUCCESS ; Should jump when result is non-zero
    JMP ERROR_HANDLER

TEST13_SUCCESS:
    ; ======================================================================
    ; Test Group 15: Register preservation verification
    ; ======================================================================
    LDI A, #$AA        ; Set A to test pattern
    LDI B, #$BB        ; Set B to test pattern
    LDI C, #$CC        ; Set C to test pattern
    SEC                ; Set carry flag for preservation test
    LDI A, #$42        ; Load non-zero value (Z=0, C should be preserved)
    JNZ PRESERVE_CHECK ; Should jump - registers should be preserved
    JMP ERROR_HANDLER

PRESERVE_CHECK:
    ; Preservation will be verified in testbench
    ; ======================================================================
    ; Test Group 16: Final Success Verification
    ; ======================================================================
    LDI A, #$FF        ; Load success code
    STA OUTPUT_PORT_1  ; Output success code
    JMP SUCCESS_END

ERROR_HANDLER:
    ; Error occurred - output error code
    LDI A, #$00        ; Load error code
    STA OUTPUT_PORT_1  ; Output error code
    JMP HALT

SUCCESS_END:
    ; All tests passed
    LDI A, #$FF        ; Load final success marker

HALT:
    HLT                ; Halt processor