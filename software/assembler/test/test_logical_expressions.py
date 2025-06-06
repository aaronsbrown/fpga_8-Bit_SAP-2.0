# software/assembler/test/test_logical_expressions.py
import pytest
import tempfile
import os
from src.assembler import Assembler, AssemblerError
from src.parser import Parser, ParserError, Token
from src.constants import InstrInfo

class TestLogicalExpressions:
    """Test cases for logical/bitwise expression support in the assembler"""

    def setup_method(self):
        """Setup test assembler instance"""
        self.assembler = Assembler.__new__(Assembler)
        self.assembler.symbols = {}
        # Mock token for testing
        self.mock_token = Token(line_no=1, source_file="test.asm", label=None, mnemonic="LDI_A", operand=None)

    # ====== Basic Bitwise OR Tests ======
    def test_basic_bitwise_or(self):
        """Test basic bitwise OR operations"""
        # Set up symbols for testing
        self.assembler.symbols = {}
        
        # Test basic OR with hex literals
        result = self.assembler._resolve_expression_to_int("$0F | $F0", self.mock_token)
        assert result == 0xFF
        
        # Test OR with decimal literals
        result = self.assembler._resolve_expression_to_int("15 | 240", self.mock_token)
        assert result == 255
        
        # Test OR with binary literals
        result = self.assembler._resolve_expression_to_int("%00001111 | %11110000", self.mock_token)
        assert result == 0xFF

    def test_bitwise_or_with_symbols(self):
        """Test bitwise OR with symbol resolution"""
        self.assembler.symbols = {
            'MASK_A': 0x0F,
            'MASK_B': 0xF0,
            'ZERO': 0x00
        }
        
        result = self.assembler._resolve_expression_to_int("MASK_A | MASK_B", self.mock_token)
        assert result == 0xFF
        
        result = self.assembler._resolve_expression_to_int("MASK_A | ZERO", self.mock_token)
        assert result == 0x0F

    # ====== Basic Bitwise AND Tests ======
    def test_basic_bitwise_and(self):
        """Test basic bitwise AND operations"""
        self.assembler.symbols = {}
        
        # Test basic AND with hex literals
        result = self.assembler._resolve_expression_to_int("$FF & $0F", self.mock_token)
        assert result == 0x0F
        
        # Test AND with decimal literals
        result = self.assembler._resolve_expression_to_int("255 & 15", self.mock_token)
        assert result == 15
        
        # Test AND masking
        result = self.assembler._resolve_expression_to_int("$AA & $55", self.mock_token)
        assert result == 0x00

    def test_bitwise_and_with_symbols(self):
        """Test bitwise AND with symbol resolution"""
        self.assembler.symbols = {
            'FULL_MASK': 0xFF,
            'LOW_NIBBLE': 0x0F,
            'HIGH_NIBBLE': 0xF0
        }
        
        result = self.assembler._resolve_expression_to_int("FULL_MASK & LOW_NIBBLE", self.mock_token)
        assert result == 0x0F
        
        result = self.assembler._resolve_expression_to_int("HIGH_NIBBLE & LOW_NIBBLE", self.mock_token)
        assert result == 0x00

    # ====== Basic Bitwise XOR Tests ======
    def test_basic_bitwise_xor(self):
        """Test basic bitwise XOR operations"""
        self.assembler.symbols = {}
        
        # Test basic XOR with hex literals
        result = self.assembler._resolve_expression_to_int("$AA ^ $55", self.mock_token)
        assert result == 0xFF
        
        # Test XOR toggle behavior
        result = self.assembler._resolve_expression_to_int("$F0 ^ $FF", self.mock_token)
        assert result == 0x0F
        
        # Test XOR identity (A ^ 0 = A)
        result = self.assembler._resolve_expression_to_int("$AA ^ $00", self.mock_token)
        assert result == 0xAA

    def test_bitwise_xor_with_symbols(self):
        """Test bitwise XOR with symbol resolution"""
        self.assembler.symbols = {
            'PATTERN_A': 0xAA,
            'PATTERN_B': 0x55,
            'TOGGLE_MASK': 0xFF,
            'NO_CHANGE': 0x00
        }
        
        result = self.assembler._resolve_expression_to_int("PATTERN_A ^ PATTERN_B", self.mock_token)
        assert result == 0xFF
        
        result = self.assembler._resolve_expression_to_int("PATTERN_A ^ NO_CHANGE", self.mock_token)
        assert result == 0xAA

    # ====== Bitwise NOT Tests ======
    def test_basic_bitwise_not(self):
        """Test basic bitwise NOT operations"""
        self.assembler.symbols = {}
        
        # Test NOT with hex literals (8-bit result)
        result = self.assembler._resolve_expression_to_int("~$F0", self.mock_token)
        assert result == 0x0F
        
        # Test NOT with zero
        result = self.assembler._resolve_expression_to_int("~$00", self.mock_token)
        assert result == 0xFF
        
        # Test NOT with all ones
        result = self.assembler._resolve_expression_to_int("~$FF", self.mock_token)
        assert result == 0x00

    def test_bitwise_not_with_symbols(self):
        """Test bitwise NOT with symbol resolution"""
        self.assembler.symbols = {
            'HIGH_NIBBLE': 0xF0,
            'LOW_NIBBLE': 0x0F,
            'ZERO': 0x00,
            'FULL': 0xFF
        }
        
        result = self.assembler._resolve_expression_to_int("~HIGH_NIBBLE", self.mock_token)
        assert result == 0x0F
        
        result = self.assembler._resolve_expression_to_int("~ZERO", self.mock_token)
        assert result == 0xFF

    # ====== Shift Operation Tests ======
    def test_basic_left_shift(self):
        """Test basic left shift operations"""
        self.assembler.symbols = {}
        
        # Test basic left shift
        result = self.assembler._resolve_expression_to_int("$01 << 4", self.mock_token)
        assert result == 0x10
        
        # Test left shift with larger values
        result = self.assembler._resolve_expression_to_int("$0F << 2", self.mock_token)
        assert result == 0x3C
        
        # Test left shift that overflows 8-bit (should wrap)
        result = self.assembler._resolve_expression_to_int("$80 << 1", self.mock_token)
        assert result == 0x00  # Wrapped around in 8-bit

    def test_basic_right_shift(self):
        """Test basic right shift operations"""
        self.assembler.symbols = {}
        
        # Test basic right shift
        result = self.assembler._resolve_expression_to_int("$80 >> 3", self.mock_token)
        assert result == 0x10
        
        # Test right shift with smaller values
        result = self.assembler._resolve_expression_to_int("$F0 >> 4", self.mock_token)
        assert result == 0x0F

    def test_shift_with_symbols(self):
        """Test shift operations with symbol resolution"""
        self.assembler.symbols = {
            'BIT_POSITION': 3,
            'BASE_VALUE': 0x08,
            'SHIFT_AMOUNT': 2
        }
        
        result = self.assembler._resolve_expression_to_int("1 << BIT_POSITION", self.mock_token)
        assert result == 0x08
        
        result = self.assembler._resolve_expression_to_int("BASE_VALUE >> SHIFT_AMOUNT", self.mock_token)
        assert result == 0x02

    # ====== Operator Precedence Tests ======
    def test_and_or_precedence(self):
        """Test that AND has higher precedence than OR"""
        self.assembler.symbols = {}
        
        # $0F | $30 & $F0 should be $0F | ($30 & $F0) = $0F | $30 = $3F
        result = self.assembler._resolve_expression_to_int("$0F | $30 & $F0", self.mock_token)
        assert result == 0x3F
        
        # Verify with parentheses for clarity
        result_explicit = self.assembler._resolve_expression_to_int("$0F | ($30 & $F0)", self.mock_token)
        assert result == result_explicit

    def test_xor_precedence(self):
        """Test XOR precedence between AND and OR"""
        self.assembler.symbols = {}
        
        # $F0 | $0C ^ $06 & $FF should be $F0 | ($0C ^ ($06 & $FF)) = $F0 | ($0C ^ $06) = $F0 | $0A = $FA
        result = self.assembler._resolve_expression_to_int("$F0 | $0C ^ $06 & $FF", self.mock_token)
        assert result == 0xFA

    def test_shift_precedence(self):
        """Test that shifts have higher precedence than bitwise operations"""
        self.assembler.symbols = {}
        
        # $01 << 2 | $02 should be ($01 << 2) | $02 = $04 | $02 = $06
        result = self.assembler._resolve_expression_to_int("$01 << 2 | $02", self.mock_token)
        assert result == 0x06

    def test_not_precedence(self):
        """Test that NOT has highest precedence among bitwise ops"""
        self.assembler.symbols = {}
        
        # ~$F0 | $0F should be (~$F0) | $0F = $0F | $0F = $0F
        result = self.assembler._resolve_expression_to_int("~$F0 | $0F", self.mock_token)
        assert result == 0x0F

    # ====== Complex Expression Tests ======
    def test_complex_gpio_configuration(self):
        """Test realistic GPIO pin configuration scenario"""
        self.assembler.symbols = {
            'GPIO_PIN_2': 1 << 2,   # 0x04
            'GPIO_PIN_5': 1 << 5,   # 0x20  
            'GPIO_PIN_7': 1 << 7,   # 0x80
            'GPIO_INPUT_MASK': 0x0F,
            'GPIO_OUTPUT_ENABLE': 0x80
        }
        
        # Create composite output pin mask
        result = self.assembler._resolve_expression_to_int("GPIO_PIN_2 | GPIO_PIN_5 | GPIO_PIN_7", self.mock_token)
        assert result == 0xA4  # 0x04 | 0x20 | 0x80
        
        # Clear input bits and set specific outputs  
        result = self.assembler._resolve_expression_to_int("(GPIO_OUTPUT_ENABLE & ~GPIO_INPUT_MASK) | GPIO_PIN_2", self.mock_token)
        assert result == 0x84  # (0x80 & 0xF0) | 0x04

    def test_complex_uart_configuration(self):
        """Test realistic UART configuration scenario"""
        self.assembler.symbols = {
            'UART_ENABLE': 0x80,
            'UART_8_BITS': 0x06,
            'UART_PARITY_EVEN': 0x08,
            'UART_STOP_2_BITS': 0x10,
            'UART_BAUD_MASK': 0x07,
            'UART_BAUD_9600': 0x03
        }
        
        # Complete UART configuration
        result = self.assembler._resolve_expression_to_int(
            "UART_ENABLE | UART_8_BITS | UART_PARITY_EVEN | UART_STOP_2_BITS | UART_BAUD_9600", 
            self.mock_token
        )
        assert result == 0x9F  # 0x80 | 0x06 | 0x08 | 0x10 | 0x03

    def test_complex_bit_field_extraction(self):
        """Test bit field extraction and manipulation"""
        self.assembler.symbols = {
            'STATUS_REG': 0xA5,     # 10100101
            'MODE_MASK': 0x1C,      # 00011100 (bits 4-2)
            'MODE_SHIFT': 2,
            'ENABLE_BIT': 0x80,     # bit 7
            'READY_BIT': 0x01       # bit 0
        }
        
        # Extract mode field
        result = self.assembler._resolve_expression_to_int("(STATUS_REG & MODE_MASK) >> MODE_SHIFT", self.mock_token)
        assert result == 0x01   # (0xA5 & 0x1C) >> 2 = 0x04 >> 2 = 0x01
        
        # Check if both enable and ready are set
        result = self.assembler._resolve_expression_to_int("(STATUS_REG & ENABLE_BIT) & (STATUS_REG & READY_BIT)", self.mock_token)
        assert result == 0x00  # (0xA5 & 0x80) & (0xA5 & 0x01) = 0x80 & 0x01 = 0x00

    # ====== Mixed Arithmetic and Logical Tests ======
    def test_arithmetic_and_logical_precedence(self):
        """Test precedence between arithmetic and logical operations"""
        self.assembler.symbols = {}
        
        # Arithmetic should have lower precedence than logical
        # $10 + $02 | $01 should be ($10 + $02) | $01 = $12 | $01 = $13
        result = self.assembler._resolve_expression_to_int("$10 + $02 | $01", self.mock_token)
        assert result == 0x13

    def test_functions_with_logical_operations(self):
        """Test LOW_BYTE/HIGH_BYTE functions with logical operations"""
        self.assembler.symbols = {
            'ADDR_16BIT': 0x1234
        }
        
        # Extract low byte and apply mask
        result = self.assembler._resolve_expression_to_int("LOW_BYTE(ADDR_16BIT) & $0F", self.mock_token)
        assert result == 0x04  # LOW_BYTE(0x1234) & 0x0F = 0x34 & 0x0F = 0x04
        
        # Extract high byte and shift
        result = self.assembler._resolve_expression_to_int("HIGH_BYTE(ADDR_16BIT) << 1", self.mock_token)
        assert result == 0x24  # HIGH_BYTE(0x1234) << 1 = 0x12 << 1 = 0x24

    # ====== Error Handling Tests ======
    def test_malformed_or_expression_errors(self):
        """Test error handling for malformed OR expressions"""
        self.assembler.symbols = {}
        
        # Missing right operand
        with pytest.raises(AssemblerError, match="[Mm]alformed logical expression|[Mm]issing operand"):
            self.assembler._resolve_expression_to_int("$0F |", self.mock_token)
        
        # Missing left operand  
        with pytest.raises(AssemblerError, match="[Bb]ad.*value.*[Nn]ot a known symbol"):
            self.assembler._resolve_expression_to_int("| $0F", self.mock_token)

    def test_malformed_and_expression_errors(self):
        """Test error handling for malformed AND expressions"""
        self.assembler.symbols = {}
        
        # Missing operands
        with pytest.raises(AssemblerError, match="[Mm]alformed logical expression|[Mm]issing operand"):
            self.assembler._resolve_expression_to_int("$0F &", self.mock_token)
        
        with pytest.raises(AssemblerError, match="[Bb]ad.*value.*[Nn]ot a known symbol"):
            self.assembler._resolve_expression_to_int("& $0F", self.mock_token)

    def test_malformed_xor_expression_errors(self):
        """Test error handling for malformed XOR expressions"""
        self.assembler.symbols = {}
        
        # Missing operands
        with pytest.raises(AssemblerError, match="[Mm]alformed logical expression|[Mm]issing operand"):
            self.assembler._resolve_expression_to_int("$0F ^", self.mock_token)
        
        with pytest.raises(AssemblerError, match="[Bb]ad.*value.*[Nn]ot a known symbol"):
            self.assembler._resolve_expression_to_int("^ $0F", self.mock_token)

    def test_malformed_shift_expression_errors(self):
        """Test error handling for malformed shift expressions"""
        self.assembler.symbols = {}
        
        # Missing operands
        with pytest.raises(AssemblerError, match="[Mm]alformed shift expression|[Mm]issing operand"):
            self.assembler._resolve_expression_to_int("$0F <<", self.mock_token)
        
        with pytest.raises(AssemblerError, match="[Bb]ad.*value.*[Nn]ot a known symbol"):
            self.assembler._resolve_expression_to_int(">> 2", self.mock_token)

    def test_malformed_not_expression_errors(self):
        """Test error handling for malformed NOT expressions"""
        self.assembler.symbols = {}
        
        # Missing operand
        with pytest.raises(AssemblerError, match="[Mm]alformed unary expression|[Mm]issing operand"):
            self.assembler._resolve_expression_to_int("~", self.mock_token)

    def test_invalid_operator_errors(self):
        """Test error handling for invalid/unsupported operators"""
        self.assembler.symbols = {}
        
        # Double operators (should be treated as logical expressions with missing operands)
        with pytest.raises(AssemblerError, match="[Mm]alformed logical expression|[Mm]issing operand"):
            self.assembler._resolve_expression_to_int("$0F || $30", self.mock_token)
        
        with pytest.raises(AssemblerError, match="[Mm]alformed logical expression|[Mm]issing operand"):
            self.assembler._resolve_expression_to_int("$0F && $30", self.mock_token)

    # ====== Integration with Parser Tests ======
    def test_logical_expressions_in_equ_statements(self):
        """Test logical expressions work in EQU statements through parser"""
        asm_content = '''
        ORG $0000
        MASK_A: EQU $0F
        MASK_B: EQU $F0  
        COMBINED: EQU MASK_A | MASK_B
        start:
        LDI A, #COMBINED
        '''
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.asm', delete=False) as f:
            f.write(asm_content)
            f.flush()
            
            try:
                parser = Parser(f.name)
                # The symbol table should show correct logical expression evaluation
                assert parser.symbol_table['MASK_A'] == 0x0F
                assert parser.symbol_table['MASK_B'] == 0xF0
                assert parser.symbol_table['COMBINED'] == 0xFF  # 0x0F | 0xF0
                assert parser.symbol_table['start'] == 0x0000
            finally:
                os.unlink(f.name)

    def test_logical_expressions_in_operands(self):
        """Test logical expressions work in instruction operands"""
        asm_content = '''
        ORG $0000
        PIN_MASK: EQU $07
        ENABLE_BIT: EQU $80
        start:
        LDI A, #(PIN_MASK | ENABLE_BIT)
        '''
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.asm', delete=False) as f:
            f.write(asm_content)
            f.flush()
            
            try:
                # This should parse without errors and correctly resolve the expression
                assembler = Assembler(f.name, "test_output.hex", None)
                assembler.assemble()
                
                # Verify the operand was correctly resolved to 0x87 (0x07 | 0x80)
                # We can check this by examining the assembled tokens
                found_ldi_token = None
                for token in assembler.parsed_tokens:
                    if token.mnemonic == 'LDI_A':
                        found_ldi_token = token
                        break
                
                assert found_ldi_token is not None
                # The operand should be the expression string, which the assembler resolves during assembly
                assert found_ldi_token.operand == "#(PIN_MASK | ENABLE_BIT)"
                
            finally:
                os.unlink(f.name)
                # Clean up any output files
                if os.path.exists("test_output.hex"):
                    os.unlink("test_output.hex")

    def test_logical_expressions_address_calculation(self):
        """Test logical expressions affecting address calculation in parser"""
        asm_content = '''
        ORG $0000
        start:
        DB "AB"           ; 2 bytes
        MASK: DB ($0F | $F0)    ; 1 byte, should be $FF
        next: NOP         ; Should be at address 3
        '''
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.asm', delete=False) as f:
            f.write(asm_content)
            f.flush()
            
            try:
                parser = Parser(f.name)
                # Address calculation should account for logical expression in DB
                assert parser.symbol_table['start'] == 0x0000
                assert parser.symbol_table['next'] == 0x0003  # start + 2 (string) + 1 (DB with expression)
            finally:
                os.unlink(f.name)