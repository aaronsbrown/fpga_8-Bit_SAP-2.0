; Simple test program
START:  NOP
        LDI A, #$10
        LDI B, #$20
        MOV A, B    ; A should become $20
        HLT