; STA_MMIO.asm
; Integration test for STA instruction to MMIO addresses
; Tests memory-mapped I/O functionality and computer.sv address decoding

INCLUDE "../../programs/includes/mmio_defs.inc"

; ======================================================================
; == PROGRAM
; ======================================================================
    ORG $F000

START:
    ; =================================================================
    ; TEST 1: Store to UART_CONFIG_REG ($E000)
    ; Expected: Value should appear in UART peripheral config register
    ; =================================================================
    LDI A, #$55         ; A = $55 (test pattern)
    STA UART_CONFIG_REG ; Store to $E000 - UART configuration register

    ; =================================================================
    ; TEST 2: Store to UART_DATA_REG ($E002) 
    ; Expected: Value should appear in UART data register for transmission
    ; =================================================================
    LDI A, #$48         ; A = $48 ('H' character for potential UART output)
    STA UART_DATA_REG   ; Store to $E002 - UART data register

    ; =================================================================
    ; TEST 3: Store to UART_COMMAND_REG ($E003)
    ; Expected: Value should trigger UART command actions
    ; =================================================================
    LDI A, #$01         ; A = $01 (clear frame error command)
    STA UART_COMMAND_REG ; Store to $E003 - UART command register

    ; =================================================================
    ; TEST 4: Store to OUTPUT_PORT_1 ($E004) - LED Output
    ; Expected: Value should appear on LED output port visible on FPGA
    ; =================================================================
    LDI A, #$AA         ; A = $AA (10101010 pattern for LEDs)
    STA OUTPUT_PORT_1   ; Store to $E004 - LED output register

    ; =================================================================
    ; TEST 5: Store different pattern to OUTPUT_PORT_1
    ; Expected: LED pattern should change, demonstrating live update
    ; =================================================================
    LDI A, #$55         ; A = $55 (01010101 pattern for LEDs)
    STA OUTPUT_PORT_1   ; Store to $E004 - LED output register

    ; =================================================================
    ; TEST 6: Store to UART_STATUS_REG ($E001) - usually read-only
    ; Expected: Depends on implementation - may be ignored or cause side effects
    ; =================================================================
    LDI A, #$FF         ; A = $FF (test if status register accepts writes)
    STA UART_STATUS_REG ; Store to $E001 - UART status register

    ; =================================================================
    ; TEST 7: Store zero to OUTPUT_PORT_1 (turn off all LEDs)
    ; Expected: All LEDs should turn off
    ; =================================================================
    LDI A, #$00         ; A = $00 (all LEDs off)
    STA OUTPUT_PORT_1   ; Store to $E004 - LED output register

    ; =================================================================
    ; TEST 8: Store to multiple UART registers in sequence
    ; Expected: Each store should reach the correct UART register
    ; =================================================================
    LDI A, #$10         ; A = $10
    STA UART_CONFIG_REG ; Store to $E000
    
    LDI A, #$20         ; A = $20  
    STA UART_DATA_REG   ; Store to $E002
    
    LDI A, #$30         ; A = $30
    STA UART_COMMAND_REG ; Store to $E003

    ; =================================================================
    ; TEST 9: Register preservation test during MMIO operations
    ; Expected: B and C registers should remain unchanged during MMIO stores
    ; =================================================================
    LDI A, #$FF         ; A = $FF
    LDI B, #$11         ; B = $11 (should be preserved)
    LDI C, #$22         ; C = $22 (should be preserved)
    STA OUTPUT_PORT_1   ; Store to MMIO - registers should be preserved
    STA UART_CONFIG_REG ; Store to MMIO - registers should be preserved

    ; =================================================================
    ; TEST 10: Final LED pattern test
    ; Expected: Set final recognizable pattern on LEDs for visual verification
    ; =================================================================
    LDI A, #$F0         ; A = $F0 (11110000 pattern)
    STA OUTPUT_PORT_1   ; Store to $E004 - Final LED pattern

    ; =================================================================
    ; FINAL: Halt instruction to end test sequence
    ; =================================================================
    HLT                 ; End of test sequence