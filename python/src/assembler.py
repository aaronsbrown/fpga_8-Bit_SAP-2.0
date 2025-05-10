# assembler.py

import argparse
import logging
import os
from typing import List, Dict, Optional, Tuple # Added Tuple, Optional
from dataclasses import dataclass # Added dataclass

from parser import Parser, Token, ParserError # Assuming Token is still relevant for type hints
from constants import INSTRUCTION_SET, ASM_FILE_PATH, OUTPUT_PATH, DEBUG, InstrInfo

logger = logging.getLogger(__name__)

class AssemblerError(Exception):
    # ... (no change)
    def __init__(self, message: str) -> None:
        super().__init__(message)
        self.message = message

    def __str__(self) -> str:
        return f"AssemblerError: {self.message}"

# Define MemoryRegion dataclass
@dataclass
class MemoryRegion:
    name: str
    start_addr: int         # Global start address (inclusive)
    end_addr: int           # Global end address (inclusive)
    output_filename: str
    lines: List[str]
    # Tracks the next expected relative address for data in this region's file
    # to decide if a new @directive is needed.
    next_expected_relative_addr: int 
    # To ensure an @ directive is emitted at least once if data exists for the region
    has_emitted_any_content: bool 


class Assembler:
    def __init__(self, input_file: str, output_specifier: str, region_configs: Optional[List[Tuple[str, str, str]]]) -> None:
        self.input_file = input_file
        self.regions: List[MemoryRegion] = []
        self.symbols: Dict[str, int] = {} # Will be populated by Parser

        output_base_dir = "." # Default to current directory

        if region_configs: # If --region flags were used
            # output_specifier is treated as the base directory for region files
            output_base_dir = output_specifier
            # Ensure base directory exists
            if output_base_dir and not os.path.exists(output_base_dir) and not os.path.splitext(output_base_dir)[1]: # if it's a dir path
                os.makedirs(output_base_dir, exist_ok=True)
            elif os.path.splitext(output_base_dir)[1]: # if it looks like a file path, use its dir
                 output_base_dir = os.path.dirname(output_base_dir) if os.path.dirname(output_base_dir) else "."


            for name, start_hex, end_hex in region_configs:
                try:
                    start_addr = int(start_hex, 16)
                    end_addr = int(end_hex, 16)
                except ValueError:
                    raise AssemblerError(f"Invalid hex address in region '{name}': start='{start_hex}', end='{end_hex}'")

                if not (0x0000 <= start_addr <= 0xFFFF and 0x0000 <= end_addr <= 0xFFFF):
                    raise AssemblerError(f"Address for region '{name}' (start=0x{start_addr:X}, end=0x{end_addr:X}) out of 16-bit range.")
                if start_addr > end_addr:
                    raise AssemblerError(f"Region '{name}': start address 0x{start_addr:X} cannot be greater than end address 0x{end_addr:X}")
                
                self.regions.append(
                    MemoryRegion(
                        name=name,
                        start_addr=start_addr,
                        end_addr=end_addr,
                        output_filename=os.path.join(output_base_dir, f"{name}.hex"),
                        lines=[],
                        next_expected_relative_addr=0, # Initial state
                        has_emitted_any_content=False
                    )
                )
        else: # No --region flags, use single output mode
            # output_specifier is the direct output file path
            single_output_file_dir = os.path.dirname(output_specifier)
            if single_output_file_dir: # Ensure directory exists if specified in path
                os.makedirs(single_output_file_dir, exist_ok=True)
            
            self.regions.append(
                MemoryRegion(
                    name="DEFAULT_OUTPUT",
                    start_addr=0x0000,
                    end_addr=0xFFFF, # Covers entire 16-bit space
                    output_filename=output_specifier,
                    lines=[],
                    next_expected_relative_addr=0, # Initial state
                    has_emitted_any_content=False
                )
            )
        
        if not self.regions:
             raise AssemblerError("Internal error: No output regions were configured.")


    def _parse_value_or_symbol(self, s_val: Optional[str], context_msg: str = "value") -> int:
        # ... (no change from your working version with '#' stripping and $/%/decimal parsing)
        if not s_val:
            raise AssemblerError(f"Missing {context_msg}")

        name_to_check = s_val.lstrip('#').strip() 

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
                return int(name_to_check, 10) 
            except ValueError:
                raise AssemblerError(
                    f"Invalid {context_msg} '{s_val!r}'. "
                    f"Not a known symbol and not a valid number (decimal, $hex, or %binary)."
                )

    def _emit_address_directive_to_region(self, region: MemoryRegion, global_addr: int) -> None:
        """Emits an @ADDR directive to the specified region's file, using relative addressing."""
        relative_addr = global_addr - region.start_addr
        if not (0 <= relative_addr <= (region.end_addr - region.start_addr +1)): # Check relative addr validity too
             logger.warning(f"Internal: Relative address 0x{relative_addr:X} for global 0x{global_addr:X} in region {region.name} seems problematic.")
        
        region.lines.append(f"@{relative_addr:04X}")
        region.next_expected_relative_addr = relative_addr # Next byte should follow this @
        region.has_emitted_any_content = True


    def _emit_byte_to_region(self, region: MemoryRegion, byte_val: int, global_addr_of_byte: int) -> None:
        """Emits a byte to the specified region's file, managing @ADDR directives."""
        relative_addr_of_byte = global_addr_of_byte - region.start_addr

        # If this is the first content for this region, OR if the current byte's location
        # is not where we expected it (i.e., not contiguous), emit an @ADDR directive.
        if not region.has_emitted_any_content or region.next_expected_relative_addr != relative_addr_of_byte:
            self._emit_address_directive_to_region(region, global_addr_of_byte)
            # _emit_address_directive_to_region updates next_expected_relative_addr to relative_addr_of_byte
        
        region.lines.append(f"{byte_val & 0xFF:02X}")
        region.next_expected_relative_addr = relative_addr_of_byte + 1 # Expect next byte here
        region.has_emitted_any_content = True


    def _encode_operand( self, op_str: Optional[str], info: InstrInfo, mnemonic_for_error: str) -> List[int]:
        # ... (no change from your working version with range checks)
        # Ensure mnemonic_for_error is used in error messages from range checks.
        # Example:
        # raise AssemblerError(
        #     f"Value 0x{val:X} ('{op_str}') for {mnemonic_for_error} is out of 8-bit range (0x00-0xFF)."
        # )
        if not op_str:
            return []

        val = self._parse_value_or_symbol(op_str, f"operand for '{mnemonic_for_error}'")

        operand_byte_count = info.size - 1 if info.opcode is not None else info.size

        if operand_byte_count < 0: 
            raise AssemblerError(f"Internal error: Negative operand byte count for {mnemonic_for_error}")
        if operand_byte_count == 0:
            if op_str: # Log warning if operand provided for no-operand instruction
                 logger.warning(f"Operand '{op_str}' provided for {mnemonic_for_error} which takes no operand. Operand ignored.")
            return []

        if operand_byte_count == 1: 
            if not (0x00 <= val <= 0xFF):
                raise AssemblerError(f"Value 0x{val:X} ('{op_str}') for {mnemonic_for_error} is out of 8-bit range (0x00-0xFF).")
            val = val & 0xFF 
        elif operand_byte_count == 2: 
            if not (0x0000 <= val <= 0xFFFF):
                raise AssemblerError(f"Value 0x{val:X} ('{op_str}') for {mnemonic_for_error} is out of 16-bit range (0x0000-0xFFFF).")
            val = val & 0xFFFF
        elif operand_byte_count > 2:
            raise AssemblerError(f"Unsupported operand size ({operand_byte_count} bytes) for {mnemonic_for_error}.")
        
        return [(val >> (8 * i)) & 0xFF for i in range(operand_byte_count)]


    def assemble(self) -> None:
        logger.info(f"Assembling {self.input_file}...") # Output files listed at the end
        parser = Parser(self.input_file)
        self.symbols = parser.symbol_table
        tokens = parser.tokens

        current_global_address = 0  # Tracks the global address of the NEXT byte to be placed/emitted

        # Initial @0000 for default region if it starts at 0 and no ORG comes first
        # Or handle this within _emit_byte_to_region's "first content" logic.

        for tok in tokens:
            if tok.mnemonic is None: # Skip pure labels
                continue
            if tok.mnemonic == 'EQU': # EQU is for symbol table only
                continue

            if tok.mnemonic == 'ORG':
                resolved_address = self._parse_value_or_symbol(tok.operand, "ORG address value")
                if not (0x0000 <= resolved_address <= 0xFFFF):
                    raise AssemblerError(
                        f"[line {tok.line_no}] ORG address 0x{resolved_address:X} ('{tok.operand}') is out of 16-bit range."
                    )
                current_global_address = resolved_address
                
                # When ORG is encountered, the next byte is at this new address.
                # Reset next_expected_relative_addr for all regions so the next _emit_byte forces an @ directive.
                # A specific @ directive for the target region of this ORG will be handled by the first
                # _emit_byte call that falls into a region at this current_global_address.
                # Or, we can explicitly emit an @ directive to the target region of the ORG now.
                found_region_for_org = False
                for region in self.regions:
                    region.next_expected_relative_addr = -1 # Force next _emit_byte to re-evaluate @
                    if region.start_addr <= current_global_address <= region.end_addr:
                        self._emit_address_directive_to_region(region, current_global_address)
                        found_region_for_org = True
                        # No break here, reset all regions' expectations
                if not found_region_for_org:
                     logger.warning(f"[line {tok.line_no}] ORG to 0x{current_global_address:04X} is outside all defined memory regions.")
                continue

            info = INSTRUCTION_SET.get(tok.mnemonic)
            if info is None: # Should have been caught by Parser
                raise AssemblerError(f"[line {tok.line_no}] Unknown mnemonic {tok.mnemonic!r} (missed by parser?)")

            # Emit opcode byte
            if info.opcode is not None:
                target_region_opcode = None
                for r in self.regions:
                    if r.start_addr <= current_global_address <= r.end_addr:
                        target_region_opcode = r
                        break
                if target_region_opcode:
                    self._emit_byte_to_region(target_region_opcode, info.opcode, current_global_address)
                # else: byte falls outside any region, effectively ignored or warning in _emit_byte
                current_global_address += 1

            # Emit operand bytes
            operand_bytes = self._encode_operand(tok.operand, info, tok.mnemonic)
            for byte_val in operand_bytes:
                target_region_operand = None
                for r in self.regions:
                    if r.start_addr <= current_global_address <= r.end_addr:
                        target_region_operand = r
                        break
                if target_region_operand:
                    self._emit_byte_to_region(target_region_operand, byte_val, current_global_address)
                # else: byte falls outside any region
                current_global_address += 1
        
        logger.info("Assembly processing complete.")


    def write_output_files(self) -> None:
        for region in self.regions:
            if not region.has_emitted_any_content: # Check if any content was actually generated
                logger.info(f"No data assembled for region '{region.name}'. Skipping file write for {region.output_filename}.")
                continue

            # Ensure the output directory for this specific file exists
            dirpath = os.path.dirname(region.output_filename)
            if dirpath: # If dirname is not empty (i.e. not current dir)
                os.makedirs(dirpath, exist_ok=True)
            
            try:
                with open(region.output_filename, "w") as f:
                    f.write("\n".join(region.lines))
                    if region.lines and not region.lines[-1].endswith("\n"): # Ensure trailing newline
                        f.write("\n")
                logger.info(f"Wrote output for region '{region.name}' to {region.output_filename}")
            except IOError as e:
                logger.error(f"Could not write to file {region.output_filename}: {e}")
                # Potentially raise an AssemblerError here too
                
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

    logging.basicConfig(
        level=logging.DEBUG if DEBUG else logging.INFO,
        format="%(levelname)s: %(message)s",
        handlers=[logging.FileHandler("assembler.log", mode='w'), logging.StreamHandler()], # mode='w' to overwrite log
    )

    try:
        main(args.input, args.output_specifier, args.regions_arg)
    except Exception: # Catch re-raised exceptions from main()
        exit(1)