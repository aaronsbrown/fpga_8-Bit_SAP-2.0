; test_phase2_jmp_clean_assembler_test.asm
; Focus: Test assembler's JMP encoding for forward, backward, and EQU targets.
; CPU execution flow is secondary for this specific test.

            ORG $F000

; --- EQU Constant for JMP Target ---
JUMP_VIA_EQU_TARGET EQU $F050

; --- Test 1: Forward Jump ---
label_before_fwd_jmp:
            JMP actual_forward_target   ; Jumps over the DB instructions
            DB $11
            DB $11 
            DB $11            ; Bytes that should be skipped by CPU

actual_forward_target:
            NOP                         ; Target of the forward jump

; --- Test 2: Backward Jump ---
target_for_backward_jmp:    ; This label is the target for the backward jump
            NOP
            DB $22
            DB $22                 ; Some data/padding
            JMP target_for_backward_jmp ; Jumps back to the NOP above.
                                        ; This creates an infinite loop for CPU execution.

; --- Test 3: Jump to EQU Address ---
; This section will not be reached by CPU if above loop runs.
; Its encoding is independent for assembler testing.
label_before_equ_jmp:
            JMP JUMP_VIA_EQU_TARGET
            DB $33
            DB $33
            DB $33            ; Bytes that should be skipped by CPU

; --- Code at the EQU Target ---
            ORG JUMP_VIA_EQU_TARGET
actual_equ_target_label:
            HLT                         ; Final instruction at the EQU-defined address