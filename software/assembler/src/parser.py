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
    label:   Optional[str] # Original label, e.g., "MY_LABEL" or ".loop"
    mnemonic: Optional[str]
    operand:  Optional[str] # Operand string, local labels may be mangled here by parser

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


# Updated LINE_PATTERN to support local labels (starting with '.')
# Group 1: Label (e.g., GLOBAL_LABEL:, .local_label:)
# Group 2: Mnemonic
# Group 3: Operand
LINE_PATTERN = re.compile(
    r'^\s*'                                 # leading whitespace
    r'(?:((?:[a-zA-Z_]\w*|\.\w+):))?'       # group 1: optional label (global or local)
    r'\s*'                                  # separator
    r'(?:'                                  # start main optional instruction part
        r'([A-Z_a-z]\w*)'                   # group 2: mnemonic
        r'(?:'                              # start OPTIONAL "delimiter and operand" subgroup
            r'(?:\s*,\s*|\s+)'              #   REQUIRED delimiter
            r'(.*?)'                        #   group 3: operand (lazy)
        r')?'                               # end OPTIONAL "delimiter and operand" subgroup
    r')?'                                   # end main optional instruction part
    r'\s*(?:;.*)?$'                         # optional trailing comment
)

# Regex to split comma-separated arguments, respecting strings
# Splits by comma, but not if comma is inside double quotes
# Example: DB "string, with comma", 10, "another"
# Will yield: ['"string, with comma"', ' 10', ' "another"'] (stripping needed later)
CSV_SPLIT_REGEX = re.compile(r',(?=(?:[^"]*"[^"]*")*[^"]*$)')


