; test_phase3_labels_comments.asm
INCLUDE "includes/test.inc"

; Tests various label definitions, comment styles, and blank lines.

            ORG CODE_ORIGIN

; Test 1: Label on its own line
label_on_own_line:
            NOP             ; Instruction following a label on its own line

; Test 2: Blank lines
; The next instruction should follow normally after these blank lines.


            LDI A, #A_ADDRESS     ; Instruction after blank lines

; Test 3: Label followed immediately by a comment (no instruction on that line)
label_with_comment_only:    ; This is a label with only a comment after it
            LDI B, #B_ADDRESS     ; Instruction associated with this label

; Test 4: Instruction with a trailing comment
            LDI C, #$33     ; This LDI C has a trailing comment.

; Test 5: Line with only a comment
; This entire line is a comment and should be ignored.

; Test 6: Label, instruction, and trailing comment all on one line
label_instr_comment: MOV A, B   ; All on one line: label, MOV A,B, then comment

; Test 7: Label defined, then blank line, then instruction
another_label:

            ADD C           ; This ADD C is associated with another_label

; Test 8: Multiple comments and blank lines
;;;;;;;;;;;;;;;;;;;;;
; Another comment block
;;;;;;;;;;;;;;;;;;;;;


final_instr:
            HLT             ; Final instruction