; constants_and_data.asm
; Uses EQU constants, multiple DB initializations, and simple ALU/memory ops.

; --- Constants ---
LED_PORT    EQU $E000     ; MMIO address for LED output register
VALUE_ONE   EQU $15       ; A constant data value
VALUE_TWO   EQU $0A       ; Another constant data value
DATA_START  EQU $0200     ; Starting address for our data block in RAM

; --- Data Section (in RAM) ---
            ORG DATA_START  ; Place data using EQU for origin
data_val1:  DB VALUE_ONE    ; Initialize with $15 using EQU
data_val2:  DB VALUE_TWO    ; Initialize with $0A using EQU
extra_byte: DB $CC          ; Another byte
sum_storage:DB $00          ; Placeholder for sum in RAM

; --- Code Section (in ROM) ---
            ORG $F000     ; Code starts in ROM

start:
            LDA data_val1   ; Load A from the address of 'data_val1' (A = $15)

            LDI B, #0       ; Temporary: Prepare B (assuming we don't have LDA into B)
            LDA data_val2   ; Load second value ($0A) into A
            MOV B, A        ; Move second value ($0A) into B. Now B = $0A.
                            ; A still holds $0A from the last LDA.

            LDA data_val1   ; Reload first value ($15) into A. Now A = $15, B = $0A.

            ADD B           ; Add Register B to Register A (A = A + B)
                            ; A = $15 + $0A = $1F

            STA LED_PORT    ; Store the result ($1F) to the LED port ($E000)
            STA sum_storage ; Store the result ($1F) also to 'sum_storage' RAM location

            HLT             ; Halt the processor