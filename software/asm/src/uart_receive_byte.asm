; uart_send_byte.asm
INCLUDE "includes/mmio_defs.inc"

; --- Code Section ---
    ORG $F000

RECEIVE_UART_BYTE:

RX_POLL_LOOP:
    LDA UART_STATUS_REG
    ANI #MASK_RX_DATA_READY
    JZ RX_POLL_LOOP ; 

    LDA UART_DATA_REG
    HLT