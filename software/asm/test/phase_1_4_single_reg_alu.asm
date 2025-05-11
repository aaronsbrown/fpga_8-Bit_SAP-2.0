; test_phase1_single_reg_alu.asm
; Tests single-register ALU operations:
; INR A, INR B, INR C
; DCR A, DCR B, DCR C
; CMA (operates on A)
; RAL (operates on A)
; RAR (operates on A)

            ORG $D000

start_single_reg_alu_test:
            ; Initial setup (not strictly necessary for assembler opcode test, but good for CPU testing)
            LDI A, #$10
            LDI B, #$20
            LDI C, #$30

            ; --- Test INR (Increment Register) ---
            INR A           ; Increment A
            INR B           ; Increment B
            INR C           ; Increment C

            ; --- Test DCR (Decrement Register) ---
            DCR A           ; Decrement A
            DCR B           ; Decrement B
            DCR C           ; Decrement C

            ; --- Test CMA (Complement Accumulator) ---
            ; Ensure A has a known value before CMA
            LDI A, #$F0     ; A = 11110000
            CMA             ; Complement A (A should become 00001111 = $0F)

            ; --- Test RAL (Rotate Accumulator Left through Carry) ---
            ; Conceptual:
            ; Assume Carry = 0 initially for this test by loading a value that won't set it high on LDI
            ; LDI A, #%01010101 ; A = $55
            ; RAL             ; A should become %10101010 ($AA), Carry becomes 0
            ; LDI A, #%10000000 ; A = $80
            ; RAL             ; A should become %00000000 ($00), Carry becomes 1
            LDI A, #$55
            RAL
            LDI A, #$80
            RAL

            ; --- Test RAR (Rotate Accumulator Right through Carry) ---
            ; Conceptual:
            ; Assume Carry = 0 initially
            ; LDI A, #%10101010 ; A = $AA
            ; RAR             ; A should become %01010101 ($55), Carry becomes 0
            ; LDI A, #%00000001 ; A = $01
            ; RAR             ; A should become %00000000 ($00), Carry becomes 1
            LDI A, #$AA
            RAR
            LDI A, #$01
            RAR

            HLT