; complex_test.asm - More comprehensive test program

; --- Constants (Exercising EQU with different bases) ---
LED_PORT    EQU $E000     ; Hex address for LEDs
DELAY_COUNT EQU 20        ; Decimal value for a simple delay loop
BIT_MASK    EQU %10001001 ; Binary value for some operation
INIT_A_VAL  EQU $C0       ; Initial hex value

; --- Data Section ---
            ORG $0200     ; Start data in RAM
counter:    DB $00        ; A byte variable to be modified
addr_table_loop1: DW loop1  ; Or just addr_table: DW loop1
addr_table_loop2: DW loop2  ; Needs a distinct label or just be a subsequent DW
message:    DB $00        ; Placeholder for a single byte message later (DB "str" not supported yet)
add_val:    DB $07 ; Or whatever value you intend

; --- Code Section ---
            ORG $F000     ; Code starts in ROM

start:
            ; Initialize A and store initial value in RAM
            LDI A, #INIT_A_VAL  ; Load A with $C0 (N=1)
            STA counter     ; Store A ($C0) into counter variable (@ $0200)

            ; Perform some ALU ops
            LDI B, #$0F     ; B = $0F
            ANA B           ; A = A & B ($C0 & $0F = $00). Sets Z=1, N=0, C=0
            LDI C, #$11     ; C = $11
            ORA C           ; A = A | C ($00 | $11 = $11). Sets Z=0, N=0, C=0

            ; Use a binary immediate value
            XRI #BIT_MASK   ; A = A ^ BIT_MASK ($11 ^ $89 = $98)
                            ; $11 = 00010001, $89 = 10001001 -> XOR = 10011000 = $98
                            ; Sets Z=0, N=1, C=0

            STA LED_PORT    ; Output result ($98) to LEDs

; --- Simple Delay Loop ---
            LDI B, #DELAY_COUNT ; Load loop counter (B = 20)
delay_loop:
            DCR B           ; Decrement B
            JNZ delay_loop  ; Loop until B is zero (Z=1)

; --- Test Conditional Jumps ---
loop1:
            LDA counter     ; Load A with value from counter ($C0)
            JN jump_target  ; Jump if Negative (N=1). Should jump as $C0 is negative.

            ; This part should be skipped by JN
            LDI A, #$EE     ; Load A with error code
            STA LED_PORT
            HLT

jump_target:                ; Land here after JN
            LDI A, #$AA     ; Load A with success code
            STA LED_PORT    ; Show success code on LEDs

loop2:                      ; Another label (address stored in addr_table[1])
            LDA add_val     ; Load A with value defined in data segment ($07)
                            ; NOTE: Needs add_val defined in data section for this line
                            ;       (Using value from previous example)

            ; Let's make A zero for JZ test
            LDI A, #0

            JZ halt_label   ; Jump if Zero. Should jump as Z=1.

            ; This part should be skipped
            LDI A, #$BB
            STA LED_PORT
            HLT

halt_label:
            HLT             ; Final halt