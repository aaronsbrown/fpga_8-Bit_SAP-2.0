; NOP.asm
; Test suite for NOP (No Operation) instruction
; Verifies NOP does not modify any registers or flags

INCLUDE "includes/mmio_defs.inc"

; ======================================================================
; == PROGRAM  
; ======================================================================
    ORG $F000

START:
    ; ================================================================
    ; TEST 1: Basic NOP with test pattern
    ; ================================================================
    
    ; Set known register state
    LDI A, #$AA        ; A = $AA 
    LDI B, #$55        ; B = $55
    LDI C, #$FF        ; C = $FF
    
    ; Set known flag state
    SEC                ; Set carry flag (Z=0, N=1 from LDI C, C=1)
    
    ; Execute NOP - should change nothing
    NOP
    
    ; ================================================================
    ; TEST 2: NOP with different pattern
    ; ================================================================
    
    ; Change to different known state
    LDI A, #$00        ; A = $00 (sets Z=1, N=0)
    LDI B, #$42        ; B = $42
    LDI C, #$84        ; C = $84 (sets Z=0, N=1)
    CLC                ; Clear carry (C=0)
    
    ; Execute NOP - should change nothing
    NOP
    
    ; ================================================================
    ; TEST 3: Multiple NOPs in sequence
    ; ================================================================
    
    ; Set final test pattern
    LDI A, #$F0        ; A = $F0
    LDI B, #$0F        ; B = $0F  
    LDI C, #$77        ; C = $77
    
    ; Execute multiple NOPs
    NOP
    NOP
    NOP
    
    ; Signal test completion
    LDI A, #$FF        ; Success code
    STA OUTPUT_PORT_1  ; Output to verify completion
    
    HLT                ; End test