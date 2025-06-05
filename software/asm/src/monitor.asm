INCLUDE "includes/mmio_defs.inc"

; ======================================================================
; == VECTORS TABLE
; ======================================================================
    ORG $FFFC
    DW START            ; Reset Vector points to START label


; ======================================================================
; CONSTANTS
; ======================================================================
ASCII_O     EQU $4F
ASCII_K     EQU $4B


; ======================================================================
; == PROGRAM
; ======================================================================
    ORG $F000


START:
    LDI A, #ASCII_O
    JSR SEND_CHAR

    LDI A, #ASCII_K
    JSR SEND_CHAR

    HLT

; ======================================================================
; == SUBROUTINE: SEND_CHAR
; ======================================================================
SEND_CHAR:

    MOV A, B                            ; save A in B

POLL_TX_BUFFER:

    LDA UART_STATUS_REG                 ; load uart status reg
    ANI #MASK_TX_BUFFER_EMPTY           ; isolate buffer_empty bit
    JZ POLL_TX_BUFFER                   ; buffer_empty == 0 ? poll : send_char
    
    MOV B, A                            ; reload A
    STA UART_DATA_REG                   ; send A
    RET
