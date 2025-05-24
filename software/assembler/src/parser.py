# software/assembler/src/parser.py
import logging
import os
import re
from typing import List, Dict, Optional, Tuple
from dataclasses import dataclass

# Assuming constants.py is in the same directory or accessible via PYTHONPATH
# Adjust if your constants file is located elsewhere relative to parser.py
try:
    from .constants import INSTRUCTION_SET
except ImportError:
    # Fallback for direct execution or different project structure
    from constants import INSTRUCTION_SET


logger = logging.getLogger(__name__)

@dataclass(frozen=True)
class Token:
    """Represents a tokenized piece of an assembly line, with source context."""
    line_no: int         # Line number within its original source_file
    source_file: str     # The original file path this token came from
    label:   Optional[str]
    mnemonic: Optional[str]
    operand:  Optional[str]

class ParserError(Exception):
    """Custom exception for parsing errors, includes context."""
    def __init__(self, message: str, source_file: Optional[str] = None, line_no: Optional[int] = None):
        self.source_file = source_file
        self.line_no = line_no
        self.base_message = message
        context = ""
        if source_file and line_no is not None:
            context = f"[{os.path.basename(source_file)} line {line_no}] "
        elif source_file:
            context = f"[{os.path.basename(source_file)}] "
        super().__init__(f"{context}{message}")

    def __str__(self) -> str:
        context = ""
        if self.source_file and self.line_no is not None:
            context = f"[{os.path.basename(self.source_file)} line {self.line_no}] "
        elif self.source_file:
            context = f"[{os.path.basename(self.source_file)}] "
        return f"ParserError: {context}{self.base_message}"


# Matches optional label, optional (mnemonic + operand), allows comma or space delimiter
# This LINE_PATTERN is from your provided code.
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

