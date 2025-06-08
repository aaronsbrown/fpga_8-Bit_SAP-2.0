; ======================================================================
; SUBROUTINE: READ_LINE
; Purpose: Reads a character-by-character input from UART until Enter
;          is pressed, storing it in a buffer with basic editing.
; (Keep your detailed Doxygen-style block here from before, it's good)
; ======================================================================
READ_LINE:
    
    ; ----------------------
    ; --- initialization ---
    ; ----------------------
    LDI C, #LOW_BYTE(RL_BUF_ADDR)
    LDI B, #HIGH_BYTE(RL_BUF_ADDR)
    
    LDI A, #0
    STA RL_CHAR_COUNT_ADDR                      ; init character count = 0


.INPUT_LOOP_START:

    ; receive and decode byte
    JSR RECEIVE_BYTE                            ; A = received UART byte
    PHA                                         ; save received byte
    
    XRI #ASCII_CR                               ; Test for carriage return (CR)
    JZ .HANDLE_EOL
    
    PLA
    PHA
    XRI #ASCII_BACKSPACE                        ; Test for backspace
    JZ .HANDLE_BACKSPACE


    ; --------------------
    ; --- regular char ---
    ; --------------------
.HANDLE_REG_CHAR:

    PHA                                         ; push new_char

    ; check buffer vacancy
    LDA RL_CHAR_COUNT_ADDR                      ; A = char_count
    PHA                                         ; push char_count
    XRI #RL_MAX_CHAR_COUNT                      ; char_count == max_count
    JZ .BUFFER_FULL                             ; if string_buff full, ring bell

.BUFFER_HAS_SPACE:
    PLA                                         ; pop char_count
    INR A                                       ; increment char_count
    STA RL_CHAR_COUNT_ADDR                      ; save char_count

    PLA                                         ; pop new_char
    JSR SEND_BYTE                               ; echo char
    PHA                                         ; push new_char
    
    ; set up self-modifying code
    MOV C, A
    STA (SMC_STA_ADDR + 1)

    MOV B, A
    STA (SMC_STA_ADDR + 2)
    
    ; execute SMC code
    PLA                                         ; pop new_char
    JSR SMC_STA_ADDR                            ; execute STA instruction                          

    ; increment string_buff
    INR C                                       ; increment string_buff low byte
    JNZ .INPUT_LOOP_START                       ; check for rollover
    INR B                                       ; if rollover, increment high byte
    JMP .INPUT_LOOP_START                       ; wait for next byte

.BUFFER_FULL:
    PLA                                         ; Pop char_count
    PLA                                         ; Pop new_char
    LDI A, #ASCII_BELL  
    JSR SEND_BYTE
    JMP .INPUT_LOOP_START                        ; buffer full, ignore character and loop


    ; -------------------
    ; --- 'Backspace' ---
    ; -------------------
.HANDLE_BACKSPACE:

    PLA                                         ; ensure received byte in A

    ; -- is buffer empty?
    LDA RL_CHAR_COUNT_ADDR                      ; load char_count
    ORI #0                                      ; char_count = 0?
    JNZ .delete_char                            ; if no, handle deletion, 
    JMP .INPUT_LOOP_START                       ; if yes, return to main_loop
    
.delete_char:
    
    ; -- decrement character count
    DCR A                                       ; decrement char_count
    STA RL_CHAR_COUNT_ADDR                      ; save char_count

    ; decrement string_buff 
    DCR C                                       ; decrement string_buff low byte
    MOV C, A                                    ; move C => A
    XRI #$FF                                    ; check for rollunder
    JNZ .send_erase_sequence                    ; if NO rollunder, jump to erase_sequence
    DCR B                                       ; if rollunder, decrement high byte
    
.send_erase_sequence:
    LDI A, #ASCII_BACKSPACE
    JSR SEND_BYTE
    LDI A, #ASCII_SPACE
    JSR SEND_BYTE
    LDI A, #ASCII_BACKSPACE
    JSR SEND_BYTE

    JMP .INPUT_LOOP_START

    ; ------------------
    ; --- end of line ---
    ; ------------------
.HANDLE_EOL:
    
    PLA                                         ; ensure received byte in A

    ; read LF byte
    JSR RECEIVE_BYTE                            ; consume LF from terminal and ignore
    
    ; send EOL sequence
    LDI A, #ASCII_CR                            ; echo new line sequence CR, LF
    JSR SEND_BYTE
    LDI A, #ASCII_LF
    JSR SEND_BYTE

    ; setup self-modifying code   
    MOV C, A                                    ; store string_buff low at STA addr + 1
    STA (SMC_STA_ADDR + 1)

    MOV B, A                                    ; store string_buff high at STA addr + 2
    STA (SMC_STA_ADDR + 2)

    ; store null terminator
    LDI A, #ASCII_NULL                          ; A = null terminator
    JSR SMC_STA_ADDR                            ; execute STA instruction: M[BC] = A
    
    ; we're done
    RET


; ======================================================================
; == SUBROUTINE: PRINT_STRING
; == Purpose: Prints a null-terminated string pointed to by BC,
; ==          with an inter-character delay.
; == Input:   BC = 16-bit start address of the string.
; ==          DELAY_LOW_ADDR, DELAY_HIGH_ADDR (RAM locations) should be
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
    JSR SMC_LDA_ADDR                    ; execute LDA instruction: A = M[BC]
    
    ORI #0                              ; A | 0 = 0? 
    JZ .finished                        ; if Z = 1, we're finished

    JSR SEND_BYTE                       ; assumed A = byte to send
    ; ==== END A_SAFE ====

    ; -- set timer
    LDI A, #DELAY_INIT_LOW
    STA DELAY_LOW_ADDR
    LDI A, #DELAY_INIT_HIGH
    STA DELAY_HIGH_ADDR

    JSR DELAY_16BIT                     ; delay for aesthetics

    INR C                               ; increment LOW BYTE of string pointer
    JNZ .loop                           ; if not = 0 (no rollover), so loop
    INR B                               ; if = 0 (rolled over), increment B
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
; == Assumes: UART_STATUS_REG, UART_DATA_REG, MASK_TX_BUF_EMPTY are
; ==          correctly defined EQUates pointing to MMIO.
; ==          Stack Pointer (SP) is initialized and valid.
; ======================================================================
SEND_BYTE:
    PHA                                     ; save A to stack

.poll_tx_buffer:

    LDA UART_STATUS_REG                     ; load uart status reg
    ANI #MASK_TX_BUF_EMPTY               ; isolate buffer_empty bit
    JZ .poll_tx_buffer                      ; buffer_empty == 0 ? poll : send_BYTE
    
    PLA                                     ; reload A from stack
    STA UART_DATA_REG                       ; send A
    RET