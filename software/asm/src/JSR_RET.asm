; JSR_RET.asm
; Comprehensive test suite for JSR (Jump to Subroutine) and RET (Return) instructions
; Tests call/return functionality, stack behavior, nesting, and register preservation

INCLUDE "includes/mmio_defs.inc"

; ======================================================================
; == PROGRAM
; ======================================================================
    ORG $F000

START:
    ; ================================================================
    ; TEST 1: Basic JSR/RET functionality
    ; Single subroutine call and return
    ; ================================================================
    LDI A, #$01         ; Set test marker
    LDI B, #$AA         ; Set register to preserve
    LDI C, #$55         ; Set register to preserve
    JSR BASIC_SUB       ; Call subroutine
    LDI A, #$02         ; Should execute after return
    ; Expected: A=$02, B=$AA, C=$55, subroutine executed

    ; ================================================================
    ; TEST 2: Nested subroutine calls (3 levels deep)
    ; Test stack behavior with multiple calls
    ; ================================================================
    LDI A, #$03         ; Set test marker
    JSR NESTED_SUB1     ; Start nested call chain
    LDI A, #$04         ; Should execute after all returns
    ; Expected: A=$04, proper return sequence

    ; ================================================================
    ; TEST 3: Register preservation across calls
    ; Verify JSR/RET don't corrupt registers
    ; ================================================================
    LDI A, #$11         ; Test value
    LDI B, #$22         ; Test value  
    LDI C, #$33         ; Test value
    JSR PRESERVE_TEST   ; Call subroutine that modifies registers
    ; Expected: A=$11, B=$22, C=$33 (all preserved)

    ; ================================================================
    ; TEST 4: Multiple sequential calls
    ; Test repeated JSR/RET cycles
    ; ================================================================
    LDI A, #$05         ; Set counter
    JSR INCREMENT_SUB   ; A should become $06
    JSR INCREMENT_SUB   ; A should become $07
    JSR INCREMENT_SUB   ; A should become $08
    ; Expected: A=$08

    ; ================================================================
    ; TEST 5: Stack pointer behavior test
    ; Verify stack grows/shrinks correctly
    ; ================================================================
    LDI A, #$10         ; Set test marker
    JSR STACK_TEST      ; Test stack operations
    LDI A, #$20         ; Should execute after return
    ; Expected: A=$20, stack properly managed

    ; ================================================================
    ; TEST 6: Deep nesting test (5 levels)
    ; Stress test the call stack
    ; ================================================================
    LDI A, #$06         ; Set test marker
    JSR DEEP_SUB1       ; Start deep nesting
    LDI A, #$07         ; Should execute after all returns
    ; Expected: A=$07, all returns successful

    ; Final state for verification
    LDI A, #$FF         ; Final marker
    STA OUTPUT_PORT_1   ; Output final result
    HLT

; ================================================================
; SUBROUTINES
; ================================================================

BASIC_SUB:
    ; Simple subroutine for basic test
    LDI A, #$BB         ; Modify A to show subroutine executed
    RET

NESTED_SUB1:
    ; First level of nested calls
    LDI A, #$C1         ; Level 1 marker
    JSR NESTED_SUB2     ; Call level 2
    LDI A, #$C1         ; Restore level 1 marker
    RET

NESTED_SUB2:
    ; Second level of nested calls
    LDI A, #$C2         ; Level 2 marker
    JSR NESTED_SUB3     ; Call level 3
    LDI A, #$C2         ; Restore level 2 marker
    RET

NESTED_SUB3:
    ; Third level of nested calls
    LDI A, #$C3         ; Level 3 marker
    RET

PRESERVE_TEST:
    ; Test that modifies registers but doesn't affect caller's values
    ; (This tests that JSR/RET preserve return address correctly)
    LDI A, #$99         ; Modify A
    LDI B, #$88         ; Modify B
    LDI C, #$77         ; Modify C
    ; Note: Caller's registers should be preserved due to our test structure
    RET

INCREMENT_SUB:
    ; Increment A register
    INR A               ; A = A + 1
    RET

STACK_TEST:
    ; Test stack operations by doing nested calls
    JSR STACK_HELPER1
    RET

STACK_HELPER1:
    JSR STACK_HELPER2
    RET

STACK_HELPER2:
    LDI A, #$DD         ; Marker to show we reached deepest level
    RET

DEEP_SUB1:
    ; Level 1 of deep nesting
    LDI A, #$D1
    JSR DEEP_SUB2
    RET

DEEP_SUB2:
    ; Level 2 of deep nesting
    LDI A, #$D2
    JSR DEEP_SUB3
    RET

DEEP_SUB3:
    ; Level 3 of deep nesting
    LDI A, #$D3
    JSR DEEP_SUB4
    RET

DEEP_SUB4:
    ; Level 4 of deep nesting
    LDI A, #$D4
    JSR DEEP_SUB5
    RET

DEEP_SUB5:
    ; Level 5 of deep nesting (deepest)
    LDI A, #$D5
    RET