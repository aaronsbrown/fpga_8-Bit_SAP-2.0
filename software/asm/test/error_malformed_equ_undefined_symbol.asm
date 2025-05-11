; EQU referencing an undefined symbol
; (Your current parser should catch this if the symbol isn't defined *before* this EQU)
            ORG $1000
ANOTHER_CONST EQU UNKNOWN_SYMBOL ; UNKNOWN_SYMBOL is not yet defined