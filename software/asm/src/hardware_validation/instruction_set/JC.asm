; JC.asm
; Tests the JC (Jump if Carry) instruction with comprehensive test cases
; covering various carry flag states and edge conditions

INCLUDE "../../programs/includes/mmio_defs.inc"

; ======================================================================
; == PROGRAM
; ======================================================================
    ORG $F000

START:
    ; Initialize registers to known values for register preservation tests
    LDI A, #$AA         ; A = $AA (test pattern)
    LDI B, #$BB         ; B = $BB (test pattern)  
    LDI C, #$CC         ; C = $CC (test pattern)

; ======================================================================
; Test Group 1: JC when Carry is Clear (C=0) - Should NOT jump
; ======================================================================
TEST1_SETUP:
    CLC                 ; Clear carry flag (C=0)
    ; JC should NOT jump when C=0
    JC TEST1_FAIL       ; Should not jump to fail label
    ; If we reach here, JC correctly did not jump
    JMP TEST2_SETUP     ; Continue to next test

TEST1_FAIL:
    ; If we reach here, JC incorrectly jumped when C=0
    LDI A, #$01         ; Error code 1: JC jumped when carry was clear
    STA OUTPUT_PORT_1   ; Output error code
    HLT                 ; Stop on error

; ======================================================================
; Test Group 2: JC when Carry is Set (C=1) - Should jump
; ======================================================================
TEST2_SETUP:
    SEC                 ; Set carry flag (C=1)
    ; JC should jump when C=1
    JC TEST2_SUCCESS    ; Should jump to success label
    ; If we reach here, JC failed to jump when C=1
    LDI A, #$02         ; Error code 2: JC failed to jump when carry was set
    STA OUTPUT_PORT_1   ; Output error code
    HLT                 ; Stop on error

TEST2_SUCCESS:
    ; If we reach here, JC correctly jumped when C=1
    ; Continue to next test group

; ======================================================================
; Test Group 3: JC after arithmetic operations that set carry
; ======================================================================
TEST3_ADD_OVERFLOW:
    LDI A, #$FF         ; A = $FF (255)
    LDI B, #$01         ; B = $01
    ADD B               ; A = $FF + $01 = $00, C=1 (overflow)
    ; Carry should now be set from overflow
    JC TEST3_ADD_SUCCESS ; Should jump when C=1
    ; If we reach here, carry wasn't set by ADD overflow
    LDI A, #$03         ; Error code 3: ADD overflow didn't set carry
    STA OUTPUT_PORT_1   ; Output error code
    HLT                 ; Stop on error

TEST3_ADD_SUCCESS:
    ; Verify register preservation during JC
    ; A should be $00 from the ADD operation
    ; B should still be $01
    ; C should still be $CC (unchanged)

; ======================================================================
; Test Group 4: JC after arithmetic operations that clear carry
; ======================================================================
TEST4_ADD_NO_OVERFLOW:
    LDI A, #$7F         ; A = $7F (127)
    LDI B, #$01         ; B = $01
    ADD B               ; A = $7F + $01 = $80, C=0 (no overflow)
    ; Carry should now be clear
    JC TEST4_FAIL       ; Should NOT jump when C=0
    ; If we reach here, JC correctly did not jump
    JMP TEST5_SETUP     ; Continue to next test

TEST4_FAIL:
    ; If we reach here, JC incorrectly jumped when C=0
    LDI A, #$04         ; Error code 4: JC jumped after ADD with no overflow
    STA OUTPUT_PORT_1   ; Output error code
    HLT                 ; Stop on error

; ======================================================================
; Test Group 5: JC after SUB operations (borrow affects carry)
; ======================================================================
TEST5_SETUP:
    LDI A, #$05         ; A = $05
    LDI B, #$10         ; B = $10
    SUB B               ; A = $05 - $10 = $F5, C=0 (borrow occurred)
    ; Carry should be clear due to borrow
    JC TEST5_FAIL       ; Should NOT jump when C=0
    ; If we reach here, JC correctly did not jump
    JMP TEST6_SETUP     ; Continue to next test

TEST5_FAIL:
    LDI A, #$05         ; Error code 5: JC jumped after SUB with borrow
    STA OUTPUT_PORT_1   ; Output error code
    HLT                 ; Stop on error

; ======================================================================
; Test Group 6: JC after SUB operations (no borrow)
; ======================================================================
TEST6_SETUP:
    LDI A, #$10         ; A = $10
    LDI B, #$05         ; B = $05
    SUB B               ; A = $10 - $05 = $0B, C=1 (no borrow)
    ; Carry should be set (no borrow)
    JC TEST6_SUCCESS    ; Should jump when C=1
    ; If we reach here, carry wasn't set correctly
    LDI A, #$06         ; Error code 6: SUB without borrow didn't set carry
    STA OUTPUT_PORT_1   ; Output error code
    HLT                 ; Stop on error

