; op_PHP_PLP.asm
; Comprehensive tests for PHP (Push Processor Status) and PLP (Pull Processor Status) instructions
; PHP pushes all flags to stack, PLP restores all flags from stack
; AIDEV-NOTE: Enhanced testbench with 14 comprehensive test cases covering all flag combinations, edge cases, and register corruption verification

INCLUDE "includes/mmio_defs.inc"

; ======================================================================
; == CONSTANTS
; ======================================================================
; Test patterns for comprehensive flag testing
PATTERN_00      EQU $00     ; Zero flag set
PATTERN_FF      EQU $FF     ; Negative flag set
PATTERN_80      EQU $80     ; Negative flag only
PATTERN_7F      EQU $7F     ; Positive, non-zero
PATTERN_01      EQU $01     ; Positive, non-zero
PATTERN_55      EQU $55     ; Alternating pattern
PATTERN_AA      EQU $AA     ; Inverted alternating pattern

SUCCESS_CODE    EQU $88

; Error codes for different test scenarios
ERROR_BASIC_RESTORE     EQU $E1 ; Basic flag restore failed
ERROR_ALL_ZEROS         EQU $E2 ; All zeros flag pattern failed
ERROR_ALL_ONES          EQU $E3 ; All ones flag pattern failed
ERROR_MIXED_PATTERNS    EQU $E4 ; Mixed pattern flags failed
ERROR_NESTED_OPERATIONS EQU $E5 ; Nested push/pull failed
ERROR_CARRY_PRESERVE    EQU $E6 ; Carry flag preservation failed
ERROR_ZERO_PRESERVE     EQU $E7 ; Zero flag preservation failed
ERROR_NEG_PRESERVE      EQU $E8 ; Negative flag preservation failed
ERROR_STACK_DEPTH       EQU $E9 ; Stack depth test failed
ERROR_ALTERNATING       EQU $EA ; Alternating pattern test failed
ERROR_SINGLE_BIT_C      EQU $EB ; Single bit carry test failed
ERROR_SINGLE_BIT_Z      EQU $EC ; Single bit zero test failed
ERROR_SINGLE_BIT_N      EQU $ED ; Single bit negative test failed
ERROR_CORRUPTION_CHECK  EQU $EE ; Register corruption check failed
ERROR_FINAL_STATE       EQU $EF ; Final state verification failed

; ======================================================================
; == PROGRAM
; ======================================================================
    ORG $F000

START:
    ; Initialize with known state
    CLC                     ; Clear carry flag
    LDI A, #$01            ; Set non-zero, positive value
    
    ; Test 1: Basic PHP/PLP functionality
    JSR TEST_BASIC_RESTORE
    
    ; Test 2: All flags zero state
    JSR TEST_ALL_ZEROS
    
    ; Test 3: Multiple flags set (negative + carry)
    JSR TEST_MIXED_FLAGS
    
    ; Test 4: Nested PHP/PLP operations
    JSR TEST_NESTED_OPERATIONS
    
    ; Test 5: Carry flag preservation
    JSR TEST_CARRY_PRESERVE
    
    ; Test 6: Zero flag preservation
    JSR TEST_ZERO_PRESERVE
    
    ; Test 7: Negative flag preservation
    JSR TEST_NEG_PRESERVE
    
    ; Test 8: Stack depth (multiple pushes)
    JSR TEST_STACK_DEPTH
    
    ; Test 9: Alternating flag patterns
    JSR TEST_ALTERNATING_PATTERNS
    
    ; Test 10: Single bit flag tests - Carry only
    JSR TEST_SINGLE_BIT_CARRY
    
    ; Test 11: Single bit flag tests - Zero only
    JSR TEST_SINGLE_BIT_ZERO
    
    ; Test 12: Single bit flag tests - Negative only
    JSR TEST_SINGLE_BIT_NEGATIVE
    
    ; Test 13: Register corruption check
    JSR TEST_REGISTER_CORRUPTION
    
    ; Test 14: Final comprehensive state verification
    JSR TEST_FINAL_STATE
    
    ; All tests passed
    LDI A, #SUCCESS_CODE
    STA OUTPUT_PORT_1
    HLT