class Parser:
    """
    First-pass parser: tokenizes assembly lines, handles INCLUDE directives,
    builds symbol table, and records a flat list of tokens for the assembler.
    """
    def __init__(self, main_input_filepath: str) -> None:
        self.main_input_filepath: str = os.path.normpath(main_input_filepath)
        self.symbol_table: Dict[str, int] = {}
        self.tokens: List[Token] = []
        self._files_in_recursion_stack: List[str] = [] # For robust cycle detection

        logger.info(f"Parser initialized for main file: {self.main_input_filepath}")
        self._parse_and_process_file(self.main_input_filepath, 0)

        logger.info("Parsing complete. Final symbol table:")
        for sym, val in self.symbol_table.items():
            logger.info(f"  {sym!r} -> 0x{val:04X}")
        logger.info(f"Total tokens collected for assembler: {len(self.tokens)}")

    def _load_lines_from_physical_file(self, filepath: str, requesting_file: str, requesting_line_no: int) -> List[str]:
        try:
            with open(filepath, 'r') as f:
                lines = f.readlines()
            logger.debug(f"Successfully loaded {len(lines)} lines from {filepath}")
            return lines
        except FileNotFoundError:
            raise ParserError(f"Include file not found: {filepath}", source_file=requesting_file, line_no=requesting_line_no)
        except Exception as e:
            raise ParserError(f"Error reading include file {filepath}: {e}", source_file=requesting_file, line_no=requesting_line_no)

    def _parse_numeric_literal(self, value_str: Optional[str], context_description: str, source_file: str, line_no: int) -> int:
        if not value_str:
            raise ParserError(f"{context_description} is missing its value.", source_file, line_no)
        s = value_str.strip()
        val: int
        base_to_use = 10
        if s.startswith('$'):
            base_to_use = 16
            s = s[1:]
        elif s.startswith('%'):
            base_to_use = 2
            s = s[1:]
        
        try:
            val = int(s, base_to_use)
        except ValueError:
            type_str = "hexadecimal" if base_to_use==16 else "binary" if base_to_use==2 else "decimal"
            raise ParserError(f"Bad {type_str} value for {context_description}: '{value_str}'.", source_file, line_no)

        if "ORG directive" in context_description: # Check for ORG address range
            if not (0x0000 <= val <= 0xFFFF):
                raise ParserError(f"Address 0x{val:X} for {context_description} is out of 16-bit range (0x0000-0xFFFF).", source_file, line_no)
        return val

    def _parse_line_components(self, raw_line_text: str, source_file: str, line_no: int) -> Optional[Tuple[Optional[str], Optional[str], Optional[str]]]:
        """Parses a raw line into (label, mnemonic, operand_string) or None if blank/comment."""
        text = raw_line_text.strip()
        if not text or text.startswith(';'):
            return None

        m = LINE_PATTERN.match(text)
        if not m:
            label_only_match = re.match(r'^\s*(\w+):\s*(?:;.*)?$', text)
            if label_only_match:
                return (label_only_match.group(1), None, None)
            # Only log as warning, might be handled by user as an error later if it produces no tokens
            logger.warning(f"Unrecognized syntax on line, skipping: '{text}'", extra={'source_file': source_file, 'line_no': line_no})
            return None # Effectively skips lines that don't match known patterns

        label, raw_mnem, raw_op = m.groups()
        
        # Handle older "LABEL EQU $VAL" or "MNEM EQU $VAL" syntax where EQU is in operand field
        # This specific handling was in your original parser, kept for compatibility.
        if raw_mnem and raw_op and raw_op.upper().startswith('EQU '): # Note space after EQU
            parts = raw_op.split(maxsplit=1) # "EQU VAL"
            if len(parts) == 2 and parts[0].upper() == 'EQU':
                actual_label_for_equ = label if label else raw_mnem
                if not actual_label_for_equ:
                     raise ParserError(f"EQU directive requires a symbol to define: '{text}'", source_file, line_no)
                return actual_label_for_equ, 'EQU', parts[1].strip()
            else: # Did not match "EQU VAL" structure
                 raise ParserError(f"Malformed EQU structure in operand field: '{text}'", source_file, line_no)

        # If EQU is the mnemonic itself
        if raw_mnem and raw_mnem.upper() == 'EQU':
            if not label:
                raise ParserError(f"EQU directive requires a label: '{text}'", source_file, line_no)
            if raw_op is None: # Check if operand exists for EQU
                raise ParserError(f"EQU directive for label '{label}' requires a value: '{text}'", source_file, line_no)
            return label, 'EQU', raw_op.strip()

        return label, raw_mnem, raw_op.strip() if raw_op else None


    def _normalize_token_components(self, label: Optional[str], mnemonic: Optional[str], operand: Optional[str], source_file: str, line_no: int) -> Tuple[Optional[str], Optional[str], Optional[str]]:
        """Normalizes mnemonic (e.g., LDI A -> LDI_A) and adjusts operand accordingly."""
        if not mnemonic: # Label-only line, or already handled EQU/ORG
            return label, mnemonic, operand

        base_mnem_upper = mnemonic.upper()
        final_operand_str = operand
        final_full_mnem = base_mnem_upper

        # Apply transformations based on your assembler's specific syntax rules
        if base_mnem_upper == 'LDI' and operand:
            parts = [p.strip() for p in operand.split(',',1)]
            if len(parts) == 2:
                reg, imm_val = parts
                final_full_mnem = f"{base_mnem_upper}_{reg.upper()}"
                final_operand_str = imm_val.strip()
            else:
                raise ParserError(f"Malformed operand for LDI: '{operand}'", source_file, line_no)
        elif base_mnem_upper == 'MOV' and operand:
            parts = [p.strip() for p in operand.split(',',1)]
            if len(parts) == 2:
                dst, src = parts
                final_full_mnem = f"MOV_{dst.upper()}{src.upper()}"
                final_operand_str = None # MOV_XY takes no further operand string
            else:
                raise ParserError(f"Malformed operand for MOV: '{operand}'", source_file, line_no)
        elif base_mnem_upper in ('INR','DCR','ADD','SUB','ADC','SBC','ANA','ORA','XRA','CMP') and operand:
            final_full_mnem = f"{base_mnem_upper}_{operand.upper()}"
            final_operand_str = None # These mnemonics also absorb their operand
        
        # For directives like DB, DW, ORG, INCLUDE, EQU (if EQU is mnemonic),
        # final_full_mnem is just base_mnem_upper and final_operand_str is operand.
        # No special transformation needed for them here, unless they have multi-part operands.
        
        return label, final_full_mnem, final_operand_str


    def _add_symbol_to_table(self, label: str, value: int, source_file: str, line_no: int) -> None:
        if label in self.symbol_table:
            if self.symbol_table[label] == value: # Benign redefinition
                logger.debug(f"Symbol '{label}' redefined with the same value 0x{value:04X}.", extra={'source_file': source_file, 'line_no': line_no})
                return
            raise ParserError(f"Duplicate symbol: '{label}' (new value 0x{value:04X}, old 0x{self.symbol_table[label]:04X}).", source_file, line_no)
        self.symbol_table[label] = value
        logger.debug(f"Symbol added: '{label}' = 0x{value:04X}", extra={'source_file': source_file, 'line_no': line_no})

    def _parse_and_process_file(self, filepath_to_process: str, current_address: int) -> int:
        """
        Loads, parses, and processes lines from a given file, handling includes recursively.
        Returns the address after processing this file and its includes.
        """
        normalized_filepath = os.path.normpath(filepath_to_process)

        if normalized_filepath in self._files_in_recursion_stack:
            raise ParserError(f"Circular INCLUDE detected: '{normalized_filepath}' is already in the inclusion chain: {' -> '.join(self._files_in_recursion_stack)} -> {normalized_filepath}",
                              source_file=self._files_in_recursion_stack[-1] if self._files_in_recursion_stack else None) # Error originates from file that tried to include it again
        
        self._files_in_recursion_stack.append(normalized_filepath)
        logger.debug(f"Starting processing of file: {normalized_filepath} (Recursion depth: {len(self._files_in_recursion_stack)})")

        try:
            lines = self._load_lines_from_physical_file(normalized_filepath, 
                                                        requesting_file=self._files_in_recursion_stack[-2] if len(self._files_in_recursion_stack) > 1 else self.main_input_filepath, 
                                                        requesting_line_no=0) # Line no for FileNotFoundError is tricky, point to INCLUDE
        except FileNotFoundError as e: # Re-raise if _load_lines specificially raises it for an include
            raise ParserError(str(e)) # The error from _load_lines should have context

        effective_address = current_address

        for line_no_in_file, raw_line in enumerate(lines, start=1):
            parsed_comps = self._parse_line_components(raw_line, normalized_filepath, line_no_in_file)
            if not parsed_comps: # Blank, comment, or unparseable
                continue
            
            label_str, mnemonic_candidate, operand_candidate = parsed_comps

            # Handle INCLUDE directive
            if mnemonic_candidate and mnemonic_candidate.upper() == "INCLUDE":
                if not operand_candidate:
                    raise ParserError("INCLUDE directive missing filename.", normalized_filepath, line_no_in_file)
                
                include_filename_rel = operand_candidate
                if include_filename_rel.startswith('"') and include_filename_rel.endswith('"'):
                    include_filename_rel = include_filename_rel[1:-1]

                base_dir_of_current_file = os.path.dirname(normalized_filepath)
                abs_path_to_include_file = os.path.normpath(os.path.join(base_dir_of_current_file, include_filename_rel))
                
                logger.info(f"Including: '{abs_path_to_include_file}' (from '{normalized_filepath}' line {line_no_in_file})")
                effective_address = self._parse_and_process_file(abs_path_to_include_file, effective_address)
                continue # Done with this INCLUDE line

            # Normalize and create Token for other instructions/directives
            final_label, final_mnemonic, final_operand = self._normalize_token_components(
                label_str, mnemonic_candidate, operand_candidate, normalized_filepath, line_no_in_file
            )
            
            # If after normalization, there's no mnemonic (e.g., label-only line), skip token creation
            if final_mnemonic is None and final_label is None: # Should not happen if parse_line_components returned something
                 continue
            if final_mnemonic is None and final_label is not None: # Label-only line, add label to symbol table, no token for assembler
                self._add_symbol_to_table(final_label, effective_address, normalized_filepath, line_no_in_file)
                continue


            # Create and add token to the flat list for the assembler
            # Ensure final_mnemonic is not None here unless it's a pure label, handled above
            if final_mnemonic: # Only create tokens for lines with mnemonics (instr or directive)
                token = Token(line_no_in_file, normalized_filepath, final_label, final_mnemonic, final_operand)
                self.tokens.append(token)
                logger.debug(f"Token created: {token}")

                # Handle ORG directive (updates current address for this pass)
                if final_mnemonic.upper() == 'ORG':
                    if not final_operand: raise ParserError("ORG directive missing address.", token.source_file, token.line_no)
                    
                    org_val: int
                    if final_operand in self.symbol_table: # ORG can use existing symbol
                        org_val = self.symbol_table[final_operand]
                    else:
                        org_val = self._parse_numeric_literal(final_operand, "ORG directive", token.source_file, token.line_no)
                    
                    effective_address = org_val
                    logger.debug(f"Origin set to 0x{effective_address:04X} by ORG.", extra={'source_file': token.source_file, 'line_no': token.line_no})
                    # ORG does not add to symbol table via label, and does not consume space in output beyond setting address
                    # The token is kept for the assembler to also acknowledge the ORG.

                # Handle EQU (adds to symbol table, does not consume space or directly become code)
                elif final_mnemonic.upper() == 'EQU':
                    if not final_label: raise ParserError("EQU directive requires a label.", token.source_file, token.line_no)
                    if not final_operand: raise ParserError(f"EQU for '{final_label}' missing value.", token.source_file, token.line_no)
                    
                    equ_value = self._parse_numeric_literal(final_operand, f"value for EQU '{final_label}'", token.source_file, token.line_no)
                    self._add_symbol_to_table(final_label, equ_value, token.source_file, token.line_no)
                    # EQU token is kept; assembler might ignore it or use it for listing.
                
                # Handle labels for non-EQU/ORG lines
                elif final_label:
                    self._add_symbol_to_table(final_label, effective_address, token.source_file, token.line_no)

                # Advance address for instructions and data directives (DB, DW)
                # EQU and ORG do not advance address here; ORG sets it, EQU defines a symbol.
                if final_mnemonic.upper() not in ['ORG', 'EQU']:
                    instr_info = INSTRUCTION_SET.get(final_mnemonic.upper()) # Use final_mnemonic
                    if instr_info is None:
                        raise ParserError(f"Unknown mnemonic or directive: '{final_mnemonic}'.", token.source_file, token.line_no)
                    effective_address += instr_info.size
                    logger.debug(f"Address after '{final_mnemonic}': 0x{effective_address:04X} (+{instr_info.size})", extra={'source_file': token.source_file, 'line_no': token.line_no})
            elif final_label: # Label on a line without a mnemonic (after this label)
                # This case was handled above by the `if final_mnemonic is None and final_label is not None`
                pass


        self._files_in_recursion_stack.pop()
        logger.debug(f"Finished processing of file: {normalized_filepath}. Current address: 0x{effective_address:04X} (Recursion depth: {len(self._files_in_recursion_stack)})")
        return effective_address