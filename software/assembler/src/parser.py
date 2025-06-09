# software/assembler/src/parser.py
import logging
import os
import re
from typing import List, Dict, Optional, Tuple, NamedTuple
from dataclasses import dataclass

# Assuming constants.py is in the same directory or accessible via PYTHONPATH
# Adjust if your constants file is located elsewhere relative to parser.py
try:
    from .constants import INSTRUCTION_SET
except ImportError:
    # Fallback for direct execution or different project structure
    from constants import INSTRUCTION_SET


logger = logging.getLogger(__name__)


class ConditionalBlock(NamedTuple):
    """Represents a conditional assembly block state."""
    directive_type: str  # 'IFDEF' or 'IFNDEF'
    symbol_name: str     # Symbol being tested
    condition_met: bool  # Whether the condition was initially true
    in_else_block: bool  # Whether we're currently in the ELSE part
    should_assemble: bool  # Whether lines in current block should be assembled
    source_file: str     # File where directive was defined
    line_no: int         # Line number where directive was defined


@dataclass(frozen=True)
class Token:
    """Represents a tokenized piece of an assembly line, with source context."""
    line_no: int         # Line number within its original source_file
    source_file: str     # The original file path this token came from
    label:   Optional[str] # Original label, e.g., "MY_LABEL" or ".loop"
    mnemonic: Optional[str]
    operand:  Optional[str] # Operand string, local labels may be mangled here by parser

