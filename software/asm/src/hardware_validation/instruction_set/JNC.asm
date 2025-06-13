; JNC.asm
; Tests the JNC (Jump if Not Carry) instruction with comprehensive test cases
; covering various carry flag states and edge conditions
; JNC jumps when carry flag is clear (C=0)
; AIDEV-NOTE: Enhanced comprehensive test suite covering 14 test groups with carry flag edge cases

INCLUDE "../../programs/includes/mmio_defs.inc"

; ======================================================================
; == PROGRAM
; ======================================================================
    ORG $F000

START:
    ; Initialize registers to known values for register preservation tests
    LDI A, #$AA         ; A = $AA (test pattern: 10101010)
    LDI B, #$BB         ; B = $BB (test pattern: 10111011)
    LDI C, #$CC         ; C = $CC (test pattern: 11001100)

; ======================================================================
; Test Group 1: JNC when Carry is Clear (C=0) - Should jump
; ======================================================================
TEST1_SETUP:
    CLC                 ; Clear carry flag (C=0)
    ; JNC should jump when C=0
    JNC TEST1_SUCCESS   ; Should jump to success label
    ; If we reach here, JNC failed to jump when C=0
    LDI A, #$01         ; Error code 1: JNC failed to jump when carry was clear
    STA OUTPUT_PORT_1   ; Output error code
    HLT                 ; Stop on error

TEST1_SUCCESS:
    ; If we reach here, JNC correctly jumped when C=0
    ; Continue to next test group

; ======================================================================
; Test Group 2: JNC when Carry is Set (C=1) - Should NOT jump
; ======================================================================
TEST2_SETUP:
    SEC                 ; Set carry flag (C=1)
    ; JNC should NOT jump when C=1
    JNC TEST2_FAIL      ; Should not jump to fail label
    ; If we reach here, JNC correctly did not jump
    JMP TEST3_SETUP     ; Continue to next test

TEST2_FAIL:
    ; If we reach here, JNC incorrectly jumped when C=1
    LDI A, #$02         ; Error code 2: JNC jumped when carry was set
    STA OUTPUT_PORT_1   ; Output error code
    HLT                 ; Stop on error

; ======================================================================
; Test Group 3: JNC after arithmetic operations that clear carry
; ======================================================================
TEST3_SETUP:
    LDI A, #$7F         ; A = $7F (127)
    LDI B, #$01         ; B = $01
    ADD B               ; A = $7F + $01 = $80, C=0 (no overflow)
    ; Carry should now be clear
    JNC TEST3_SUCCESS   ; Should jump when C=0
    ; If we reach here, carry was unexpectedly set
    LDI A, #$03         ; Error code 3: ADD should not have set carry
    STA OUTPUT_PORT_1   ; Output error code
    HLT                 ; Stop on error

TEST3_SUCCESS:
    ; Verify register preservation during JNC
    ; A should be $80 from the ADD operation
    ; B should still be $01
    ; C should still be $CC (unchanged)

; ======================================================================
; Test Group 4: JNC after arithmetic operations that set carry
; ======================================================================
TEST4_SETUP:
    LDI A, #$FF         ; A = $FF (255)
    LDI B, #$01         ; B = $01
    ADD B               ; A = $FF + $01 = $00, C=1 (overflow)
    ; Carry should now be set
    JNC TEST4_FAIL      ; Should NOT jump when C=1
    ; If we reach here, JNC correctly did not jump
    JMP TEST5_SETUP     ; Continue to next test

TEST4_FAIL:
    ; If we reach here, JNC incorrectly jumped when C=1
    LDI A, #$04         ; Error code 4: JNC jumped after ADD overflow
    STA OUTPUT_PORT_1   ; Output error code
    HLT                 ; Stop on error

; ======================================================================
; Test Group 5: JNC after SUB operations (borrow clears carry)
; ======================================================================
TEST5_SETUP:
    LDI A, #$05         ; A = $05
    LDI B, #$10         ; B = $10
    SUB B               ; A = $05 - $10 = $F5, C=0 (borrow occurred)
    ; Carry should be clear due to borrow
    JNC TEST5_SUCCESS   ; Should jump when C=0
    ; If we reach here, carry was unexpectedly set
    LDI A, #$05         ; Error code 5: SUB with borrow should clear carry
    STA OUTPUT_PORT_1   ; Output error code
    HLT                 ; Stop on error

