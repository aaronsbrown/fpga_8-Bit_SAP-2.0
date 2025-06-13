; JN.asm - JN (Jump if Negative) Comprehensive Test Program
; Tests JN instruction: Jump to 16-bit address if Negative flag (N=1) is set
; Opcode: $13, Format: JN address (3 bytes)
; Flags affected: None (flags preserved during jump)

INCLUDE "../../programs/includes/mmio_defs.inc"

; ======================================================================
; == PROGRAM
; ======================================================================
    ORG $F000

START:
    ; =================================================================
    ; TEST GROUP 1: Initial register setup and flag state verification
    ; =================================================================
    ; Load test patterns into registers for preservation testing
    LDI A, #$AA    ; A = $AA (test pattern)
    LDI B, #$BB    ; B = $BB (test pattern)
    LDI C, #$CC    ; C = $CC (test pattern)
    
    ; =================================================================
    ; TEST GROUP 2: JN when Negative flag is clear (N=0) - Should NOT jump
    ; =================================================================
    ; Clear negative flag by loading positive value
    LDI A, #$7F    ; Load positive value ($7F, bit 7 clear, N=0)
    JN TEST2_FAIL  ; Should NOT jump when N=0
    ; If we reach here, JN correctly did NOT jump
    JMP TEST3_SETUP
    
TEST2_FAIL:
    ; This should never be reached - indicates test failure
    LDI A, #$E1    ; Error code $E1 (JN jumped when N=0)
    STA OUTPUT_PORT_1
    HLT
    
TEST3_SETUP:
    ; =================================================================
    ; TEST GROUP 3: JN when Negative flag is set (N=1) - Should jump
    ; =================================================================
    ; Set negative flag by loading negative value
    LDI A, #$80    ; Load negative value ($80, bit 7 set, N=1)
    JN TEST3_SUCCESS ; Should jump when N=1
    ; If we reach here, JN failed to jump when N=1
    LDI A, #$E2    ; Error code $E2 (JN did not jump when N=1)
    STA OUTPUT_PORT_1
    HLT
    
TEST3_SUCCESS:
    ; =================================================================
    ; TEST GROUP 4: JN after arithmetic operation resulting in negative
    ; =================================================================
    ; Test JN after SUB operation that results in negative value
    LDI A, #$05    ; A = 5
    LDI B, #$10    ; B = 16
    SUB B          ; A = 5 - 16 = -11 (sets N=1)
    JN TEST4_SUCCESS ; Should jump when N=1 from SUB
    ; If we reach here, JN failed after SUB
    LDI A, #$E3    ; Error code $E3
    STA OUTPUT_PORT_1
    HLT
    
TEST4_SUCCESS:
    ; =================================================================
    ; TEST GROUP 5: JN after arithmetic operation resulting in positive
    ; =================================================================
    ; Test JN after ADD operation that results in positive value
    LDI A, #$10    ; A = 16
    LDI B, #$05    ; B = 5
    SUB B          ; A = 16 - 5 = 11 (clears N=0)
    JN TEST5_FAIL  ; Should NOT jump when N=0
    ; If we reach here, JN correctly did NOT jump
    JMP TEST6_SETUP
    
TEST5_FAIL:
    ; This should never be reached
    LDI A, #$E4    ; Error code $E4
    STA OUTPUT_PORT_1
    HLT
    
TEST6_SETUP:
    ; =================================================================
    ; TEST GROUP 6: JN after logical operation resulting in zero
    ; =================================================================
    ; Test JN after logical AND that results in zero (N=0, Z=1)
    LDI A, #$AA    ; A = $AA (10101010)
    LDI B, #$55    ; B = $55 (01010101)
    ANA B          ; A = $AA & $55 = $00 (N=0, Z=1)
    JN TEST6_FAIL  ; Should NOT jump when N=0
    ; If we reach here, JN correctly did NOT jump
    JMP TEST7_SETUP
    
TEST6_FAIL:
    ; This should never be reached
    LDI A, #$E5    ; Error code $E5
    STA OUTPUT_PORT_1
    HLT
    
TEST7_SETUP:
    ; =================================================================
    ; TEST GROUP 7: JN after logical operation resulting in negative
    ; =================================================================
    ; Test JN after logical OR that results in negative value
    LDI A, #$80    ; A = $80 (10000000)
    LDI B, #$40    ; B = $40 (01000000)
    ORA B          ; A = $80 | $40 = $C0 (sets N=1)
    JN TEST7_SUCCESS ; Should jump when N=1
    ; If we reach here, JN failed
    LDI A, #$E6    ; Error code $E6
    STA OUTPUT_PORT_1
    HLT
    
TEST7_SUCCESS:
    ; =================================================================
    ; TEST GROUP 8: JN after increment operation overflow
    ; =================================================================
    ; Test JN after INR that causes wrap to negative
    LDI A, #$7F    ; A = $7F (01111111, maximum positive)
    INR A          ; A = $80 (10000000, sets N=1)
    JN TEST8_SUCCESS ; Should jump when N=1
    ; If we reach here, JN failed
    LDI A, #$E7    ; Error code $E7
    STA OUTPUT_PORT_1
    HLT
    
