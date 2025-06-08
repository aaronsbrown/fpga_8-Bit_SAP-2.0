; ===========================================================================
; Program:      Simple Monitor Program (monitor.asm)
; Author:       Aaron Brown
; Version:      0.1 
; CPU:          FPGA_8-Bit_SAP2 (Custom 8-bit CPU)
; Assembler:    Custom Python Assembler
;
; Description:
; -------------
; This program implements a very basic monitor for the custom 8-bit CPU.
; Upon startup, it initializes a Self-Modifying Code (SMC) zone in RAM
; used for indirect memory reads (simulating LDA (BC) functionality).
; It then displays a welcome message and a secondary message to the UART,
; with a "typed character" delay effect between characters.
; After displaying messages, it enters an infinite echo loop, where any
; character received via UART is immediately sent back to the UART.
;
; The program starts execution at ROM address $F000, assuming the CPU's
; Program Counter is initialized to this address (e.g., via a static
; reset mechanism).
;
; Key Features:
;   - UART output for displaying messages.
;   - UART input for character echoing.
;   - Self-Modifying Code (SMC) to read string data from ROM.
;   - Programmable inter-character delay for "typed" output effect.
;
; Memory Usage:
;   - Program Code & Data: Resides in ROM starting at $F000.
;   - SMC Zone: Uses RAM addresses $0200-$0203 for dynamic LDA instruction.
;   - Delay Counter: Uses RAM addresses $0204-$0205 for the 16-bit delay timer.
;   - Stack: Uses RAM (descending from SP_VECTOR, e.g., $01FF).
;
; Included Files:
;   - "includes/mmio_defs.inc": Memory-Mapped I/O address definitions.
;   - "includes/routines_uart.inc": Contains PRINT_STRING, SEND_BYTE, RECEIVE_BYTE.
;   - "includes/routines_delay.inc": Contains DELAY_16BIT.
;
; To Assemble (Example):
;   python assembler.py monitor.asm output_dir --region ROM F000 FFFF
;
; Future Enhancements / To-Do:
;   - Implement command parsing.
;   - Add commands: PEEK, POKE, JUMP_TO_ADDRESS, DUMP_MEMORY, etc.
;   - More robust line input with editing (backspace).
; ===========================================================================

INCLUDE "includes/mmio_defs.inc"

; ======================================================================
; CONSTANTS
; ======================================================================

ASCII_NULL      EQU $00
ASCII_BELL      EQU $07
ASCII_BACKSPACE EQU $08
ASCII_LF        EQU $0A
ASCII_CR        EQU $0D
ASCII_SPACE     EQU $20

OPCODE_RET  EQU $19                         ; opcode for RET (return) instruction
OPCODE_LDA  EQU $A0                         ; opcode for LDA (load A with Mem contents) instruction
OPCODE_STA  EQU $A1

; --- self-modifying code zones ---
SMC_LDA_ADDR    EQU $0200                       ; beginning of general RAM 
SMC_LDA_SIZE    EQU 4

SMC_STA_ADDR    EQU (SMC_LDA_ADDR + SMC_LDA_SIZE)   
SMC_STA_SIZE    EQU 4

; --- read line sub-routine data ---
RL_BUF_ADDR   EQU (SMC_STA_ADDR + SMC_STA_SIZE)
RL_BUF_SIZE   EQU 64

RL_CHAR_COUNT_ADDR       EQU (RL_BUF_ADDR + RL_BUF_SIZE)
RL_CHAR_COUNT_SIZE       EQU 1
RL_MAX_CHAR_COUNT        EQU (RL_BUF_SIZE - 1)

; --- character print delay --- 
DELAY_LOW_ADDR    EQU (RL_CHAR_COUNT_ADDR + RL_CHAR_COUNT_SIZE)    ; address for delay counter, low 
DELAY_HIGH_ADDR   EQU DELAY_LOW_ADDR + 1    ; address for delay counter, high

DELAY_INIT_LOW     EQU $00                              ; counter init value, low
DELAY_INIT_HIGH    EQU $30                              ; counter init value, high

; ======================================================================
; == PROGRAM START AND MAIN CODE
; ======================================================================
    ORG $F000                                   ; establish base memory address for ROM MMIO

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
    
    LDI A, #OPCODE_LDA                      ; load LDA op code to self-modifying code RAM block
    STA SMC_LDA_ADDR
    
    LDI A, #OPCODE_RET                      ; load RET op code to self-modifying code RAM block
    STA SMC_LDA_ADDR + 3 

    LDI A, #OPCODE_STA
    STA SMC_STA_ADDR

    LDI A, #OPCODE_RET
    STA SMC_STA_ADDR + 3

    RET
      
; ======================================================================
; == SUBROUTINE:MAIN_LOOP
; ======================================================================
MAIN_LOOP:

    ; --- send prompt ---
    LDI A, '>'
    JSR SEND_BYTE
    LDI A, ASCII_SPACE
    JSR SEND_BYTE

    ; --- read line of user input ---
    JSR READ_LINE

    ; --- TODO: parse and execute command

    ; --- debug: echo received string
    LDI C, #LOW_BYTE(RL_BUF_ADDR)
    LDI B, #HIGH_BYTE(RL_BUF_ADDR)
    JSR PRINT_STRING
    LDI A, #ASCII_CR
    JSR SEND_BYTE
    LDI A, #ASCII_LF
    JSR SEND_BYTE


    JMP MAIN_LOOP               ; infinite loop

; ======================================================================
; == SUBROUTINE: PRINT_WELCOME_MSG
; ======================================================================
PRINT_WELCOME_MSG:

                                                ; -- load string pointer
    LDI C, #LOW_BYTE(welcome_message)           ; C = low bytes of string start address
    LDI B, #HIGH_BYTE(welcome_message)          ; B = high bytes of string start address
    JSR PRINT_STRING
    RET

; ======================================================================
; == SUBROUTINE: PRINT_WG_MSG
; ======================================================================
PRINT_WG_MSG:

                                                ; -- load string pointer
    LDI C, #LOW_BYTE(wargame_message)           ; C = low bytes of string start address
    LDI B, #HIGH_BYTE(wargame_message)          ; B = high bytes of string start address
    JSR PRINT_STRING
    RET

; ======================================================================
; == SUBROUTINE INCLUDES
; ======================================================================
INCLUDE "includes/routines_uart.inc"
INCLUDE "includes/routines_delay.inc"

; ======================================================================
; == CONSTANT DATA
; ======================================================================
welcome_message: DB "ASB Monitor v0.1\n", 0           
wargame_message: DB "Shall we play a game?\n", 0