; test_phase2_conditional_jumps.asm
; Tests assembler encoding for conditional jump instructions: JZ, JNZ, JN.
; - Forward and backward label resolution.
; - EQU symbol as target.

            ORG $A000

; --- EQU Constants for Jump Targets ---
JZ_EQU_TARGET   EQU $A030
JNZ_EQU_TARGET  EQU $A040
JN_EQU_TARGET   EQU $A050

; --- Test JZ (Jump if Zero) ---
start_jz_test:
            JZ  forward_jz_target       ; Forward jump
            DB  $11                     ; Padding
            JZ  start_jz_test           ; Backward jump (to itself for simplicity)
            DB  $12                     ; Padding
            JZ  JZ_EQU_TARGET           ; Jump to EQU-defined address
            DB  $13                     ; Padding

forward_jz_target:
            NOP

; --- Test JNZ (Jump if Not Zero) ---
start_jnz_test:             ; Also serves as backward target for JNZ
            JNZ forward_jnz_target      ; Forward jump
            DB  $21                     ; Padding
            JNZ start_jnz_test          ; Backward jump
            DB  $22                     ; Padding
            JNZ JNZ_EQU_TARGET          ; Jump to EQU-defined address
            DB  $23                     ; Padding

forward_jnz_target:
            NOP

; --- Test JN (Jump if Negative/Sign) ---
start_jn_test:              ; Also serves as backward target for JN
            JN  forward_jn_target       ; Forward jump
            DB  $31                     ; Padding
            JN  start_jn_test           ; Backward jump
            DB  $32                     ; Padding
            JN  JN_EQU_TARGET           ; Jump to EQU-defined address
            DB  $33                     ; Padding

forward_jn_target:
            NOP

; --- Target locations defined by EQU ---
            ORG JZ_EQU_TARGET
jz_equ_landing:
            DB  $F0                 ; Data at JZ EQU target

            ORG JNZ_EQU_TARGET
jnz_equ_landing:
            DB  $F1                 ; Data at JNZ EQU target

            ORG JN_EQU_TARGET
jn_equ_landing:
            DB  $F2                 ; Data at JN EQU target

            ORG $AFFF               ; Ensure HLT is far away and last thing.
final_halt:
            HLT