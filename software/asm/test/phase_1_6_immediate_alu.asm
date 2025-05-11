; test_phase1_immediate_alu.asm
; Tests immediate ALU operations: ANI, ORI, XRI
; These operate on the Accumulator (A) with an immediate byte.

            ORG $B000

start_immediate_alu_test:
            ; Initial setup
            LDI A, #$AA     ; A = 10101010

            ; --- Test ANI (AND Immediate with Accumulator) ---
            ; A = $AA (10101010)
            ; ANI #$F0 (11110000)
            ; Result A should be $A0 (10100000)
            ANI #$F0

            ; Restore A for next test
            LDI A, #$AA     ; A = 10101010

            ; --- Test ORI (OR Immediate with Accumulator) ---
            ; A = $AA (10101010)
            ; ORI #$0F (00001111)
            ; Result A should be $AF (10101111)
            ORI #$0F

            ; Restore A for next test
            LDI A, #$AA     ; A = 10101010

            ; --- Test XRI (XOR Immediate with Accumulator) ---
            ; A = $AA (10101010)
            ; XRI #$FF (11111111)
            ; Result A should be $55 (01010101)
            XRI #$FF

            ; Test with different operand formats
            LDI A, #$C3     ; A = 11000011
            ANI #%00111100  ; AND with $3C (00111100) -> A = $0C (00001100)
            
            LDI A, #$C3     ; A = 11000011
            ORI #15         ; OR with $0F (decimal 15) -> A = $CF (11001111)

            HLT