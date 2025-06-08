; uart_send_byte.asm
INCLUDE "includes/mmio_defs.inc"

; ======================================================================
; == VECTORS TABLE
; ======================================================================
    ORG $FFFC
    DW START           ; Reset Vector points to START label


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