; Macro System Demo for 8-bit SAP2 CPU
; This demonstrates the new macro functionality

; Basic utility macros
MACRO DELAY count
    LDI A, count
@@loop:
    DCR A
    JNZ @@loop
ENDM

MACRO LOAD_REG reg, value
    LDI reg, value
ENDM

MACRO CLEAR_REG reg
    LDI reg, #$00
ENDM

; Higher-level macro that uses other macros
MACRO INIT_SYSTEM
    CLEAR_REG A
    CLEAR_REG B
    CLEAR_REG C
    LOAD_REG A, #$FF
ENDM

; UART communication macros
MACRO UART_SEND_CHAR char
    LDI A, char
    STA $E002          ; UART Data register
ENDM

MACRO UART_SEND_STRING
    ; Macro with no parameters - uses inline data
    LDI A, #$48        ; 'H'
    STA $E002
    LDI A, #$69        ; 'i'
    STA $E002
    LDI A, #$21        ; '!'
    STA $E002
ENDM

; Main program using macros
ORG $F000

START:
    INIT_SYSTEM                ; Initialize all registers
    
    ; Send a greeting
    UART_SEND_CHAR #$48        ; 'H'
    UART_SEND_CHAR #$69        ; 'i'
    UART_SEND_CHAR #$20        ; ' '
    
    ; Demo multiple delay loops with unique labels
    DELAY #$10                 ; First delay loop
    UART_SEND_CHAR #$21        ; '!'
    
    DELAY #$20                 ; Second delay loop (different labels)
    UART_SEND_CHAR #$0A        ; '\n'
    
    ; Load different values into registers
    LOAD_REG A, #$42
    LOAD_REG B, #$33  
    LOAD_REG C, #$11
    
    HLT

; Data section
DATA_SECTION:
    DB "Macro system demo", 0