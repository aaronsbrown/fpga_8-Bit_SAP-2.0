# software/assembler/test/test_conditional_assembly.py
import pytest
import re
from src.parser import Parser, ParserError
from src.assembler import Assembler, AssemblerError


class TestConditionalAssemblyParser:
    """Test conditional assembly directives in parser."""
    
    def test_ifdef_basic_defined_symbol(self, monkeypatch):
        """Test IFDEF with a defined symbol."""
        asm_content = """
        MY_FLAG EQU 1
        START: NOP
        IFDEF MY_FLAG
            LDI A, #$10  ; This should be included
        ENDIF
        HLT
        """
        dummy_filepath = "/dummy/test_ifdef_defined.asm"
        
        def mock_load(instance_self, filepath_to_load, requesting_file, requesting_line_no):
            if filepath_to_load == dummy_filepath:
                return asm_content.splitlines()
            raise FileNotFoundError(f"[Mock] File not found: {filepath_to_load}")
        
        monkeypatch.setattr(Parser, "_load_lines_from_physical_file", mock_load)
        parser = Parser(main_input_filepath=dummy_filepath)
        
        # Should include the LDI instruction
        mnemonics = [t.mnemonic for t in parser.tokens if t.mnemonic != 'EQU']
        assert mnemonics == ["NOP", "LDI_A", "HLT"]
        
    def test_ifdef_undefined_symbol(self, monkeypatch):
        """Test IFDEF with an undefined symbol."""
        asm_content = """
        START: NOP
        IFDEF UNDEFINED_FLAG
            LDI A, #$10  ; This should be skipped
        ENDIF
        HLT
        """
        dummy_filepath = "/dummy/test_ifdef_undefined.asm"
        
        def mock_load(instance_self, filepath_to_load, requesting_file, requesting_line_no):
            if filepath_to_load == dummy_filepath:
                return asm_content.splitlines()
            raise FileNotFoundError(f"[Mock] File not found: {filepath_to_load}")
        
        monkeypatch.setattr(Parser, "_load_lines_from_physical_file", mock_load)
        parser = Parser(main_input_filepath=dummy_filepath)
        
        # Should skip the LDI instruction
        mnemonics = [t.mnemonic for t in parser.tokens]
        assert mnemonics == ["NOP", "HLT"]
        
    def test_ifndef_basic_undefined_symbol(self, monkeypatch):
        """Test IFNDEF with an undefined symbol."""
        asm_content = """
        START: NOP
        IFNDEF UNDEFINED_FLAG
            LDI A, #$10  ; This should be included
        ENDIF
        HLT
        """
        dummy_filepath = "/dummy/test_ifndef_undefined.asm"
        
        def mock_load(instance_self, filepath_to_load, requesting_file, requesting_line_no):
            if filepath_to_load == dummy_filepath:
                return asm_content.splitlines()
            raise FileNotFoundError(f"[Mock] File not found: {filepath_to_load}")
        
        monkeypatch.setattr(Parser, "_load_lines_from_physical_file", mock_load)
        parser = Parser(main_input_filepath=dummy_filepath)
        
        # Should include the LDI instruction
        mnemonics = [t.mnemonic for t in parser.tokens]
        assert mnemonics == ["NOP", "LDI_A", "HLT"]
        
    def test_ifndef_defined_symbol(self, monkeypatch):
        """Test IFNDEF with a defined symbol."""
        asm_content = """
        MY_FLAG EQU 1
        START: NOP
        IFNDEF MY_FLAG
            LDI A, #$10  ; This should be skipped
        ENDIF
        HLT
        """
        dummy_filepath = "/dummy/test_ifndef_defined.asm"
        
        def mock_load(instance_self, filepath_to_load, requesting_file, requesting_line_no):
            if filepath_to_load == dummy_filepath:
                return asm_content.splitlines()
            raise FileNotFoundError(f"[Mock] File not found: {filepath_to_load}")
        
        monkeypatch.setattr(Parser, "_load_lines_from_physical_file", mock_load)
        parser = Parser(main_input_filepath=dummy_filepath)
        
        # Should skip the LDI instruction
        mnemonics = [t.mnemonic for t in parser.tokens if t.mnemonic != 'EQU']
        assert mnemonics == ["NOP", "HLT"]
        
    def test_ifdef_else_defined_symbol(self, monkeypatch):
        """Test IFDEF with ELSE when symbol is defined."""
        asm_content = """
        MY_FLAG EQU 1
        START: NOP
        IFDEF MY_FLAG
            LDI A, #$10  ; This should be included
        ELSE
            LDI A, #$20  ; This should be skipped
        ENDIF
        HLT
        """
        dummy_filepath = "/dummy/test_ifdef_else_defined.asm"
        
        def mock_load(instance_self, filepath_to_load, requesting_file, requesting_line_no):
            if filepath_to_load == dummy_filepath:
                return asm_content.splitlines()
            raise FileNotFoundError(f"[Mock] File not found: {filepath_to_load}")
        
        monkeypatch.setattr(Parser, "_load_lines_from_physical_file", mock_load)
        parser = Parser(main_input_filepath=dummy_filepath)
        
        # Should include first LDI, skip second
        operands = [t.operand for t in parser.tokens if t.mnemonic == 'LDI_A']
        assert operands == ["#$10"]
        
    def test_ifdef_else_undefined_symbol(self, monkeypatch):
        """Test IFDEF with ELSE when symbol is undefined."""
        asm_content = """
        START: NOP
        IFDEF UNDEFINED_FLAG
            LDI A, #$10  ; This should be skipped
        ELSE
            LDI A, #$20  ; This should be included
        ENDIF
        HLT
        """
        dummy_filepath = "/dummy/test_ifdef_else_undefined.asm"
        
        def mock_load(instance_self, filepath_to_load, requesting_file, requesting_line_no):
            if filepath_to_load == dummy_filepath:
                return asm_content.splitlines()
            raise FileNotFoundError(f"[Mock] File not found: {filepath_to_load}")
        
        monkeypatch.setattr(Parser, "_load_lines_from_physical_file", mock_load)
        parser = Parser(main_input_filepath=dummy_filepath)
        
        # Should skip first LDI, include second
        operands = [t.operand for t in parser.tokens if t.mnemonic == 'LDI_A']
        assert operands == ["#$20"]
        
    def test_nested_conditional_assembly(self, monkeypatch):
        """Test nested conditional assembly blocks."""
        asm_content = """
        OUTER_FLAG EQU 1
        START: NOP
        IFDEF OUTER_FLAG
            LDI A, #$10  ; Should be included
            IFNDEF INNER_FLAG
                LDI B, #$20  ; Should be included (INNER_FLAG not defined)
            ELSE
                LDI B, #$30  ; Should be skipped
            ENDIF
            LDI C, #$40  ; Should be included
        ENDIF
        HLT
        """
        dummy_filepath = "/dummy/test_nested_conditional.asm"
        
        def mock_load(instance_self, filepath_to_load, requesting_file, requesting_line_no):
            if filepath_to_load == dummy_filepath:
                return asm_content.splitlines()
            raise FileNotFoundError(f"[Mock] File not found: {filepath_to_load}")
        
        monkeypatch.setattr(Parser, "_load_lines_from_physical_file", mock_load)
        parser = Parser(main_input_filepath=dummy_filepath)
        
        # Should include LDI A #$10, LDI B #$20, LDI C #$40
        ldi_tokens = [t for t in parser.tokens if t.mnemonic.startswith('LDI_')]
        expected_operands = ["#$10", "#$20", "#$40"]
        actual_operands = [t.operand for t in ldi_tokens]
        assert actual_operands == expected_operands
        
    def test_conditional_with_labels_and_symbols(self, monkeypatch):
        """Test that labels and symbols inside conditional blocks are handled correctly."""
        asm_content = """
        DEBUG_MODE EQU 1
        START: NOP
        IFDEF DEBUG_MODE
        DEBUG_ROUTINE:
            LDI A, #$FF
            DEBUG_VAL EQU $42
        ENDIF
        LDI B, #DEBUG_VAL  ; Should use the defined value
        HLT
        """
        dummy_filepath = "/dummy/test_conditional_symbols.asm"
        
        def mock_load(instance_self, filepath_to_load, requesting_file, requesting_line_no):
            if filepath_to_load == dummy_filepath:
                return asm_content.splitlines()
            raise FileNotFoundError(f"[Mock] File not found: {filepath_to_load}")
        
        monkeypatch.setattr(Parser, "_load_lines_from_physical_file", mock_load)
        parser = Parser(main_input_filepath=dummy_filepath)
        
        # DEBUG_ROUTINE and DEBUG_VAL should be defined
        assert "DEBUG_ROUTINE" in parser.symbol_table
        assert "DEBUG_VAL" in parser.symbol_table
        assert parser.symbol_table["DEBUG_VAL"] == 0x42
        
        # LDI B should use DEBUG_VAL
        ldi_b_token = next(t for t in parser.tokens if t.mnemonic == 'LDI_B')
        assert ldi_b_token.operand == "#DEBUG_VAL"


