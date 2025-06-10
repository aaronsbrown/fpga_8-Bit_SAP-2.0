; SEC.asm
; Comprehensive test suite for SEC (Set Carry) instruction
; Tests SEC functionality, flag behavior, and register preservation

INCLUDE "includes/mmio_defs.inc"

; ======================================================================
; == PROGRAM
; ======================================================================
    ORG $F000

START:
    ; ================================================================
    ; TEST 1: Basic SEC functionality - Carry flag clear to set
    ; Expected: Carry=1, Zero and Negative flags unchanged
    ; ================================================================
    CLC                 ; Clear carry first to establish known state
    LDI A, #$00         ; Load A with 0 (sets Z=1, N=0)
    SEC                 ; Set carry flag
    ; Expected: A=$00, Carry=1, Zero=1, Negative=0

    ; ================================================================
    ; TEST 2: SEC with different accumulator values
    ; Verify SEC doesn't affect A register and other flags remain unchanged
    ; ================================================================
    LDI A, #$FF         ; Load A with all 1s (sets Z=0, N=1)
    SEC                 ; Set carry - should not change A or other flags
    ; Expected: A=$FF, Carry=1, Zero=0, Negative=1

    ; ================================================================
    ; TEST 3: SEC with positive value in accumulator
    ; ================================================================
    LDI A, #$7F         ; Load A with $7F (sets Z=0, N=0)
    SEC                 ; Set carry
    ; Expected: A=$7F, Carry=1, Zero=0, Negative=0

    ; ================================================================
    ; TEST 4: SEC when carry is already set
    ; Verify SEC works correctly when carry is already 1
    ; ================================================================
    SEC                 ; Set carry (already set from previous test)
    ; Expected: A=$7F (unchanged), Carry=1, Zero=0, Negative=0

    ; ================================================================
    ; TEST 5: SEC after clear carry - toggle behavior
    ; ================================================================
    CLC                 ; Clear carry
    SEC                 ; Set carry
    ; Expected: A=$7F (unchanged), Carry=1, Zero=0, Negative=0

    ; ================================================================
    ; TEST 6: Register preservation test
    ; Verify SEC doesn't affect registers B and C
    ; ================================================================
    LDI B, #$AA         ; Load B with pattern
    LDI C, #$55         ; Load C with pattern
    LDI A, #$33         ; Load A with different pattern
    SEC                 ; Set carry
    ; Expected: A=$33, B=$AA, C=$55, Carry=1, Zero=0, Negative=0

    ; ================================================================
    ; TEST 7: SEC with alternating bit patterns
    ; ================================================================
    LDI A, #$A5         ; Alternating pattern 10100101
    SEC                 ; Set carry
    ; Expected: A=$A5, Carry=1, Zero=0, Negative=1

    ; ================================================================
    ; TEST 8: SEC with single bit patterns
    ; ================================================================
    LDI A, #$01         ; Single bit set (bit 0)
    SEC                 ; Set carry
    ; Expected: A=$01, Carry=1, Zero=0, Negative=0

    LDI A, #$80         ; Single bit set (bit 7)
    SEC                 ; Set carry
    ; Expected: A=$80, Carry=1, Zero=0, Negative=1

    ; ================================================================
    ; TEST 9: Final state verification
    ; Leave system in known state for final verification
    ; ================================================================
    LDI A, #$42         ; Load final test value
    CLC                 ; Clear carry
    SEC                 ; Set carry
    ; Expected: A=$42, Carry=1, Zero=0, Negative=0

    HLT                 ; Halt processor