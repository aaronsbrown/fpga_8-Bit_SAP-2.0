; test_phase1_mov.asm
; Tests all register-to-register MOV instructions:
; MOV A, B
; MOV A, C
; MOV B, A
; MOV B, C
; MOV C, A
; MOV C, B

            ORG $C000       ; Start code at a different address

start_mov_test:
            ; To make the MOV operations somewhat visible if we were debugging
            ; on the CPU, let's load initial distinct values.
            ; This isn't strictly necessary for testing the assembler's MOV encoding,
            ; but good practice for writing testable CPU code.

            LDI A, #$11     ; A = $11
            LDI B, #$22     ; B = $22
            LDI C, #$33     ; C = $33

            ; --- Test MOV A, B ---
            ; Expected: A becomes $22 (B's value), B and C unchanged from last LDI/MOV
            MOV A, B        ; A = B. (A=$22, B=$22, C=$33)

            ; --- Test MOV A, C ---
            ; Expected: A becomes $33 (C's value)
            LDI B, #$44     ; Change B to ensure MOV A,C isn't affected by previous A=B
                            ; (A=$22, B=$44, C=$33)
            MOV A, C        ; A = C. (A=$33, B=$44, C=$33)

            ; --- Test MOV B, A ---
            ; Expected: B becomes $33 (A's value)
            LDI C, #$55     ; Change C
                            ; (A=$33, B=$44, C=$55)
            MOV B, A        ; B = A. (A=$33, B=$33, C=$55)

            ; --- Test MOV B, C ---
            ; Expected: B becomes $55 (C's value)
            LDI A, #$66     ; Change A
                            ; (A=$66, B=$33, C=$55)
            MOV B, C        ; B = C. (A=$66, B=$55, C=$55)

            ; --- Test MOV C, A ---
            ; Expected: C becomes $66 (A's value)
            LDI B, #$77     ; Change B
                            ; (A=$66, B=$77, C=$55)
            MOV C, A        ; C = A. (A=$66, B=$77, C=$66)

            ; --- Test MOV C, B ---
            ; Expected: C becomes $77 (B's value)
            LDI A, #$88     ; Change A
                            ; (A=$88, B=$77, C=$66)
            MOV C, B        ; C = B. (A=$88, B=$77, C=$77)

            HLT