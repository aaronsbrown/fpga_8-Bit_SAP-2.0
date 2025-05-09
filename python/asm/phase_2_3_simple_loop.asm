; test_phase2_simple_loop.asm
; Tests a common loop structure using a counter and JNZ.
; Primarily verifies label resolution for a backward jump in a loop context.

            ORG $B100

; Constants
INITIAL_COUNT   EQU 5       ; How many times the loop should (conceptually) iterate
LED_PORT        EQU $E000   ; Conceptual output port

start_program:
            LDI B, #INITIAL_COUNT ; Load counter into register B

loop_start:
            ; Body of the loop
            LDI A, #$CC     ; Load some value into A (loop body activity)
            STA LED_PORT    ; Output it (conceptual)
            ADD B           ; Add B to A (just some ALU op in the loop, A = A+B)
            STA LED_PORT    ; Output new A

            ; Loop control
            DCR B           ; Decrement counter in B. This affects Zero flag.
            JNZ loop_start  ; If B is not zero after DCR, jump back to loop_start

            ; Code after the loop finishes
loop_exit:
            LDI A, #$EE     ; Indicate loop has exited
            STA LED_PORT
            HLT