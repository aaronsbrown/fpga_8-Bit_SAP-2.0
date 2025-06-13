; JZ.asm - Enhanced testbench for JZ (Jump if Zero) instruction
; JZ instruction: Jump to 16-bit address if Zero flag (Z=1) is set
; Opcode: $11, Format: JZ address (3 bytes), Flags affected: None

INCLUDE "../../programs/includes/mmio_defs.inc"

; ======================================================================
; == PROGRAM
; ======================================================================
    ORG $F000

START:
    ; ======================================================================
    ; Test Group 1: Initial Register Setup
    ; ======================================================================
    ; Load test patterns into registers
    LDI A, #$AA         ; A=$AA (10101010), Z=0, N=1
    LDI B, #$BB         ; B=$BB (10111011), Z=0, N=1  
    LDI C, #$CC         ; C=$CC (11001100), Z=0, N=1

    ; ======================================================================
    ; Test Group 2: JZ when Zero flag is Clear (Z=0) - Should NOT jump
    ; ======================================================================
    ; A is already non-zero from above, so Z=0
    JZ FAIL_1           ; Should NOT jump when Z=0
    
    ; If we reach here, JZ correctly did NOT jump
    LDI A, #$01         ; Set success marker (A=1)

    ; ======================================================================
    ; Test Group 3: JZ when Zero flag is Set (Z=1) - Should jump
    ; ======================================================================
    LDI A, #$00         ; Z=1 (loading zero sets zero flag)
    JZ TEST3_SUCCESS    ; Should jump when Z=1
    
    ; If we reach here, JZ failed to jump when it should have
    LDI A, #$FF         ; Error code
    JMP HALT

TEST3_SUCCESS:
    LDI A, #$02         ; Set success marker (A=2)

    ; ======================================================================
    ; Test Group 4: JZ after arithmetic resulting in zero
    ; ======================================================================
    LDI A, #$55         ; A=$55 (01010101)
    LDI B, #$AA         ; B=$AA (10101010)
    ANA B               ; A = $55 & $AA = $00, Z=1
    JZ TEST4_SUCCESS    ; Should jump when Z=1 from AND result
    
    ; Error if we reach here
    LDI A, #$FE         ; Error code
    JMP HALT

TEST4_SUCCESS:
    LDI A, #$03         ; Set success marker (A=3)

    ; ======================================================================
    ; Test Group 5: JZ after arithmetic resulting in non-zero
    ; ======================================================================
    LDI A, #$FF         ; A=$FF
    LDI B, #$00         ; B=$00
    ORA B               ; A = $FF | $00 = $FF, Z=0
    JZ FAIL_5           ; Should NOT jump when Z=0
    
    LDI A, #$04         ; Set success marker (A=4)

    ; ======================================================================
    ; Test Group 6: JZ after subtraction resulting in zero
    ; ======================================================================
    LDI A, #$55         ; A=$55
    LDI B, #$55         ; B=$55
    SUB B               ; A = $55 - $55 = $00, Z=1
    JZ TEST6_SUCCESS    ; Should jump when Z=1 from SUB result
    
    LDI A, #$FD         ; Error code
    JMP HALT

TEST6_SUCCESS:
    LDI A, #$05         ; Set success marker (A=5)

    ; ======================================================================
    ; Test Group 7: JZ after subtraction resulting in non-zero
    ; ======================================================================
    LDI A, #$10         ; A=$10
    LDI B, #$05         ; B=$05
    SUB B               ; A = $10 - $05 = $0B, Z=0
    JZ FAIL_7           ; Should NOT jump when Z=0
    
    LDI A, #$06         ; Set success marker (A=6)

    ; ======================================================================
    ; Test Group 8: JZ after increment resulting in zero (wrap around)
    ; ======================================================================
    LDI A, #$FF         ; A=$FF
    INR A               ; A = $FF + 1 = $00, Z=1
    JZ TEST8_SUCCESS    ; Should jump when Z=1 from INR wrap
    
    LDI A, #$FC         ; Error code
    JMP HALT

TEST8_SUCCESS:
    LDI A, #$07         ; Set success marker (A=7)

    ; ======================================================================
    ; Test Group 9: JZ after decrement resulting in zero
    ; ======================================================================
    LDI A, #$01         ; A=$01
    DCR A               ; A = $01 - 1 = $00, Z=1
    JZ TEST9_SUCCESS    ; Should jump when Z=1 from DCR
    
    LDI A, #$FB         ; Error code
    JMP HALT

TEST9_SUCCESS:
    LDI A, #$08         ; Set success marker (A=8)

    ; ======================================================================
    ; Test Group 10: JZ after XOR resulting in zero (same values)
    ; ======================================================================
    LDI A, #$33         ; A=$33 (00110011)
    LDI B, #$33         ; B=$33 (00110011)
    XRA B               ; A = $33 ^ $33 = $00, Z=1
    JZ TEST10_SUCCESS   ; Should jump when Z=1 from XOR
    
    LDI A, #$FA         ; Error code
    JMP HALT

TEST10_SUCCESS:
    LDI A, #$09         ; Set success marker (A=9)

    ; ======================================================================
    ; Test Group 11: JZ after complement of $FF (becomes $00)
    ; ======================================================================
    LDI A, #$FF         ; A=$FF (all ones)
    CMA                 ; A = ~$FF = $00, Z=1
    JZ TEST11_SUCCESS   ; Should jump when Z=1 from CMA
    
    LDI A, #$F9         ; Error code
    JMP HALT

TEST11_SUCCESS:
    LDI A, #$0A         ; Set success marker (A=10)

    ; ======================================================================
    ; Test Group 12: JZ preservation of uninvolved registers
    ; ======================================================================
    LDI B, #$DD         ; B=$DD (test pattern) 
    LDI C, #$EE         ; C=$EE (test pattern)
    LDI A, #$00         ; A=$00, Z=1 (load zero last to preserve Z flag)
    JZ TEST12_SUCCESS   ; Should jump and preserve B,C
    
    LDI A, #$F8         ; Error code
    JMP HALT

TEST12_SUCCESS:
    ; Verify registers were preserved (will be checked in testbench)
    LDI A, #$0B         ; Set success marker (A=11)

    ; ======================================================================
    ; Test Group 13: Final success - store result to output port
    ; ======================================================================
    STA OUTPUT_PORT_1   ; Store success code to output
    JMP HALT

    ; ======================================================================
    ; Error handlers - should never be reached
    ; ======================================================================
FAIL_1:
    LDI A, #$E1         ; Error: JZ jumped when Z=0
    JMP HALT

FAIL_5:
    LDI A, #$E5         ; Error: JZ jumped when Z=0 after ORA
    JMP HALT

FAIL_7:
    LDI A, #$E7         ; Error: JZ jumped when Z=0 after SUB
    JMP HALT

HALT:
    HLT