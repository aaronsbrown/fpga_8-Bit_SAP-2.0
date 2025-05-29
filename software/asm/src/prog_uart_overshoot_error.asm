; uart_frame_error.asm
INCLUDE "includes/mmio_defs.inc"

; -- Constants --
OVERSHOOT_ERROR_CODE EQU $66

; --- Code Section ---
    ORG $F000

START:

RX_POLL_LOOP_NO_READ:
    LDA UART_STATUS_REG             ; load status register
    ANI #MASK_RX_DATA_READY         ; bit test data ready flag
    JZ RX_POLL_LOOP_NO_READ        ; if not ready, loop

; --- START DELAY LOOP ---

    LDI C, #$01

DELAY_OUTER_LOOP:
    LDI B, #$6F

DELAY_INNER_LOOP:
    DCR B
    JNZ DELAY_INNER_LOOP

    DCR C
    JNZ DELAY_OUTER_LOOP

; --- END DELAY LOOP ---

RX_POLL_LOOP_READ:
    LDA UART_STATUS_REG
    MOV A, B

    ANI #MASK_ERROR_OVERSHOOT
    JNZ HANDLE_OVERSHOOT_ERROR

    MOV B, A
    ANI #MASK_RX_DATA_READY
    LDA UART_DATA_REG
    JMP DONE 

HANDLE_OVERSHOOT_ERROR:
    LDI A, #OVERSHOOT_ERROR_CODE            ; load error code into reg A
    STA OUTPUT_PORT_1                   ; write error code to ouput 1
    
    LDI A, #UART_CMD_CLEAR_OVERSHOOT_ERROR  ; load clear frame error cmd
    STA UART_COMMAND_REG                ; execute command, fall through to read data

READ_DATA:  
    LDA UART_DATA_REG           ; read data and clear ready status

DONE:
   JMP DONE             ; wait for next byte 