class Parser:
    """
    First-pass parser: tokenizes assembly lines, handles INCLUDE directives,
    builds symbol table (mangling local labels), and records a flat list of tokens
    (with local label references in operands also mangled).
    """
    def __init__(self, main_input_filepath: str) -> None:
        self.main_input_filepath: str = os.path.normpath(main_input_filepath)
        self.symbol_table: Dict[str, int] = {}
        self.tokens: List[Token] = []
        self._files_in_recursion_stack: List[str] = []

        logger.info(f"Parser initialized for main file: {self.main_input_filepath}")
        # Initial call, no current global label scope, start address 0
        self._parse_and_process_file(self.main_input_filepath, 0, None) 

        logger.info("Parsing complete. Final symbol table:")
        for sym, val in sorted(self.symbol_table.items()): # Sort for consistent logging
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

        # Range checks for specific contexts (like ORG) are good here
        if "ORG directive" in context_description or "address" in context_description:
            if not (0x0000 <= val <= 0xFFFF):
                raise ParserError(f"Address 0x{val:X} for {context_description} is out of 16-bit range (0x0000-0xFFFF).", source_file, line_no)
        # Further 8-bit/16-bit checks for DB/DW items will be done by assembler,
        # but basic numeric parsing is done here.
        return val

    def _process_string_escapes(self, string_content: str, source_file: str, line_no: int) -> str:
        """Process escape sequences in string literals and return processed string"""
        if not string_content:
            return string_content
            
        result = []
        i = 0
        while i < len(string_content):
            if string_content[i] == '\\' and i + 1 < len(string_content):
                next_char = string_content[i + 1]
                if next_char == 'n':
                    result.append('\n')
                    i += 2
                elif next_char == 't':
                    result.append('\t')
                    i += 2
                elif next_char == 'r':
                    result.append('\r')
                    i += 2
                elif next_char == '0':
                    result.append('\0')
                    i += 2
                elif next_char == '\\':
                    result.append('\\')
                    i += 2
                elif next_char == '"':
                    result.append('"')
                    i += 2
                elif next_char == 'x':
                    # Hex escape sequence \xHH
                    if i + 3 >= len(string_content):
                        raise ParserError(f"Incomplete hex escape sequence at end of string", source_file, line_no)
                    hex_digits = string_content[i + 2:i + 4]
                    if len(hex_digits) != 2:
                        raise ParserError(f"Incomplete hex escape sequence '\\x{hex_digits}' - expected 2 hex digits", source_file, line_no)
                    try:
                        hex_value = int(hex_digits, 16)
                        result.append(chr(hex_value))
                        i += 4
                    except ValueError:
                        raise ParserError(f"Invalid hex escape sequence '\\x{hex_digits}' - invalid hex digits", source_file, line_no)
                else:
                    raise ParserError(f"Unknown escape sequence '\\{next_char}' in string literal", source_file, line_no)
            else:
                result.append(string_content[i])
                i += 1
                
        return ''.join(result)

    def _calculate_string_processed_length(self, string_content: str, source_file: str, line_no: int) -> int:
        """Calculate the byte length of a string after escape sequence processing"""
        processed_string = self._process_string_escapes(string_content, source_file, line_no)
        return len(processed_string)

    def _parse_line_components(self, raw_line_text: str, source_file: str, line_no: int) -> Optional[Tuple[Optional[str], Optional[str], Optional[str]]]:
        text = raw_line_text.strip()
        if not text or text.startswith(';'):
            return None

        m = LINE_PATTERN.match(text)
        if not m:
            # Check for label-only line with updated pattern (e.g. .label_only:)
            label_only_match = re.match(r'^\s*((?:[a-zA-Z_]\w*|\.\w+):)\s*(?:;.*)?$', text)
            if label_only_match:
                return (label_only_match.group(1).rstrip(':'), None, None) # Strip colon from label
            logger.warning(f"Unrecognized syntax on line, skipping: '{text}'", extra={'source_file': source_file, 'line_no': line_no})
            return None

        raw_label, raw_mnem, raw_op = m.groups()
        label = raw_label.rstrip(':') if raw_label else None

        if raw_mnem and raw_op and raw_op.upper().startswith('EQU '):
            parts = raw_op.split(maxsplit=1)
            if len(parts) == 2 and parts[0].upper() == 'EQU':
                actual_label_for_equ = label if label else raw_mnem # If "SYM EQU VAL" syntax used where SYM is in mnemonic field
                if not actual_label_for_equ:
                     raise ParserError(f"EQU directive requires a symbol to define: '{text}'", source_file, line_no)
                return actual_label_for_equ, 'EQU', parts[1].strip()
            else:
                 raise ParserError(f"Malformed EQU structure in operand field: '{text}'", source_file, line_no)

        if raw_mnem and raw_mnem.upper() == 'EQU':
            if not label:
                raise ParserError(f"EQU directive requires a label: '{text}'", source_file, line_no)
            if raw_op is None:
                raise ParserError(f"EQU directive for label '{label}' requires a value: '{text}'", source_file, line_no)
            return label, 'EQU', raw_op.strip()

        return label, raw_mnem, raw_op.strip() if raw_op else None


    def _normalize_token_components(self, label: Optional[str], mnemonic: Optional[str], operand: Optional[str], 
                                    current_global_scope: Optional[str], source_file: str, line_no: int
                                   ) -> Tuple[Optional[str], Optional[str], Optional[str]]:
        if not mnemonic: 
            return label, mnemonic, operand

        base_mnem_upper = mnemonic.upper()
        final_operand_str = operand 
        final_full_mnem = base_mnem_upper

        if base_mnem_upper == 'LDI' and operand: 
            parts = [p.strip() for p in CSV_SPLIT_REGEX.split(operand, 1)] 
            if len(parts) == 2:
                reg, imm_val = parts
                final_full_mnem = f"{base_mnem_upper}_{reg.upper()}"
                final_operand_str = imm_val.strip() 
            else:
                raise ParserError(f"Malformed operand for LDI: '{operand}'. Expected 'REG, VALUE'.", source_file, line_no)
        elif base_mnem_upper == 'MOV' and operand: 
            parts = [p.strip() for p in CSV_SPLIT_REGEX.split(operand, 1)]
            if len(parts) == 2:
                dst, src = parts
                final_full_mnem = f"MOV_{dst.upper()}{src.upper()}"
                final_operand_str = None 
            else:
                raise ParserError(f"Malformed operand for MOV: '{operand}'. Expected 'DST, SRC'.", source_file, line_no)
        elif base_mnem_upper in ('INR','DCR','ADD','SUB','ADC','SBC','ANA','ORA','XRA','CMP') and operand: 
            final_full_mnem = f"{base_mnem_upper}_{operand.upper()}"
            final_operand_str = None 
        
        if final_operand_str: 
            local_label_pattern = r'(?<![a-zA-Z0-9_.])(\.\w+)'

            if current_global_scope:
                final_operand_str = re.sub(local_label_pattern, 
                                           lambda m: f"{current_global_scope}{m.group(1)}", 
                                           final_operand_str)
            # This is the critical 'elif' that should be present and correct:
            elif re.search(local_label_pattern, final_operand_str): 
                first_local_match = re.search(local_label_pattern, final_operand_str)
                local_name_for_error = first_local_match.group(1) if first_local_match and first_local_match.group(1) else "an unresolved local label"
                raise ParserError(f"Local label reference '{local_name_for_error}' used without an active global label scope.", 
                                  source_file, line_no)
        
        return label, final_full_mnem, final_operand_str


    def _add_symbol_to_table(self, label: str, value: int, source_file: str, line_no: int) -> None:
        if label in self.symbol_table:
            if self.symbol_table[label] == value:
                logger.debug(f"Symbol '{label}' redefined with the same value 0x{value:04X}.", extra={'source_file': source_file, 'line_no': line_no})
                return
            raise ParserError(f"Duplicate symbol: '{label}' (new value 0x{value:04X}, old 0x{self.symbol_table[label]:04X}).", source_file, line_no)
        self.symbol_table[label] = value
        logger.debug(f"Symbol added: '{label}' = 0x{value:04X}", extra={'source_file': source_file, 'line_no': line_no})

    def _calculate_db_dw_size(self, mnemonic_upper: str, operand_str: Optional[str], source_file: str, line_no: int) -> int:
        if not operand_str:
            raise ParserError(f"{mnemonic_upper} directive requires operand(s).", source_file, line_no)

        items = CSV_SPLIT_REGEX.split(operand_str)
        total_bytes = 0
        
        item_size = 1 if mnemonic_upper == "DB" else 2 # Default item size for DW

        if mnemonic_upper == "DB":
            for item_text in items:
                item_text = item_text.strip()
                if not item_text: continue # Skip empty items from trailing commas, etc.

                if item_text.startswith('"') and item_text.endswith('"'):
                    if len(item_text) < 2:
                        raise ParserError(f"Malformed string literal in DB: {item_text}", source_file, line_no)
                    string_content = item_text[1:-1]
                    # Calculate string length after escape sequence processing
                    total_bytes += self._calculate_string_processed_length(string_content, source_file, line_no)
                else: # Assumed numeric or symbol
                    total_bytes += item_size # 1 byte for this item
        elif mnemonic_upper == "DW":
            # For DW, current implementation expects one value. If multiple allowed in future:
            if len(items) > 1:
                logger.warning(f"[{source_file} line {line_no}] DW directive currently supports only one value per line. "
                               f"'{operand_str}' will be treated as {len(items)} words if assembler supports it, "
                               f"but parser address advance assumes this for now.")
            for item_text in items:
                item_text = item_text.strip()
                if not item_text: continue
                total_bytes += item_size # 2 bytes per item
        
        if total_bytes == 0 and items: # e.g. DB ""
             pass # allow DB "" to produce 0 bytes

        return total_bytes


    def _parse_and_process_file(self, filepath_to_process: str, current_address: int, 
                                current_global_label_scope: Optional[str]) -> Tuple[int, Optional[str]]:
        normalized_filepath = os.path.normpath(filepath_to_process)

        if normalized_filepath in self._files_in_recursion_stack:
            raise ParserError(f"Circular INCLUDE detected: '{normalized_filepath}'",
                              source_file=self._files_in_recursion_stack[-1] if self._files_in_recursion_stack else None)
        
        self._files_in_recursion_stack.append(normalized_filepath)
        # Use current_global_label_scope for the active_global_label within this file initially
        active_global_label = current_global_label_scope 
        logger.debug(f"Starting processing of file: {normalized_filepath} (initial active_global_scope: {active_global_label})")

        try:
            lines = self._load_lines_from_physical_file(normalized_filepath, 
                                                        requesting_file=self._files_in_recursion_stack[-2] if len(self._files_in_recursion_stack) > 1 else self.main_input_filepath, 
                                                        requesting_line_no=0)
        except ParserError as e: 
            self._files_in_recursion_stack.pop()
            raise e

        effective_address = current_address

        for line_no_in_file, raw_line in enumerate(lines, start=1):
            parsed_comps = self._parse_line_components(raw_line, normalized_filepath, line_no_in_file)
            if not parsed_comps:
                continue
            
            original_label_str, mnemonic_candidate, operand_candidate = parsed_comps

            if mnemonic_candidate and mnemonic_candidate.upper() == "INCLUDE":
                if not operand_candidate:
                    raise ParserError("INCLUDE directive missing filename.", normalized_filepath, line_no_in_file)
                
                include_filename_rel = operand_candidate.strip('"')
                base_dir_of_current_file = os.path.dirname(normalized_filepath)
                abs_path_to_include_file = os.path.normpath(os.path.join(base_dir_of_current_file, include_filename_rel))
                
                logger.info(f"Including: '{abs_path_to_include_file}' (from '{normalized_filepath}' line {line_no_in_file})")
                # Pass current effective_address and current active_global_label to the included file
                effective_address, active_global_label = self._parse_and_process_file(abs_path_to_include_file, effective_address, active_global_label)
                continue

            # Normalize components. Operands are mangled using the 'active_global_label' which is the scope
            # active *before* this line's own global label (if any) takes effect for subsequent lines.
            _, final_mnemonic, final_operand = self._normalize_token_components(
                original_label_str, mnemonic_candidate, operand_candidate, 
                active_global_label, # This is the scope for mangling operands ON THIS LINE
                normalized_filepath, line_no_in_file
            )
            
            # Determine the label name for the symbol table and update active_global_label for *subsequent* lines
            label_name_for_symbol_table: Optional[str] = None
            
            if original_label_str:
                if original_label_str.startswith('.'): # Local label
                    if not active_global_label: # Must have a current global scope
                        raise ParserError(f"Local label '{original_label_str}' defined without a preceding global label.", normalized_filepath, line_no_in_file)
                    label_name_for_symbol_table = f"{active_global_label}{original_label_str}"
                else: # Global label
                    label_name_for_symbol_table = original_label_str
                    # If this global label is NOT for an EQU directive, it updates the active scope for subsequent lines.
                    # We check final_mnemonic because _parse_line_components might turn "L: M EQU V" into (L, M, "EQU V")
                    # and _normalize_token_components would then fix M to be the label and EQU to be the mnemonic.
                    # Or, _parse_line_components directly returns (L, "EQU", V).
                    # So, final_mnemonic is the most reliable indicator of an EQU directive.
                    if not (final_mnemonic and final_mnemonic.upper() == 'EQU'):
                        active_global_label = original_label_str # Update scope for next lines
            
            # If after normalization, there's no mnemonic (e.g., label-only line)
            if not final_mnemonic:
                if label_name_for_symbol_table: # It's a label-only line
                    self._add_symbol_to_table(label_name_for_symbol_table, effective_address, normalized_filepath, line_no_in_file)
                # active_global_label would have been updated above if it was a non-EQU global label.
                continue 

            # Add label to symbol table (if it's for an addressable instruction/data, not an EQU's own label)
            # EQU handles its own label addition separately.
            if label_name_for_symbol_table and final_mnemonic.upper() != 'EQU':
                self._add_symbol_to_table(label_name_for_symbol_table, effective_address, normalized_filepath, line_no_in_file)

            # Create and add token
            token = Token(line_no_in_file, normalized_filepath, original_label_str, final_mnemonic, final_operand)
            self.tokens.append(token)
            logger.debug(f"Token created: {token} (current effective_address: 0x{effective_address:04X}, next active_global_label for subsequent lines: {active_global_label})")

            # Handle ORG, EQU, or advance address for instructions/data
            mnem_upper = final_mnemonic.upper()
            if mnem_upper == 'ORG':
                if not final_operand: raise ParserError("ORG directive missing address.", token.source_file, token.line_no)
                # Simplified ORG value resolution for parser pass (as before)
                org_val: int
                if final_operand in self.symbol_table:
                    org_val = self.symbol_table[final_operand]
                else:
                    try:
                        org_val = self._parse_numeric_literal(final_operand, "ORG directive", token.source_file, token.line_no)
                    except ParserError as e:
                        raise ParserError(f"ORG operand '{final_operand}' must be a pre-defined symbol or numeric literal for parser's current pass. Error: {e}",
                                          token.source_file, token.line_no)
                effective_address = org_val
                logger.debug(f"Origin set to 0x{effective_address:04X} by ORG.", extra={'source_file': token.source_file, 'line_no': token.line_no})

            elif mnem_upper == 'EQU':
                # The label for EQU is 'label_name_for_symbol_table'
                if not label_name_for_symbol_table: 
                    raise ParserError(f"EQU directive requires a label (parsed components: label='{original_label_str}', mnem='{final_mnemonic}').", token.source_file, token.line_no)
                if not final_operand: 
                    raise ParserError(f"EQU for '{label_name_for_symbol_table}' missing value.", token.source_file, token.line_no)
                
                # EQU value resolution (as before, simple literals or existing symbols for parser)
                equ_value: int
                if final_operand in self.symbol_table:
                    equ_value = self.symbol_table[final_operand]
                else:
                    try:
                        equ_value = self._parse_numeric_literal(final_operand, f"value for EQU '{label_name_for_symbol_table}'", token.source_file, token.line_no)
                    except ParserError as e:
                         raise ParserError(f"EQU value '{final_operand}' for '{label_name_for_symbol_table}' must be a numeric literal or a pre-defined symbol in parser's pass. Error: {e}",
                                           token.source_file, token.line_no)
                self._add_symbol_to_table(label_name_for_symbol_table, equ_value, token.source_file, token.line_no)
            
            elif mnem_upper not in ['ORG', 'EQU']: # Regular instruction or DB/DW
                instr_info = INSTRUCTION_SET.get(mnem_upper)
                if instr_info is None:
                    raise ParserError(f"Unknown mnemonic or directive: '{mnem_upper}'.", token.source_file, token.line_no)
                
                num_bytes_for_line = 0
                if mnem_upper in ["DB", "DW"]:
                    num_bytes_for_line = self._calculate_db_dw_size(mnem_upper, final_operand, token.source_file, token.line_no)
                else:
                    num_bytes_for_line = instr_info.size
                
                effective_address += num_bytes_for_line
                logger.debug(f"Address after '{final_mnemonic}': 0x{effective_address:04X} (+{num_bytes_for_line})", extra={'source_file': token.source_file, 'line_no': token.line_no})

        self._files_in_recursion_stack.pop()
        logger.debug(f"Finished processing of file: {normalized_filepath}. Returning address: 0x{effective_address:04X}, final active_global_scope for caller: {active_global_label}")
        return effective_address, active_global_label 