; ======================================================================
; == TEST SUBROUTINES
; ======================================================================

; Test 1: Basic flag restore functionality
; Set flags, push, corrupt, pull, verify
TEST_BASIC_RESTORE:
    ; Set up known flag state: Z=0, N=1, C=0
    LDI A, #PATTERN_FF      ; A=$FF, Z=0, N=1, C=0
    CLC                     ; C=0
    
    PHP                     ; Push flags to stack
    
    ; Corrupt flags by setting opposite state
    LDI A, #PATTERN_00      ; A=$00, Z=1, N=0, C=0
    SEC                     ; C=1
    
    PLP                     ; Restore flags from stack
    
    ; Verify flags are restored: Z=0, N=1, C=0
    JZ LOG_ERROR_BASIC_RESTORE    ; Should not be zero
    JNN LOG_ERROR_BASIC_RESTORE   ; Should be negative
    JC LOG_ERROR_BASIC_RESTORE    ; Should not have carry
    
    RET

; Test 2: All flags in zero state
TEST_ALL_ZEROS:
    ; Set all flags to zero state
    LDI A, #PATTERN_01      ; A=$01, Z=0, N=0, C=0
    CLC                     ; Ensure C=0
    
    PHP                     ; Push all-zero flags
    
    ; Corrupt with all flags set
    LDI A, #PATTERN_FF      ; A=$FF, Z=0, N=1, C=0
    SEC                     ; C=1
    LDI A, #PATTERN_00      ; A=$00, Z=1, N=0, C=1
    
    PLP                     ; Restore all-zero flags
    
    ; Verify all flags are zero: Z=0, N=0, C=0
    JZ LOG_ERROR_ALL_ZEROS        ; Z should be 0
    JN LOG_ERROR_ALL_ZEROS        ; N should be 0
    JC LOG_ERROR_ALL_ZEROS        ; C should be 0
    
    RET

; Test 3: Mixed flag patterns
TEST_MIXED_FLAGS:
    ; Create state with N=1, Z=0, C=1
    LDI A, #PATTERN_FF      ; A=$FF, Z=0, N=1, C=0
    LDI B, #PATTERN_01      ; B=$01
    ADD B                   ; A=$FF+$01=$00, Z=1, N=0, C=1
    LDI A, #PATTERN_80      ; A=$80, Z=0, N=1, C=1 (preserve C)
    
    PHP                     ; Push mixed flags: Z=0, N=1, C=1
    
    ; Corrupt with opposite pattern
    CLC                     ; C=0
    LDI A, #PATTERN_01      ; A=$01, Z=0, N=0, C=0
    
    PLP                     ; Restore mixed flags
    
    ; Verify: Z=0, N=1, C=1
    JZ LOG_ERROR_MIXED_PATTERNS   ; Z should be 0
    JNN LOG_ERROR_MIXED_PATTERNS  ; N should be 1
    JNC LOG_ERROR_MIXED_PATTERNS  ; C should be 1
    
    RET

; Test 4: Nested PHP/PLP operations
TEST_NESTED_OPERATIONS:
    ; First state: Z=0, N=0, C=1
    LDI A, #PATTERN_01      ; A=$01, Z=0, N=0, C=0
    SEC                     ; C=1
    PHP                     ; Push state 1
    
    ; Second state: Z=1, N=0, C=0
    LDI A, #PATTERN_00      ; A=$00, Z=1, N=0, C=0
    CLC                     ; C=0
    PHP                     ; Push state 2
    
    ; Corrupt current state
    LDI A, #PATTERN_FF      ; A=$FF, Z=0, N=1, C=0
    SEC                     ; C=1
    
    ; Restore state 2: Z=1, N=0, C=0
    PLP
    JNZ LOG_ERROR_NESTED_PUSH     ; Z should be 1
    JN LOG_ERROR_NESTED_PUSH      ; N should be 0
    JC LOG_ERROR_NESTED_PUSH      ; C should be 0
    
    ; Restore state 1: Z=0, N=0, C=1
    PLP
    JZ LOG_ERROR_NESTED_PUSH      ; Z should be 0
    JN LOG_ERROR_NESTED_PUSH      ; N should be 0
    JNC LOG_ERROR_NESTED_PUSH     ; C should be 1
    
    RET

