INCLUDE "includes/mmio_defs.inc"


; ======================================================================
; CONSTANTS
; ======================================================================
ASCII_O     EQU $4F
ASCII_K     EQU $4B
ASCII_LF    EQU $0A


; ======================================================================
; == PROGRAM
; ======================================================================
    ORG $F000


START:

    LDI A, #ASCII_O
    JSR SEND_BYTE

    LDI A, #ASCII_K
    JSR SEND_BYTE

    LDI A, #ASCII_LF
    JSR SEND_BYTE

    JSR MAIN_LOOP

    HLT


; ======================================================================
; == SUBROUTINE:MAIN_LOOP
; ======================================================================
MAIN_LOOP:
    JSR RECEIVE_BYTE
    JSR SEND_BYTE
    JMP MAIN_LOOP


; ======================================================================
; == SUBROUTINE: RECEIVE_BYTE
; ======================================================================
RECEIVE_BYTE:

POLL_RX_READY:
    LDA UART_STATUS_REG
    ANI #MASK_RX_DATA_READY
    JZ POLL_RX_READY

    LDA UART_DATA_REG
    RET


; ======================================================================
; == SUBROUTINE: SEND_BYTE
; ======================================================================
SEND_BYTE:
    MOV A, B                            ; save A in B

POLL_TX_BUFFER:

    LDA UART_STATUS_REG                 ; load uart status reg
    ANI #MASK_TX_BUFFER_EMPTY           ; isolate buffer_empty bit
    JZ POLL_TX_BUFFER                   ; buffer_empty == 0 ? poll : send_BYTE
    
    MOV B, A                            ; reload A
    STA UART_DATA_REG                   ; send A
    RET