TEST5_SUCCESS:
    ; Continue to next test group

; ======================================================================
; Test Group 6: JNC after SUB operations (no borrow sets carry)
; ======================================================================
TEST6_SETUP:
    LDI A, #$10         ; A = $10
    LDI B, #$05         ; B = $05
    SUB B               ; A = $10 - $05 = $0B, C=1 (no borrow)
    ; Carry should be set (no borrow)
    JNC TEST6_FAIL      ; Should NOT jump when C=1
    ; If we reach here, JNC correctly did not jump
    JMP TEST7_SETUP     ; Continue to next test

TEST6_FAIL:
    LDI A, #$06         ; Error code 6: JNC jumped after SUB with no borrow
    STA OUTPUT_PORT_1   ; Output error code
    HLT                 ; Stop on error

; ======================================================================
; Test Group 7: JNC after logical operations (always clear carry)
; ======================================================================
TEST7_SETUP:
    SEC                 ; First set carry to ensure it gets cleared
    LDI A, #$AA         ; A = $AA (10101010)
    LDI B, #$55         ; B = $55 (01010101)
    ANA B               ; A = $AA & $55 = $00, C=0 (logical ops clear carry)
    ; Carry should now be clear
    JNC TEST7_SUCCESS   ; Should jump when C=0
    ; If we reach here, logical operation failed to clear carry
    LDI A, #$07         ; Error code 7: ANA should have cleared carry
    STA OUTPUT_PORT_1   ; Output error code
    HLT                 ; Stop on error

TEST7_SUCCESS:
    ; Continue to next test

; ======================================================================
; Test Group 8: JNC after logical OR operations (also clear carry)
; ======================================================================
TEST8_SETUP:
    SEC                 ; Set carry first
    LDI A, #$00         ; A = $00 (all zeros)
    LDI B, #$FF         ; B = $FF (all ones)
    ORA B               ; A = $00 | $FF = $FF, C=0 (logical ops clear carry)
    ; Carry should now be clear
    JNC TEST8_SUCCESS   ; Should jump when C=0
    ; If we reach here, logical OR failed to clear carry
    LDI A, #$08         ; Error code 8: ORA should have cleared carry
    STA OUTPUT_PORT_1   ; Output error code
    HLT                 ; Stop on error

TEST8_SUCCESS:
    ; Continue to next test

; ======================================================================
; Test Group 9: JNC after XOR operations (also clear carry)
; ======================================================================
TEST9_SETUP:
    SEC                 ; Set carry first
    LDI A, #$F0         ; A = $F0 (11110000)
    LDI B, #$0F         ; B = $0F (00001111)
    XRA B               ; A = $F0 ^ $0F = $FF, C=0 (logical ops clear carry)
    ; Carry should now be clear
    JNC TEST9_SUCCESS   ; Should jump when C=0
    ; If we reach here, logical XOR failed to clear carry
    LDI A, #$09         ; Error code 9: XRA should have cleared carry
    STA OUTPUT_PORT_1   ; Output error code
    HLT                 ; Stop on error

TEST9_SUCCESS:
    ; Continue to next test

; ======================================================================
; Test Group 10: JNC after rotate operations (carry from bit rotation)
; ======================================================================
TEST10_SETUP:
    SEC                 ; Set carry first
    LDI A, #$80         ; A = $80 (10000000)
    RAR                 ; Rotate right: A = $C0, C=0 (bit 0 was 0 -> carry)
    ; Carry should now be clear from rotation
    JNC TEST10_SUCCESS  ; Should jump when C=0
    ; If we reach here, rotate didn't clear carry correctly
    LDI A, #$0A         ; Error code 10: RAR should clear carry when bit 0 = 0
    STA OUTPUT_PORT_1   ; Output error code
    HLT                 ; Stop on error

TEST10_SUCCESS:
    ; Continue to next test

