; XRI Comprehensive Test Program
; Tests XRI (Exclusive OR A with immediate) instruction: A = A ^ immediate
; Flags: Z=+/- (result), N=+/- (result), C=0 (always cleared)

    org $F000

; =================================================================
; TEST 1: Basic XOR operation - A=$00 ^ #$FF = $FF
; Expected: A=$FF, Z=0, N=1, C=0
; =================================================================
LDI A, #$00    ; Load $00 into A (00000000)
LDI B, #$BB    ; Load $BB into B for preservation test
LDI C, #$CC    ; Load $CC into C for preservation test
XRI #$FF       ; A = $00 ^ $FF = $FF (11111111)

; =================================================================
; TEST 2: XOR operation resulting in zero - A=$FF ^ #$FF = $00
; Expected: A=$00, Z=1, N=0, C=0
; =================================================================
LDI A, #$FF    ; Load $FF into A (11111111)
XRI #$FF       ; A = $FF ^ $FF = $00 (00000000)

; =================================================================
; TEST 3: Alternating pattern - A=$55 ^ #$AA = $FF
; Expected: A=$FF, Z=0, N=1, C=0
; =================================================================
LDI A, #$55    ; Load $55 into A (01010101)
XRI #$AA       ; A = $55 ^ $AA = $FF (11111111)

; =================================================================
; TEST 4: Same value XOR - A=$42 ^ #$42 = $00
; Expected: A=$00, Z=1, N=0, C=0
; =================================================================
LDI A, #$42    ; Load $42 into A (01000010)
XRI #$42       ; A = $42 ^ $42 = $00 (00000000)

; =================================================================
; TEST 5: Single bit operations - A=$01 ^ #$80 = $81
; Expected: A=$81, Z=0, N=1, C=0
; =================================================================
LDI A, #$01    ; Load $01 into A (00000001)
XRI #$80       ; A = $01 ^ $80 = $81 (10000001)

; =================================================================
; TEST 6: Carry flag clearing test - set carry, then XOR
; Expected: A=$7F, Z=0, N=0, C=0 (carry cleared by XRI)
; =================================================================
SEC            ; Set carry flag (C=1)
LDI A, #$3F    ; Load $3F into A (00111111)
XRI #$40       ; A = $3F ^ $40 = $7F (01111111), C cleared

; =================================================================
; TEST 7: XOR with zero - A=$80 ^ #$00 = $80
; Expected: A=$80, Z=0, N=1, C=0
; =================================================================
LDI A, #$80    ; Load $80 into A (10000000)
XRI #$00       ; A = $80 ^ $00 = $80 (10000000)

; =================================================================
; TEST 8: Complex bit pattern - A=$69 ^ #$96 = $FF
; Expected: A=$FF, Z=0, N=1, C=0
; =================================================================
LDI A, #$69    ; Load $69 into A (01101001)
XRI #$96       ; A = $69 ^ $96 = $FF (11111111)

; =================================================================
; TEST 9: Register preservation test
; Expected: B=$5A, C=$5A preserved, A=$66
; =================================================================
LDI A, #$3C    ; Load $3C into A (00111100)
LDI B, #$5A    ; Load $5A into B (01011010)
LDI C, #$5A    ; Load $5A into C (01011010)
XRI #$5A       ; A = $3C ^ $5A = $66 (01100110)

; =================================================================
; TEST 10: Sequential XOR operations to verify no side effects
; =================================================================
LDI A, #$01    ; Load $01 into A (00000001)
XRI #$02       ; A = $01 ^ $02 = $03 (00000011)
XRI #$04       ; A = $03 ^ $04 = $07 (00000111)

; =================================================================
; TEST 11: Boundary value testing - A=$7F ^ #$80 = $FF
; Expected: A=$FF, Z=0, N=1, C=0
; =================================================================
LDI A, #$7F    ; Load $7F into A (01111111)
XRI #$80       ; A = $7F ^ $80 = $FF (11111111)

; =================================================================
; TEST 12: Final flag state verification with carry clearing
; Expected: A=$00, Z=1, N=0, C=0 (carry cleared even when set before)
; =================================================================
SEC            ; Set carry flag (C=1)
LDI A, #$AA    ; Load $AA into A (10101010)
XRI #$AA       ; A = $AA ^ $AA = $00 (00000000), C cleared

HLT            ; Halt processor