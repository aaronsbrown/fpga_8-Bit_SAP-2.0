# software/assembler/src/assembler.py

# Ensure these imports are at the top of your assembler.py
import argparse
import logging
import os
import re 
from typing import List, Dict, Optional, Tuple 
from dataclasses import dataclass

# Import the NEW Parser and its Token/ParserError from parser.py
try:
    # Make sure InstrInfo is imported from constants if it's used as a type hint directly
    # However, we are using string forward references like 'InstrInfo' and 'Token'
    # so direct import for type hinting in class body might not be strictly necessary if Python version handles it.
    from parser import Parser, Token, ParserError, CSV_SPLIT_REGEX 
    from constants import INSTRUCTION_SET, DEBUG, InstrInfo # Keep InstrInfo imported for runtime access
except ImportError:
    from .parser import Parser, Token, ParserError, CSV_SPLIT_REGEX
    from .constants import INSTRUCTION_SET, DEBUG, InstrInfo


logger = logging.getLogger(__name__) 

class AssemblerError(Exception): 
    """Custom exception for assembly errors, includes source file context."""
    def __init__(self, message: str, source_file: Optional[str] = None, line_no: Optional[int] = None) -> None:
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
        return f"AssemblerError: {context}{self.base_message}"


@dataclass
class MemoryRegion: 
    """Represents a memory region for output file generation with address tracking."""
    name: str
    start_addr: int
    end_addr: int
    output_filename: str
    lines: List[str]
    next_expected_relative_addr: int
    has_emitted_any_content: bool


