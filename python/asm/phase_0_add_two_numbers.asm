; add_two_numbers.asm
; Reads two numbers from RAM, adds them, stores result in RAM.

; --- Constants ---
; (None strictly needed for this simple version, but good practice to have section)

; --- Data Section (in RAM) ---
            ORG $0200     ; Place data starting at RAM address $0200
operand1:   DB $05        ; First number to add
operand2:   DB $0A        ; Second number to add
sum_result: DB $00        ; Placeholder for the sum (will be overwritten)

; --- Code Section (in ROM) ---
            ORG $F000     ; Code starts in ROM

start:
            LDA operand1    ; Load the first number ($05) into Register A
                            ; A = $05. Flags: Z=0, N=0 (C cleared by LDA)

            MOV B, A        ; Move the first number from A into Register B
                            ; B = $05. A still $05.

            LDA operand2    ; Load the second number ($0A) into Register A
                            ; A = $0A. B = $05. Flags: Z=0, N=0 (C cleared)

            ADD B           ; Add Register B to Register A (A = A + B)
                            ; A = $0A + $05 = $0F. Flags: Z=0, N=0, C=0

            STA sum_result  ; Store the result ($0F) into the 'sum_result' RAM location

            HLT             ; Halt the processor