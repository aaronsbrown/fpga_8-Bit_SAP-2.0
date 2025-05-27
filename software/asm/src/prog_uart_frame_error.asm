; uart_frame_error.asm
INCLUDE "includes/mmio_defs.inc"

; -- Constants --
FRAME_ERROR_CODE EQU $EE

; --- Code Section ---
    ORG $F000

TEST_FRAME_ERROR:

RX_POLL_LOOP:
    LDA UART_STATUS_REG         ; load status register
    ANI #MASK_RX_DATA_READY     ; bit test data ready flag
    JZ RX_POLL_LOOP             ; if not ready, loop

DATA_READY:
    LDA UART_STATUS_REG         ; Reload Status Reg
    ANI #MASK_ERROR_FRAME       ; bit test frame error
    JNZ LOG_ERROR               ; if error, log it

    LDA UART_DATA_REG           ; if no error, load data to reg A
    JMP DONE

LOG_ERROR:
    LDI A, #FRAME_ERROR_CODE     ; load error code into reg A
    STA OUTPUT_PORT_1           ; write error code to ouput 1
    LDA UART_DATA_REG           ; clear data-ready status
    
    LDI A, #UART_CMD_CLEAR_FRAME_ERROR 
    STA UART_COMMAND_REG


DONE:
   JMP RX_POLL_LOOP             ; wait for next byte 