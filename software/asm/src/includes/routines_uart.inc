; ======================================================================
; == SUBROUTINE: PRINT_STRING
; == Purpose: Prints a null-terminated string pointed to by BC,
; ==          with an inter-character delay.
; == Input:   BC = 16-bit start address of the string.
; ==          CHAR_PRINT_DELAY_COUNT_LOW_ADDR, CHAR_PRINT_DELAY_COUNT_HIGH_ADDR (RAM locations) should be
; ==          pre-set by this routine or its caller to control the
; ==          delay between characters. A value of $0000 or $0001 in
; ==          DELAY_COUNT_HIGH:DELAY_COUNT_LOW will result in minimal delay.
; == Clobbers: A, Flags. Modifies BC. Uses SMC_LDA_ADDR.
; ======================================================================
PRINT_STRING:

.loop:

    MOV C, A                         
    STA (SMC_LDA_ADDR + 1)              ; Store low byte at self-modifying code operand address + 1

    MOV B, A
    STA (SMC_LDA_ADDR + 2)              ; Store high byte at self-modifying code operand address + 2

    ; ====== BEG A_SAFE ====== 
    JSR SMC_LDA_ADDR                    ; ***SETS A*** execute self-modifying code op: A = LDA[BC]
    
    ORI #0                              ; A | 0 = 0? 
    JZ .finished                        ; if Z = 1, we're finished

    JSR SEND_BYTE                       ; assumed A = byte to send
    ; ==== END A_SAFE ====

    ; -- set timer
    LDI A, #CHAR_PRINT_DELAY_COUNT_LOW_VAL
    STA CHAR_PRINT_DELAY_COUNT_LOW_ADDR
    LDI A, #CHAR_PRINT_DELAY_COUNT_HIGH_VAL
    STA CHAR_PRINT_DELAY_COUNT_HIGH_ADDR

    JSR DELAY_16BIT                     ; delay for aesthetics

    INR C                               ; increment LOW BYTE of string pointer
    JNZ .loop                           ; if not, loop
    INR B                               ; if so, increment B
    JMP .loop                           ; loop

.finished:
    RET


; ======================================================================
; == SUBROUTINE: RECEIVE_BYTE
; == Purpose: Waits for and reads a single byte from the UART.
; == Input:   None (implicitly polls UART hardware).
; == Output:  Accumulator A = Received byte from UART.
; == Clobbers: Accumulator A, Flags (Z, N due to LDA/ANI).
; == Assumes: UART_STATUS_REG, UART_DATA_REG, MASK_RX_DATA_READY are
; ==          correctly defined EQUates pointing to MMIO.
; ======================================================================
RECEIVE_BYTE:

.poll_rx_ready:
    LDA UART_STATUS_REG
    ANI #MASK_RX_DATA_READY
    JZ .poll_rx_ready

    LDA UART_DATA_REG
    RET


; ======================================================================
; == SUBROUTINE: SEND_BYTE
; == Purpose: Sends a single byte to the UART.
; == Input:   Accumulator A = Byte to be transmitted.
; == Output:  None (byte is sent via UART).
; == Clobbers: Accumulator A (temporarily, restored from stack), Flags.
; ==          Uses stack space (PHA/PLA).
; == Assumes: UART_STATUS_REG, UART_DATA_REG, MASK_TX_BUFFER_EMPTY are
; ==          correctly defined EQUates pointing to MMIO.
; ==          Stack Pointer (SP) is initialized and valid.
; ======================================================================
SEND_BYTE:
    PHA                                     ; save A to stack

.poll_tx_buffer:

    LDA UART_STATUS_REG                     ; load uart status reg
    ANI #MASK_TX_BUFFER_EMPTY               ; isolate buffer_empty bit
    JZ .poll_tx_buffer                      ; buffer_empty == 0 ? poll : send_BYTE
    
    PLA                                     ; reload A from stack
    STA UART_DATA_REG                       ; send A
    RET