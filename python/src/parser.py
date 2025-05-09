import logging
import re
from dataclasses import dataclass
from typing import List, Optional, Dict

from constants import INSTRUCTION_SET

logger = logging.getLogger(__name__)

# Matches optional label, optional (mnemonic + operand), allows comma or space delimiter
LINE_PATTERN = re.compile(
    r'^\s*'                             # leading whitespace
    r'(?:(\w+):)?'                      # group 1: optional label
    r'\s*'                              # separator
    r'(?:'                              # start main optional instruction part (this whole part is optional for label-only lines)
        r'([A-Z_a-z]\w*)'               # group 2: mnemonic (e.g., HLT, LDI, MOV)
        r'(?:'                          # start OPTIONAL "delimiter and operand" subgroup
            r'(?:\s*,\s*|\s+)'          #   REQUIRED delimiter (one or more spaces/comma) IF THIS SUBGROUP IS PRESENT
            r'(.*?)'                    #   group 3: operand (lazy)
        r')?'                           # end OPTIONAL "delimiter and operand" subgroup
    r')?'                               # end main optional instruction part
    r'\s*(?:;.*)?$'                     # optional trailing comment (this needs to be robust too)
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
                if not tok.operand: # Should ideally be caught by line parser if ORG requires operand
                    raise ParserError(f"[line {tok.line_no}] ORG directive missing operand.")
                
                # Try to resolve ORG operand as a symbol first
                if tok.operand in self.symbol_table:
                    address = self.symbol_table[tok.operand]
                else:
                    # If not a symbol, parse as a numeric literal
                    try:
                        address = self._parse_numeric_literal(tok.operand, tok.line_no, "ORG directive")
                    except ParserError as e: # Catch specific error to re-raise with context if needed or just let it propagate
                        # Potentially add more context here if operand could be something else
                        raise ParserError(f"[line {tok.line_no}] ORG operand {tok.operand!r} is not a defined symbol and not a valid address literal. {e}")

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

    def _parse_numeric_literal(self, value_str: Optional[str], line_no: int, context_description: str) -> int:
        """
        Parses a string that should represent a number (for ORG literals, EQU values).
        Supports decimal, $hex (e.g., $FF), %binary (e.g., %1010).
        Raises ParserError on failure.
        """
        if not value_str:
            raise ParserError(f"[line {line_no}] {context_description} is missing its value.")
        
        s = value_str.strip()
        if s.startswith('$'):
            try:
                return int(s[1:], 16)
            except ValueError:
                raise ParserError(f"[line {line_no}] Bad hexadecimal value for {context_description}: {s!r}")
        elif s.startswith('%'):
            try:
                return int(s[1:], 2)
            except ValueError:
                raise ParserError(f"[line {line_no}] Bad binary value for {context_description}: {s!r}")
        else:
            try:
                return int(s, 10) # Assume decimal
            except ValueError:
                raise ParserError(f"[line {line_no}] Invalid numeric value for {context_description} (must be decimal, $hex, or %binary): {s!r}")

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

        if base == 'LDI' and op_text:
            parts = [p.strip() for p in op_text.split(',',1)]
            if len(parts) != 2:
                raise ParserError(f"[line {line_no}] Malformed operand for LDI: {op_text!r}")
            reg, imm_val = parts # Use a different name for immediate part to avoid confusion with 'op'
            full_mnem = f"{base}_{reg.upper()}"
            op = imm_val  # <<<< CRITICAL: Assign the immediate part to 'op'
        elif base in ('ANI', 'ORI', 'XRI') and op_text:
            # For these, full_mnem is already 'base'
            # And 'op' is already 'op_text' (the immediate value), which is correct.
            # No changes needed to full_mnem or op within this block.
            pass 
        elif base == 'MOV' and op_text: # Ensure using op_text for condition consistency
            
            parts = [p.strip() for p in op_text.split(',',1)] 
            if len(parts) != 2:
                raise ParserError(f"[line {line_no}] Malformed operand for MOV: {op_text!r}") 
            dst, src = parts 
            full_mnem = f"MOV_{dst.upper()}{src.upper()}"
            op = None
        elif base in ('INR','DCR','ADD','SUB','ADC','SBC','ANA','ORA','XRA','CMP') and op_text: # op_text for condition
            full_mnem = f"{base}_{op_text.upper()}"
            op = None

        return Token(line_no, label, full_mnem, op)

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
                raise ParserError(f"[line {line_no}] EQU for '{label}' missing value.")
            
            val: int
            # --- START MODIFICATION ---
            # Try to resolve operand as an existing symbol first
            if operand in self.symbol_table:
                val = self.symbol_table[operand]
                logger.debug(f"EQU '{label}' resolved using existing symbol '{operand}' to 0x{val:04X}")
            else:
                # If not an existing symbol, try parsing as a numeric literal
                try:
                    # self._parse_numeric_literal should already be defined in your Parser class
                    val = self._parse_numeric_literal(operand, line_no, f"EQU directive for '{label}'")
                except ParserError as e:
                    # If it's neither a known symbol nor a valid numeric literal, raise an error
                    raise ParserError(
                        f"[line {line_no}] EQU operand '{operand}' for '{label}' is not a defined symbol "
                        f"and not a valid numeric literal. Original error: {e.message if hasattr(e, 'message') else e}" # Access underlying message
                    )
            # --- END MODIFICATION ---
            
            self.symbol_table[label] = val
            logger.debug(f"Constant added: {label!r} = 0x{val:04X}")
        else:
            # This is for regular labels (not EQU)
            self.symbol_table[label] = address
            logger.debug(f"Label added:    {label!r} at 0x{address:04X}")