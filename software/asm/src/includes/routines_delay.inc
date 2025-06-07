; ======================================================================
; SUBROUTINE: DELAY_16BIT
; Purpose: Creates a programmable delay by counting down a 16-bit value
;          stored in dedicated RAM locations.
; Input:   The RAM locations CHAR_PRINT_DELAY_COUNT_HIGH_ADDR and
;          CHAR_PRINT_DELAY_COUNT_LOW_ADDR must be pre-loaded by the
;          caller with the desired 16-bit starting count for the delay.
;          Example: For max delay, HighAddr=$FF, LowAddr=$FF.
;          A count of $0000 or $0001 will result in minimal delay.
; Output:  None (time is consumed).
; Clobbers: Accumulator A, Processor Flags (Z, N, C).
;          Does not modify registers B or C.
; Assumes: CHAR_PRINT_DELAY_COUNT_HIGH_ADDR and
;          CHAR_PRINT_DELAY_COUNT_LOW_ADDR are valid EQUates pointing
;          to two distinct, writable RAM locations.
; ======================================================================
DELAY_16BIT:
    
.delay_loop:
    
    ; -- Step 1: Decrement the 16-bit counter (HighByte:LowByte) --
    LDA CHAR_PRINT_DELAY_COUNT_LOW_ADDR                    ; Load and decrement LOW BYTE  
    DCR A
    STA CHAR_PRINT_DELAY_COUNT_LOW_ADDR

                                                ; See if we counted down from 00 -> FF
    XRI #$FF                                    ; Z = 0 if A = $FF, means we wrapped from $00 -> $FF
    JNZ .check_if_delay_finished                ; if we didn't wrap, jump to 'check if finished'

    LDA CHAR_PRINT_DELAY_COUNT_HIGH_ADDR                   ; if we did wrap, possibly decrement HIGH byte
    ORI #$00                                    ; check if HIGH BYTE already zero
    JZ .check_if_delay_finished 
    
    DCR A
    STA CHAR_PRINT_DELAY_COUNT_HIGH_ADDR

    

.check_if_delay_finished:
    ; -- Step 2: Check if the 16-bit counter has reached zero --

    ; -- Check HIGH BYTE == 0
    LDA CHAR_PRINT_DELAY_COUNT_HIGH_ADDR
    ORI #0                                      ; Z=1 if HIGH_BYTE = 0
    JNZ .delay_loop                             ; Loop if HIGH_BYTE != 0 (Z=0)

    ; -- Check LOW BYTE == 0
    LDA CHAR_PRINT_DELAY_COUNT_LOW_ADDR
    ORI #0                                      ; Z=1 if LOW_BYTE = 0
    JNZ .delay_loop                             ; Loop if LOW_BYTE != 0 (Z=0)
                
    ; -- COUNTER IS ZERO!
    RET