class Assembler:
    """
    Two-pass assembler for 8-bit SAP2 CPU that converts assembly language into machine code.
    
    The assembler performs two passes:
    1. Parsing pass: Tokenizes input, resolves symbols, handles includes and labels
    2. Assembly pass: Generates machine code and emits bytes to configured memory regions
    
    Supports memory-mapped regions, string literals with escape sequences, arithmetic expressions,
    and functions like LOW_BYTE/HIGH_BYTE for advanced address manipulation.
    """
    def __init__(self, input_filepath: str, output_specifier: str, region_configs: Optional[List[Tuple[str, str, str]]]) -> None:
        self.input_filepath = input_filepath 
        self.output_specifier = output_specifier 
        self.region_configs = region_configs
        
        self.regions: List[MemoryRegion] = []
        self.symbols: Dict[str, int] = {}      
        self.parsed_tokens: List['Token'] = [] # Use forward reference for Token

        self._setup_memory_regions()
        logger.info("Assembler initialized.")

    def _setup_memory_regions(self) -> None:
        output_base_dir = "." 
        if self.region_configs:
            output_base_dir = self.output_specifier
            if output_base_dir and (not os.path.exists(output_base_dir) or not os.path.isdir(output_base_dir)):
                if os.path.splitext(output_base_dir)[1]: 
                    output_base_dir = os.path.dirname(output_base_dir)
                if output_base_dir : 
                    os.makedirs(output_base_dir, exist_ok=True)
                else: 
                    output_base_dir = "."
            elif not output_base_dir: 
                output_base_dir = "."

            for name, start_hex, end_hex in self.region_configs:
                try:
                    start_addr = int(start_hex, 16); end_addr = int(end_hex, 16)
                except ValueError: raise AssemblerError(f"Invalid hex address in region '{name}': start='{start_hex}', end='{end_hex}'")
                if not (0x0000 <= start_addr <= 0xFFFF and 0x0000 <= end_addr <= 0xFFFF): raise AssemblerError(f"Address for region '{name}' out of 16-bit range.")
                if start_addr > end_addr: raise AssemblerError(f"Region '{name}': start address 0x{start_addr:X} > end address 0x{end_addr:X}")
                self.regions.append(MemoryRegion(name=name, start_addr=start_addr, end_addr=end_addr, output_filename=os.path.join(output_base_dir, f"{name}.hex"), lines=[], next_expected_relative_addr=0, has_emitted_any_content=False))
        else: 
            output_file_path = self.output_specifier
            single_output_file_dir = os.path.dirname(output_file_path)
            if single_output_file_dir: os.makedirs(single_output_file_dir, exist_ok=True)
            self.regions.append(MemoryRegion(name="DEFAULT_OUTPUT", start_addr=0x0000, end_addr=0xFFFF, output_filename=output_file_path, lines=[], next_expected_relative_addr=0, has_emitted_any_content=False))
        
        if not self.regions: raise AssemblerError("Internal error: No output regions were configured.")
        logger.debug(f"Memory regions configured: {len(self.regions)} regions.")


    def _resolve_raw_symbol_or_literal(self, value_str: str, context_description: str, current_token: 'Token') -> int:
        """Resolves a plain symbol, numeric literal, or character literal to an integer."""
        s = value_str.strip()
        # err_src_file_basename and err_line_no are available from current_token if needed for errors

        # Check for character literal first (single quotes)
        if s.startswith("'") and s.endswith("'"):
            return self._parse_character_literal(s, current_token)
        
        # Check for unterminated character literal
        if s.startswith("'") and not s.endswith("'"):
            raise AssemblerError(f"Unterminated character literal: '{s}'",
                                 source_file=current_token.source_file, line_no=current_token.line_no)

        if s in self.symbols:
            return self.symbols[s]
        
        base_to_use = 10
        num_str = s
        if s.startswith('$'):
            base_to_use = 16
            num_str = s[1:]
        elif s.startswith('%'):
            base_to_use = 2
            num_str = s[1:]
        
        try:
            val = int(num_str, base_to_use)
            return val
        except ValueError:
            type_str = "hexadecimal" if base_to_use == 16 else "binary" if base_to_use == 2 else "decimal"
            raise AssemblerError(f"Bad {type_str} value for {context_description}: '{value_str}'. Not a known symbol.",
                                 source_file=current_token.source_file, line_no=current_token.line_no)

    def _parse_character_literal(self, char_literal_str: str, current_token: 'Token') -> int:
        """
        Parse a character literal (e.g., 'A', '\\n') and return its ASCII value.
        
        Args:
            char_literal_str: Character literal string including quotes (e.g., "'A'")
            current_token: Token context for error reporting
            
        Returns:
            ASCII value of the character
            
        Raises:
            AssemblerError: If character literal is malformed
        """
        # Remove outer quotes
        if len(char_literal_str) < 2 or not (char_literal_str.startswith("'") and char_literal_str.endswith("'")):
            raise AssemblerError(f"Malformed character literal: '{char_literal_str}'",
                                 source_file=current_token.source_file, line_no=current_token.line_no)
        
        char_content = char_literal_str[1:-1]
        
        # Check for empty character literal
        if not char_content:
            raise AssemblerError(f"Empty character literal: '{char_literal_str}'",
                                 source_file=current_token.source_file, line_no=current_token.line_no)
        
        # Check for unterminated character literal (this case should not occur with our check above, but being thorough)
        if len(char_literal_str) < 3:
            raise AssemblerError(f"Unterminated character literal: '{char_literal_str}'",
                                 source_file=current_token.source_file, line_no=current_token.line_no)
        
        # Process escape sequences
        if char_content.startswith('\\'):
            if len(char_content) < 2:
                raise AssemblerError(f"Incomplete escape sequence in character literal: '{char_literal_str}'",
                                     source_file=current_token.source_file, line_no=current_token.line_no)
            
            escape_char = char_content[1]
            if escape_char == 'n':
                return ord('\n')  # 10
            elif escape_char == 't':
                return ord('\t')  # 9
            elif escape_char == 'r':
                return ord('\r')  # 13
            elif escape_char == '0':
                return ord('\0')  # 0
            elif escape_char == '\\':
                return ord('\\')  # 92
            elif escape_char == "'":
                return ord("'")   # 39
            else:
                raise AssemblerError(f"Unknown escape sequence '\\{escape_char}' in character literal: '{char_literal_str}'",
                                     source_file=current_token.source_file, line_no=current_token.line_no)
        
        # Regular character - must be exactly one character
        if len(char_content) != 1:
            raise AssemblerError(f"Character literal must contain exactly one character: '{char_literal_str}' (contains {len(char_content)} characters)",
                                 source_file=current_token.source_file, line_no=current_token.line_no)
        
        return ord(char_content[0])

    def _resolve_expression_to_int(self, expression_str: str, current_token: 'Token') -> int:
        """
        Recursively resolves an expression string (symbol, literal, arithmetic, logical, functions) to an integer.
        
        Args:
            expression_str: Expression string to resolve (e.g., "LOW_BYTE(SYMBOL)", "A + B", "MASK_A | MASK_B")
            current_token: Token context for error reporting
            
        Returns:
            Integer value of the resolved expression
            
        Raises:
            AssemblerError: If expression cannot be resolved
        """
        expr = expression_str.strip()

        # Try function call parsing first (highest precedence)
        func_result = self._try_parse_function_call(expr, current_token)
        if func_result is not None:
            return func_result

        # Try parentheses parsing (grouping)
        paren_result = self._try_parse_parentheses(expr, current_token)
        if paren_result is not None:
            return paren_result

        # Try logical expression parsing (|, ^, &) - lowest precedence
        logical_result = self._try_parse_logical_expression(expr, current_token)
        if logical_result is not None:
            return logical_result

        # Try arithmetic expression parsing (+ -) - higher than logical
        arith_result = self._try_parse_arithmetic_expression(expr, current_token)
        if arith_result is not None:
            return arith_result

        # Try shift expression parsing - higher precedence than arithmetic  
        shift_result = self._try_parse_shift_expression(expr, current_token)
        if shift_result is not None:
            return shift_result

        # Try unary expression parsing (NOT operator) - high precedence
        unary_result = self._try_parse_unary_expression(expr, current_token)
        if unary_result is not None:
            return unary_result

        # Fall back to raw symbol/literal parsing
        return self._resolve_raw_symbol_or_literal(expr, "expression component", current_token)

    def _try_parse_function_call(self, expr: str, current_token: 'Token') -> Optional[int]:
        """
        Try to parse expression as a function call (LOW_BYTE/HIGH_BYTE).
        
        Args:
            expr: Expression string to check for function call pattern
            current_token: Token context for error reporting
            
        Returns:
            Function result if expression is a function call, None otherwise
            
        Raises:
            AssemblerError: If function call is malformed or argument is invalid
        """
        full_func_match = re.fullmatch(r"(LOW_BYTE|HIGH_BYTE)\s*\(\s*(.+)\s*\)", expr, re.IGNORECASE)
        if not full_func_match:
            return None
            
        func_name = full_func_match.group(1).upper()
        inner_expr_str = full_func_match.group(2).strip()
        
        # Recursively resolve the function argument
        value = self._resolve_expression_to_int(inner_expr_str, current_token)

        if not (0x0000 <= value <= 0xFFFF):
            raise AssemblerError(f"Value for {func_name} argument '{inner_expr_str}' (resolved to 0x{value:X}) is out of 16-bit range (0x0000-0xFFFF).",
                                 source_file=current_token.source_file, line_no=current_token.line_no)

        if func_name == "LOW_BYTE":
            return value & 0xFF
        else:  # HIGH_BYTE
            return (value >> 8) & 0xFF

    def _try_parse_arithmetic_expression(self, expr: str, current_token: 'Token') -> Optional[int]:
        """
        Try to parse expression as arithmetic (addition/subtraction).
        
        Args:
            expr: Expression string to check for arithmetic pattern
            current_token: Token context for error reporting
            
        Returns:
            Arithmetic result if expression contains operators, None otherwise
            
        Raises:
            AssemblerError: If arithmetic expression is malformed
        """
        # Find the rightmost + or - operator for left-to-right evaluation
        op_char, split_pos = self._find_rightmost_arithmetic_operator(expr)
        
        if not op_char or split_pos <= 0:
            return None

        lhs_str = expr[:split_pos].strip()
        rhs_str = expr[split_pos+1:].strip()

        if not lhs_str or not rhs_str:
            raise AssemblerError(f"Malformed arithmetic expression: '{expr}'. Missing operand around '{op_char}'.",
                                 source_file=current_token.source_file, line_no=current_token.line_no)

        lhs_val = self._resolve_expression_to_int(lhs_str, current_token)
        rhs_val = self._resolve_expression_to_int(rhs_str, current_token)
        
        if op_char == '+':
            return lhs_val + rhs_val
        else:  # op_char == '-'
            return lhs_val - rhs_val

    def _find_rightmost_arithmetic_operator(self, expr: str) -> Tuple[Optional[str], int]:
        """
        Find the rightmost arithmetic operator (+ or -) in an expression.
        
        Args:
            expr: Expression string to search
            
        Returns:
            Tuple of (operator_char, position) or (None, -1) if no operator found
        """
        return self._find_rightmost_operator_outside_parens(expr, ['+', '-'])

    def _try_parse_logical_expression(self, expr: str, current_token: 'Token') -> Optional[int]:
        """
        Try to parse expression as logical operations (|, ^, &) with proper precedence.
        
        Args:
            expr: Expression string to check for logical pattern
            current_token: Token context for error reporting
            
        Returns:
            Logical result if expression contains logical operators, None otherwise
            
        Raises:
            AssemblerError: If logical expression is malformed
        """
        # Find the rightmost logical operator with proper precedence (| lowest, & highest)
        op_char, split_pos = self._find_rightmost_logical_operator(expr)
        
        if not op_char or split_pos <= 0:
            return None

        lhs_str = expr[:split_pos].strip()
        rhs_str = expr[split_pos+len(op_char):].strip()

        if not lhs_str or not rhs_str:
            raise AssemblerError(f"Malformed logical expression: '{expr}'. Missing operand around '{op_char}'.",
                                 source_file=current_token.source_file, line_no=current_token.line_no)

        lhs_val = self._resolve_expression_to_int(lhs_str, current_token)
        rhs_val = self._resolve_expression_to_int(rhs_str, current_token)
        
        if op_char == '|':
            return lhs_val | rhs_val
        elif op_char == '^':
            return lhs_val ^ rhs_val
        elif op_char == '&':
            return lhs_val & rhs_val
        else:
            # Should not reach here
            raise AssemblerError(f"Internal error: unknown logical operator '{op_char}'.",
                                 source_file=current_token.source_file, line_no=current_token.line_no)

    def _find_rightmost_operator_outside_parens(self, expr: str, operators: List[str]) -> Tuple[Optional[str], int]:
        """
        Find the rightmost occurrence of any operator that is not inside parentheses.
        
        Args:
            expr: Expression string to search
            operators: List of operators to search for (in order of precedence, lowest first)
            
        Returns:
            Tuple of (operator_string, position) or (None, -1) if no operator found
        """
        for op in operators:
            # Find all occurrences of this operator
            pos = len(expr)
            while True:
                pos = expr.rfind(op, 0, pos)
                if pos == -1:
                    break
                if pos == 0:
                    break  # Can't have LHS operand at position 0
                    
                # Check if this operator is inside parentheses
                paren_depth = 0
                for i in range(pos):
                    if expr[i] == '(':
                        paren_depth += 1
                    elif expr[i] == ')':
                        paren_depth -= 1
                
                if paren_depth == 0:  # Not inside parentheses
                    return op, pos
                
                pos -= 1
                if pos < 0:
                    break
                
        return None, -1

    def _find_rightmost_logical_operator(self, expr: str) -> Tuple[Optional[str], int]:
        """
        Find the rightmost logical operator (|, ^, &) with proper precedence.
        Precedence: | (lowest) > ^ > & (highest)
        
        Args:
            expr: Expression string to search
            
        Returns:
            Tuple of (operator_char, position) or (None, -1) if no operator found
        """
        return self._find_rightmost_operator_outside_parens(expr, ['|', '^', '&'])

    def _try_parse_shift_expression(self, expr: str, current_token: 'Token') -> Optional[int]:
        """
        Try to parse expression as shift operations (<<, >>).
        
        Args:
            expr: Expression string to check for shift pattern
            current_token: Token context for error reporting
            
        Returns:
            Shift result if expression contains shift operators, None otherwise
            
        Raises:
            AssemblerError: If shift expression is malformed
        """
        # Find the rightmost shift operator
        op_str, split_pos = self._find_rightmost_shift_operator(expr)
        
        if not op_str or split_pos <= 0:
            return None

        lhs_str = expr[:split_pos].strip()
        rhs_str = expr[split_pos+len(op_str):].strip()

        if not lhs_str or not rhs_str:
            raise AssemblerError(f"Malformed shift expression: '{expr}'. Missing operand around '{op_str}'.",
                                 source_file=current_token.source_file, line_no=current_token.line_no)

        lhs_val = self._resolve_expression_to_int(lhs_str, current_token)
        rhs_val = self._resolve_expression_to_int(rhs_str, current_token)
        
        if op_str == '<<':
            # Left shift - limit result to 8-bit for assembler context
            result = lhs_val << rhs_val
            return result & 0xFF  # Keep in 8-bit range
        elif op_str == '>>':
            # Right shift
            return lhs_val >> rhs_val
        else:
            # Should not reach here
            raise AssemblerError(f"Internal error: unknown shift operator '{op_str}'.",
                                 source_file=current_token.source_file, line_no=current_token.line_no)

    def _find_rightmost_shift_operator(self, expr: str) -> Tuple[Optional[str], int]:
        """
        Find the rightmost shift operator (<<, >>) in an expression.
        
        Args:
            expr: Expression string to search
            
        Returns:
            Tuple of (operator_string, position) or (None, -1) if no operator found
        """
        return self._find_rightmost_operator_outside_parens(expr, ['<<', '>>'])

    def _try_parse_unary_expression(self, expr: str, current_token: 'Token') -> Optional[int]:
        """
        Try to parse expression as unary operation (~).
        
        Args:
            expr: Expression string to check for unary pattern
            current_token: Token context for error reporting
            
        Returns:
            Unary result if expression starts with unary operator, None otherwise
            
        Raises:
            AssemblerError: If unary expression is malformed
        """
        if not expr.startswith('~'):
            return None
            
        # Extract operand after the ~ operator
        operand_str = expr[1:].strip()
        
        if not operand_str:
            raise AssemblerError(f"Malformed unary expression: '{expr}'. Missing operand after '~'.",
                                 source_file=current_token.source_file, line_no=current_token.line_no)

        operand_val = self._resolve_expression_to_int(operand_str, current_token)
        
        # Bitwise NOT - limit to 8-bit result for assembler context
        return (~operand_val) & 0xFF

    def _try_parse_parentheses(self, expr: str, current_token: 'Token') -> Optional[int]:
        """
        Try to parse expression with parentheses for grouping.
        
        Args:
            expr: Expression string to check for parentheses pattern
            current_token: Token context for error reporting
            
        Returns:
            Result of parenthesized expression, None if no parentheses found
            
        Raises:
            AssemblerError: If parentheses are malformed or mismatched
        """
        expr = expr.strip()
        
        # Check if expression is fully wrapped in parentheses
        if not (expr.startswith('(') and expr.endswith(')')):
            return None
            
        # Check if the outer parentheses actually wrap the entire expression
        # by ensuring they are balanced when we ignore the outer pair
        paren_depth = 0
        for i, char in enumerate(expr[1:-1]):  # Skip first and last char
            if char == '(':
                paren_depth += 1
            elif char == ')':
                paren_depth -= 1
                if paren_depth < 0:
                    # Found a closing paren that doesn't match an opening one
                    # This means the outer parens don't wrap the entire expression
                    return None
        
        if paren_depth != 0:
            # Unbalanced parentheses - outer parens don't wrap entire expression
            return None
            
        # Extract content inside parentheses
        inner_expr = expr[1:-1].strip()
        
        if not inner_expr:
            raise AssemblerError(f"Empty parentheses in expression: '{expr}'.",
                                 source_file=current_token.source_file, line_no=current_token.line_no)
        
        # Recursively evaluate the inner expression
        return self._resolve_expression_to_int(inner_expr, current_token)

    def _parse_value_or_symbol(self, value_str: Optional[str], context_description: str, current_token: 'Token') -> int:
        """Wrapper to resolve an expression string from an operand to an integer value."""
        if not value_str:
            raise AssemblerError(f"{context_description} is missing its value.",
                                 source_file=current_token.source_file, line_no=current_token.line_no)
        
        try:
            return self._resolve_expression_to_int(value_str, current_token)
        except AssemblerError: 
            raise 
        except Exception as e: 
            # Add exc_info=True for better debugging of unexpected errors
            logger.error(f"Unexpected error resolving {context_description} '{value_str}': {e}", exc_info=True)
            raise AssemblerError(f"Unexpected error resolving {context_description} '{value_str}': {e}",
                                 source_file=current_token.source_file, line_no=current_token.line_no)

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
                        raise AssemblerError(f"Incomplete hex escape sequence at end of string", source_file=source_file, line_no=line_no)
                    hex_digits = string_content[i + 2:i + 4]
                    if len(hex_digits) != 2:
                        raise AssemblerError(f"Incomplete hex escape sequence '\\x{hex_digits}' - expected 2 hex digits", source_file=source_file, line_no=line_no)
                    try:
                        hex_value = int(hex_digits, 16)
                        result.append(chr(hex_value))
                        i += 4
                    except ValueError:
                        raise AssemblerError(f"Invalid hex escape sequence '\\x{hex_digits}' - invalid hex digits", source_file=source_file, line_no=line_no)
                else:
                    raise AssemblerError(f"Unknown escape sequence '\\{next_char}' in string literal", source_file=source_file, line_no=line_no)
            else:
                result.append(string_content[i])
                i += 1
                
        return ''.join(result)

    def _process_token(self, token: 'Token', current_global_address: int) -> int:
        """
        Process a single token during assembly, handling ORG directives and regular instructions.
        
        Args:
            token: The token to process
            current_global_address: Current assembly address
            
        Returns:
            Updated global address after processing this token
            
        Raises:
            AssemblerError: If token processing fails
        """
        # Skip EQU tokens (already processed by parser)
        if not token.mnemonic or token.mnemonic.upper() == 'EQU':
            return current_global_address

        # Handle ORG directive
        if token.mnemonic.upper() == 'ORG':
            return self._handle_org_directive(token)

        # Handle regular instructions and data directives
        return self._emit_instruction(token, current_global_address)

    def _handle_org_directive(self, token: 'Token') -> int:
        """
        Handle ORG directive processing.
        
        Args:
            token: Token containing the ORG directive
            
        Returns:
            New global address set by ORG
            
        Raises:
            AssemblerError: If ORG directive is malformed or invalid
        """
        if not token.operand: 
            raise AssemblerError(f"ORG directive missing operand in assembler pass.", source_file=token.source_file, line_no=token.line_no)
        
        try:
            resolved_org_address = self._parse_value_or_symbol(token.operand, "ORG address", token)
        except AssemblerError as e_org: 
            raise AssemblerError(f"Could not resolve ORG operand '{token.operand}': {e_org.base_message}",
                                 source_file=token.source_file, line_no=token.line_no) from e_org
        
        if not (0x0000 <= resolved_org_address <= 0xFFFF):
            raise AssemblerError(f"ORG address 0x{resolved_org_address:04X} is out of 16-bit range.",
                                 source_file=token.source_file, line_no=token.line_no)

        # Reset region tracking for new origin
        for region in self.regions:
            region.next_expected_relative_addr = -1 
            
        logger.debug(f"ORG encountered. Global address set to 0x{resolved_org_address:04X}", extra={'source_file': os.path.basename(token.source_file), 'line_no': token.line_no})
        return resolved_org_address

    def _emit_instruction(self, token: 'Token', current_global_address: int) -> int:
        """
        Emit instruction opcode and operand bytes for a regular instruction or data directive.
        
        Args:
            token: Token containing the instruction/directive
            current_global_address: Current assembly address
            
        Returns:
            Updated global address after emitting instruction
            
        Raises:
            AssemblerError: If instruction emission fails
        """
        instr_info = INSTRUCTION_SET.get(token.mnemonic.upper())
        if instr_info is None: 
            raise AssemblerError(f"Unknown mnemonic '{token.mnemonic}' in assembler pass (should have been caught by parser).",
                                 source_file=token.source_file, line_no=token.line_no)

        # Emit opcode if instruction has one
        if instr_info.opcode is not None:
            target_region_for_opcode = self._find_region_for_address(current_global_address)
            if target_region_for_opcode:
                self._emit_byte_to_region(target_region_for_opcode, instr_info.opcode, current_global_address, token)
            elif self.regions: 
                logger.warning(f"Opcode for '{token.mnemonic}' at global address 0x{current_global_address:04X} is outside all defined memory regions. Opcode not emitted.",
                               extra={'source_file': os.path.basename(token.source_file), 'line_no': token.line_no})
            current_global_address += 1

        # Emit operand bytes
        operand_bytes = self._encode_operand(token.operand, instr_info, token)
        for byte_val in operand_bytes:
            target_region_for_byte = self._find_region_for_address(current_global_address)
            if target_region_for_byte:
                self._emit_byte_to_region(target_region_for_byte, byte_val, current_global_address, token)
            elif self.regions: 
                 logger.warning(f"Operand/data byte for '{token.mnemonic}' (value 0x{byte_val:02X}) at global address 0x{current_global_address:04X} is outside all defined memory regions. Byte not emitted.",
                                extra={'source_file': os.path.basename(token.source_file), 'line_no': token.line_no})
            current_global_address += 1
            
        return current_global_address

    def _find_region_for_address(self, global_address: int) -> Optional[MemoryRegion]:
        """
        Find the memory region that contains the given global address.
        
        Args:
            global_address: Address to find region for
            
        Returns:
            MemoryRegion containing the address, or None if not found
        """
        for region in self.regions:
            if region.start_addr <= global_address <= region.end_addr:
                return region
        return None

    def _emit_address_directive_to_region(self, region: MemoryRegion, global_addr: int) -> None:
        relative_addr = global_addr - region.start_addr
        if not (0 <= relative_addr <= (region.end_addr - region.start_addr)):
             logger.warning(f"Internal: Emitting @ADDR for relative address 0x{relative_addr:X} (global 0x{global_addr:X}) "
                            f"which seems outside expected bounds for region '{region.name}' (size {region.end_addr - region.start_addr + 1}).")
        region.lines.append(f"@{relative_addr:04X}")
        region.next_expected_relative_addr = relative_addr 
        region.has_emitted_any_content = True


    def _emit_byte_to_region(self, region: MemoryRegion, byte_val: int, global_addr_of_byte: int, token_context: 'Token') -> None:
        relative_addr_of_byte = global_addr_of_byte - region.start_addr
        
        if not (region.start_addr <= global_addr_of_byte <= region.end_addr):
            logger.warning(f"[{os.path.basename(token_context.source_file)} line {token_context.line_no}] "
                           f"Byte 0x{byte_val:02X} for '{token_context.mnemonic}' at global address 0x{global_addr_of_byte:04X} "
                           f"is being considered for region '{region.name}' (0x{region.start_addr:04X}-0x{region.end_addr:04X}) "
                           f"but is outside its defined range. Emission skipped for this region.")
            return 

        if not region.has_emitted_any_content or region.next_expected_relative_addr != relative_addr_of_byte:
            self._emit_address_directive_to_region(region, global_addr_of_byte)
        
        region.lines.append(f"{byte_val & 0xFF:02X}")
        region.next_expected_relative_addr = relative_addr_of_byte + 1 
        region.has_emitted_any_content = True

    def _encode_operand(self, operand_str: Optional[str], instr_info: 'InstrInfo', current_token: 'Token') -> List[int]:
        """
        Encode operand into byte list for instructions and data directives.
        
        Args:
            operand_str: Operand string from token (may be None)
            instr_info: Instruction information from constants
            current_token: Token context for error reporting
            
        Returns:
            List of bytes representing the encoded operand
            
        Raises:
            AssemblerError: If operand encoding fails
        """
        mnemonic_for_error = current_token.mnemonic or "directive"
        
        # Handle DB directive separately
        if mnemonic_for_error.upper() == 'DB':
            return self._encode_db_operand(operand_str, current_token)
        
        # Handle standard operand encoding for other instructions/directives
        return self._encode_standard_operand(operand_str, instr_info, current_token)

    def _encode_db_operand(self, operand_str: Optional[str], current_token: 'Token') -> List[int]:
        """
        Encode DB directive operand into byte list, handling strings and numeric values.
        
        Args:
            operand_str: DB operand string containing comma-separated values/strings
            current_token: Token context for error reporting
            
        Returns:
            List of bytes from DB operand
            
        Raises:
            AssemblerError: If DB operand encoding fails
        """
        if not operand_str:
            raise AssemblerError(f"DB directive requires operand(s).", source_file=current_token.source_file, line_no=current_token.line_no)
        
        output_bytes: List[int] = []
        items = CSV_SPLIT_REGEX.split(operand_str)
        
        for item_text_raw in items:
            item_text = item_text_raw.strip()
            if not item_text: 
                continue

            if item_text.startswith('"') and item_text.endswith('"'): 
                # String literal processing
                if len(item_text) < 2:
                    raise AssemblerError(f"Malformed string literal in DB: {item_text}", source_file=current_token.source_file, line_no=current_token.line_no)
                string_content = item_text[1:-1]
                processed_string = self._process_string_escapes(string_content, current_token.source_file, current_token.line_no)
                
                for char_in_string in processed_string:
                    byte_val = ord(char_in_string)
                    if not (0x00 <= byte_val <= 0xFF): 
                        raise AssemblerError(f"Character '{char_in_string}' in string for DB has value {byte_val} out of 8-bit range.",
                                             source_file=current_token.source_file, line_no=current_token.line_no)
                    output_bytes.append(byte_val)
            else: 
                # Numeric value processing
                val_to_parse = item_text.lstrip('#').strip()
                byte_val = self._parse_value_or_symbol(val_to_parse, f"DB item '{item_text}'", current_token)
                if not (0x00 <= byte_val <= 0xFF):
                    raise AssemblerError(f"Value 0x{byte_val:X} ('{item_text}') for DB is out of 8-bit range (0x00-0xFF).",
                                         source_file=current_token.source_file, line_no=current_token.line_no)
                output_bytes.append(byte_val & 0xFF)
                
        return output_bytes

    def _encode_standard_operand(self, operand_str: Optional[str], instr_info: 'InstrInfo', current_token: 'Token') -> List[int]:
        """
        Encode standard instruction operand into byte list.
        
        Args:
            operand_str: Operand string from token (may be None)
            instr_info: Instruction information from constants
            current_token: Token context for error reporting
            
        Returns:
            List of bytes representing the encoded operand
            
        Raises:
            AssemblerError: If operand encoding fails
        """
        mnemonic_for_error = current_token.mnemonic or "directive"
        expected_operand_bytes = instr_info.size - (1 if instr_info.opcode is not None else 0)

        # No operand string provided
        if not operand_str:
            if expected_operand_bytes > 0:
                raise AssemblerError(f"Mnemonic '{mnemonic_for_error}' expects an operand, but none given.",
                                     source_file=current_token.source_file, line_no=current_token.line_no)
            return []

        # Operand string provided but none expected
        if expected_operand_bytes == 0: 
            raise AssemblerError(f"Operand '{operand_str}' provided for {mnemonic_for_error} which takes no operand.",
                                 source_file=current_token.source_file, line_no=current_token.line_no)

        # Parse and encode operand value
        cleaned_operand_str = operand_str.lstrip('#').strip()
        val = self._parse_value_or_symbol(cleaned_operand_str, f"operand for '{mnemonic_for_error}'", current_token)
        
        if expected_operand_bytes == 1: 
            if not (0x00 <= val <= 0xFF): 
                raise AssemblerError(f"Value 0x{val:X} ('{operand_str}') for {mnemonic_for_error} is out of 8-bit range (0x00-0xFF).",
                                     source_file=current_token.source_file, line_no=current_token.line_no)
            return [val & 0xFF]
        elif expected_operand_bytes == 2: 
            if not (0x0000 <= val <= 0xFFFF): 
                raise AssemblerError(f"Value 0x{val:X} ('{operand_str}') for {mnemonic_for_error} is out of 16-bit range (0x0000-0xFFFF).",
                                     source_file=current_token.source_file, line_no=current_token.line_no)
            return [val & 0xFF, (val >> 8) & 0xFF] # Little-endian: LSB first
        else:
            raise AssemblerError(f"Internal error or unsupported operand size ({expected_operand_bytes} bytes) for {mnemonic_for_error}.",
                                 source_file=current_token.source_file, line_no=current_token.line_no) 

    def assemble(self) -> None:
        """
        Main assembly orchestrator: parses input, generates code, and emits bytes.
        
        Raises:
            AssemblerError: If parsing or assembly fails
        """
        logger.info(f"Starting assembly process for main file: {self.input_filepath}")
        
        # Parse input file and build symbol table
        try:
            parser_instance = Parser(self.input_filepath)
            self.symbols = parser_instance.symbol_table
            self.parsed_tokens = parser_instance.tokens
        except ParserError as e:
            logger.error(f"Parsing failed: {e}") 
            raise AssemblerError(f"Parser error: {e.base_message}", source_file=e.source_file, line_no=e.line_no) from e
        except Exception as e_gen:
            logger.error(f"An unexpected error occurred during parsing: {e_gen}", exc_info=True)
            raise AssemblerError(f"Unexpected parser error: {e_gen}")

        logger.info(f"Parsing phase complete. Symbols defined: {len(self.symbols)}, Tokens generated: {len(self.parsed_tokens)}")
        if DEBUG:
            logger.debug("Symbol Table from Parser:")
            for s, v in sorted(self.symbols.items()): 
                logger.debug(f"  {s}: 0x{v:04X}")

        # Generate code (second pass)
        logger.info("Starting code generation (second pass)...")
        current_global_address = 0 

        for token in self.parsed_tokens:
            current_global_address = self._process_token(token, current_global_address)
        
        logger.info("Code generation (second pass) complete.")

    def write_output_files(self) -> None:
        """
        Write assembled output to files for each configured memory region.
        
        Creates output directories as needed and writes hex format files containing
        the assembled machine code for each memory region that has content.
        
        Raises:
            AssemblerError: If output directory creation or file writing fails
        """
        if not self.regions:
            logger.warning("No output regions defined. Nothing to write.")
            return

        for region in self.regions:
            if not region.has_emitted_any_content:
                logger.info(f"No data assembled for region '{region.name}'. Skipping file write for '{region.output_filename}'.")
                continue

            output_dir = os.path.dirname(region.output_filename)
            if output_dir: 
                try:
                    os.makedirs(output_dir, exist_ok=True)
                    logger.debug(f"Ensured directory exists: {output_dir}")
                except OSError as e:
                    logger.error(f"Could not create directory {output_dir} for region '{region.name}': {e}")
                    raise AssemblerError(f"Failed to create output directory {output_dir}: {e}")

            try:
                with open(region.output_filename, "w") as f:
                    f.write("\n".join(region.lines))
                    if region.lines and not region.lines[-1].endswith("\n"):
                         f.write("\n") 
                logger.info(f"Wrote output for region '{region.name}' to '{region.output_filename}' ({len(region.lines)} lines).")
            except IOError as e:
                logger.error(f"Could not write to file '{region.output_filename}' for region '{region.name}': {e}")
                raise AssemblerError(f"IOError writing to {region.output_filename}: {e}")
                
