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
    JSR PRINT_WG_MSG
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
    
    RET
    
    
; ======================================================================
; == DATA
; ======================================================================
welcome_message: DB "ASB Monitor v0.1>\n", 0           
wg_message: DB "Shall we play a game?\n", 0
    

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

    LDI C, #LOW_BYTE(welcome_message)       ; C = low bytes of string start address
    LDI B, #HIGH_BYTE(welcome_message)      ; B = high bytes of string start address
    JSR PRINT_STRING
    RET


; ======================================================================
; == SUBROUTINE: PRINT_WG_MSG
; ======================================================================
PRINT_WG_MSG:

    LDI C, #LOW_BYTE(wg_message)       ; C = low bytes of string start address
    LDI B, #HIGH_BYTE(wg_message)      ; B = high bytes of string start address
    JSR PRINT_STRING
    RET



; ======================================================================
; == SUBROUTINE: PRINT_STRING
; ======================================================================
PRINT_STRING:

.loop:

    MOV C, A                         
    STA (SMC_LDA_ADDR + 1)          ; Store low byte at self-modifying code operand address + 1

    MOV B, A
    STA (SMC_LDA_ADDR + 2)          ; Store high byte at self-modifying code operand address + 2

    ; ====== A_SAFE ====== 
    JSR SMC_LDA_ADDR                ; ***SETS A*** execute self-modifying code op: A = LDA[BC]
    
    ORI #0                          ; A | 0 = 0? 
    JZ .finished                    ; if Z = 1, we're finished

    JSR SEND_BYTE                   ; assumed A = byte to send
    ; ==== END A_SAFE ====

    INR C                           ; increment LOW BYTE of string pointer
    JNZ .loop                       ; if not, loop
    INR B                           ; if so, increment B
    JMP .loop                       ; loop


.finished:
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
