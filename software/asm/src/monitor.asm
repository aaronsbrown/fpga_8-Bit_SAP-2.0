INCLUDE "includes/mmio_defs.inc"


; ======================================================================
; CONSTANTS
; ======================================================================
SMC_LDA_ADDR    EQU $0200       ; beginning of general RAM
SMC_LDA_OPCODE  EQU $A0         ; opcode for LDA (load A with Mem contents) instruction
SMC_RET_OPCODE  EQU $19         ; opcode for RET (return) instruction


; ======================================================================
; == PROGRAM
; ======================================================================
    ORG $F000


START:

    JSR INIT
    JSR PRINT_WELCOME_MSG
    JSR MAIN_LOOP

    HLT


; ======================================================================
; == SUBROUTINE: INIT
; ======================================================================
INIT:
    
    LDI A, #SMC_LDA_OPCODE      ; load LDA op code to self-modifying code RAM block
    STA SMC_LDA_ADDR
    
    LDI A, #SMC_RET_OPCODE      ; load RET op code to self-modifying code RAM block
    STA SMC_LDA_ADDR + 3 
    
    welcome_message: DB "Hello!\n", 0           ; 48, 65, 6C, 6C, 6F, 21, 0A, 00
    welcome_message_addr: DW welcome_message 
    
    RET


; ======================================================================
; == SUBROUTINE:MAIN_LOOP
; ======================================================================
MAIN_LOOP:
    JSR RECEIVE_BYTE
    JSR SEND_BYTE
    JMP MAIN_LOOP               ; infinite loop


; ======================================================================
; == SUBROUTINE: PRINT_WELCOME_MSG
; ======================================================================
PRINT_WELCOME_MSG:
    
    LDI B, #LOW_BYTE(welcome_message_addr)

.loop
    ; load welcome_message_addr low byte into SMC_LDA_ADDR + 1
    MOV B, A
    STA SMC_LDA_ADDR + 1

    ; load welcome_message_addr high byte into SMC_LDA_ADDR + 2
    LDI A, #HIGH_BYTE(welcome_message_addr)
    STA SMC_LDA_ADDR + 2

    JSR SMC_LDA_ADDR        ; load A with (char) byte
    JSR SEND_BYTE           ; print byte

    LDI C, #$00             ; C = $00 (null terminator)
    CMP C                   ; if A = C
    JZ .return             ; return

    INR B ; icnrement B     ; else, increment B
    JMP .loop

.return:
    RET

; ======================================================================
; == SUBROUTINE: RECEIVE_BYTE
; ======================================================================
RECEIVE_BYTE:

POLL_RX_READY:
    LDA UART_STATUS_REG
    ANI #MASK_RX_DATA_READY
    JZ POLL_RX_READY

    LDA UART_DATA_REG
    RET


; ======================================================================
; == SUBROUTINE: SEND_BYTE
; ======================================================================
SEND_BYTE:
    PHA                                 ; save A to stack

POLL_TX_BUFFER:

    LDA UART_STATUS_REG                 ; load uart status reg
    ANI #MASK_TX_BUFFER_EMPTY           ; isolate buffer_empty bit
    JZ POLL_TX_BUFFER                   ; buffer_empty == 0 ? poll : send_BYTE
    
    PLA                                 ; reload A from stack
    STA UART_DATA_REG                   ; send A
    RET
