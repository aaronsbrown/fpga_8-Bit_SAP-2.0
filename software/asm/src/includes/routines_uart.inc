; ======================================================================
; SUBROUTINE: READ_LINE
; Purpose: Reads a character-by-character input from UART until Enter
;          is pressed, storing it in a buffer with basic editing.
; (Keep your detailed Doxygen-style block here from before, it's good)
; ======================================================================
READ_LINE:
    ; --- Phase 1: Initialization ---
    ; Set up your starting buffer pointer (e.g., using B and C for address parts).
    ; Initialize your character count (likely in a RAM location) to zero.
    LDI B, HIGH_BYTE(RL_BUF_ADDR)
    LDI C, LOW_BYTE(RL_BUF_ADDR)
    LDI A, #0
    STA RL_CHAR_COUNT_ADDR


.INPUT_LOOP_START:
    ; --- Phase 2: Get Character ---
    ; Wait for and receive a single character from the UART into Accumulator A.

    ; --- Phase 3: Decode Character Type ---
    ; Based on the character in A, decide what it is:
    ;   - Is it the 'End of Line' character (e.g., Carriage Return)?
    ;   - Is it the 'Backspace' character?
    ;   - Or is it a 'Regular Printable Character'?

    ; --- Phase 4A: Handle 'End of Line' ---
    ; If CR:
    ;   Echo appropriate new line sequence to terminal (e.g., CR then LF).
    ;   Store a 'null terminator' (0) at the current buffer position.
    ;   Consume any trailing LF from the terminal.
    ;   This line is complete: Return from READ_LINE subroutine.

    ; --- Phase 4B: Handle 'Backspace' ---
    ; If Backspace:
    ;   Check if there are any characters in the buffer to delete (is count > 0?).
    ;   If yes:
    ;     Decrement the character count.
    ;     Move the buffer pointer back one position.
    ;     Send the "erase character" sequence (BS, Space, BS) to the terminal.
    ;   If no characters to delete, do nothing.
    ;   Go back to .INPUT_LOOP_START to get the next character.

    ; --- Phase 4C: Handle 'Regular Printable Character' ---
    ; If it's a regular character:
    ;   Check if the buffer has space for this character (is count < max_buffer_size - 1?).
    ;   If yes (space available):
    ;     Increment the character count.
    ;     Echo the character to the terminal.
    ;     Store the character at the current buffer position.
    ;     Advance the buffer pointer to the next position.
    ;   If no (buffer full):
    ;     Ignore the character (optional: provide user feedback like a 'bell').
    ;   Go back to .INPUT_LOOP_START to get the next character.

    ; Should always loop back or return from EOL, so a RET here is likely an error path or unreachable.
    JMP .INPUT_LOOP_START ; Or RET if structured differently


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
    JSR SMC_LDA_ADDR                    ; ***SETS A*** execute self-modifying code op: A = LDA[BC]
    
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