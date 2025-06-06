; Test for new features: LOW_BYTE, HIGH_BYTE, arithmetic, local labels, DB strings

        ORG $0000
BOOT_MSG_PTR_LOW:  EQU LOW_BYTE(BOOT_MESSAGE)
BOOT_MSG_PTR_HIGH: EQU HIGH_BYTE(BOOT_MESSAGE)

START:
        LDI A, #BOOT_MSG_PTR_LOW
        LDI B, #BOOT_MSG_PTR_HIGH
        LDI C, #LOW_BYTE(BOOT_MESSAGE + 1) ; 'E'
.print_loop:
        DB "X" ; Placeholder for print char routine call
        JMP .print_loop

        ORG $0050
BOOT_MESSAGE:
        DB "BOOT OK", 0, $AA
VAL_AFTER_STR: EQU $CC
        DB VAL_AFTER_STR

        ORG $0100
ADDR_TABLE:
        DW BOOT_MESSAGE      ; Store address of BOOT_MESSAGE
        DW BOOT_MESSAGE + 4  ; Address of "OK"
        DW START - 1         ; Should resolve to -1 (0xFFFF if type permits, or error if not)
                             ; Current _resolve_expression_to_int returns python int.
                             ; DW expects 0-0xFFFF. So 0xFFFF.

END_PGM: HLT