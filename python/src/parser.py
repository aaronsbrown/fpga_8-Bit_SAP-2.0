import logging
import re
from dataclasses import dataclass
from typing import List, Optional, Dict

from constants import INSTRUCTION_SET

logger = logging.getLogger(__name__)

# Matches optional label, optional (mnemonic + operand), allows comma or space delimiter
LINE_PATTERN = re.compile(
    r'^\s*'                    # leading whitespace
    r'(?:(\w+):)?'             # optional label
    r'\s*'
    r'(?:'                     # begin optional mnemonic+operand group
      r'(\w+)'                 # mnemonic
      r'(?:\s*,\s*|\s+)'       # delimiter: comma or whitespace
      r'(.*?)'                 # operand (lazy)
    r')?'                      # end optional mnemonic+operand
    r'\s*(?:;.*)?$'            # optional trailing comment
)

@dataclass(frozen=True)
class Token:
    line_no: int
    label:   Optional[str]
    mnemonic: Optional[str]
    operand:  Optional[str]

class ParserError(Exception):
    """Raised for any parsing or symbol-table errors."""
    pass

class Parser:
    """
    First-pass parser: tokenizes assembly lines, builds symbol table,
    and records tokens for the second-pass assembler.
    """
    def __init__(self, input_file: str) -> None:
        self.input_file: str = input_file
        self.lines: List[str] = self._load_lines()
        self.symbol_table: Dict[str, int] = {}
        self.tokens: List[Token] = []
        self._parse_lines()

    def _load_lines(self) -> List[str]:
        try:
            with open(self.input_file, 'r') as f:
                lines = f.readlines()
            logger.info(f"Loaded {len(lines)} lines from {self.input_file}")
            return lines
        except FileNotFoundError:
            logger.error(f"File not found: {self.input_file}")
            raise ParserError(f"Source file not found: {self.input_file}")

    def _parse_lines(self) -> None:
        address = 0
        for idx, raw in enumerate(self.lines, start=1):
            tok = self._parse_line(idx, raw)
            if tok is None:
                continue

            # collect for pass 2
            self.tokens.append(tok)
            logger.debug(f"Parsed → {tok}")

            # 1) ORG sets the current origin
            if tok.mnemonic == 'ORG':
                address = self._parse_address(tok.operand, tok.line_no)
                logger.debug(f"Set origin to 0x{address:04X}")

            # 2) Record any label (or EQU symbol) at this address/value
            if tok.label:
                self._add_symbol(tok.label, tok.mnemonic, tok.operand, address, tok.line_no)

            # 3) Skip both ORG and EQU for sizing
            if tok.mnemonic in ('ORG', 'EQU'):
                continue

            # 4) All other mnemonics consume space
            if tok.mnemonic:
                info = INSTRUCTION_SET.get(tok.mnemonic)
                if info is None:
                    raise ParserError(f"[line {tok.line_no}] Unknown mnemonic: '{tok.mnemonic}'")
                address += info.size
                logger.debug(f"Address bumped by {info.size}, now @ 0x{address:04X}")

        # final dump
        logger.info("Final symbol table:")
        for sym, addr in self.symbol_table.items():
            logger.info(f"  {sym!r} → 0x{addr:04X}")

    def _parse_line(self, line_no: int, raw: str) -> Optional[Token]:
        text = raw.strip()
        if not text or text.startswith(';'):
            return None

        m = LINE_PATTERN.match(text)
        if not m:
            # allow lines like "label:   ; comment"
            label_only = re.match(r'^\s*(\w+):\s*(?:;.*)?$', text)
            if label_only:
                return Token(line_no, label_only.group(1), None, None)
            logger.warning(f"Unrecognized syntax on line {line_no}, skipping: {text!r}")
            return None

        label, raw_mnem, raw_op = m.groups()

        # handle older "LABEL EQU $VAL" syntax
        if raw_mnem and raw_op and raw_op.upper().startswith('EQU'):
            parts = raw_op.split(maxsplit=1)
            if len(parts) != 2:
                raise ParserError(f"[line {line_no}] Malformed EQU: {text!r}")
            mnem = 'EQU'
            op   = parts[1]
            return Token(line_no, label or raw_mnem, mnem, op)

        # normalize
        base = raw_mnem.upper() if raw_mnem else None
        op_text = raw_op.strip() if raw_op else None
        full_mnem = base
        op = op_text

        # build internal keys for register ops
        if base in ('LDI','ANI','ORI','XRI') and op:
            reg, imm = [p.strip() for p in op.split(',',1)]
            full_mnem = f"{base}_{reg.upper()}"
            op = imm
        elif base == 'MOV' and op:
            dst, src = [p.strip() for p in op.split(',',1)]
            full_mnem = f"MOV_{dst.upper()}{src.upper()}"
            op = None
        elif base in ('INR','DCR','ADD','SUB','ADC','SBC','ANA','ORA','XRA','CMP') and op:
            full_mnem = f"{base}_{op.upper()}"
            op = None

        return Token(line_no, label, full_mnem, op)

    def _parse_address(self, operand: Optional[str], line_no: int) -> int:
        if not operand:
            raise ParserError(f"[line {line_no}] ORG missing operand")
        try:
            return int(operand.lstrip('$'), 16)
        except ValueError:
            raise ParserError(f"[line {line_no}] Bad hex in ORG: {operand!r}")

    def _add_symbol(
        self,
        label:    str,
        mnemonic: Optional[str],
        operand:  Optional[str],
        address:  int,
        line_no:  int
    ) -> None:
        if label in self.symbol_table:
            raise ParserError(f"[line {line_no}] Duplicate symbol: {label!r}")

        if mnemonic == 'EQU':
            if not operand:
                raise ParserError(f"[line {line_no}] EQU missing value")
            try:
                val = int(operand.lstrip('$'), 16)
            except ValueError:
                raise ParserError(f"[line {line_no}] Bad hex in EQU: {operand!r}")
            self.symbol_table[label] = val
            logger.debug(f"Constant added: {label!r} = 0x{val:04X}")
        else:
            self.symbol_table[label] = address
            logger.debug(f"Label added:    {label!r} at 0x{address:04X}")