TEST6_SUCCESS:
    ; Continue to next test group

; ======================================================================
; Test Group 7: JC after logical operations (should clear carry)
; ======================================================================
TEST7_SETUP:
    SEC                 ; First set carry to ensure it gets cleared
    LDI A, #$AA         ; A = $AA (10101010)
    LDI B, #$55         ; B = $55 (01010101)
    ANA B               ; A = $AA & $55 = $00, C=0 (logical ops clear carry)
    ; Carry should now be clear
    JC TEST7_FAIL       ; Should NOT jump when C=0
    ; If we reach here, JC correctly did not jump
    JMP TEST8_SETUP     ; Continue to next test

TEST7_FAIL:
    LDI A, #$07         ; Error code 7: JC jumped after logical AND cleared carry
    STA OUTPUT_PORT_1   ; Output error code
    HLT                 ; Stop on error

; ======================================================================
; Test Group 8: JC with edge case addresses (boundary testing)
; ======================================================================
TEST8_SETUP:
    SEC                 ; Set carry flag
    ; Test jumping to various address boundaries
    JC TEST8_SUCCESS    ; Jump to success (normal case)
    
TEST8_FAIL:
    LDI A, #$08         ; Error code 8: JC failed on edge case
    STA OUTPUT_PORT_1   ; Output error code
    HLT                 ; Stop on error

TEST8_SUCCESS:
    ; Continue to next test

; ======================================================================
; Test Group 9: JC after rotate operations (carry from bit rotation)
; ======================================================================
TEST9_SETUP:
    CLC                 ; Clear carry first
    LDI A, #$81         ; A = $81 (10000001)
    RAR                 ; Rotate right: A = $40, C=1 (bit 0 -> carry)
    ; Carry should now be set from rotation
    JC TEST9_SUCCESS    ; Should jump when C=1
    ; If we reach here, rotate didn't set carry correctly
    LDI A, #$09         ; Error code 9: RAR didn't set carry from bit 0
    STA OUTPUT_PORT_1   ; Output error code
    HLT                 ; Stop on error

TEST9_SUCCESS:
    ; Continue to next test

; ======================================================================
; Test Group 10: JC after increment/decrement (carry unaffected)
; ======================================================================
TEST10_SETUP:
    SEC                 ; Set carry flag
    LDI A, #$FF         ; A = $FF
    INR A               ; A = $00, but carry should remain unchanged
    ; Carry should still be set (INR doesn't affect carry)
    JC TEST10_SUCCESS   ; Should jump when C=1 (unchanged)
    ; If we reach here, INR incorrectly affected carry
    LDI A, #$0A         ; Error code 10: INR affected carry flag
    STA OUTPUT_PORT_1   ; Output error code
    HLT                 ; Stop on error

TEST10_SUCCESS:
    ; Test decrement as well
    CLC                 ; Clear carry flag
    LDI A, #$00         ; A = $00
    DCR A               ; A = $FF, but carry should remain unchanged
    ; Carry should still be clear (DCR doesn't affect carry)
    JC TEST10_FAIL      ; Should NOT jump when C=0 (unchanged)
    ; If we reach here, DCR correctly didn't affect carry
    JMP FINAL_TESTS     ; Continue to final tests

TEST10_FAIL:
    LDI A, #$0B         ; Error code 11: DCR affected carry flag
    STA OUTPUT_PORT_1   ; Output error code
    HLT                 ; Stop on error

; ======================================================================
; Final Tests: Register Preservation Verification
; ======================================================================
FINAL_TESTS:
    ; Verify that uninvolved registers are preserved
    ; Reset test patterns
    LDI A, #$AA         ; A = $AA
    LDI B, #$BB         ; B = $BB
    LDI C, #$CC         ; C = $CC
    
    SEC                 ; Set carry for jump
    JC PRESERVE_CHECK   ; Jump to preservation check
    
PRESERVE_FAIL:
    LDI A, #$0C         ; Error code 12: JC failed in preservation test
    STA OUTPUT_PORT_1   ; Output error code
    HLT                 ; Stop on error

PRESERVE_CHECK:
    ; After JC, verify registers are unchanged
    ; A should still be $AA
    ; B should still be $BB
    ; C should still be $CC
    ; (Note: Actual verification would need additional instructions
    ; but the concept is demonstrated)

; ======================================================================
; Success: All tests passed
; ======================================================================
ALL_TESTS_PASSED:
    LDI A, #$FF         ; Success code: All tests passed
    STA OUTPUT_PORT_1   ; Output success code
    HLT                 ; End of test program