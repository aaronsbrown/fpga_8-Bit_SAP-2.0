# software/assembler/test/test_character_literals.py
import pytest
from src.assembler import Assembler, AssemblerError
from src.parser import Token
from src.constants import INSTRUCTION_SET


class TestCharacterLiterals:
    def setup_method(self):
        # Create a basic assembler instance for tests, no actual file IO
        self.assembler = Assembler.__new__(Assembler) 
        self.assembler.symbols = {}  # Initialize symbols
        # Mock a token for context
        self.mock_token = Token(line_no=1, source_file="test.asm", label=None, mnemonic="MOCK", operand=None)

    def test_resolve_expression_character_literals_basic(self):
        """Test basic character literal parsing with single quotes"""
        # ASCII printable characters
        assert self.assembler._resolve_expression_to_int("'A'", self.mock_token) == 65  # 0x41
        assert self.assembler._resolve_expression_to_int("'a'", self.mock_token) == 97  # 0x61
        assert self.assembler._resolve_expression_to_int("'0'", self.mock_token) == 48  # 0x30
        assert self.assembler._resolve_expression_to_int("'9'", self.mock_token) == 57  # 0x39
        assert self.assembler._resolve_expression_to_int("' '", self.mock_token) == 32  # 0x20 space
        assert self.assembler._resolve_expression_to_int("'!'", self.mock_token) == 33  # 0x21
        assert self.assembler._resolve_expression_to_int("'@'", self.mock_token) == 64  # 0x40
        assert self.assembler._resolve_expression_to_int("'#'", self.mock_token) == 35  # 0x23

    def test_resolve_expression_character_literals_escape_sequences(self):
        """Test character literals with escape sequences"""
        # Basic escape sequences
        assert self.assembler._resolve_expression_to_int("'\\n'", self.mock_token) == 10   # 0x0A newline
        assert self.assembler._resolve_expression_to_int("'\\r'", self.mock_token) == 13   # 0x0D carriage return  
        assert self.assembler._resolve_expression_to_int("'\\t'", self.mock_token) == 9    # 0x09 tab
        assert self.assembler._resolve_expression_to_int("'\\0'", self.mock_token) == 0    # 0x00 null
        assert self.assembler._resolve_expression_to_int("'\\\\'", self.mock_token) == 92  # 0x5C backslash
        assert self.assembler._resolve_expression_to_int("'\\''", self.mock_token) == 39  # 0x27 single quote

    def test_resolve_expression_character_literals_in_expressions(self):
        """Test character literals used in arithmetic expressions"""
        # Character literals in expressions
        assert self.assembler._resolve_expression_to_int("'A' + 1", self.mock_token) == 66      # 'A' + 1 = 66
        assert self.assembler._resolve_expression_to_int("'Z' - 'A'", self.mock_token) == 25    # 90 - 65 = 25
        assert self.assembler._resolve_expression_to_int("'0' + 5", self.mock_token) == 53      # 48 + 5 = 53

    def test_resolve_expression_character_literals_errors(self):
        """Test error cases for character literals"""
        # Empty character literal
        with pytest.raises(AssemblerError, match="Empty character literal"):
            self.assembler._resolve_expression_to_int("''", self.mock_token)
        
        # Multiple characters
        with pytest.raises(AssemblerError, match="Character literal must contain exactly one character"):
            self.assembler._resolve_expression_to_int("'AB'", self.mock_token)
        
        # Unclosed character literal
        with pytest.raises(AssemblerError, match="Unterminated character literal"):
            self.assembler._resolve_expression_to_int("'A", self.mock_token)
        
        # Invalid escape sequence
        with pytest.raises(AssemblerError, match="Unknown escape sequence"):
            self.assembler._resolve_expression_to_int("'\\x'", self.mock_token)

    @pytest.mark.parametrize("mnemonic, operand_str, expected_bytes", [
        # LDI instructions with character literals
        ("LDI_A", "#'A'", [0x41]),
        ("LDI_B", "#'Z'", [0x5A]),
        ("LDI_C", "#'0'", [0x30]),
        ("LDI_A", "#'\\n'", [0x0A]),
        ("LDI_B", "#'\\t'", [0x09]),
        ("LDI_C", "#'\\''", [0x27]),
        
        # Immediate logical instructions with character literals
        ("ANI", "#'\\0'", [0x00]),
        ("ORI", "#'A'", [0x41]),
        ("XRI", "#'0'", [0x30]),
        
        # Character literals in expressions
        ("LDI_A", "#'A' + 1", [0x42]),  # 'A' + 1 = 66
        ("LDI_B", "#'Z' - 'A'", [0x19]),  # 'Z' - 'A' = 25
    ])
    def test_encode_operand_character_literals_valid(self, mnemonic, operand_str, expected_bytes):
        """Test encoding operands with character literals for applicable instructions"""
        instr_info = INSTRUCTION_SET[mnemonic.upper()]
        token = Token(1, "test.asm", None, mnemonic, operand_str)
        
        encoded = self.assembler._encode_operand(operand_str, instr_info, token)
        assert encoded == expected_bytes

    @pytest.mark.parametrize("mnemonic, operand_str, error_msg_part", [
        # Invalid character literals
        ("LDI_A", "#''", "Empty character literal"),
        ("LDI_B", "#'AB'", "Character literal must contain exactly one character"),
        ("LDI_C", "#'A", "Unterminated character literal"),
        ("ANI", "#'\\x'", "Unknown escape sequence"),
        
        # Character values out of range for 8-bit (this shouldn't happen with standard ASCII, but testing bounds)
        # These would need special high-value characters or expressions that result in > 255
        ("LDI_A", "#'A' + 200", "out of 8-bit range"),  # 65 + 200 = 265 > 255
    ])
    def test_encode_operand_character_literals_errors(self, mnemonic, operand_str, error_msg_part):
        """Test error cases when encoding operands with character literals"""
        instr_info = INSTRUCTION_SET[mnemonic.upper()]
        token = Token(1, "test.asm", None, mnemonic, operand_str)
        
        with pytest.raises(AssemblerError) as excinfo:
            self.assembler._encode_operand(operand_str, instr_info, token)
        assert error_msg_part.lower() in str(excinfo.value).lower()

    def test_character_literals_with_db_directive(self):
        """Test character literals work with DB directive"""
        instr_info_db = INSTRUCTION_SET["DB"]
        
        # Single character literal
        operand_str = "'A'"
        token = Token(1, "test.asm", None, "DB", operand_str)
        expected_bytes = [0x41]
        encoded = self.assembler._encode_operand(operand_str, instr_info_db, token)
        assert encoded == expected_bytes
        
        # Mixed character literals and numeric values
        operand_str = "'H', 'e', 'l', 'l', 'o', 0"
        token = Token(1, "test.asm", None, "DB", operand_str)
        expected_bytes = [0x48, 0x65, 0x6C, 0x6C, 0x6F, 0x00]  # "Hello" + null terminator
        encoded = self.assembler._encode_operand(operand_str, instr_info_db, token)
        assert encoded == expected_bytes
        
        # Character literals with escape sequences
        operand_str = "'\\n', '\\t', '\\r', '\\0'"
        token = Token(1, "test.asm", None, "DB", operand_str)
        expected_bytes = [0x0A, 0x09, 0x0D, 0x00]
        encoded = self.assembler._encode_operand(operand_str, instr_info_db, token)
        assert encoded == expected_bytes

    def test_character_literals_not_confused_with_string_literals(self):
        """Test that character literals are distinct from string literals"""
        # Character literal 'A' should give single byte value 65
        assert self.assembler._resolve_expression_to_int("'A'", self.mock_token) == 65
        
        # This would be a string literal (handled differently in DB directive)
        # but should fail as expression for immediate operand since it's not implemented
        # for single character resolution in expressions
        
    @pytest.mark.parametrize("instruction", [
        "LDI_A", "LDI_B", "LDI_C",  # Load immediate instructions
        "ANI", "ORI", "XRI",        # Immediate logical instructions
    ])
    def test_all_applicable_instructions_with_character_literals(self, instruction):
        """Test that character literals work with all applicable instructions"""
        instr_info = INSTRUCTION_SET[instruction]
        operand_str = "#'A'"
        token = Token(1, "test.asm", None, instruction, operand_str)
        
        encoded = self.assembler._encode_operand(operand_str, instr_info, token)
        assert encoded == [0x41]  # ASCII 'A'
        
        # Test with escape sequence
        operand_str = "#'\\n'"
        token = Token(1, "test.asm", None, instruction, operand_str)
        
        encoded = self.assembler._encode_operand(operand_str, instr_info, token)
        assert encoded == [0x0A]  # newline