import argparse
import logging
import os
from typing import List, Dict, Optional # Added Dict

from parser import Parser, Token, ParserError # Token might not be directly needed here but good for type hints if it were
from constants import INSTRUCTION_SET, ASM_FILE_PATH, OUTPUT_PATH, DEBUG, InstrInfo # Added InstrInfo for type hint

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
        self.symbols: Dict[str, int] = {} # Will store the symbol table from the parser

    def _parse_value_or_symbol(self, s_val: Optional[str], context_msg: str = "value") -> int:
        """
        Resolves a string as a symbol from self.symbols or parses it as a numeric literal.
        Supports decimal, $hex (e.g., $FF), %binary (e.g., %1010).
        Handles leading '#' for immediate values by stripping it.
        Raises AssemblerError on failure.
        """
        if not s_val:
            raise AssemblerError(f"Missing {context_msg}")

        name_to_check = s_val.lstrip('#').strip() # Strip leading '#' and whitespace

        if name_to_check in self.symbols:
            return self.symbols[name_to_check]
        elif name_to_check.startswith('$'):
            try:
                return int(name_to_check[1:], 16)
            except ValueError:
                raise AssemblerError(f"Bad hexadecimal {context_msg}: {s_val!r}")
        elif name_to_check.startswith('%'):
            try:
                return int(name_to_check[1:], 2)
            except ValueError:
                raise AssemblerError(f"Bad binary {context_msg}: {s_val!r}")
        else:
            try:
                return int(name_to_check, 10) # Assume decimal
            except ValueError:
                raise AssemblerError(
                    f"Invalid {context_msg} '{s_val!r}'. "
                    f"Not a known symbol and not a valid number (decimal, $hex, or %binary)."
                )

    def assemble(self) -> None:
        logger.info(f"Assembling {self.input_file} → {self.output_file}")
        parser = Parser(self.input_file)
        self.symbols = parser.symbol_table # Store symbols from parser
        tokens  = parser.tokens

        current_addr = 0 # This will be set by the first ORG or remain 0.
        for tok in tokens:
            # 1) Skip pure labels
            if tok.mnemonic is None:
                continue

            # 2) ORG directive
            if tok.mnemonic == 'ORG':
                # Use the new helper to resolve ORG operand (which could be a symbol or literal)
                # The tok.operand is already the string like "DATA_START" or "$F000"
                resolved_address = self._parse_value_or_symbol(tok.operand, "ORG address")
                current_addr = resolved_address
                self._emit_address_directive(current_addr)
                continue

            # 3) EQU directive (already processed by parser for symbol table)
            if tok.mnemonic == 'EQU':
                continue

            # 4) All other mnemonics: look up opcode+size
            info = INSTRUCTION_SET.get(tok.mnemonic)
            if info is None:
                # This should ideally be caught by the Parser in Pass 1
                raise AssemblerError(f"Unknown mnemonic {tok.mnemonic!r} on token {tok} (should have been caught in Pass 1)")

            # 5) Emit the opcode byte (if any)
            if info.opcode is not None:
                self._emit_byte(info.opcode)

            # 6) Emit operand/data bytes
            # Pass only necessary info; self.symbols is used by _encode_operand
            for b in self._encode_operand(tok.operand, info):
                self._emit_byte(b)

            # 7) Advance the address counter (for assembler's internal tracking, mostly for output verification)
            # The actual addresses for labels are determined in Pass 1.
            # This current_addr helps ensure we're emitting to the "correct" conceptual address.
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
        op_str:  Optional[str], # Renamed from 'op' to 'op_str' for clarity
        info:    InstrInfo,    # Use the imported InstrInfo type hint
        # symbols: dict[str, int] -> REMOVED, uses self.symbols now
    ) -> List[int]:
        """
        Emit the correct number of little‑endian bytes:
         - For instructions (info.opcode not None), count = info.size - 1
         - For data directives (opcode is None), count = info.size
        Uses self.symbols for symbol resolution.
        """
        if not op_str: # If operand string is None or empty
            return []

        # Use the helper to resolve the operand string (e.g., "VALUE_ONE", "#$10", "data_val1")
        # The context_msg helps in error reporting.
        val = self._parse_value_or_symbol(op_str, f"operand for {info}")


        # determine how many bytes to emit
        count = info.size - 1 if info.opcode is not None else info.size
        if count < 0: # Should not happen with valid InstrInfo
            raise AssemblerError(f"Invalid size calculation for operand encoding (count={count}) for {info}")

        # split into little‑endian bytes
        return [(val >> (8 * i)) & 0xFF for i in range(count)]


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