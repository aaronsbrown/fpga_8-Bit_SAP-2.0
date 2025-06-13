; uart_send_byte.asm
INCLUDE "../../programs/includes/mmio_defs.inc"

; ======================================================================
; == PROGRAM
; ======================================================================
    ORG $F000


START:

TX_POLL_LOOP:
    LDA UART_STATUS_REG
    ANI #MASK_TX_BUF_EMPTY
    JZ TX_POLL_LOOP ; 

    LDI A, #$41
    STA UART_DATA_REG
    HLT