class TestConditionalAssemblyErrors:
    """Test error conditions for conditional assembly directives."""
    
    def test_unmatched_ifdef(self, monkeypatch):
        """Test error when IFDEF has no matching ENDIF."""
        asm_content = """
        START: NOP
        IFDEF MY_FLAG
            LDI A, #$10
        ; Missing ENDIF
        HLT
        """
        dummy_filepath = "/dummy/test_unmatched_ifdef.asm"
        
        def mock_load(instance_self, filepath_to_load, requesting_file, requesting_line_no):
            if filepath_to_load == dummy_filepath:
                return asm_content.splitlines()
            raise FileNotFoundError(f"[Mock] File not found: {filepath_to_load}")
        
        monkeypatch.setattr(Parser, "_load_lines_from_physical_file", mock_load)
        
        with pytest.raises(ParserError, match="Unmatched IFDEF.*ENDIF"):
            Parser(main_input_filepath=dummy_filepath)
            
    def test_unmatched_endif(self, monkeypatch):
        """Test error when ENDIF has no matching IFDEF/IFNDEF."""
        asm_content = """
        START: NOP
        ENDIF  ; No matching IFDEF/IFNDEF
        HLT
        """
        dummy_filepath = "/dummy/test_unmatched_endif.asm"
        
        def mock_load(instance_self, filepath_to_load, requesting_file, requesting_line_no):
            if filepath_to_load == dummy_filepath:
                return asm_content.splitlines()
            raise FileNotFoundError(f"[Mock] File not found: {filepath_to_load}")
        
        monkeypatch.setattr(Parser, "_load_lines_from_physical_file", mock_load)
        
        with pytest.raises(ParserError, match="ENDIF.*without.*matching.*IFDEF"):
            Parser(main_input_filepath=dummy_filepath)
            
    def test_unmatched_else(self, monkeypatch):
        """Test error when ELSE has no matching IFDEF/IFNDEF."""
        asm_content = """
        START: NOP
        ELSE  ; No matching IFDEF/IFNDEF
            LDI A, #$10
        HLT
        """
        dummy_filepath = "/dummy/test_unmatched_else.asm"
        
        def mock_load(instance_self, filepath_to_load, requesting_file, requesting_line_no):
            if filepath_to_load == dummy_filepath:
                return asm_content.splitlines()
            raise FileNotFoundError(f"[Mock] File not found: {filepath_to_load}")
        
        monkeypatch.setattr(Parser, "_load_lines_from_physical_file", mock_load)
        
        with pytest.raises(ParserError, match="ELSE.*without.*matching.*IFDEF"):
            Parser(main_input_filepath=dummy_filepath)
            
    def test_multiple_else_blocks(self, monkeypatch):
        """Test error when multiple ELSE blocks are used in same conditional."""
        asm_content = """
        START: NOP
        IFDEF MY_FLAG
            LDI A, #$10
        ELSE
            LDI A, #$20
        ELSE  ; Second ELSE - should be error
            LDI A, #$30
        ENDIF
        HLT
        """
        dummy_filepath = "/dummy/test_multiple_else.asm"
        
        def mock_load(instance_self, filepath_to_load, requesting_file, requesting_line_no):
            if filepath_to_load == dummy_filepath:
                return asm_content.splitlines()
            raise FileNotFoundError(f"[Mock] File not found: {filepath_to_load}")
        
        monkeypatch.setattr(Parser, "_load_lines_from_physical_file", mock_load)
        
        with pytest.raises(ParserError, match="Multiple ELSE.*same.*conditional"):
            Parser(main_input_filepath=dummy_filepath)