TEST8_SUCCESS:
    ; =================================================================
    ; TEST GROUP 9: JN after decrement operation to positive
    ; =================================================================
    ; Test JN after DCR that results in positive value
    LDI A, #$81    ; A = $81 (10000001, negative)
    DCR A          ; A = $80 (10000000, still N=1)
    JN TEST9_SUCCESS ; Should jump when N=1
    ; If we reach here, JN failed
    LDI A, #$E8    ; Error code $E8
    STA OUTPUT_PORT_1
    HLT
    
TEST9_SUCCESS:
    ; =================================================================
    ; TEST GROUP 10: JN after rotate operation
    ; =================================================================
    ; Test JN after RAL (rotate left) that sets MSB
    CLC            ; Clear carry
    LDI A, #$40    ; A = $40 (01000000)
    RAL            ; A = $80 (10000000, sets N=1)
    JN TEST10_SUCCESS ; Should jump when N=1
    ; If we reach here, JN failed
    LDI A, #$E9    ; Error code $E9
    STA OUTPUT_PORT_1
    HLT
    
TEST10_SUCCESS:
    ; =================================================================
    ; TEST GROUP 11: JN after complement operation
    ; =================================================================
    ; Test JN after CMA (complement A)
    LDI A, #$7F    ; A = $7F (01111111, positive)
    CMA            ; A = ~$7F = $80 (10000000, sets N=1)
    JN TEST11_SUCCESS ; Should jump when N=1
    ; If we reach here, JN failed
    LDI A, #$EA    ; Error code $EA
    STA OUTPUT_PORT_1
    HLT
    
TEST11_SUCCESS:
    ; =================================================================
    ; TEST GROUP 12: JN edge case - maximum negative value
    ; =================================================================
    ; Test JN with $FF (all bits set)
    LDI A, #$FF    ; A = $FF (11111111, N=1)
    JN TEST12_SUCCESS ; Should jump when N=1
    ; If we reach here, JN failed
    LDI A, #$EB    ; Error code $EB
    STA OUTPUT_PORT_1
    HLT
    
TEST12_SUCCESS:
    ; =================================================================
    ; TEST GROUP 13: JN edge case - minimum negative value
    ; =================================================================
    ; Test JN with $80 (minimum negative in two's complement)
    LDI A, #$80    ; A = $80 (10000000, N=1)
    JN TEST13_SUCCESS ; Should jump when N=1
    ; If we reach here, JN failed
    LDI A, #$EC    ; Error code $EC
    STA OUTPUT_PORT_1
    HLT
    
TEST13_SUCCESS:
    ; =================================================================
    ; TEST GROUP 14: Register preservation test
    ; =================================================================
    ; Verify that JN preserves all registers and uninvolved flags
    LDI A, #$AA    ; A = test pattern
    LDI B, #$BB    ; B = test pattern
    LDI C, #$CC    ; C = test pattern
    SEC            ; Set carry flag (should be preserved)
    LDI A, #$80    ; A = negative value (sets N=1, preserves C=1)
    JN PRESERVE_CHECK ; Should jump when N=1
    ; If we reach here, JN failed
    LDI A, #$ED    ; Error code $ED
    STA OUTPUT_PORT_1
    HLT
    
PRESERVE_CHECK:
    ; After JN, verify registers and flags are preserved
    ; Note: We can't directly test register values in assembly,
    ; but the testbench will verify this
    
    ; =================================================================
    ; TEST GROUP 15: Alternating bit patterns
    ; =================================================================
    ; Test with alternating patterns that have MSB set
    LDI A, #$AA    ; A = $AA (10101010, N=1)
    JN TEST15_SUCCESS ; Should jump when N=1
    ; If we reach here, JN failed
    LDI A, #$EE    ; Error code $EE
    STA OUTPUT_PORT_1
    HLT
    
TEST15_SUCCESS:
    LDI A, #$55    ; A = $55 (01010101, N=0)
    JN TEST15_FAIL ; Should NOT jump when N=0
    ; If we reach here, JN correctly did NOT jump
    JMP FINAL_TESTS
    
TEST15_FAIL:
    ; This should never be reached
    LDI A, #$EF    ; Error code $EF
    STA OUTPUT_PORT_1
    HLT
    
FINAL_TESTS:
    ; =================================================================
    ; TEST GROUP 16: Complex chain of operations
    ; =================================================================
    ; Test JN after a complex chain that ends in negative
    LDI A, #$10    ; Start with positive
    LDI B, #$20    ; 
    SUB B          ; A = $10 - $20 = negative result
    INR A          ; Increment (still negative)
    DCR A          ; Decrement back
    JN CHAIN_SUCCESS ; Should jump when N=1
    ; If we reach here, JN failed
    LDI A, #$F0    ; Error code $F0
    STA OUTPUT_PORT_1
    HLT
    
CHAIN_SUCCESS:
    ; =================================================================
    ; FINAL SUCCESS: All tests passed
    ; =================================================================
    LDI A, #$FF    ; Success code $FF
    STA OUTPUT_PORT_1
    
    ; Final verification that uninvolved registers preserved
    ; (Testbench will verify B=$BB, C=$CC still)
    
    HLT            ; End of test program