def main(input_filepath: str, output_specifier: str, region_definitions: Optional[List[Tuple[str,str,str]]]) -> None:
    """
    Main assembly function that orchestrates the complete assembly process.
    
    Args:
        input_filepath: Path to the input assembly file
        output_specifier: Output file path or directory for assembled output
        region_definitions: Optional list of memory region definitions (name, start_hex, end_hex)
        
    Raises:
        ParserError: If parsing the assembly file fails
        AssemblerError: If assembly or output writing fails  
        ValueError: If unexpected value errors occur during processing
    """
    try:
        asm = Assembler(input_filepath, output_specifier, region_definitions)
        asm.assemble()
        asm.write_output_files()
    except (ParserError, AssemblerError, ValueError) as e: 
        if isinstance(e, ValueError) and not isinstance(e, (ParserError, AssemblerError)):
             logger.error(f"Assembly failed due to unexpected value error: {e}", exc_info=True)
        else:
            logger.error(f"Assembly failed: {e}") 
        raise 

if __name__ == "__main__":
    default_input = "prog.asm" 
    default_output = "prog.hex"

    argp = argparse.ArgumentParser(description="Custom 8-bit CPU Assembler")
    argp.add_argument("input", nargs="?", default=default_input, help=f"Input assembly file (default: {default_input})")
    argp.add_argument(
        "output_specifier", 
        nargs="?",
        default=default_output,
        help=f"Default output file if no --region is specified, OR the output directory if --region is used (default: {default_output})."
    )
    argp.add_argument(
        "--region",
        action="append",
        nargs=3,
        metavar=("NAME", "START_ADDR_HEX", "END_ADDR_HEX"), 
        dest="regions_arg", 
        help="Define a memory region: NAME START_ADDR_HEX END_ADDR_HEX. Output file will be NAME.hex. Example: --region ROM F000 FFFF"
    )
    args = argp.parse_args()

    SCRIPT_DIR_ASM = os.path.dirname(os.path.abspath(__file__)) 
    ASSEMBLER_BASE_DIR = os.path.dirname(SCRIPT_DIR_ASM)      
    LOG_FILE_PATH = os.path.join(ASSEMBLER_BASE_DIR, "assembler.log")

    logging.basicConfig(
        level=logging.DEBUG if DEBUG else logging.INFO,
        format="%(levelname)-8s [%(filename)s:%(lineno)d %(funcName)s] %(message)s" if DEBUG else "%(levelname)s: %(message)s",
        handlers=[logging.FileHandler(LOG_FILE_PATH, mode='w'), logging.StreamHandler()],
    )

    try:
        main(args.input, args.output_specifier, args.regions_arg)
    except Exception: 
        exit(1)