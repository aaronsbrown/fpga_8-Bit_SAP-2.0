; uart_frame_error.asm
INCLUDE "includes/mmio_defs.inc"

; ======================================================================
; == CONSTANTS
; ======================================================================
FRAME_ERROR_CODE EQU $EE


; ======================================================================
; == PROGRAM
; ======================================================================
    ORG $F000


START:

RX_POLL_LOOP:
    LDA UART_STATUS_REG         ; load status register
    MOV A, B

    ANI #MASK_ERROR_FRAME       ; bit test frame error 
    JNZ LOG_ERROR               ; if error, log it 
    
    MOV B, A
    ANI #MASK_RX_DATA_READY     ; bit test data ready flag
    JNZ READ_DATA               ; if data ready, process
    JMP RX_POLL_LOOP            ; if not ready, loop

LOG_ERROR:
    LDI A, #FRAME_ERROR_CODE            ; load error code into reg A
    STA OUTPUT_PORT_1                   ; write error code to ouput 1
    LDI A, #UART_CMD_CLEAR_FRAME_ERROR  ; load clear frame error cmd
    STA UART_COMMAND_REG                ; execute command, fall through to read data

READ_DATA:  
    LDA UART_DATA_REG           ; read data and clear ready status

DONE:
   JMP START             ; wait for next byte 