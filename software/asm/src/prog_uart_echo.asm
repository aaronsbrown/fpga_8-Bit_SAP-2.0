; uart_send_byte.asm
INCLUDE "includes/mmio_defs.inc"

; --- Code Section ---
    ORG $F000

START_ECHO:
RX_POLL_LOOP:
    LDA UART_STATUS_REG         ; Load status register
    ANI #MASK_RX_DATA_READY     ; bit test for data ready
    JZ RX_POLL_LOOP             ; if no data ready, loop 

    LDA UART_DATA_REG           ; if data ready, load data from Data Reg into A
    MOV A, B                    ; move A => B


TX_POLL_LOOP:
    LDA UART_STATUS_REG         ; Load status register
    ANI #MASK_TX_BUFFER_EMPTY   ; bit test for empty send buffer
    JZ TX_POLL_LOOP             ; if buffer full, loop

    MOV B, A                    ; move B => A
    STA UART_DATA_REG           ; if buffer empty, send value in Reg A
    JMP RX_POLL_LOOP            ; wait for next byte

