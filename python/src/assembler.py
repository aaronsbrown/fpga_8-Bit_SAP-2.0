import argparse
import logging
import os
from typing import List

from parser import Parser, Token, ParserError
from constants import INSTRUCTION_SET, ASM_FILE_PATH, OUTPUT_PATH, DEBUG

logger = logging.getLogger(__name__)

class AssemblerError(Exception):
    def __init__(self, message: str) -> None:
        super().__init__(message)
        self.message = message

    def __str__(self) -> str:
        return f"AssemblerError: {self.message}"

class Assembler:
    def __init__(self, input_file: str, output_file: str) -> None:
        self.input_file  = input_file
        self.output_file = output_file
        self.output_lines: List[str] = []

    def assemble(self) -> None:
        logger.info(f"Assembling {self.input_file} → {self.output_file}")
        parser = Parser(self.input_file)
        symbols = parser.symbol_table
        tokens  = parser.tokens

        current_addr = 0
        for tok in tokens:
            # 1) Skip pure labels
            if tok.mnemonic is None:
                continue

            # 2) ORG directive
            if tok.mnemonic == 'ORG':
                current_addr = self._parse_address(tok.operand)
                self._emit_address_directive(current_addr)
                continue

            # 3) EQU directive
            if tok.mnemonic == 'EQU':
                continue

            # 4) All other mnemonics: look up opcode+size
            info = INSTRUCTION_SET.get(tok.mnemonic)
            if info is None:
                raise AssemblerError(f"Unknown mnemonic {tok.mnemonic!r} on token {tok}")

            # 5) Emit the opcode byte (if any)
            if info.opcode is not None:
                self._emit_byte(info.opcode)

            # 6) Emit operand/data bytes
            for b in self._encode_operand(tok.operand, info, symbols):
                self._emit_byte(b)

            # 7) Advance the address counter
            current_addr += info.size

        logger.info("Assembly complete.")

    def write_output_file(self) -> None:
        dirpath = os.path.dirname(self.output_file)
        if dirpath:
            os.makedirs(dirpath, exist_ok=True)
        with open(self.output_file, "w") as f:
            f.write("\n".join(self.output_lines))
        logger.info(f"Wrote output to {self.output_file}")

    # ────────────────────────────────────────────────────────────────────────────
    # Helpers for Pass 2
    # ────────────────────────────────────────────────────────────────────────────

    def _emit_address_directive(self, addr: int) -> None:
        """Emit a new @XXXX directive (hex)."""
        self.output_lines.append(f"@{addr:04X}")

    def _emit_byte(self, b: int) -> None:
        """Append a single byte as two‑digit hex."""
        self.output_lines.append(f"{b & 0xFF:02X}")

    def _encode_operand(
        self,
        op:      str,
        info:    'InstrInfo',
        symbols: dict[str, int]
    ) -> List[int]:
        """
        Emit the correct number of little‑endian bytes:
         - For instructions (info.opcode not None), count = info.size - 1
         - For data directives (opcode is None), count = info.size
        """
        if not op:
            return []

        # strip immediate marker
        name = op.lstrip('#')

        # resolve symbol or literal
        if name in symbols:
            val = symbols[name]
        elif name.startswith('$'):
            val = int(name[1:], 16)
        elif name.startswith('%'):
            val = int(name[1:], 2)
        else:
            val = int(name, 10)

        # determine how many bytes to emit
        count = info.size - 1 if info.opcode is not None else info.size

        # split into little‑endian bytes
        return [(val >> (8 * i)) & 0xFF for i in range(count)]

    def _parse_address(self, operand: str) -> int:
        return int(operand.lstrip('$'), 16)


def main(input_filepath, output_filepath) -> None:
    try:
        asm = Assembler(input_filepath, output_filepath)
        asm.assemble()
        asm.write_output_file()
    except (ParserError, AssemblerError) as e:
        logger.error(f"Assembly failed: {e}")
        exit(1)


if __name__ == "__main__":
    argp = argparse.ArgumentParser(description="Custom 8‑bit CPU Assembler")
    argp.add_argument("input",  nargs="?", default=f"{ASM_FILE_PATH}_prog.asm")
    argp.add_argument("output", nargs="?", default=f"{OUTPUT_PATH}_prog.hex")
    args = argp.parse_args()

    logging.basicConfig(
        level=logging.DEBUG if DEBUG else logging.INFO,
        format="%(levelname)s: %(message)s",
        handlers=[logging.FileHandler("assembler.log"), logging.StreamHandler()],
    )

    main(args.input, args.output)