; Invalid register for an instruction like ADD
            ORG $1000
            ADD X     ; X is not a valid register (A, B, or C)
            HLT