@dataclass(frozen=True)
class MacroDefinition:
    """Represents a macro definition with parameters and body."""
    name: str                    # Macro name
    parameters: List[str]        # Parameter names
    body_lines: List[str]        # Raw body lines (before expansion)
    source_file: str             # File where macro was defined
    line_no: int                 # Line number where macro was defined

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
        self.macros: Dict[str, MacroDefinition] = {}  # Macro storage
        self._files_in_recursion_stack: List[str] = []
        self._macro_expansion_counter: int = 0  # For unique local label generation
        self._conditional_stack: List[ConditionalBlock] = []

        logger.info(f"Parser initialized for main file: {self.main_input_filepath}")
        
        # First: collect all macro definitions from all files
        self._collect_macros_from_file(self.main_input_filepath)
        
        # Then: process all files with macro expansion
        self._parse_and_process_file(self.main_input_filepath, 0, None) 

        logger.info("Parsing complete. Final symbol table:")
        for sym, val in sorted(self.symbol_table.items()): # Sort for consistent logging
            logger.info(f"  {sym!r} -> 0x{val:04X}")
        logger.info(f"Total tokens collected for assembler: {len(self.tokens)}")
        
        # Check for unmatched conditional directives at end of parsing
        if self._conditional_stack:
            unmatched_block = self._conditional_stack[-1]
            raise ParserError(f"Unmatched {unmatched_block.directive_type} directive - missing ENDIF", 
                              unmatched_block.source_file, unmatched_block.line_no)

    def _should_assemble_line(self) -> bool:
        """Determine if the current line should be assembled based on conditional stack."""
        if not self._conditional_stack:
            return True
        
        # If any level in the stack says don't assemble, then don't assemble
        for block in self._conditional_stack:
            if not block.should_assemble:
                return False
        return True

    def _handle_conditional_directive(self, mnemonic: str, operand: Optional[str], 
                                      source_file: str, line_no: int) -> bool:
        """
        Handle conditional assembly directives (IFDEF, IFNDEF, ELSE, ENDIF).
        
        Returns:
            True if the directive was handled (and caller should continue to next line)
            False if this is not a conditional directive
        """
        mnemonic_upper = mnemonic.upper()
        
        if mnemonic_upper in ('IFDEF', 'IFNDEF'):
            if not operand:
                raise ParserError(f"{mnemonic_upper} directive requires a symbol name", source_file, line_no)
            
            symbol_name = operand.strip()
            is_defined = symbol_name in self.symbol_table
            
            # Determine if condition is met
            if mnemonic_upper == 'IFDEF':
                condition_met = is_defined
            else:  # IFNDEF
                condition_met = not is_defined
            
            # Determine if this block should be assembled
            # Consider parent blocks - if any parent says don't assemble, we inherit that
            parent_should_assemble = self._should_assemble_line()
            should_assemble = parent_should_assemble and condition_met
            
            # Push new conditional block
            new_block = ConditionalBlock(
                directive_type=mnemonic_upper,
                symbol_name=symbol_name,
                condition_met=condition_met,
                in_else_block=False,
                should_assemble=should_assemble,
                source_file=source_file,
                line_no=line_no
            )
            self._conditional_stack.append(new_block)
            
            logger.debug(f"{mnemonic_upper} {symbol_name}: symbol_defined={is_defined}, "
                        f"condition_met={condition_met}, should_assemble={should_assemble}")
            return True
            
        elif mnemonic_upper == 'ELSE':
            if not self._conditional_stack:
                raise ParserError("ELSE directive without matching IFDEF or IFNDEF", source_file, line_no)
            
            current_block = self._conditional_stack[-1]
            if current_block.in_else_block:
                raise ParserError("Multiple ELSE directives in same conditional block", source_file, line_no)
            
            # Switch to else block - invert the assembly condition
            parent_should_assemble = True
            if len(self._conditional_stack) > 1:
                # Check if parent blocks allow assembly
                for block in self._conditional_stack[:-1]:
                    if not block.should_assemble:
                        parent_should_assemble = False
                        break
            
            # In ELSE block, assemble if parent allows AND original condition was NOT met
            should_assemble = parent_should_assemble and not current_block.condition_met
            
            # Replace top of stack with updated block
            updated_block = current_block._replace(
                in_else_block=True,
                should_assemble=should_assemble
            )
            self._conditional_stack[-1] = updated_block
            
            logger.debug(f"ELSE: switching to else block, should_assemble={should_assemble}")
            return True
            
        elif mnemonic_upper == 'ENDIF':
            if not self._conditional_stack:
                raise ParserError("ENDIF directive without matching IFDEF or IFNDEF", source_file, line_no)
            
            closed_block = self._conditional_stack.pop()
            logger.debug(f"ENDIF: closed {closed_block.directive_type} block for '{closed_block.symbol_name}'")
            return True
            
        return False

    def _parse_macro_definition(self, macro_line: str, lines: List[str], line_index: int, 
                                source_file: str) -> Tuple[MacroDefinition, int]:
        """
        Parse a macro definition starting from MACRO line.
        
        Args:
            macro_line: The line containing "MACRO name [params]"
            lines: All lines in the file
            line_index: Current line index (0-based)
            source_file: Source file path
            
        Returns:
            Tuple of (MacroDefinition, end_line_index)
            
        Raises:
            ParserError: If macro definition is malformed
        """
        line_no = line_index + 1  # Convert to 1-based
        
        # Parse MACRO line
        macro_match = re.match(r'^\s*MACRO\s+([A-Za-z_]\w*)(?:\s+(.+?))?\s*(?:;.*)?$', macro_line, re.IGNORECASE)
        if not macro_match:
            raise ParserError("Malformed MACRO directive", source_file, line_no)
        
        macro_name = macro_match.group(1).upper()
        params_str = macro_match.group(2)
        
        # Check for duplicate macro definition
        if macro_name in self.macros:
            raise ParserError(f"Macro '{macro_name}' already defined at {self.macros[macro_name].source_file}:{self.macros[macro_name].line_no}", 
                              source_file, line_no)
        
        # Parse parameters
        parameters: List[str] = []
        if params_str:
            # Split by comma and clean up parameter names
            param_parts = [p.strip() for p in params_str.split(',')]
            for param in param_parts:
                if not param:
                    continue
                if not re.match(r'^[A-Za-z_]\w*$', param):
                    raise ParserError(f"Invalid parameter name '{param}' in macro definition", source_file, line_no)
                parameters.append(param)
        
        # Collect macro body lines until ENDM
        body_lines: List[str] = []
        current_line_index = line_index + 1
        
        while current_line_index < len(lines):
            current_line = lines[current_line_index].rstrip()
            current_line_no = current_line_index + 1
            
            # Check for ENDM
            if re.match(r'^\s*ENDM\s*(?:;.*)?$', current_line, re.IGNORECASE):
                # Found end of macro
                macro_def = MacroDefinition(
                    name=macro_name,
                    parameters=parameters,
                    body_lines=body_lines,
                    source_file=source_file,
                    line_no=line_no
                )
                return macro_def, current_line_index
            
            # Skip empty lines and comments in macro body
            stripped_line = current_line.strip()
            if stripped_line and not stripped_line.startswith(';'):
                body_lines.append(current_line)
            elif stripped_line:  # Keep comments for formatting
                body_lines.append(current_line)
            
            current_line_index += 1
        
        # If we get here, we never found ENDM
        raise ParserError(f"Macro '{macro_name}' not closed with ENDM", source_file, line_no)

    def _expand_macro(self, macro_name: str, args: List[str], source_file: str, line_no: int) -> List[str]:
        """
        Expand a macro invocation into assembly lines with recursive expansion support.
        
        Args:
            macro_name: Name of macro to expand
            args: Arguments for macro expansion
            source_file: Source file of macro invocation
            line_no: Line number of macro invocation
            
        Returns:
            List of expanded assembly lines
            
        Raises:
            ParserError: If macro expansion fails
        """
        if macro_name not in self.macros:
            raise ParserError(f"Unknown mnemonic or macro: '{macro_name}'", source_file, line_no)
        
        macro_def = self.macros[macro_name]
        
        # Check parameter count
        if len(args) != len(macro_def.parameters):
            raise ParserError(f"Parameter count mismatch for macro '{macro_name}': expected {len(macro_def.parameters)}, got {len(args)}", 
                              source_file, line_no)
        
        # Generate unique expansion ID for local labels
        self._macro_expansion_counter += 1
        expansion_id = self._macro_expansion_counter
        
        # Create parameter substitution map
        param_map = dict(zip(macro_def.parameters, args))
        
        # Expand macro body
        expanded_lines: List[str] = []
        for body_line in macro_def.body_lines:
            expanded_line = body_line
            
            # Substitute parameters
            for param, arg in param_map.items():
                # Use word boundaries to avoid partial matches
                pattern = r'\b' + re.escape(param) + r'\b'
                expanded_line = re.sub(pattern, arg, expanded_line)
            
            # Handle local labels (@@label -> unique label)
            local_label_pattern = r'@@([A-Za-z_]\w*)'
            expanded_line = re.sub(local_label_pattern, 
                                   rf'__MACRO_{expansion_id}_\1', 
                                   expanded_line)
            
            # Check if the expanded line contains another macro invocation
            nested_parsed = self._parse_line_components(expanded_line, source_file, line_no)
            if nested_parsed:
                nested_label, nested_mnemonic, nested_operand = nested_parsed
                if nested_mnemonic and self._is_macro_invocation(nested_mnemonic.upper()):
                    # Parse nested macro arguments
                    nested_args: List[str] = []
                    if nested_operand:
                        nested_args = [arg.strip() for arg in CSV_SPLIT_REGEX.split(nested_operand)]
                        nested_args = [arg for arg in nested_args if arg]
                    
                    # Recursively expand nested macro
                    nested_expanded = self._expand_macro(nested_mnemonic.upper(), nested_args, source_file, line_no)
                    
                    # Add label to first line of nested expansion if present
                    if nested_label and nested_expanded:
                        nested_expanded[0] = f"{nested_label}: {nested_expanded[0]}"
                    elif nested_label:
                        expanded_lines.append(f"{nested_label}:")
                    
                    # Add all nested expanded lines
                    expanded_lines.extend(nested_expanded)
                    continue
            
            expanded_lines.append(expanded_line)
        
        logger.debug(f"Expanded macro '{macro_name}' with {len(args)} args into {len(expanded_lines)} lines")
        return expanded_lines

    def _is_macro_invocation(self, mnemonic: str) -> bool:
        """Check if a mnemonic is a macro invocation."""
        return mnemonic.upper() in self.macros

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

    def _load_and_validate_file(self, filepath_to_process: str) -> Tuple[str, List[str]]:
        """
        Load and validate a file for parsing, handling recursion detection.
        
        Args:
            filepath_to_process: Path to the file to load and validate
            
        Returns:
            Tuple of (normalized_filepath, lines_from_file)
            
        Raises:
            ParserError: If circular include detected or file cannot be loaded
        """
        normalized_filepath = os.path.normpath(filepath_to_process)

        if normalized_filepath in self._files_in_recursion_stack:
            raise ParserError(f"Circular INCLUDE detected: '{normalized_filepath}'",
                              source_file=self._files_in_recursion_stack[-1] if self._files_in_recursion_stack else None)
        
        self._files_in_recursion_stack.append(normalized_filepath)
        logger.debug(f"Starting processing of file: {normalized_filepath}")

        try:
            lines = self._load_lines_from_physical_file(normalized_filepath, 
                                                        requesting_file=self._files_in_recursion_stack[-2] if len(self._files_in_recursion_stack) > 1 else self.main_input_filepath, 
                                                        requesting_line_no=0)
            return normalized_filepath, lines
        except ParserError as e: 
            self._files_in_recursion_stack.pop()
            raise e

    def _process_include_directive(self, operand_candidate: str, normalized_filepath: str, line_no_in_file: int, 
                                   effective_address: int, active_global_label: Optional[str]) -> Tuple[int, Optional[str]]:
        """
        Process an INCLUDE directive by recursively parsing the included file.
        
        Args:
            operand_candidate: The filename operand from the INCLUDE directive
            normalized_filepath: Current file being processed
            line_no_in_file: Line number of the INCLUDE directive
            effective_address: Current assembly address
            active_global_label: Current global label scope
            
        Returns:
            Tuple of (updated_address, updated_global_label_scope)
            
        Raises:
            ParserError: If INCLUDE directive is malformed or file cannot be found
        """
        if not operand_candidate:
            raise ParserError("INCLUDE directive missing filename.", normalized_filepath, line_no_in_file)
        
        include_filename_rel = operand_candidate.strip('"')
        base_dir_of_current_file = os.path.dirname(normalized_filepath)
        abs_path_to_include_file = os.path.normpath(os.path.join(base_dir_of_current_file, include_filename_rel))
        
        logger.info(f"Including: '{abs_path_to_include_file}' (from '{normalized_filepath}' line {line_no_in_file})")
        # Pass current effective_address and current active_global_label to the included file
        return self._parse_and_process_file(abs_path_to_include_file, effective_address, active_global_label)

    def _update_symbol_table_and_address(self, label_name_for_symbol_table: Optional[str], 
                                         final_mnemonic: str, final_operand: Optional[str],
                                         effective_address: int, normalized_filepath: str, line_no_in_file: int) -> int:
        """
        Update symbol table and calculate new address after processing a line.
        
        Args:
            label_name_for_symbol_table: Label name to add to symbol table (if any)
            final_mnemonic: Processed mnemonic
            final_operand: Processed operand
            effective_address: Current assembly address
            normalized_filepath: Current file being processed
            line_no_in_file: Current line number
            
        Returns:
            Updated effective address after processing this line
            
        Raises:
            ParserError: If directive is malformed or symbol conflicts occur
        """
        # Add label to symbol table (if it's for an addressable instruction/data, not an EQU's own label)
        # EQU handles its own label addition separately.
        if label_name_for_symbol_table and final_mnemonic.upper() != 'EQU':
            self._add_symbol_to_table(label_name_for_symbol_table, effective_address, normalized_filepath, line_no_in_file)

        # Handle ORG, EQU, or advance address for instructions/data
        mnem_upper = final_mnemonic.upper()
        if mnem_upper == 'ORG':
            if not final_operand: 
                raise ParserError("ORG directive missing address.", normalized_filepath, line_no_in_file)
            # Simplified ORG value resolution for parser pass (as before)
            org_val: int
            if final_operand in self.symbol_table:
                org_val = self.symbol_table[final_operand]
            else:
                try:
                    org_val = self._parse_numeric_literal(final_operand, "ORG directive", normalized_filepath, line_no_in_file)
                except ParserError as e:
                    raise ParserError(f"ORG operand '{final_operand}' must be a pre-defined symbol or numeric literal for parser's current pass. Error: {e}",
                                      normalized_filepath, line_no_in_file)
            effective_address = org_val
            logger.debug(f"Origin set to 0x{effective_address:04X} by ORG.", extra={'source_file': normalized_filepath, 'line_no': line_no_in_file})

        elif mnem_upper == 'EQU':
            # The label for EQU is 'label_name_for_symbol_table'
            if not label_name_for_symbol_table: 
                raise ParserError(f"EQU directive requires a label.", normalized_filepath, line_no_in_file)
            if not final_operand: 
                raise ParserError(f"EQU for '{label_name_for_symbol_table}' missing value.", normalized_filepath, line_no_in_file)
            
            # EQU value resolution - try expression parsing if simple lookup fails
            equ_value: int
            if final_operand in self.symbol_table:
                equ_value = self.symbol_table[final_operand]
            else:
                try:
                    # First try simple numeric literal
                    equ_value = self._parse_numeric_literal(final_operand, f"value for EQU '{label_name_for_symbol_table}'", normalized_filepath, line_no_in_file)
                except ParserError:
                    # If that fails, try basic expression parsing with currently defined symbols
                    try:
                        equ_value = self._parse_simple_expression(final_operand, normalized_filepath, line_no_in_file)
                    except ParserError as e:
                        raise ParserError(f"EQU value '{final_operand}' for '{label_name_for_symbol_table}' must be a numeric literal or a pre-defined symbol in parser's pass. Error: {e}",
                                          normalized_filepath, line_no_in_file)
            self._add_symbol_to_table(label_name_for_symbol_table, equ_value, normalized_filepath, line_no_in_file)
        
        elif mnem_upper not in ['ORG', 'EQU']: # Regular instruction or DB/DW
            instr_info = INSTRUCTION_SET.get(mnem_upper)
            if instr_info is None:
                raise ParserError(f"Unknown mnemonic or macro: '{mnem_upper}'.", normalized_filepath, line_no_in_file)
            
            num_bytes_for_line = 0
            if mnem_upper in ["DB", "DW"]:
                num_bytes_for_line = self._calculate_db_dw_size(mnem_upper, final_operand, normalized_filepath, line_no_in_file)
            else:
                num_bytes_for_line = instr_info.size
            
            effective_address += num_bytes_for_line
            logger.debug(f"Address after '{final_mnemonic}': 0x{effective_address:04X} (+{num_bytes_for_line})", extra={'source_file': normalized_filepath, 'line_no': line_no_in_file})

        return effective_address

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


    def _collect_macros_from_file(self, filepath_to_process: str) -> None:
        """
        Collect macro definitions from a file and all its includes recursively.
        This must be done first before any macro expansion.
        """
        # Load and validate file
        normalized_filepath, lines = self._load_and_validate_file(filepath_to_process)
        
        line_index = 0
        while line_index < len(lines):
            raw_line = lines[line_index]
            line_no_in_file = line_index + 1
            
            # Check for macro definition
            if re.match(r'^\s*MACRO\s+', raw_line, re.IGNORECASE):
                macro_def, end_index = self._parse_macro_definition(raw_line, lines, line_index, normalized_filepath)
                self.macros[macro_def.name] = macro_def
                logger.debug(f"Collected macro definition: {macro_def.name} with {len(macro_def.parameters)} parameters")
                line_index = end_index + 1  # Skip to after ENDM
                continue
            
            # Check for ENDM without MACRO
            if re.match(r'^\s*ENDM\s*(?:;.*)?$', raw_line, re.IGNORECASE):
                raise ParserError("ENDM without corresponding MACRO definition", normalized_filepath, line_no_in_file)
            
            # Check for INCLUDE directive to recursively collect macros
            parsed_comps = self._parse_line_components(raw_line, normalized_filepath, line_no_in_file)
            if parsed_comps:
                _, mnemonic_candidate, operand_candidate = parsed_comps
                if mnemonic_candidate and mnemonic_candidate.upper() == "INCLUDE":
                    if not operand_candidate:
                        raise ParserError("INCLUDE directive missing filename.", normalized_filepath, line_no_in_file)
                    
                    include_filename_rel = operand_candidate.strip('"')
                    base_dir_of_current_file = os.path.dirname(normalized_filepath)
                    abs_path_to_include_file = os.path.normpath(os.path.join(base_dir_of_current_file, include_filename_rel))
                    
                    # Recursively collect macros from included file
                    self._collect_macros_from_file(abs_path_to_include_file)
            
            line_index += 1
        
        # Clean up recursion stack
        self._files_in_recursion_stack.pop()

    def _parse_and_process_file(self, filepath_to_process: str, current_address: int, 
                                current_global_label_scope: Optional[str]) -> Tuple[int, Optional[str]]:
        """
        Main file processing orchestrator that parses assembly files and handles includes.
        
        Args:
            filepath_to_process: Path to the assembly file to process
            current_address: Starting address for assembly
            current_global_label_scope: Current global label scope for local label resolution
            
        Returns:
            Tuple of (final_address, final_global_label_scope)
            
        Raises:
            ParserError: If file parsing fails or circular includes detected
        """
        # Load and validate file
        normalized_filepath, lines = self._load_and_validate_file(filepath_to_process)
        
        # Initialize processing state
        active_global_label = current_global_label_scope 
        effective_address = current_address
        logger.debug(f"Starting processing of file: {normalized_filepath} (initial active_global_scope: {active_global_label})")

        # Process lines with macro expansion (macros already collected globally)
        line_index = 0
        expanded_lines: List[Tuple[str, int, str]] = []  # (line_content, original_line_no, source_file)
        
        while line_index < len(lines):
            raw_line = lines[line_index]
            line_no_in_file = line_index + 1
            
            # Skip macro definitions (already processed in global collection phase)
            if re.match(r'^\s*MACRO\s+', raw_line, re.IGNORECASE):
                # Find corresponding ENDM and skip
                while line_index < len(lines) and not re.match(r'^\s*ENDM\s*(?:;.*)?$', lines[line_index], re.IGNORECASE):
                    line_index += 1
                line_index += 1  # Skip ENDM line
                continue
            
            # Check for macro invocation
            parsed_comps = self._parse_line_components(raw_line, normalized_filepath, line_no_in_file)
            if parsed_comps:
                original_label_str, mnemonic_candidate, operand_candidate = parsed_comps
                
                # Check if mnemonic is a macro
                if mnemonic_candidate and self._is_macro_invocation(mnemonic_candidate.upper()):
                    # Parse macro arguments
                    args: List[str] = []
                    if operand_candidate:
                        args = [arg.strip() for arg in CSV_SPLIT_REGEX.split(operand_candidate)]
                        args = [arg for arg in args if arg]  # Remove empty args
                    
                    # Expand macro
                    macro_lines = self._expand_macro(mnemonic_candidate.upper(), args, normalized_filepath, line_no_in_file)
                    
                    # Add label to first expanded line if present
                    if original_label_str and macro_lines:
                        macro_lines[0] = f"{original_label_str}: {macro_lines[0]}"
                    elif original_label_str:
                        # Label but no macro body - just add the label line
                        expanded_lines.append((f"{original_label_str}:", line_no_in_file, normalized_filepath))
                    
                    # Add all expanded lines
                    for macro_line in macro_lines:
                        expanded_lines.append((macro_line, line_no_in_file, normalized_filepath))
                    
                    line_index += 1
                    continue
            
            # Regular line - add as-is
            expanded_lines.append((raw_line, line_no_in_file, normalized_filepath))
            line_index += 1

        # Process expanded lines
        for expanded_line, original_line_no, source_file in expanded_lines:
            parsed_comps = self._parse_line_components(expanded_line, source_file, original_line_no)
            if not parsed_comps:
                continue
            
            original_label_str, mnemonic_candidate, operand_candidate = parsed_comps

            # Handle conditional assembly directives first
            if mnemonic_candidate and self._handle_conditional_directive(
                mnemonic_candidate, operand_candidate, normalized_filepath, line_no_in_file):
                continue

            # Skip processing if we're in a conditional block that shouldn't be assembled
            if not self._should_assemble_line():
                continue

            # Handle INCLUDE directive
            if mnemonic_candidate and mnemonic_candidate.upper() == "INCLUDE":
                effective_address, active_global_label = self._process_include_directive(
                    operand_candidate, source_file, original_line_no, 
                    effective_address, active_global_label)
                continue

            # Normalize components with current scope
            _, final_mnemonic, final_operand = self._normalize_token_components(
                original_label_str, mnemonic_candidate, operand_candidate, 
                active_global_label, source_file, original_line_no
            )
            
            # Determine label name for symbol table and update global scope
            label_name_for_symbol_table: Optional[str] = None
            
            if original_label_str:
                if original_label_str.startswith('.'): # Local label
                    if not active_global_label:
                        raise ParserError(f"Local label '{original_label_str}' defined without a preceding global label.", source_file, original_line_no)
                    label_name_for_symbol_table = f"{active_global_label}{original_label_str}"
                else: # Global label
                    label_name_for_symbol_table = original_label_str
                    # Update active scope for subsequent lines (unless EQU)
                    if not (final_mnemonic and final_mnemonic.upper() == 'EQU'):
                        active_global_label = original_label_str
            
            # Handle label-only lines
            if not final_mnemonic:
                if label_name_for_symbol_table:
                    self._add_symbol_to_table(label_name_for_symbol_table, effective_address, source_file, original_line_no)
                continue 

            # Create and add token
            token = Token(original_line_no, source_file, original_label_str, final_mnemonic, final_operand)
            self.tokens.append(token)
            logger.debug(f"Token created: {token} (current effective_address: 0x{effective_address:04X}, next active_global_label for subsequent lines: {active_global_label})")

            # Update symbol table and calculate new address
            effective_address = self._update_symbol_table_and_address(
                label_name_for_symbol_table, final_mnemonic, final_operand,
                effective_address, source_file, original_line_no)

        # Clean up and return
        self._files_in_recursion_stack.pop()
        logger.debug(f"Finished processing of file: {normalized_filepath}. Returning address: 0x{effective_address:04X}, final active_global_scope for caller: {active_global_label}")
        return effective_address, active_global_label

    def _parse_simple_expression(self, expression_str: str, source_file: str, line_no: int) -> int:
        """
        Parse simple logical/arithmetic expressions for EQU statements in the parser.
        Only supports expressions using symbols already defined in the symbol table.
        
        Args:
            expression_str: Expression string to parse
            source_file: Source file for error reporting
            line_no: Line number for error reporting
            
        Returns:
            Integer value of the resolved expression
            
        Raises:
            ParserError: If expression cannot be resolved with current symbols
        """
        # Import assembler functionality temporarily for expression parsing
        # This creates a minimal assembler-like environment just for expression resolution
        try:
            from .assembler import Assembler, AssemblerError
        except ImportError:
            # Fallback for direct execution
            import sys
            import os
            sys.path.append(os.path.dirname(__file__))
            from assembler import Assembler, AssemblerError
        
        try:
            # Create a temporary assembler instance for expression parsing
            temp_assembler = Assembler.__new__(Assembler)
            temp_assembler.symbols = self.symbol_table.copy()  # Use current parser symbols
            
            # Create a mock token for error context
            mock_token = Token(line_no=line_no, source_file=source_file, label=None, mnemonic="EQU", operand=expression_str)
            
            # Use assembler's expression parsing
            result = temp_assembler._resolve_expression_to_int(expression_str, mock_token)
            return result
            
        except AssemblerError as e:
            # Convert assembler error to parser error
            raise ParserError(f"Cannot resolve expression '{expression_str}': {e.base_message}", source_file, line_no)
        except Exception as e:
            # Handle any other unexpected errors
            raise ParserError(f"Unexpected error parsing expression '{expression_str}': {e}", source_file, line_no) 