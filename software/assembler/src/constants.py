# software/assembler/src/constants.py
from dataclasses import dataclass
from typing import Optional

DEBUG = True

# ASM_FILE_PATH and OUTPUT_PATH removed as they are handled by argparse defaults

@dataclass(frozen=True)
class InstrInfo:
    opcode: Optional[int]  # None for data directives like DB/DW
    size:   int            # total bytes (opcode + operands)
                           # For DB/DW, this is size PER ITEM if multiple items allowed by parser.

# Single source of truth for pass 1 & pass 2
INSTRUCTION_SET: dict[str, InstrInfo] = {
    # — Data directives — no opcode, just define bytes
    "DB":   InstrInfo(opcode=None, size=1), # Size is per item
    "DW":   InstrInfo(opcode=None, size=2), # Size is per item

    # — Zero‑operand instructions (1 byte total) —
    "NOP":   InstrInfo(opcode=0x00, size=1),
    "HLT":   InstrInfo(opcode=0x01, size=1),
    "RET":   InstrInfo(opcode=0x19, size=1),
    "ADD_B": InstrInfo(opcode=0x20, size=1),
    "ADD_C": InstrInfo(opcode=0x21, size=1),
    "SUB_B": InstrInfo(opcode=0x24, size=1),
    "SUB_C": InstrInfo(opcode=0x25, size=1),
    "INR_A": InstrInfo(opcode=0x28, size=1),
    "DCR_A": InstrInfo(opcode=0x29, size=1),
    "ADC_B": InstrInfo(opcode=0x22, size=1),
    "ADC_C": InstrInfo(opcode=0x23, size=1),
    "SBC_B": InstrInfo(opcode=0x26, size=1),
    "SBC_C": InstrInfo(opcode=0x27, size=1),
    "ANA_B": InstrInfo(opcode=0x30, size=1),
    "ANA_C": InstrInfo(opcode=0x31, size=1),
    "ORA_B": InstrInfo(opcode=0x34, size=1),
    "ORA_C": InstrInfo(opcode=0x35, size=1),
    "XRA_B": InstrInfo(opcode=0x38, size=1),
    "XRA_C": InstrInfo(opcode=0x39, size=1),
    "CMP_B": InstrInfo(opcode=0x3C, size=1),
    "CMP_C": InstrInfo(opcode=0x3D, size=1),
    "MOV_AB":InstrInfo(opcode=0x60, size=1),
    "MOV_AC":InstrInfo(opcode=0x61, size=1),
    "MOV_BA":InstrInfo(opcode=0x62, size=1),
    "MOV_BC":InstrInfo(opcode=0x63, size=1),
    "MOV_CA":InstrInfo(opcode=0x64, size=1),
    "MOV_CB":InstrInfo(opcode=0x65, size=1),
    "CMA":   InstrInfo(opcode=0x42, size=1),
    "INR_B": InstrInfo(opcode=0x50, size=1),
    "DCR_B": InstrInfo(opcode=0x51, size=1),
    "INR_C": InstrInfo(opcode=0x54, size=1),
    "DCR_C": InstrInfo(opcode=0x55, size=1),
    "RAL":   InstrInfo(opcode=0x40, size=1),
    "RAR":   InstrInfo(opcode=0x41, size=1),
    "SEC":   InstrInfo(opcode=0x70, size=1),
    "CLC":   InstrInfo(opcode=0x71, size=1),
    "PHA":   InstrInfo(opcode=0x80, size=1),
    "PLA":   InstrInfo(opcode=0x81, size=1),
    "PHP":   InstrInfo(opcode=0x82, size=1),
    "PLP":   InstrInfo(opcode=0x83, size=1),
    
    # — One‑operand instructions (2 bytes total) —
    "ANI":   InstrInfo(opcode=0x32, size=2),
    "ORI":   InstrInfo(opcode=0x36, size=2),
    "XRI":   InstrInfo(opcode=0x3A, size=2),
    "LDI_A": InstrInfo(opcode=0xB0, size=2),
    "LDI_B": InstrInfo(opcode=0xB1, size=2),
    "LDI_C": InstrInfo(opcode=0xB2, size=2),

    # — Two‑operand instructions (3 bytes total) —
    "JMP":   InstrInfo(opcode=0x10, size=3),
    "JZ":    InstrInfo(opcode=0x11, size=3),
    "JNZ":   InstrInfo(opcode=0x12, size=3),
    "JN":    InstrInfo(opcode=0x13, size=3),
    "JNN":   InstrInfo(opcode=0x14, size=3),
    "JC":   InstrInfo(opcode=0x15, size=3),
    "JNC":   InstrInfo(opcode=0x16, size=3),  
    "JSR":   InstrInfo(opcode=0x18, size=3),
    "LDA":   InstrInfo(opcode=0xA0, size=3),
    "STA":   InstrInfo(opcode=0xA1, size=3),
}