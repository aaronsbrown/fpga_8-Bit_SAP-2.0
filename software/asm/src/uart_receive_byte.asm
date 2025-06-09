; uart_send_byte.asm
INCLUDE "includes/mmio_defs.inc"

; ======================================================================
; == PROGRAM
; ======================================================================
    ORG $F000


START:

RX_POLL_LOOP:
    LDA UART_STATUS_REG
    ANI #MASK_RX_DATA_READY
    JZ RX_POLL_LOOP ; 

    LDA UART_DATA_REG
    HLT