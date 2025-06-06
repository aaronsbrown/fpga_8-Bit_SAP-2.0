        ORG $0010
VAL1:   EQU $AA
START:  LDI A, #VAL1
        DB VAL1, $BB
        ORG $F000
RESET_VEC: LDI C, #$FF
        HLT