; Test 5: Carry flag preservation across operations
TEST_CARRY_PRESERVE:
    ; Set carry flag only
    CLC                     ; C=0
    LDI A, #PATTERN_FF      ; A=$FF, Z=0, N=1, C=0
    LDI B, #PATTERN_01      ; B=$01
    ADD B                   ; A=$00, Z=1, N=0, C=1
    LDI A, #PATTERN_01      ; A=$01, Z=0, N=0, C=1 (preserve C)
    
    PHP                     ; Push with C=1
    
    ; Do operations that would normally affect carry
    LDI A, #PATTERN_7F      ; A=$7F, Z=0, N=0, C=0
    LDI B, #PATTERN_01      ; B=$01
    ADD B                   ; A=$80, Z=0, N=1, C=0
    
    PLP                     ; Restore C=1
    
    ; Verify carry is restored
    JNC LOG_ERROR_CARRY_PRESERVE
    
    RET

; Test 6: Zero flag preservation
TEST_ZERO_PRESERVE:
    ; Set zero flag specifically
    LDI A, #PATTERN_00      ; A=$00, Z=1, N=0, C=0
    CLC                     ; C=0
    
    PHP                     ; Push with Z=1
    
    ; Corrupt zero flag
    LDI A, #PATTERN_FF      ; A=$FF, Z=0, N=1, C=0
    
    PLP                     ; Restore Z=1
    
    ; Verify zero flag is restored
    JNZ LOG_ERROR_ZERO_PRESERVE
    
    RET

; Test 7: Negative flag preservation
TEST_NEG_PRESERVE:
    ; Set negative flag specifically
    LDI A, #PATTERN_80      ; A=$80, Z=0, N=1, C=0
    CLC                     ; C=0
    
    PHP                     ; Push with N=1
    
    ; Corrupt negative flag
    LDI A, #PATTERN_01      ; A=$01, Z=0, N=0, C=0
    
    PLP                     ; Restore N=1
    
    ; Verify negative flag is restored
    JNN LOG_ERROR_NEG_PRESERVE
    
    RET

; Test 8: Stack depth test (multiple sequential pushes)
TEST_STACK_DEPTH:
    ; Push three different flag states
    LDI A, #PATTERN_00      ; State 1: Z=1, N=0, C=0
    CLC
    PHP
    
    LDI A, #PATTERN_80      ; State 2: Z=0, N=1, C=0
    CLC
    PHP
    
    LDI A, #PATTERN_FF      ; State 3: Z=0, N=1, C=0
    LDI B, #PATTERN_01
    ADD B                   ; Create C=1
    LDI A, #PATTERN_01      ; A=$01, Z=0, N=0, C=1
    PHP
    
    ; Pull in reverse order and verify
    PLP                     ; Restore state 3: Z=0, N=0, C=1
    JZ LOG_ERROR_STACK_DEPTH
    JN LOG_ERROR_STACK_DEPTH
    JNC LOG_ERROR_STACK_DEPTH
    
    PLP                     ; Restore state 2: Z=0, N=1, C=0
    JZ LOG_ERROR_STACK_DEPTH
    JNN LOG_ERROR_STACK_DEPTH
    JC LOG_ERROR_STACK_DEPTH
    
    PLP                     ; Restore state 1: Z=1, N=0, C=0
    JNZ LOG_ERROR_STACK_DEPTH
    JN LOG_ERROR_STACK_DEPTH
    JC LOG_ERROR_STACK_DEPTH
    
    RET

; Test 9: Alternating flag patterns
TEST_ALTERNATING_PATTERNS:
    ; Pattern 1: Z=1, N=0, C=1
    LDI A, #PATTERN_FF      ; A=$FF
    LDI B, #PATTERN_01      ; B=$01
    ADD B                   ; A=$00, Z=1, N=0, C=1
    PHP
    
    ; Pattern 2: Z=0, N=1, C=0
    LDI A, #PATTERN_80      ; A=$80, Z=0, N=1, C=0
    CLC
    PHP
    
    ; Restore pattern 2
    PLP
    JZ LOG_ERROR_ALTERNATING
    JNN LOG_ERROR_ALTERNATING
    JC LOG_ERROR_ALTERNATING
    
    ; Restore pattern 1
    PLP
    JNZ LOG_ERROR_ALTERNATING
    JN LOG_ERROR_ALTERNATING
    JNC LOG_ERROR_ALTERNATING
    
    RET

