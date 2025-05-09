; Example Program for Custom 8-bit CPU
; Demonstrates basic instructions, MMIO, DB, DW, ORG, EQU, Labels.
; 1. Counts down from START_VAL to 1, outputting to LEDs.
; 2. After loop, loads 'initial_val', adds 'add_val', stores result at 'result_addr'.

; --- Constants ---
LED_PORT    EQU $E000     ; MMIO address for LED output register
START_VAL   EQU $05       ; Initial value for the countdown
MAX_COUNT   EQU $06       ; Count limit (used in old compare logic, ignored here)

; --- Data Section (in RAM) ---
            ORG $0200     ; Place subsequent data starting at RAM address $0200
initial_val: DB $10        ; Define a byte named 'initial_val', initialize to $10
add_val:     DB $07        ; Define a byte named 'add_val', initialize to $07
result_word: DW $0000      ; Define a 16-bit word named 'result_word', initialize to 0
                           ; NOTE: DW outputs low byte then high byte. Assembler handles this.
                           ; $0000 -> outputs byte $00 then byte $00.

; --- Code Section (in ROM) ---
            ORG $F000     ; Place subsequent code starting at address $F000 (in ROM)

start:                      ; Program entry point label
            LDI A, #START_VAL ; Load Accumulator A with the starting value ($05)

loop:                       ; Label for the main loop start
            STA LED_PORT    ; Store current value in A to the LED port ($E000)

            DCR A           ; Decrement Accumulator A (A = A - 1)

            JNZ loop        ; Jump back to 'loop' if A is not zero yet.

            ; --- Countdown Finished ---
            ; Now perform RAM operations
            LDA initial_val ; Load A from the address of 'initial_val' (=$0200)
                            ; A should become $10

            LDI B, #0       ; Clear B initially (Needed for next step - could load directly)
            ; ** NOTE: We don't have ADD memory yet, so load add_val into B **
            LDA add_val     ; Load A from address of 'add_val' (=$0201) - Temporarily use A
            MOV B, A        ; Move value from A ($07) into B (Need MOV BA)
            ; Reload A with initial_val
            LDA initial_val ; Load A again with $10

            ADD B           ; Add B ($07) to A ($10). A should become $17

            ; ** NOTE: We don't have STA word yet. Store A in low byte of result_word **
            STA result_word ; Store A ($17) to the address of 'result_word' (=$0202)
                            ; RAM[$0202] becomes $17. RAM[$0203] remains $00.

            HLT             ; Halt the processor