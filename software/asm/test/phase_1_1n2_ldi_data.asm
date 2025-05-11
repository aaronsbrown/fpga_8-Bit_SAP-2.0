; test_phase1_ldi_data.asm
; Tests various LDI instructions with different immediate value formats.
; Tests DB and DW data directives, including symbol resolution and little-endian for DW.

; --- Constants ---
ADDR_FOR_DW   EQU $0A00   ; An address to be stored in a DW
CONST_FOR_DW  EQU $ABCD   ; A 16-bit constant for DW
HEX_BYTE      EQU $F0     ; 8-bit hex for LDI
BINARY_BYTE   EQU %10100101 ; 8-bit binary for LDI
DECIMAL_BYTE  EQU 128     ; 8-bit decimal for LDI

; --- Data Section ---
            ORG $0100

; DB Tests
byte_data1: DB HEX_BYTE        ; DB with an EQU symbol ($F0)
byte_data2: DB %11001100    ; DB with a binary literal ($CC)
byte_data3: DB 42             ; DB with a decimal literal ($2A)
byte_data4: DB $AA            ; DB with a hex literal

; DW Tests
word_data1: DW $1234          ; DW with a hex literal (expect 34 12)
word_data2: DW ADDR_FOR_DW    ; DW with an EQU address symbol (expect 00 0A for $0A00)
word_data3: DW CONST_FOR_DW   ; DW with an EQU 16-bit constant (expect CD AB for $ABCD)
word_data4: DW data_val_ptr   ; DW with a label (address of 'data_val_ptr' itself, or a nearby label)
                            ; Let's point it to 'byte_data1' for a concrete address ($0100)

another_label: DB $EE         ; Just to have another address for DW to point to

data_val_ptr: EQU byte_data1  ; Make data_val_ptr an alias for byte_data1's address

; --- Code Section ---
            ORG $F800
start_code:
            LDI A, #HEX_BYTE    ; LDI A, #$F0
            LDI B, #BINARY_BYTE ; LDI B, #%10100101 (which is $A5)
            LDI C, #DECIMAL_BYTE; LDI C, #128 (which is $80)

            LDI A, #$11         ; LDI A with direct hex immediate
            LDI B, #%00110011   ; LDI B with direct binary immediate ($33)
            LDI C, #55          ; LDI C with direct decimal immediate ($37)

            HLT                 ; Halt