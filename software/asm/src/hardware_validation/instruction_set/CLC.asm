; CLC.asm - Clear Carry Flag Instruction Test
; Comprehensive test suite for the CLC (Clear Carry) instruction
; Tests carry flag clearing behavior with various processor states
; AIDEV-NOTE: Enhanced assembly program with 8 comprehensive test cases covering edge cases, flag interactions, and register preservation

INCLUDE "../../programs/includes/mmio_defs.inc"

; ======================================================================
; == PROGRAM
; ======================================================================
    ORG $F000

START:
    ; =================================================================
    ; TEST 1: Basic CLC functionality - Carry flag should be cleared
    ; =================================================================
    ; Set up: Force carry flag to 1, then clear it with CLC
    LDI A, #$FF      ; Load A with 0xFF
    LDI B, #$01      ; Load B with 0x01  
    ADD B            ; A = 0xFF + 0x01 = 0x00, should set Carry=1
    ; Expected state: A=0x00, Carry=1, Zero=1, Negative=0
    CLC              ; Clear carry flag - should set Carry=0
    ; Expected state: A=0x00, Carry=0, Zero=1, Negative=0 (Z,N unchanged)

    ; =================================================================
    ; TEST 2: CLC with different register values - verify no side effects
    ; =================================================================
    ; Ensure CLC doesn't affect other registers or unrelated flags
    LDI A, #$80      ; Load A with 0x80 (negative value)
    LDI B, #$42      ; Load B with 0x42
    LDI C, #$AA      ; Load C with 0xAA (alternating pattern)
    SEC              ; Set carry flag to 1
    ; Expected state: A=0x80, B=0x42, C=0xAA, Carry=1, Zero=0, Negative=1
    CLC              ; Clear carry flag
    ; Expected state: A=0x80, B=0x42, C=0xAA, Carry=0, Zero=0, Negative=1 (only C changed)

    ; =================================================================
    ; TEST 3: CLC when Carry is already 0 - should remain 0
    ; =================================================================
    ; Test idempotent behavior: clearing an already clear flag
    LDI A, #$55      ; Load A with 0x55 (alternating bits)
    ANI #$55         ; A = A & 0x55 = 0x55, clears carry as side effect
    ; Expected state: A=0x55, Carry=0, Zero=0, Negative=0
    CLC              ; Clear carry flag (already 0)
    ; Expected state: A=0x55, Carry=0, Zero=0, Negative=0 (no change)

    ; =================================================================
    ; TEST 4: CLC with Zero flag set - verify Zero flag preservation
    ; =================================================================
    ; Ensure CLC doesn't interfere with Zero flag
    LDI A, #$FF      ; Load A with 0xFF
    LDI B, #$01      ; Load B with 0x01
    ADD B            ; A = 0xFF + 0x01 = 0x00, sets Carry=1, Zero=1
    ; Expected state: A=0x00, Carry=1, Zero=1, Negative=0
    CLC              ; Clear carry flag
    ; Expected state: A=0x00, Carry=0, Zero=1, Negative=0 (Z preserved)

    ; =================================================================
    ; TEST 5: CLC with Negative flag set - verify Negative flag preservation  
    ; =================================================================
    ; Ensure CLC doesn't interfere with Negative flag
    LDI A, #$FE      ; Load A with 0xFE (negative value)
    SEC              ; Set carry flag to 1
    ; Expected state: A=0xFE, Carry=1, Zero=0, Negative=1
    CLC              ; Clear carry flag
    ; Expected state: A=0xFE, Carry=0, Zero=0, Negative=1 (N preserved)

    ; =================================================================
    ; TEST 6: Multiple CLC operations - verify consistent behavior
    ; =================================================================
    ; Test multiple successive CLC operations
    SEC              ; Set carry flag to 1
    ; Expected state: Carry=1
    CLC              ; Clear carry flag (1st time)
    ; Expected state: Carry=0
    CLC              ; Clear carry flag (2nd time) 
    ; Expected state: Carry=0 (should remain 0)
    CLC              ; Clear carry flag (3rd time)
    ; Expected state: Carry=0 (should remain 0)

    ; =================================================================
    ; TEST 7: CLC with all flags in different states
    ; =================================================================
    ; Test CLC behavior with various flag combinations
    LDI A, #$7F      ; Load A with 0x7F
    LDI B, #$01      ; Load B with 0x01
    ADD B            ; A = 0x7F + 0x01 = 0x80, sets Carry=0, Zero=0, Negative=1
    SEC              ; Set carry flag to 1
    ; Expected state: A=0x80, Carry=1, Zero=0, Negative=1
    CLC              ; Clear carry flag
    ; Expected state: A=0x80, Carry=0, Zero=0, Negative=1 (only C changed)

    ; =================================================================
    ; TEST 8: Register preservation test - verify B and C unchanged
    ; =================================================================
    ; Final verification that CLC doesn't corrupt other registers
    LDI A, #$00      ; Load A with 0x00
    LDI B, #$55      ; Load B with 0x55 (specific test pattern)
    LDI C, #$AA      ; Load C with 0xAA (specific test pattern)
    SEC              ; Set carry flag to 1
    ; Expected state: A=0x00, B=0x55, C=0xAA, Carry=1, Zero=1, Negative=0
    CLC              ; Clear carry flag
    ; Expected state: A=0x00, B=0x55, C=0xAA, Carry=0, Zero=1, Negative=0
    ; Verify: A should be 0x00, B should be 0x55, C should be 0xAA

    HLT              ; End of test program