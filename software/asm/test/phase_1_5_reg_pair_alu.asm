; test_phase1_reg_pair_alu.asm
; Tests register-pair ALU operations (Acc + RegB or RegC):
; ADD B, ADD C
; ADC B, ADC C
; SUB B, SUB C
; SBC B, SBC C
; ANA B, ANA C ; (ANA is bitwise AND with Acc)
; ORA B, ORA C ; (ORA is bitwise OR with Acc)
; XRA B, XRA C ; (XRA is bitwise XOR with Acc)
; CMP B, CMP C

            ORG $E000

start_reg_pair_alu_test:
            ; Initial setup (not strictly necessary for assembler opcode test)
            LDI A, #$10
            LDI B, #$05
            LDI C, #$02

            ; --- Test ADD (Add Register to Accumulator) ---
            ADD B           ; A = A + B
            ADD C           ; A = A + C

            ; --- Test ADC (Add Register to Accumulator with Carry) ---
            ; For ADC, the carry flag state matters for CPU execution,
            ; but for assembler testing, we just check opcode generation.
            ADC B           ; A = A + B + Carry
            ADC C           ; A = A + C + Carry

            ; --- Test SUB (Subtract Register from Accumulator) ---
            SUB B           ; A = A - B
            SUB C           ; A = A - C

            ; --- Test SBC (Subtract Register from Accumulator with Borrow/Carry) ---
            SBC B           ; A = A - B - Carry
            SBC C           ; A = A - C - Carry

            ; --- Test ANA (Logical AND Register with Accumulator) ---
            ANA B           ; A = A & B
            ANA C           ; A = A & C

            ; --- Test ORA (Logical OR Register with Accumulator) ---
            ORA B           ; A = A | B
            ORA C           ; A = A | C

            ; --- Test XRA (Logical XOR Register with Accumulator) ---
            XRA B           ; A = A ^ B
            XRA C           ; A = A ^ C

            ; --- Test CMP (Compare Register with Accumulator) ---
            ; CMP B sets flags based on A - B, but A is not changed.
            CMP B
            CMP C

            HLT