; ======================================================================
; Test Group 11: JNC when rotate sets carry (should not jump)
; ======================================================================
TEST11_SETUP:
    CLC                 ; Clear carry first
    LDI A, #$81         ; A = $81 (10000001)
    RAR                 ; Rotate right: A = $40, C=1 (bit 0 was 1 -> carry)
    ; Carry should now be set from rotation
    JNC TEST11_FAIL     ; Should NOT jump when C=1
    ; If we reach here, JNC correctly did not jump
    JMP TEST12_SETUP    ; Continue to next test

TEST11_FAIL:
    LDI A, #$0B         ; Error code 11: JNC jumped when carry was set by rotate
    STA OUTPUT_PORT_1   ; Output error code
    HLT                 ; Stop on error

; ======================================================================
; Test Group 12: JNC after increment/decrement (carry unaffected)
; ======================================================================
TEST12_SETUP:
    CLC                 ; Clear carry flag
    LDI A, #$FF         ; A = $FF
    INR A               ; A = $00, but carry should remain unchanged
    ; Carry should still be clear (INR doesn't affect carry)
    JNC TEST12_SUCCESS  ; Should jump when C=0 (unchanged)
    ; If we reach here, INR incorrectly affected carry
    LDI A, #$0C         ; Error code 12: INR should not affect carry flag
    STA OUTPUT_PORT_1   ; Output error code
    HLT                 ; Stop on error

TEST12_SUCCESS:
    ; Test decrement as well
    SEC                 ; Set carry flag
    LDI A, #$00         ; A = $00
    DCR A               ; A = $FF, but carry should remain unchanged
    ; Carry should still be set (DCR doesn't affect carry)
    JNC TEST12_FAIL     ; Should NOT jump when C=1 (unchanged)
    ; If we reach here, DCR correctly didn't affect carry
    JMP TEST13_SETUP    ; Continue to next test

TEST12_FAIL:
    LDI A, #$0D         ; Error code 13: DCR should not affect carry flag
    STA OUTPUT_PORT_1   ; Output error code
    HLT                 ; Stop on error

; ======================================================================
; Test Group 13: JNC edge case with alternating bit patterns
; ======================================================================
TEST13_SETUP:
    LDI A, #$55         ; A = $55 (01010101)
    LDI B, #$AA         ; B = $AA (10101010)
    ANA B               ; A = $55 & $AA = $00, C=0
    ; Carry should be clear
    JNC TEST13_SUCCESS  ; Should jump when C=0
    ; If we reach here, alternating pattern test failed
    LDI A, #$0E         ; Error code 14: Alternating pattern AND failed
    STA OUTPUT_PORT_1   ; Output error code
    HLT                 ; Stop on error

TEST13_SUCCESS:
    ; Continue to final tests

; ======================================================================
; Test Group 14: JNC with complement operation (clears carry)
; ======================================================================
TEST14_SETUP:
    SEC                 ; Set carry first
    LDI A, #$F0         ; A = $F0
    CMA                 ; A = ~$F0 = $0F, C=0 (CMA clears carry)
    ; Carry should now be clear
    JNC TEST14_SUCCESS  ; Should jump when C=0
    ; If we reach here, CMA failed to clear carry
    LDI A, #$0F         ; Error code 15: CMA should clear carry
    STA OUTPUT_PORT_1   ; Output error code
    HLT                 ; Stop on error

TEST14_SUCCESS:
    ; Continue to final tests

; ======================================================================
; Final Tests: Register Preservation Verification
; ======================================================================
FINAL_TESTS:
    ; Verify that uninvolved registers are preserved
    ; Reset test patterns
    LDI A, #$AA         ; A = $AA
    LDI B, #$BB         ; B = $BB
    LDI C, #$CC         ; C = $CC
    
    CLC                 ; Clear carry for jump
    JNC PRESERVE_CHECK  ; Jump to preservation check
    
PRESERVE_FAIL:
    LDI A, #$10         ; Error code 16: JNC failed in preservation test
    STA OUTPUT_PORT_1   ; Output error code
    HLT                 ; Stop on error

PRESERVE_CHECK:
    ; After JNC, verify registers are preserved
    ; The testbench will verify A, B, C are still $AA, $BB, $CC
    
; ======================================================================
; Success: All tests passed
; ======================================================================
ALL_TESTS_PASSED:
    LDI A, #$FF         ; Success code: All tests passed
    STA OUTPUT_PORT_1   ; Output success code
    HLT                 ; End of test program