; Test 10: Single bit - Carry only
TEST_SINGLE_BIT_CARRY:
    ; Set only carry flag
    LDI A, #PATTERN_01      ; A=$01, Z=0, N=0, C=0
    SEC                     ; C=1
    PHP
    
    ; Corrupt all flags
    LDI A, #PATTERN_00      ; A=$00, Z=1, N=0, C=0
    CLC
    
    PLP                     ; Restore only C=1
    
    ; Verify only carry is set
    JZ LOG_ERROR_SINGLE_BIT_C     ; Z should be 0
    JN LOG_ERROR_SINGLE_BIT_C     ; N should be 0
    JNC LOG_ERROR_SINGLE_BIT_C    ; C should be 1
    
    RET

; Test 11: Single bit - Zero only
TEST_SINGLE_BIT_ZERO:
    ; Set only zero flag
    LDI A, #PATTERN_00      ; A=$00, Z=1, N=0, C=0
    CLC
    PHP
    
    ; Corrupt all flags
    LDI A, #PATTERN_FF      ; A=$FF, Z=0, N=1, C=0
    SEC
    
    PLP                     ; Restore only Z=1
    
    ; Verify only zero is set
    JNZ LOG_ERROR_SINGLE_BIT_Z    ; Z should be 1
    JN LOG_ERROR_SINGLE_BIT_Z     ; N should be 0
    JC LOG_ERROR_SINGLE_BIT_Z     ; C should be 0
    
    RET

; Test 12: Single bit - Negative only
TEST_SINGLE_BIT_NEGATIVE:
    ; Set only negative flag
    LDI A, #PATTERN_80      ; A=$80, Z=0, N=1, C=0
    CLC
    PHP
    
    ; Corrupt all flags
    LDI A, #PATTERN_00      ; A=$00, Z=1, N=0, C=0
    SEC
    
    PLP                     ; Restore only N=1
    
    ; Verify only negative is set
    JZ LOG_ERROR_SINGLE_BIT_N     ; Z should be 0
    JNN LOG_ERROR_SINGLE_BIT_N    ; N should be 1
    JC LOG_ERROR_SINGLE_BIT_N     ; C should be 0
    
    RET

; Test 13: Register corruption check
; Verify that PHP/PLP don't affect A, B, C registers
TEST_REGISTER_CORRUPTION:
    ; Set up known register values
    LDI A, #PATTERN_AA      ; A=$AA
    LDI B, #PATTERN_55      ; B=$55
    LDI C, #PATTERN_FF      ; C=$FF
    
    ; Create flag state and test PHP
    CMP B                   ; Compare A($AA) with B($55): A>B, Z=0, N=0, C=1
    
    PHP                     ; Push flags (should not affect registers)
    
    ; Verify A register unchanged after PHP
    CMP B                   ; Compare A($AA) with B($55): should still be A>B
    JZ LOG_ERROR_CORRUPTION_CHECK   ; If Z=1, A was corrupted
    JN LOG_ERROR_CORRUPTION_CHECK   ; If N=1, A was corrupted
    JNC LOG_ERROR_CORRUPTION_CHECK  ; If C=0, either flags or A was corrupted
    
    ; Verify B register unchanged after PHP by using it in comparison
    LDI A, #PATTERN_55      ; A=$55 (same as B should be)
    CMP B                   ; Compare A($55) with B($55): should be equal, Z=1, C=1
    JNZ LOG_ERROR_CORRUPTION_CHECK  ; If Z=0, B was corrupted
    JNC LOG_ERROR_CORRUPTION_CHECK  ; If C=0, B was corrupted
    
    ; Verify C register unchanged after PHP
    LDI A, #PATTERN_FF      ; A=$FF (same as C should be)
    CMP C                   ; Compare A($FF) with C($FF): should be equal, Z=1, C=1
    JNZ LOG_ERROR_CORRUPTION_CHECK  ; If Z=0, C was corrupted
    JNC LOG_ERROR_CORRUPTION_CHECK  ; If C=0, C was corrupted
    
    ; Restore original state for PLP test
    LDI A, #PATTERN_AA      ; A=$AA
    LDI B, #PATTERN_55      ; B=$55  
    LDI C, #PATTERN_FF      ; C=$FF
    CMP B                   ; Set flags again: A>B, Z=0, N=0, C=1
    
    PLP                     ; Pull flags (should not affect registers, restore original flags)
    
    ; Verify A register unchanged after PLP
    CMP B                   ; Compare A($AA) with B($55): should still be A>B, Z=0, N=0, C=1
    JZ LOG_ERROR_CORRUPTION_CHECK   ; If Z=1, A was corrupted
    JN LOG_ERROR_CORRUPTION_CHECK   ; If N=1, A was corrupted  
    JNC LOG_ERROR_CORRUPTION_CHECK  ; If C=0, A was corrupted or flags not restored
    
    RET

