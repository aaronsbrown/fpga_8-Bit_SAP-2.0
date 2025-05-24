# software/assembler/src/assembler.py

# Ensure these imports are at the top of your assembler.py
import argparse
import logging
import os
import re # Should already be there if LINE_PATTERN was global
from typing import List, Dict, Optional, Tuple # Tuple is used by region_configs
from dataclasses import dataclass

# Import the NEW Parser and its Token/ParserError from parser.py
try:
    from parser import Parser, Token, ParserError
    from constants import INSTRUCTION_SET, DEBUG, InstrInfo, ASM_FILE_PATH, OUTPUT_PATH # Removed ASM_FILE_PATH, OUTPUT_PATH
except ImportError:
    from parser import Parser, Token, ParserError # Fallback
    from constants import INSTRUCTION_SET, DEBUG


logger = logging.getLogger(__name__) # Should be defined once at module level

class AssemblerError(Exception): # This can be defined once, either here or in parser.py and imported
    def __init__(self, message: str) -> None:
        super().__init__(message)
        self.message = message
    def __str__(self) -> str:
        # The ParserError now includes context, AssemblerError can be simpler
        return f"AssemblerError: {self.message}"

@dataclass
class MemoryRegion: # Keep this dataclass defined for Assembler
    name: str
    start_addr: int
    end_addr: int
    output_filename: str
    lines: List[str]
    next_expected_relative_addr: int
    has_emitted_any_content: bool


