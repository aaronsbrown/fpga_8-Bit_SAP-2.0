; simple_tx_test.asm

INCLUDE "includes/mmio_defs.inc"

; ======================================================================
; == VECTORS TABLE
; ======================================================================
    ORG $FFFC
    DW START           ; Reset Vector points to START label


; ======================================================================
; == CONSTANTS
; ======================================================================
CHAR_TO_SEND EQU $55 ; ASCII for 'U' is $55


; ======================================================================
; == PROGRAM
; ======================================================================
    ORG $F000


START:
    ; Optional: Initial clear of UART errors
    LDI A, #UART_CMD_CLEAR_FRAME_ERROR
    STA UART_COMMAND_REG
    LDI A, #UART_CMD_CLEAR_OVERSHOOT_ERROR
    STA UART_COMMAND_REG

SEND_LOOP:
TX_POLL:
    LDA UART_STATUS_REG
    ANI #MASK_TX_BUFFER_EMPTY
    JZ TX_POLL
    LDI A, #CHAR_TO_SEND
    STA UART_DATA_REG

    ; Simple delay to make characters distinguishable
    LDI C, #$FF
DELAY_OUTER:
    LDI B, #$FF
DELAY_INNER:
    DCR B
    JNZ DELAY_INNER
    DCR C
    JNZ DELAY_OUTER

    JMP SEND_LOOP ; Continuously send 'U'