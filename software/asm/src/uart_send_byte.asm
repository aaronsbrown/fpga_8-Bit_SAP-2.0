; uart_send_byte.asm
INCLUDE "includes/mmio_defs.inc"

; --- Code Section ---
    ORG $F000

SEND_UART_BYTE:

TX_POLL_LOOP:
    LDA UART_STATUS_REG
    ANI #MASK_TX_BUFFER_EMPTY
    JZ TX_POLL_LOOP ; 

    LDI A, #$41
    STA UART_DATA_REG
    HLT