class Assembler:
    def __init__(self, input_filepath: str, output_specifier: str, region_configs: Optional[List[Tuple[str, str, str]]]) -> None:
        self.input_filepath = input_filepath 
        self.output_specifier = output_specifier 
        self.region_configs = region_configs
        
        self.regions: List[MemoryRegion] = []
        self.symbols: Dict[str, int] = {}      # Will be populated by the Parser
        self.parsed_tokens: List[Token] = [] # Will be populated by the Parser

        self._setup_memory_regions()
        logger.info("Assembler initialized.")

    def _setup_memory_regions(self) -> None:
        # This is your existing logic for setting up regions. It should be fine.
        # Ensure it handles output_base_dir correctly.
        output_base_dir = "." 
        if self.region_configs:
            output_base_dir = self.output_specifier
            if output_base_dir and (not os.path.exists(output_base_dir) or not os.path.isdir(output_base_dir)):
                if os.path.splitext(output_base_dir)[1]: # Looks like a file, use its dir
                    output_base_dir = os.path.dirname(output_base_dir)
                if output_base_dir : # If dirname is not empty
                    os.makedirs(output_base_dir, exist_ok=True)
                else: # Fallback to current dir if path was just a filename
                    output_base_dir = "."
            elif not output_base_dir: # If output_specifier was empty
                output_base_dir = "."


            for name, start_hex, end_hex in self.region_configs:
                try:
                    start_addr = int(start_hex, 16); end_addr = int(end_hex, 16)
                except ValueError: raise AssemblerError(f"Invalid hex address in region '{name}': start='{start_hex}', end='{end_hex}'")
                if not (0x0000 <= start_addr <= 0xFFFF and 0x0000 <= end_addr <= 0xFFFF): raise AssemblerError(f"Address for region '{name}' out of 16-bit range.")
                if start_addr > end_addr: raise AssemblerError(f"Region '{name}': start address 0x{start_addr:X} > end address 0x{end_addr:X}")
                self.regions.append(MemoryRegion(name=name, start_addr=start_addr, end_addr=end_addr, output_filename=os.path.join(output_base_dir, f"{name}.hex"), lines=[], next_expected_relative_addr=0, has_emitted_any_content=False))
        else: # Single output mode
            output_file_path = self.output_specifier
            single_output_file_dir = os.path.dirname(output_file_path)
            if single_output_file_dir: os.makedirs(single_output_file_dir, exist_ok=True)
            self.regions.append(MemoryRegion(name="DEFAULT_OUTPUT", start_addr=0x0000, end_addr=0xFFFF, output_filename=output_file_path, lines=[], next_expected_relative_addr=0, has_emitted_any_content=False))
        
        if not self.regions: raise AssemblerError("Internal error: No output regions were configured.")
        logger.debug(f"Memory regions configured: {len(self.regions)} regions.")


    def _parse_value_or_symbol(self, value_str: Optional[str], context_description: str, current_token: Token) -> int:
        """Resolves a string to a value, using symbol table or parsing as literal. Uses Token for error context."""
        err_src_file = os.path.basename(current_token.source_file)
        err_line_no = current_token.line_no
        
        if not value_str:
            raise AssemblerError(f"[{err_src_file} line {err_line_no}] {context_description} is missing its value.")
        
        s = value_str.strip().lstrip('#') # Strip leading # for immediate values if present

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
            return int(num_str, base_to_use)
        except ValueError:
            type_str = "hexadecimal" if base_to_use==16 else "binary" if base_to_use==2 else "decimal"
            raise AssemblerError(f"[{err_src_file} line {err_line_no}] Bad {type_str} value for {context_description}: '{value_str}'. Not a known symbol.")

    def _emit_address_directive_to_region(self, region: MemoryRegion, global_addr: int) -> None:
        # Your existing logic for this method is fine.
        relative_addr = global_addr - region.start_addr
        if not (0 <= relative_addr <= (region.end_addr - region.start_addr)):
             logger.warning(f"Internal: Emitting @ADDR for relative address 0x{relative_addr:X} (global 0x{global_addr:X}) "
                            f"which seems outside expected bounds for region '{region.name}' (size {region.end_addr - region.start_addr + 1}).")
        region.lines.append(f"@{relative_addr:04X}")
        region.next_expected_relative_addr = relative_addr 
        region.has_emitted_any_content = True


    def _emit_byte_to_region(self, region: MemoryRegion, byte_val: int, global_addr_of_byte: int, token_context: Token) -> None:
        # Your existing logic, but added token_context for better warnings if needed.
        relative_addr_of_byte = global_addr_of_byte - region.start_addr
        
        if not (region.start_addr <= global_addr_of_byte <= region.end_addr):
             # This warning is good, it means the byte is being emitted to a region it doesn't "own"
             # based on the simple loop in assemble(), but the calling logic should have picked the right region.
             # This indicates a mismatch or an ORG that jumped outside.
            logger.warning(f"[{os.path.basename(token_context.source_file)} line {token_context.line_no}] "
                           f"Byte 0x{byte_val:02X} for '{token_context.mnemonic}' at global address 0x{global_addr_of_byte:04X} "
                           f"is being considered for region '{region.name}' (0x{region.start_addr:04X}-0x{region.end_addr:04X}) "
                           f"but is outside its defined range. This emission will be skipped for this region.")
            return # Skip emitting to this region if global address is outside

        if not region.has_emitted_any_content or region.next_expected_relative_addr != relative_addr_of_byte:
            self._emit_address_directive_to_region(region, global_addr_of_byte)
        
        region.lines.append(f"{byte_val & 0xFF:02X}")
        region.next_expected_relative_addr = relative_addr_of_byte + 1 
        region.has_emitted_any_content = True

    def _encode_operand(self, operand_str: Optional[str], instr_info: InstrInfo, current_token: Token) -> List[int]:
        """Encodes operand string into list of bytes. Uses Token for error context."""
        err_src_file = os.path.basename(current_token.source_file)
        err_line_no = current_token.line_no
        mnemonic_for_error = current_token.mnemonic or "directive" # Should always have mnemonic here

        expected_operand_bytes = instr_info.size - (1 if instr_info.opcode is not None else 0)

        if not operand_str: # No operand string provided
            if expected_operand_bytes > 0:
                raise AssemblerError(f"[{err_src_file} line {err_line_no}] Mnemonic '{mnemonic_for_error}' expects an operand, but none given.")
            return []

        # Operand string is present, parse it
        # _parse_value_or_symbol will use the token for its own error context
        val = self._parse_value_or_symbol(operand_str, f"operand for '{mnemonic_for_error}'", current_token)
        
        if expected_operand_bytes == 0: # op_str was present but not expected
             logger.warning(f"[{err_src_file} line {err_line_no}] Operand '{operand_str}' provided for {mnemonic_for_error} which takes no operand. Operand ignored.")
             return []
        
        # Range checks
        if expected_operand_bytes == 1: 
            if not (0x00 <= val <= 0xFF): 
                raise AssemblerError(f"[{err_src_file} line {err_line_no}] Value 0x{val:X} ('{operand_str}') for {mnemonic_for_error} is out of 8-bit range (0x00-0xFF).")
            return [val & 0xFF]
        elif expected_operand_bytes == 2: 
            if not (0x0000 <= val <= 0xFFFF): 
                raise AssemblerError(f"[{err_src_file} line {err_line_no}] Value 0x{val:X} ('{operand_str}') for {mnemonic_for_error} is out of 16-bit range (0x0000-0xFFFF).")
            return [val & 0xFF, (val >> 8) & 0xFF] # Little-endian: LSB first
        else: # Should not happen based on INSTRUCTION_SET if sizes are 0, 1, or 2 for operands
            raise AssemblerError(f"[{err_src_file} line {err_line_no}] Internal error or unsupported operand size ({expected_operand_bytes} bytes) for {mnemonic_for_error}.")


    def assemble(self) -> None:
        """Main assembly process: parses files, then generates code."""
        logger.info(f"Starting assembly process for main file: {self.input_filepath}")
        
        # --- Pass 1 (Handled by Parser) ---
        try:
            parser_instance = Parser(self.input_filepath)
            self.symbols = parser_instance.symbol_table
            self.parsed_tokens = parser_instance.tokens # This is the flat list of all tokens
        except ParserError as e:
            # ParserError from parser.py should already be well-formatted
            logger.error(f"Parsing failed: {e}")
            raise AssemblerError(f"Parser error: {e}") # Optionally re-wrap or just re-raise
        except Exception as e_gen:
            logger.error(f"An unexpected error occurred during parsing: {e_gen}")
            raise AssemblerError(f"Unexpected parser error: {e_gen}")


        logger.info(f"Parsing phase complete. Symbols defined: {len(self.symbols)}, Tokens generated: {len(self.parsed_tokens)}")

        # --- Pass 2 (Code Generation) ---
        logger.info("Starting code generation (second pass)...")
        current_global_address = 0 # Default starting address, ORG will override

        for token in self.parsed_tokens: # Iterate over the flat list of tokens
            err_src_file = os.path.basename(token.source_file)
            err_line_no = token.line_no

            # Labels were processed by Parser for symbol table.
            # EQU directives were processed by Parser for symbol table.
            # We only care about mnemonics that generate code or ORG.
            if not token.mnemonic or token.mnemonic.upper() == 'EQU':
                continue

            if token.mnemonic.upper() == 'ORG':
                if not token.operand: # Parser should have caught this
                    raise AssemblerError(f"[{err_src_file} line {err_line_no}] ORG directive missing operand in assembler pass.")
                try:
                    # Re-resolve ORG operand using the final symbol table
                    # This handles cases where ORG might use a symbol defined later in an included file.
                    resolved_org_address = self._parse_value_or_symbol(token.operand, "ORG address", token)
                except AssemblerError as e_org: # Catch error from _parse_value_or_symbol
                    raise AssemblerError(f"[{err_src_file} line {err_line_no}] Could not resolve ORG operand '{token.operand}': {e_org}")

                current_global_address = resolved_org_address
                logger.debug(f"ORG encountered. Global address set to 0x{current_global_address:04X}", extra={'source_file': err_src_file, 'line_no': err_line_no})
                
                # When ORG is encountered, subsequent bytes might need new @ADDR directives.
                # Mark all regions as needing a potential new @ADDR.
                for region in self.regions:
                    region.next_expected_relative_addr = -1 # Force re-evaluation
                continue # ORG processed

            # Process instruction or data directive (DB, DW)
            instr_info = INSTRUCTION_SET.get(token.mnemonic.upper()) # Use .upper() for safety
            if instr_info is None: # Parser should have caught this
                raise AssemblerError(f"[{err_src_file} line {err_line_no}] Unknown mnemonic '{token.mnemonic}' in assembler pass.")

            # Emit opcode (if it's an instruction, not DB/DW where opcode is None)
            if instr_info.opcode is not None:
                # Determine which region this byte falls into
                target_region_for_opcode = None
                for r in self.regions:
                    if r.start_addr <= current_global_address <= r.end_addr:
                        target_region_for_opcode = r
                        break
                
                if target_region_for_opcode:
                    self._emit_byte_to_region(target_region_for_opcode, instr_info.opcode, current_global_address, token)
                elif self.regions: # Only warn if regions are explicitly defined
                    logger.warning(f"Opcode for '{token.mnemonic}' at global address 0x{current_global_address:04X} is outside all defined memory regions. Opcode not emitted.",
                                   extra={'source_file': err_src_file, 'line_no': err_line_no})
                current_global_address += 1

            # Emit operand bytes (for instructions) or data bytes (for DB/DW)
            operand_bytes = self._encode_operand(token.operand, instr_info, token)
            for byte_val in operand_bytes:
                target_region_for_byte = None
                for r in self.regions:
                    if r.start_addr <= current_global_address <= r.end_addr:
                        target_region_for_byte = r
                        break
                
                if target_region_for_byte:
                    self._emit_byte_to_region(target_region_for_byte, byte_val, current_global_address, token)
                elif self.regions:
                     logger.warning(f"Operand/data byte for '{token.mnemonic}' at global address 0x{current_global_address:04X} is outside all defined memory regions. Byte not emitted.",
                                    extra={'source_file': err_src_file, 'line_no': err_line_no})
                current_global_address += 1
        
        logger.info("Code generation (second pass) complete.")

    def write_output_files(self) -> None:
        # Your existing logic for this method is generally fine.
        # Ensure that the directory creation logic is robust.
        if not self.regions:
            logger.warning("No output regions defined. Nothing to write.")
            return

        for region in self.regions:
            if not region.has_emitted_any_content:
                logger.info(f"No data assembled for region '{region.name}'. Skipping file write for '{region.output_filename}'.")
                continue

            output_dir = os.path.dirname(region.output_filename)
            if output_dir: # If output_filename includes a directory path
                try:
                    os.makedirs(output_dir, exist_ok=True)
                    logger.debug(f"Ensured directory exists: {output_dir}")
                except OSError as e:
                    logger.error(f"Could not create directory {output_dir} for region '{region.name}': {e}")
                    # Decide if this is a fatal error for the assembler
                    raise AssemblerError(f"Failed to create output directory {output_dir}: {e}")

            try:
                with open(region.output_filename, "w") as f:
                    f.write("\n".join(region.lines))
                    # Ensure a final newline if content exists, Verilog $readmemh can be picky
                    if region.lines and not region.lines[-1].endswith("\n"):
                         f.write("\n") # Add trailing newline if missing
                logger.info(f"Wrote output for region '{region.name}' to '{region.output_filename}' ({len(region.lines)} lines).")
            except IOError as e:
                logger.error(f"Could not write to file '{region.output_filename}' for region '{region.name}': {e}")
                raise AssemblerError(f"IOError writing to {region.output_filename}: {e}")
                
                
                
