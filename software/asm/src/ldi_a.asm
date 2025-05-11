; --- Code Section ---
            ORG $F000
start_code:
            LDI A, #$F5         ; LDI A with direct hex immediate
            HLT                ; Halt