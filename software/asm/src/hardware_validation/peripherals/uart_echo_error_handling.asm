; uart_echo_error_handling.asm
INCLUDE "../../programs/includes/mmio_defs.inc"

; ======================================================================
; == CONSTANTS
; ======================================================================
ERROR_CODE_FRAME        EQU $08
ERROR_CODE_OVERSHOOT    EQU $09


; ======================================================================
; == PROGRAM
; ======================================================================
    ORG $F000


START:

; --- startup and reset ---
LDI A, #UART_CMD_CLEAR_FRAME_ERROR
STA UART_COMMAND_REG

LDI A, #UART_CMD_CLEAR_OVERSHOOT_ERROR
STA UART_COMMAND_REG

LDA UART_DATA_REG                
; --- end start up & reset ---


; --- ADD SHORT DELAY ---
LDI B, #$10 ; Small delay, e.g., 16 iterations
INIT_DELAY_LOOP:
    DCR B
    JNZ INIT_DELAY_LOOP
; --- END SHORT DELAY ---

START_ECHO:

RX_POLL_LOOP:
    LDA UART_STATUS_REG         ; Load status register
    MOV A, B

    ; frame error
    ANI #MASK_ERROR_FRAME
    JNZ HANDLE_FRAME_ERROR

    ; overshoot error
    MOV B, A
    ANI #MASK_ERROR_OVERSHOOT
    JNZ HANDLE_OVERSHOOT_ERROR

    ; data ready
    MOV B, A
    ANI #MASK_RX_DATA_READY     ; bit test for data ready
    JZ RX_POLL_LOOP             ; if no data ready, loop 

    LDA UART_DATA_REG           ; if data ready, load data from Data Reg into A
    MOV A, C                    ; move A => C

TX_POLL_LOOP:
    LDA UART_STATUS_REG         ; Load status register
    ANI #MASK_TX_BUF_EMPTY   ; bit test for empty send buffer
    JZ TX_POLL_LOOP             ; if buffer full, loop

    MOV C, A                    ; move C => A
    STA UART_DATA_REG           ; if buffer empty, send value in Reg A
    JMP RX_POLL_LOOP            ; wait for next byte

HANDLE_FRAME_ERROR:
    LDI A, #ERROR_CODE_FRAME
    STA OUTPUT_PORT_1

    LDI A, #UART_CMD_CLEAR_FRAME_ERROR
    STA UART_COMMAND_REG

    LDA UART_DATA_REG
    JMP RX_POLL_LOOP

HANDLE_OVERSHOOT_ERROR:
    LDI A, #ERROR_CODE_OVERSHOOT
    STA OUTPUT_PORT_1

    LDI A, #UART_CMD_CLEAR_OVERSHOOT_ERROR
    STA UART_COMMAND_REG

    LDA UART_DATA_REG
    JMP RX_POLL_LOOP