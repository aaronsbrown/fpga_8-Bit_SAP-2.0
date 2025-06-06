# software/assembler/tests/test_assembler_core.py
import pytest
from src.assembler import Assembler, AssemblerError
from src.parser import Token # For creating mock tokens
from src.constants import INSTRUCTION_SET, InstrInfo

class TestAssemblerCore:
    def setup_method(self):
        # Create a basic assembler instance for tests, no actual file IO
        self.assembler = Assembler.__new__(Assembler) 
        self.assembler.symbols = {} # Initialize symbols
        # Mock a token for context
        self.mock_token = Token(line_no=1, source_file="test.asm", label=None, mnemonic="MOCK", operand=None)

    def test_resolve_expression_to_int_literals(self):
        assert self.assembler._resolve_expression_to_int("123", self.mock_token) == 123
        assert self.assembler._resolve_expression_to_int("$FF", self.mock_token) == 255
        assert self.assembler._resolve_expression_to_int("%101", self.mock_token) == 5

    def test_resolve_expression_to_int_symbols(self):
        self.assembler.symbols = {"MY_SYM": 100, "ADDR": 0xF000}
        assert self.assembler._resolve_expression_to_int("MY_SYM", self.mock_token) == 100
        assert self.assembler._resolve_expression_to_int("ADDR", self.mock_token) == 0xF000

    def test_resolve_expression_to_int_low_high_byte(self):
        self.assembler.symbols = {"SIXTEEN_BIT": 0xABCD}
        assert self.assembler._resolve_expression_to_int("LOW_BYTE(SIXTEEN_BIT)", self.mock_token) == 0xCD
        assert self.assembler._resolve_expression_to_int("HIGH_BYTE(SIXTEEN_BIT)", self.mock_token) == 0xAB
        assert self.assembler._resolve_expression_to_int("LOW_BYTE($1234)", self.mock_token) == 0x34
        assert self.assembler._resolve_expression_to_int("HIGH_BYTE($1234)", self.mock_token) == 0x12
        
        with pytest.raises(AssemblerError, match="out of 16-bit range"):
            self.assembler._resolve_expression_to_int("LOW_BYTE($12345)", self.mock_token)
        with pytest.raises(AssemblerError, match="out of 16-bit range"):
            self.assembler._resolve_expression_to_int("HIGH_BYTE(-1)", self.mock_token)


    def test_resolve_expression_to_int_arithmetic(self):
        self.assembler.symbols = {"BASE": 0x100, "OFFSET": 10, "VAL": 0xFF00}
        assert self.assembler._resolve_expression_to_int("BASE + 5", self.mock_token) == 0x105
        assert self.assembler._resolve_expression_to_int("BASE - 5", self.mock_token) == 0x0FB
        assert self.assembler._resolve_expression_to_int("BASE + OFFSET", self.mock_token) == 0x10A
        assert self.assembler._resolve_expression_to_int("VAL - OFFSET + 1", self.mock_token) == (0xFF00 - 10 + 1)
        assert self.assembler._resolve_expression_to_int("100 - 20 + 5", self.mock_token) == 85


    def test_resolve_expression_to_int_nested_and_complex(self):
        self.assembler.symbols = {"ADDR1": 0x1234, "ADDR2": 0x50, "OFFSET": 5}
        expr = "LOW_BYTE(ADDR1 + OFFSET)" # LOW_BYTE(0x1234 + 5) = LOW_BYTE(0x1239) = 0x39
        assert self.assembler._resolve_expression_to_int(expr, self.mock_token) == 0x39
        expr2 = "HIGH_BYTE(ADDR1 - ADDR2) + 1" # HIGH_BYTE(0x1234 - 0x50) = HIGH_BYTE(0x11E4) = 0x11. Result = 0x11 + 1 = 0x12
        assert self.assembler._resolve_expression_to_int(expr2, self.mock_token) == 0x12

    def test_resolve_expression_to_int_errors(self):
        with pytest.raises(AssemblerError, match="Not a known symbol"):
            self.assembler._resolve_expression_to_int("UNDEFINED_SYM", self.mock_token)
        with pytest.raises(AssemblerError, match="Bad decimal value"):
            self.assembler._resolve_expression_to_int("10 + BAD", self.mock_token) # BAD is not numeric here
        with pytest.raises(AssemblerError, match="Malformed arithmetic expression"):
            self.assembler._resolve_expression_to_int("SYM + ", self.mock_token)


    @pytest.mark.parametrize("mnemonic, operand_str, symbol_val, expected_bytes, is_16bit_val_not_used_now", [
        # Zero operand
        ("NOP", None, None, [], False),
        # One byte operand (immediate)
        ("LDI_A", "#$AB", None, [0xAB], False),
        ("LDI_B", "#MY_BYTE_CONST", 0xCD, [0xCD], False), # Needs MY_BYTE_CONST
        ("ANI", "#$F0", None, [0xF0], False),
        # One byte operand (from expression)
        ("LDI_C", "#LOW_BYTE(ADDR_VAL)", 0x1234, [0x34], True), # Needs ADDR_VAL
        # Two byte operand (address)
        ("JMP", "TARGET_ADDR", 0xABCD, [0xCD, 0xAB], True), # Needs TARGET_ADDR
        ("LDA", "MEM_LOC", 0x1234, [0x34, 0x12], True),     # Needs MEM_LOC
        ("STA", "MEM_LOC + 2", 0x1000, [0x02, 0x10], True), # Needs MEM_LOC (symbol_val is base for MEM_LOC)
        # DW directive
        ("DW", "$FEDC", None, [0xDC, 0xFE], False),
        ("DW", "SIXTEEN_BIT_CONST", 0xBEEF, [0xEF, 0xBE], True), # Needs SIXTEEN_BIT_CONST
    ])
    def test_encode_operand_valid(self, mnemonic, operand_str, symbol_val, expected_bytes, is_16bit_val_not_used_now): # Renamed last param
        instr_info = INSTRUCTION_SET[mnemonic.upper()]
        token = Token(1, "test.asm", None, mnemonic, operand_str)
        
        self.assembler.symbols = {} # Reset for each case
        if symbol_val is not None:
            # Explicitly set up symbols based on the test case's needs
            if mnemonic == "LDI_B" and operand_str == "#MY_BYTE_CONST":
                self.assembler.symbols["MY_BYTE_CONST"] = symbol_val
            elif mnemonic == "LDI_C" and operand_str == "#LOW_BYTE(ADDR_VAL)":
                self.assembler.symbols["ADDR_VAL"] = symbol_val
            elif mnemonic == "JMP" and operand_str == "TARGET_ADDR":
                self.assembler.symbols["TARGET_ADDR"] = symbol_val
            elif mnemonic == "LDA" and operand_str == "MEM_LOC":
                self.assembler.symbols["MEM_LOC"] = symbol_val
            elif mnemonic == "STA" and operand_str == "MEM_LOC + 2":
                # Here, symbol_val (0x1000) is the value for MEM_LOC itself
                self.assembler.symbols["MEM_LOC"] = symbol_val 
            elif mnemonic == "DW" and operand_str == "SIXTEEN_BIT_CONST":
                self.assembler.symbols["SIXTEEN_BIT_CONST"] = symbol_val
            # Add more specific setups if other parameterized tests require different symbols from operand_str

        encoded = self.assembler._encode_operand(operand_str, instr_info, token)
        assert encoded == expected_bytes

    def test_encode_operand_db_directive(self):
        self.assembler.symbols = {"COUNT": 5, "CHAR_A": 0x41}
        # DB $01, "HI", COUNT, CHAR_A + 1
        #    01,  48, 49, 05,   42
        instr_info_db = INSTRUCTION_SET["DB"]
        operand_str = "$01, \"HI\", COUNT, CHAR_A + 1"
        token = Token(1, "test.asm", None, "DB", operand_str)
        expected_bytes = [0x01, ord('H'), ord('I'), 5, 0x41 + 1]
        encoded = self.assembler._encode_operand(operand_str, instr_info_db, token)
        assert encoded == expected_bytes

        # Empty string
        encoded_empty = self.assembler._encode_operand("\"\"", instr_info_db, token)
        assert encoded_empty == []
        
        # Just a string
        encoded_str_only = self.assembler._encode_operand("\"Test\"", instr_info_db, token)
        assert encoded_str_only == [ord('T'), ord('e'), ord('s'), ord('t')]

    @pytest.mark.parametrize("mnemonic, operand_str, symbol_val, error_msg_part, is_16bit_val", [
        ("LDI_A", "#$100", None, "out of 8-bit range", False),       # Value too large for 8-bit
        ("LDI_A", "#NO_SUCH_SYM", None, "Not a known symbol", False),# Undefined symbol for immediate
        ("JMP", "$10000", None, "out of 16-bit range", False),      # Address too large
        ("LDA", "NO_ADDR_SYM", None, "Not a known symbol", False),   # Undefined symbol for address
        ("NOP", "$10", None, "takes no operand", False),            # Operand for NOP
        ("LDI_A", None, None, "expects an operand", False),         # Missing operand for LDI_A
        ("DB", "$FF, $100", None, "out of 8-bit range", False),     # DB item too large
        ("DB", "NO_SYM", None, "Not a known symbol", False),        # DB undefined symbol
    ])
    def test_encode_operand_errors(self, mnemonic, operand_str, symbol_val, error_msg_part, is_16bit_val):
        instr_info = INSTRUCTION_SET[mnemonic.upper()]
        token = Token(1, "test.asm", None, mnemonic, operand_str)
        self.assembler.symbols = {} # Reset symbols
        if symbol_val is not None: # For tests that might need a symbol defined
             self.assembler.symbols["SOME_SYM_FOR_ERROR_TEST"] = symbol_val


        with pytest.raises(AssemblerError) as excinfo:
            self.assembler._encode_operand(operand_str, instr_info, token)
        assert error_msg_part.lower() in str(excinfo.value).lower()