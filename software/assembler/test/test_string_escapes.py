# software/assembler/test/test_string_escapes.py
import pytest
import tempfile
import os
from src.assembler import Assembler, AssemblerError
from src.parser import Parser, ParserError, Token
from src.constants import InstrInfo

class TestStringEscapeSequences:
    """Test cases for enhanced string literal support with escape sequences"""

    def setup_method(self):
        """Setup test assembler instance"""
        self.assembler = Assembler.__new__(Assembler)
        self.assembler.symbols = {}
        # Mock token for testing
        self.mock_token = Token(line_no=1, source_file="test.asm", label=None, mnemonic="DB", operand=None)
        # Mock instruction info for DB directive
        self.db_instr = InstrInfo(opcode=None, size=1)

    def test_basic_strings_still_work(self):
        """Ensure existing string functionality remains unchanged"""        
        result = self.assembler._encode_operand('"Hello World"', self.db_instr, self.mock_token)
        expected = [ord(c) for c in "Hello World"]
        assert result == expected

    def test_newline_escape_sequence(self):
        """Test \\n escape sequence converts to ASCII 10"""
        result = self.assembler._encode_operand('"Line1\\nLine2"', self.db_instr, self.mock_token)
        expected = [ord('L'), ord('i'), ord('n'), ord('e'), ord('1'), 10, 
                   ord('L'), ord('i'), ord('n'), ord('e'), ord('2')]
        assert result == expected

    def test_tab_escape_sequence(self):
        """Test \\t escape sequence converts to ASCII 9"""
        result = self.assembler._encode_operand('"Col1\\tCol2"', self.db_instr, self.mock_token)
        expected = [ord('C'), ord('o'), ord('l'), ord('1'), 9,
                   ord('C'), ord('o'), ord('l'), ord('2')]
        assert result == expected

    def test_carriage_return_escape_sequence(self):
        """Test \\r escape sequence converts to ASCII 13"""
        result = self.assembler._encode_operand('"Line1\\rLine2"', self.db_instr, self.mock_token)
        expected = [ord('L'), ord('i'), ord('n'), ord('e'), ord('1'), 13,
                   ord('L'), ord('i'), ord('n'), ord('e'), ord('2')]
        assert result == expected

    def test_null_terminator_escape_sequence(self):
        """Test \\0 escape sequence converts to ASCII 0"""
        result = self.assembler._encode_operand('"Hello\\0World"', self.db_instr, self.mock_token)
        expected = [ord('H'), ord('e'), ord('l'), ord('l'), ord('o'), 0,
                   ord('W'), ord('o'), ord('r'), ord('l'), ord('d')]
        assert result == expected

    def test_backslash_escape_sequence(self):
        """Test \\\\ escape sequence converts to single backslash (ASCII 92)"""
        result = self.assembler._encode_operand('"Path\\\\File"', self.db_instr, self.mock_token)
        expected = [ord('P'), ord('a'), ord('t'), ord('h'), 92,
                   ord('F'), ord('i'), ord('l'), ord('e')]
        assert result == expected

    def test_quote_escape_sequence(self):
        """Test \\" escape sequence converts to double quote (ASCII 34)"""
        result = self.assembler._encode_operand('"Say \\"Hello\\""', self.db_instr, self.mock_token)
        expected = [ord('S'), ord('a'), ord('y'), ord(' '), 34,
                   ord('H'), ord('e'), ord('l'), ord('l'), ord('o'), 34]
        assert result == expected

    def test_hex_escape_sequences(self):
        """Test \\xHH hex escape sequences"""
        result = self.assembler._encode_operand('"Bell: \\x07"', self.db_instr, self.mock_token)
        expected = [ord('B'), ord('e'), ord('l'), ord('l'), ord(':'), ord(' '), 7]
        assert result == expected

    def test_multiple_hex_escapes(self):
        """Test multiple hex escape sequences in one string"""
        result = self.assembler._encode_operand('"\\x41\\x42\\x43"', self.db_instr, self.mock_token)
        expected = [0x41, 0x42, 0x43]  # A, B, C
        assert result == expected

    def test_mixed_escape_sequences(self):
        """Test mixing different escape sequences in one string"""
        result = self.assembler._encode_operand('"Line1\\nTab\\tQuote\\"End\\x00"', self.db_instr, self.mock_token)
        expected = [ord('L'), ord('i'), ord('n'), ord('e'), ord('1'), 10,  # Line1\n
                   ord('T'), ord('a'), ord('b'), 9,                        # Tab\t  
                   ord('Q'), ord('u'), ord('o'), ord('t'), ord('e'), 34,   # Quote\"
                   ord('E'), ord('n'), ord('d'), 0]                        # End\x00
        assert result == expected

    def test_invalid_hex_escape_too_short(self):
        """Test error handling for incomplete hex escape sequences"""
        with pytest.raises(AssemblerError, match="[Ii]ncomplete hex escape"):
            self.assembler._encode_operand('"Bad \\x4"', self.db_instr, self.mock_token)

    def test_invalid_hex_escape_bad_digits(self):
        """Test error handling for invalid hex digits in escape sequences"""
        with pytest.raises(AssemblerError, match="[Ii]nvalid hex escape"):
            self.assembler._encode_operand('"Bad \\xGH"', self.db_instr, self.mock_token)

    def test_unknown_escape_sequence(self):
        """Test error handling for unknown escape sequences"""
        with pytest.raises(AssemblerError, match="[Uu]nknown escape sequence"):
            self.assembler._encode_operand('"Bad \\z sequence"', self.db_instr, self.mock_token)

    def test_escape_sequences_in_parser_size_calculation(self):
        """Test that parser correctly calculates string sizes with escape sequences"""
        asm_content = '''
        ORG $0000
        start:
        MSG: DB "A\\nB\\tC\\x41"  ; Should be 6 bytes: A, newline, B, tab, C, 0x41
        next: DB 42
        '''
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.asm', delete=False) as f:
            f.write(asm_content)
            f.flush()
            
            try:
                parser = Parser(f.name)
                # The symbol table should show correct address advancement
                assert parser.symbol_table['start'] == 0x0000
                assert parser.symbol_table['next'] == 0x0006  # 6 bytes for the string
            finally:
                os.unlink(f.name)

    def test_empty_string_with_escapes(self):
        """Test handling of empty strings and strings with only escapes"""
        # Empty string should produce no bytes
        result_empty = self.assembler._encode_operand('""', self.db_instr, self.mock_token)
        assert result_empty == []
        
        # String with just null should produce one zero byte
        result_null = self.assembler._encode_operand('"\\x00"', self.db_instr, self.mock_token)
        assert result_null == [0]

    def test_complex_real_world_string(self):
        """Test a realistic string with multiple escape types"""
        result = self.assembler._encode_operand('"CPU Boot v1.0\\nPress \\"ENTER\\" to continue...\\x0D\\x0A\\x00"', self.db_instr, self.mock_token)
        
        # Verify key parts of the string
        assert result[0:13] == [ord(c) for c in "CPU Boot v1.0"]  # Start of string
        assert result[13] == 10  # \n
        assert result[20] == 34  # " (quote)
        assert result[26] == 34  # " (quote) 
        assert result[-3] == 13  # \x0D (CR)
        assert result[-2] == 10  # \x0A (LF)  
        assert result[-1] == 0   # \x00 (null terminator)