; Test 14: Final comprehensive verification
TEST_FINAL_STATE:
    ; Set up a complex flag state
    LDI A, #PATTERN_FF      ; A=$FF, Z=0, N=1, C=0
    LDI B, #PATTERN_FF      ; B=$FF
    ADD B                   ; A=$FE, Z=0, N=1, C=1
    
    PHP                     ; Push final state
    
    ; Completely corrupt state
    CLC                     ; C=0
    LDI A, #PATTERN_00      ; A=$00, Z=1, N=0, C=0
    
    PLP                     ; Restore final state
    
    ; Verify final state: Z=0, N=1, C=1
    JZ LOG_ERROR_FINAL_STATE      ; Z should be 0
    JNN LOG_ERROR_FINAL_STATE     ; N should be 1
    JNC LOG_ERROR_FINAL_STATE     ; C should be 1
    
    RET

; ======================================================================
; == ERROR HANDLERS
; ======================================================================

LOG_ERROR_BASIC_RESTORE:
    LDI A, #ERROR_BASIC_RESTORE
    JMP LOG_ERROR_HALT

LOG_ERROR_ALL_ZEROS:
    LDI A, #ERROR_ALL_ZEROS
    JMP LOG_ERROR_HALT

LOG_ERROR_MIXED_PATTERNS:
    LDI A, #ERROR_MIXED_PATTERNS
    JMP LOG_ERROR_HALT

LOG_ERROR_NESTED_PUSH:
    LDI A, #ERROR_NESTED_OPERATIONS
    JMP LOG_ERROR_HALT

LOG_ERROR_CARRY_PRESERVE:
    LDI A, #ERROR_CARRY_PRESERVE
    JMP LOG_ERROR_HALT

LOG_ERROR_ZERO_PRESERVE:
    LDI A, #ERROR_ZERO_PRESERVE
    JMP LOG_ERROR_HALT

LOG_ERROR_NEG_PRESERVE:
    LDI A, #ERROR_NEG_PRESERVE
    JMP LOG_ERROR_HALT

LOG_ERROR_STACK_DEPTH:
    LDI A, #ERROR_STACK_DEPTH
    JMP LOG_ERROR_HALT

LOG_ERROR_ALTERNATING:
    LDI A, #ERROR_ALTERNATING
    JMP LOG_ERROR_HALT

LOG_ERROR_SINGLE_BIT_C:
    LDI A, #ERROR_SINGLE_BIT_C
    JMP LOG_ERROR_HALT

LOG_ERROR_SINGLE_BIT_Z:
    LDI A, #ERROR_SINGLE_BIT_Z
    JMP LOG_ERROR_HALT

LOG_ERROR_SINGLE_BIT_N:
    LDI A, #ERROR_SINGLE_BIT_N
    JMP LOG_ERROR_HALT

LOG_ERROR_CORRUPTION_CHECK:
    LDI A, #ERROR_CORRUPTION_CHECK
    JMP LOG_ERROR_HALT

LOG_ERROR_FINAL_STATE:
    LDI A, #ERROR_FINAL_STATE
    JMP LOG_ERROR_HALT

LOG_ERROR_HALT:
    STA OUTPUT_PORT_1
    HLT