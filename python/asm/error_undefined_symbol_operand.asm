; Undefined symbol in an instruction's operand
            ORG $1000
            LDI A, #NOT_DEFINED_CONST ; UNDEFINED_CONST is not defined
            HLT