def main(input_filepath: str, output_specifier: str, region_definitions: Optional[List[Tuple[str,str,str]]]) -> None: # Added types
    try:
        asm = Assembler(input_filepath, output_specifier, region_definitions)
        asm.assemble()
        asm.write_output_files() # Changed to new method name
    except (ParserError, AssemblerError, ValueError) as e: # Added ValueError for int conversion
        logger.error(f"Assembly failed: {e}")
        # exit(1) # Let the caller script handle exit if necessary or re-raise
        raise # Re-raise the exception to be caught by the __main__ block for exit(1)


if __name__ == "__main__":
    argp = argparse.ArgumentParser(description="Custom 8-bit CPU Assembler")
    argp.add_argument("input", nargs="?", default=f"{ASM_FILE_PATH}_prog.asm")
    argp.add_argument(
        "output_specifier",  # Renamed from "output" for clarity
        nargs="?",
        default=f"{OUTPUT_PATH}_prog.hex",
        help="Default output file if no --region is specified, OR the output directory if --region is used (e.g., 'build/')."
    )
    argp.add_argument(
        "--region",
        action="append",
        nargs=3,
        metavar=("NAME", "START_ADDR_HEX", "END_ADDR_HEX"), # Corrected metavar
        dest="regions_arg", # Store in args.regions_arg
        help="Define a memory region: NAME START_ADDR_HEX END_ADDR_HEX. Output file will be NAME.hex. Example: --region ROM F000 FFFF"
    )
    args = argp.parse_args()

    SCRIPT_DIR_ASM = os.path.dirname(os.path.abspath(__file__)) # Gets .../software/assembler/src
    ASSEMBLER_BASE_DIR = os.path.dirname(SCRIPT_DIR_ASM)      # Gets .../software/assembler
    LOG_FILE_PATH = os.path.join(ASSEMBLER_BASE_DIR, "assembler.log")

    logging.basicConfig(
        level=logging.DEBUG if DEBUG else logging.INFO,
        format="%(levelname)s: %(message)s",
        handlers=[logging.FileHandler(LOG_FILE_PATH, mode='w'), logging.StreamHandler()],
    )

    try:
        main(args.input, args.output_specifier, args.regions_arg)
    except Exception: # Catch re-raised exceptions from main()
        exit(1)