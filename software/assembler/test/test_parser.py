# software/assembler/test/test_parser.py
import pytest
import os
import re # For re.escape in one of the tests
from io import StringIO

# Adjust import path based on how pytest discovers your modules.
# If running pytest from `software/assembler/` directory:
from src.parser import Parser, ParserError, Token, LINE_PATTERN, CSV_SPLIT_REGEX
from src.constants import INSTRUCTION_SET # For checking mnemonic validity in some tests

class TestParserUnit:
    @pytest.mark.parametrize(
        "line, expected_label, expected_mnemonic, expected_operand",
        [
            ("START: LDA #$10 ; comment", "START", "LDA", "#$10"),
            ("NOP", None, "NOP", None),
            ("    HLT    ", None, "HLT", None),
            (".loop: ADD B", ".loop", "ADD", "B"),
            ("MY_CONST: EQU $1234", "MY_CONST", "EQU", "$1234"),
            ("INCLUDE \"other.asm\"", None, "INCLUDE", "\"other.asm\""),
            ("DB $01, $02, \"HELLO\"", None, "DB", "$01, $02, \"HELLO\""),
            ("label_only:", "label_only", None, None),
            (".local_only:", ".local_only", None, None),
            ("  ; fully commented line", None, None, None),
            ("", None, None, None), # Empty line
            ("LDA MY_SYM + 5", None, "LDA", "MY_SYM + 5"),
            ("LDA LOW_BYTE(MY_SYM)", None, "LDA", "LOW_BYTE(MY_SYM)"),
            ("LDA #LOW_BYTE(MY_SYM)", None, "LDA", "#LOW_BYTE(MY_SYM)"),
            ("LDI A, #$FF", None, "LDI", "A, #$FF"), # Before normalization
            ("some_symbol EQU value", "some_symbol", "EQU", "value"), # Alternative EQU syntax
        ],
    )
    def test_parse_line_components_valid(self, line, expected_label, expected_mnemonic, expected_operand):
        parser = Parser.__new__(Parser) # Create instance without calling __init__
        components = parser._parse_line_components(line, "test.asm", 1)
        if expected_label is None and expected_mnemonic is None and expected_operand is None:
            assert components is None
        else:
            assert components is not None
            label, mnemonic, operand = components
            assert label == expected_label
            assert mnemonic == expected_mnemonic
            assert operand == expected_operand

    @pytest.mark.parametrize(
        "line, expected_error_msg_part",
        [
            # ("BAD:SYNTAX LDA", "Unrecognized syntax"), # Removed as it's structurally parseable
            ("EQU $10", "EQU directive requires a label"),
            ("MY_LABEL: EQU", "EQU directive for label 'MY_LABEL' requires a value"),
            # ("LDI A EQU $10", "Malformed EQU structure in operand field"), # Removed, better tested in _normalize
        ]
    )
    def test_parse_line_components_invalid(self, line, expected_error_msg_part):
        parser = Parser.__new__(Parser)
        # "Unrecognized syntax" case was removed, so this 'if' branch might not be hit with current params.
        # It's okay to leave for future test cases that might trigger the warning path.
        if "Unrecognized syntax" in expected_error_msg_part:
             assert parser._parse_line_components(line, "test.asm", 1) is None
        else:
            with pytest.raises(ParserError) as excinfo:
                parser._parse_line_components(line, "test.asm", 1)
            assert expected_error_msg_part in str(excinfo.value)

    def test_normalize_token_components_malformed_ldi_operand(self):
        parser = Parser.__new__(Parser)
        with pytest.raises(ParserError, match="Malformed operand for LDI: 'A EQU \\$10'. Expected 'REG, VALUE'."):
            parser._normalize_token_components(
                None, "LDI", "A EQU $10", None, "test.asm", 1
            )

    @pytest.mark.parametrize(
        "value_str, base, expected_val",
        [
            ("123", 10, 123),
            ("$FF", 16, 255),
            ("%1010", 2, 10),
            ("$0", 16, 0),
            ("0", 10, 0),
            ("%0", 2, 0),
        ],
    )
    def test_parse_numeric_literal_valid(self, value_str, base, expected_val):
        parser = Parser.__new__(Parser)
        test_str = value_str
        if base == 16 and not value_str.startswith('$'): test_str = "$" + value_str
        elif base == 2 and not value_str.startswith('%'): test_str = "%" + value_str
        
        if value_str.startswith('$') or value_str.startswith('%'):
             test_str = value_str

        val = parser._parse_numeric_literal(test_str, "test value", "test.asm", 1)
        assert val == expected_val

    @pytest.mark.parametrize(
        "value_str, expected_error_msg_part",
        [
            ("$FG", "Bad hexadecimal value"),
            ("%123", "Bad binary value"),
            ("abc", "Bad decimal value"),
            (None, "missing its value"),
            ("$", "Bad hexadecimal value"), 
            ("%", "Bad binary value"),   
        ],
    )
    def test_parse_numeric_literal_invalid(self, value_str, expected_error_msg_part):
        parser = Parser.__new__(Parser)
        with pytest.raises(ParserError) as excinfo:
            parser._parse_numeric_literal(value_str, "test value", "test.asm", 1)
        assert expected_error_msg_part in str(excinfo.value)

    def test_parse_numeric_literal_org_range_check(self):
        parser = Parser.__new__(Parser)
        with pytest.raises(ParserError, match="out of 16-bit range"):
            parser._parse_numeric_literal("$10000", "ORG directive", "test.asm", 1) 
        assert parser._parse_numeric_literal("$FFFF", "ORG directive", "test.asm", 1) == 0xFFFF
        assert parser._parse_numeric_literal("65535", "ORG directive", "test.asm", 1) == 0xFFFF

    @pytest.mark.parametrize(
        "label, mnemonic, operand, current_global_scope, expected_norm_mnem, expected_norm_op",
        [
            (None, "LDI", "A, #$10", None, "LDI_A", "#$10"),
            (None, "MOV", "B, C", None, "MOV_BC", None),
            (None, "ADD", "B", None, "ADD_B", None),
            (None, "LDA", "MY_ADDR", None, "LDA", "MY_ADDR"),
            (None, "JMP", ".loop", "GLOBAL", "JMP", "GLOBAL.loop"),
            (None, "DB", "\"Str\", .val", "SCOPE", "DB", "\"Str\", SCOPE.val"),
            (None, "LDA", "TARGET + .OFFSET", "MAIN", "LDA", "TARGET + MAIN.OFFSET"),
        ],
    )
    def test_normalize_token_components(
        self, label, mnemonic, operand, current_global_scope, expected_norm_mnem, expected_norm_op
    ):
        parser = Parser.__new__(Parser)
        _, norm_mnem, norm_op = parser._normalize_token_components(
            label, mnemonic, operand, current_global_scope, "test.asm", 1
        )
        assert norm_mnem == expected_norm_mnem
        assert norm_op == expected_norm_op
    
    def test_normalize_token_components_local_label_no_scope_error(self):
        parser = Parser.__new__(Parser)
        with pytest.raises(ParserError, match="Local label reference '.loop' used without an active global label scope."):
            parser._normalize_token_components(None, "JMP", ".loop", None, "test.asm", 1)

    def test_add_symbol_to_table(self):
        parser = Parser.__new__(Parser)
        parser.symbol_table = {}
        parser._add_symbol_to_table("SYM1", 100, "test.asm", 1)
        assert parser.symbol_table["SYM1"] == 100
        parser._add_symbol_to_table("SYM1", 100, "test.asm", 2)
        assert parser.symbol_table["SYM1"] == 100
        with pytest.raises(ParserError, match="Duplicate symbol: 'SYM1'"):
            parser._add_symbol_to_table("SYM1", 200, "test.asm", 3)

    def test_calculate_db_dw_size(self):
        parser = Parser.__new__(Parser)
        assert parser._calculate_db_dw_size("DB", "$01", "f.asm", 1) == 1
        assert parser._calculate_db_dw_size("DB", "$01, $02, $03", "f.asm", 1) == 3
        assert parser._calculate_db_dw_size("DB", "\"ABC\"", "f.asm", 1) == 3
        assert parser._calculate_db_dw_size("DB", "\"A\", $01, \"BC\"", "f.asm", 1) == 1 + 1 + 2 
        assert parser._calculate_db_dw_size("DB", "\"\"", "f.asm", 1) == 0 
        assert parser._calculate_db_dw_size("DW", "$1234", "f.asm", 1) == 2
        assert parser._calculate_db_dw_size("DW", "$1234, $5678", "f.asm", 1) == 4
        with pytest.raises(ParserError, match="DB directive requires operand"):
            parser._calculate_db_dw_size("DB", None, "f.asm", 1)

    def test_parser_overall_simple_program(self, monkeypatch):
        asm_content = """
        START:  NOP         ; First instruction
                LDI A, #$10 ; Load A
        VAL:    EQU $05     ; A constant
                DB  VAL     ; Define a byte
                HLT
        .local: NOP         ; Local label
        """
        dummy_filepath = "/dummy/test_simple.asm" 
        mock_tracker = {"called_for_file": None}

        def mock_load(instance_self, filepath_to_load, requesting_file, requesting_line_no):
            mock_tracker["called_for_file"] = filepath_to_load
            if filepath_to_load == dummy_filepath:
                return asm_content.splitlines()
            raise FileNotFoundError(f"[Mock] File not found: {filepath_to_load}")

        monkeypatch.setattr(Parser, "_load_lines_from_physical_file", mock_load)
        parser = Parser(main_input_filepath=dummy_filepath) 
        assert mock_tracker["called_for_file"] == dummy_filepath

        expected_symbols = {
            "START": 0x0000,
            "VAL": 0x0005,
            "START.local": 0x0005 
        }
        assert parser.symbol_table == expected_symbols

        expected_tokens = [
            Token(source_file=dummy_filepath, line_no=2, label='START', mnemonic='NOP', operand=None),
            Token(source_file=dummy_filepath, line_no=3, label=None, mnemonic='LDI_A', operand='#$10'),
            Token(source_file=dummy_filepath, line_no=4, label='VAL', mnemonic='EQU', operand='$05'),
            Token(source_file=dummy_filepath, line_no=5, label=None, mnemonic='DB', operand='VAL'), 
            Token(source_file=dummy_filepath, line_no=6, label=None, mnemonic='HLT', operand=None),
            Token(source_file=dummy_filepath, line_no=7, label='.local', mnemonic='NOP', operand=None)
        ]
        assert len(parser.tokens) == len(expected_tokens)
        for i, token in enumerate(parser.tokens):
            exp_token = expected_tokens[i]
            assert token.line_no == exp_token.line_no
            assert token.source_file == exp_token.source_file 
            assert token.label == exp_token.label
            assert token.mnemonic == exp_token.mnemonic
            assert token.operand == exp_token.operand
            
    def test_parser_include_directive(self, tmp_path, monkeypatch): # Added monkeypatch
        main_asm_content = """
        GLOBAL_MAIN: NOP
        INCLUDE "included.asm"
        LDI C, #$30
        """
        included_asm_content = """
        ; This is included.asm
        .local_in_include: LDI B, #$20
        DATA_INCL: DB "INC" 
        """
        main_file_path_str = str(tmp_path / "main.asm")
        included_file_path_str = str(tmp_path / "included.asm")

        with open(main_file_path_str, "w") as f:
            f.write(main_asm_content)
        with open(included_file_path_str, "w") as f:
            f.write(included_asm_content)

        # For test_parser_include_directive, we don't need to mock _load_lines_from_physical_file
        # because we want to test the actual file loading and include mechanism.
        # So, no monkeypatch.setattr here for _load_lines_from_physical_file.
        # The Parser will use its real file loading.
        
        parser = Parser(main_file_path_str)

        expected_symbols = {
            "GLOBAL_MAIN": 0x0000,
            "GLOBAL_MAIN.local_in_include": 0x0001, 
            "DATA_INCL": 0x0003, 
        }
        for k,v in expected_symbols.items():
            assert k in parser.symbol_table, f"Symbol {k} not found in symbol table."
            assert parser.symbol_table[k] == v, f"Symbol {k} has value {parser.symbol_table[k]}, expected {v}"
        
        expected_token_mnemonics = ["NOP", "LDI_B", "DB", "LDI_C"] # INCLUDE token itself is not added to self.tokens
        actual_token_mnemonics = [t.mnemonic for t in parser.tokens] # No need to filter INCLUDE here
        assert actual_token_mnemonics == expected_token_mnemonics
        
        # Check that operand for LDI_B (from included file) is mangled correctly
        # Token order: NOP (main), LDI_B (incl), DB (incl), LDI_C (main)
        assert parser.tokens[1].mnemonic == "LDI_B"
        assert parser.tokens[1].operand == "#$20" # Local label .local_in_include is on same line, not an operand here
                                                  # If LDI B used an operand like ".foo", it would be mangled.

    def test_parser_local_label_scoping(self, monkeypatch): # Added monkeypatch
        asm_content = """
        ROUTINE1: NOP
        .loop:    LDI A, #1
                  JMP .loop
        ROUTINE2: NOP
        .loop:    LDI B, #2
                  JMP .loop 
        """
        dummy_filepath = "/dummy/test_local_scope.asm"
        mock_tracker = {"called_for_file": None}

        def mock_load(instance_self, filepath_to_load, requesting_file, requesting_line_no):
            mock_tracker["called_for_file"] = filepath_to_load
            if filepath_to_load == dummy_filepath:
                return asm_content.splitlines()
            raise FileNotFoundError(f"[Mock] File not found: {filepath_to_load}")

        monkeypatch.setattr(Parser, "_load_lines_from_physical_file", mock_load)
        parser = Parser(main_input_filepath=dummy_filepath)
        assert mock_tracker["called_for_file"] == dummy_filepath

        expected_symbols = {
            "ROUTINE1": 0x0000,
            "ROUTINE1.loop": 0x0001,
            "ROUTINE2": 0x0006, # NOP(1) + LDI_A(2) + JMP(3) = 6
            "ROUTINE2.loop": 0x0007  # ROUTINE2_NOP(1) -> .loop is at 6+1=7
        }
        assert parser.symbol_table == expected_symbols

        expected_token_details = [
            ('NOP', None), 
            ('LDI_A', '#1'), 
            ('JMP', 'ROUTINE1.loop'), 
            ('NOP', None), 
            ('LDI_B', '#2'), 
            ('JMP', 'ROUTINE2.loop')
        ]
        actual_token_details = [(t.mnemonic, t.operand) for t in parser.tokens]
        assert actual_token_details == expected_token_details

    def test_parser_error_local_label_no_global(self, monkeypatch): # Added monkeypatch
        asm_content = ".noluck: NOP" 
        dummy_filepath = "/dummy/test_local_error.asm"
        mock_tracker = {"called_for_file": None}

        def mock_load(instance_self, filepath_to_load, requesting_file, requesting_line_no):
            mock_tracker["called_for_file"] = filepath_to_load
            if filepath_to_load == dummy_filepath:
                return asm_content.splitlines()
            raise FileNotFoundError(f"[Mock] File not found: {filepath_to_load}")

        monkeypatch.setattr(Parser, "_load_lines_from_physical_file", mock_load)

        expected_error_msg = "Local label '.noluck' defined without a preceding global label."
        # Use re.escape because the message contains '.', which is a special char in regex
        with pytest.raises(ParserError, match=re.escape(expected_error_msg)) as excinfo:
            parser = Parser(main_input_filepath=dummy_filepath)
        
        assert mock_tracker["called_for_file"] == dummy_filepath # Ensure mock was hit before error
        assert excinfo.value.source_file == dummy_filepath
        assert excinfo.value.line_no == 1 # .noluck: NOP is on the first line of asm_content