class TestConditionalAssemblyEndToEnd:
    """Test conditional assembly with complete assembler pipeline."""
    
    def test_default_constants_override(self, tmp_path):
        """Test the main use case: overriding default constants from includes."""
        # Create main program that defines USER_DELAY_LOW before include
        main_asm_content = """
        USER_DELAY_LOW EQU $50  ; User overrides the default
        INCLUDE "library.inc"
        
        START:
            LDI A, #USER_DELAY_LOW  ; Should use $50
            HLT
        """
        
        # Create library include file with conditional default
        library_asm_content = """
        ; Library with conditional defaults
        IFNDEF USER_DELAY_LOW   ; If user hasn't defined it
            USER_DELAY_LOW EQU $10  ; Define a default
        ENDIF
        
        LIBRARY_ROUTINE:
            LDI B, #USER_DELAY_LOW  ; Uses user value or default
            RET
        """
        
        main_file_path = tmp_path / "main.asm"
        library_file_path = tmp_path / "library.inc"
        output_file_path = tmp_path / "output.hex"
        
        with open(main_file_path, "w") as f:
            f.write(main_asm_content)
        with open(library_file_path, "w") as f:
            f.write(library_asm_content)
        
        # Should assemble successfully with user override
        assembler = Assembler(str(main_file_path), str(output_file_path), None)
        assembler.assemble()
        
        # Verify that USER_DELAY_LOW has the overridden value
        assert assembler.symbols["USER_DELAY_LOW"] == 0x50
        
        # Verify both LDI instructions use the overridden value
        ldi_tokens = [t for t in assembler.parsed_tokens if t.mnemonic.startswith('LDI_')]
        for token in ldi_tokens:
            assert token.operand == "#USER_DELAY_LOW"
            
    def test_default_constants_no_override(self, tmp_path):
        """Test library defaults when user doesn't override."""
        # Create main program that doesn't define USER_DELAY_LOW
        main_asm_content = """
        INCLUDE "library.inc"
        
        START:
            LDI A, #USER_DELAY_LOW  ; Should use default $10
            HLT
        """
        
        # Create library include file with conditional default
        library_asm_content = """
        ; Library with conditional defaults
        IFNDEF USER_DELAY_LOW   ; If user hasn't defined it
            USER_DELAY_LOW EQU $10  ; Define a default
        ENDIF
        
        LIBRARY_ROUTINE:
            LDI B, #USER_DELAY_LOW  ; Uses default
            RET
        """
        
        main_file_path = tmp_path / "main.asm"
        library_file_path = tmp_path / "library.inc"
        output_file_path = tmp_path / "output.hex"
        
        with open(main_file_path, "w") as f:
            f.write(main_asm_content)
        with open(library_file_path, "w") as f:
            f.write(library_asm_content)
        
        # Should assemble successfully with default value
        assembler = Assembler(str(main_file_path), str(output_file_path), None)
        assembler.assemble()
        
        # Verify that USER_DELAY_LOW has the default value
        assert assembler.symbols["USER_DELAY_LOW"] == 0x10