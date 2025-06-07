# software/assembler/test/test_macros.py

import pytest
import tempfile
import os
from unittest.mock import patch
from src.parser import Parser, ParserError
from src.assembler import Assembler, AssemblerError


class TestMacroDefinition:
    """Test macro definition parsing and storage"""
    
    def test_simple_macro_definition(self):
        """Test basic macro definition syntax"""
        asm_content = """
        MACRO TEST_MACRO
            NOP
            HLT
        ENDM
        
        TEST_MACRO
        """
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.asm', delete=False) as f:
            f.write(asm_content)
            f.flush()
            
            try:
                parser = Parser(f.name)
                
                # Should have collected the macro definition
                assert "TEST_MACRO" in parser.macros
                macro = parser.macros["TEST_MACRO"]
                assert macro.name == "TEST_MACRO"
                assert len(macro.parameters) == 0
                assert len(macro.body_lines) == 2
                
                # Should have expanded the macro invocation
                # Looking for NOP and HLT tokens
                nop_tokens = [t for t in parser.tokens if t.mnemonic == "NOP"]
                hlt_tokens = [t for t in parser.tokens if t.mnemonic == "HLT"]
                assert len(nop_tokens) == 1
                assert len(hlt_tokens) == 1
                
            finally:
                os.unlink(f.name)
    
    def test_macro_with_parameters(self):
        """Test macro definition with parameters"""
        asm_content = """
        MACRO LOAD_REG reg, value
            LDI reg, value
        ENDM
        
        LOAD_REG A, #$42
        LOAD_REG B, #$33
        """
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.asm', delete=False) as f:
            f.write(asm_content)
            f.flush()
            
            try:
                parser = Parser(f.name)
                
                # Check macro definition
                assert "LOAD_REG" in parser.macros
                macro = parser.macros["LOAD_REG"]
                assert macro.parameters == ["reg", "value"]
                
                # Check expanded tokens
                ldi_a_tokens = [t for t in parser.tokens if t.mnemonic == "LDI_A"]
                ldi_b_tokens = [t for t in parser.tokens if t.mnemonic == "LDI_B"]
                assert len(ldi_a_tokens) == 1
                assert len(ldi_b_tokens) == 1
                assert ldi_a_tokens[0].operand == "#$42"
                assert ldi_b_tokens[0].operand == "#$33"
                
            finally:
                os.unlink(f.name)
    
    def test_macro_with_local_labels(self):
        """Test macro with local labels using @@ syntax"""
        asm_content = """
        MACRO DELAY_LOOP count
            LDI A, count
        @@loop:
            DCR A
            JNZ @@loop
        ENDM
        
        DELAY_LOOP #$10
        DELAY_LOOP #$05
        """
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.asm', delete=False) as f:
            f.write(asm_content)
            f.flush()
            
            try:
                parser = Parser(f.name)
                
                # Check that local labels were made unique
                # Each expansion should have different local label names
                jnz_tokens = [t for t in parser.tokens if t.mnemonic == "JNZ"]
                assert len(jnz_tokens) == 2
                
                # Local labels should be unique across expansions
                label_targets = [t.operand for t in jnz_tokens]
                assert len(set(label_targets)) == 2  # Should be different
                assert all("__MACRO_" in target for target in label_targets)
                
            finally:
                os.unlink(f.name)


class TestMacroExpansion:
    """Test macro invocation and expansion"""
    
    def test_parameter_substitution(self):
        """Test that parameters are correctly substituted"""
        asm_content = """
        MACRO ADD_TO_REG reg, value
            LDI A, value
            ADD reg
            MOV reg, A
        ENDM
        
        ADD_TO_REG B, #$10
        """
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.asm', delete=False) as f:
            f.write(asm_content)
            f.flush()
            
            try:
                parser = Parser(f.name)
                
                # Check parameter substitution
                tokens = parser.tokens
                ldi_token = next(t for t in tokens if t.mnemonic == "LDI_A")
                add_token = next(t for t in tokens if t.mnemonic == "ADD_B")
                mov_token = next(t for t in tokens if t.mnemonic == "MOV_BA")
                
                assert ldi_token.operand == "#$10"
                assert add_token is not None
                assert mov_token is not None
                
            finally:
                os.unlink(f.name)
    
    def test_multiple_macro_invocations(self):
        """Test multiple invocations of the same macro"""
        asm_content = """
        MACRO INC_REG reg
            INR reg
        ENDM
        
        INC_REG A
        INC_REG B
        INC_REG C
        """
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.asm', delete=False) as f:
            f.write(asm_content)
            f.flush()
            
            try:
                parser = Parser(f.name)
                
                # Should have 3 INR instructions
                inr_a_tokens = [t for t in parser.tokens if t.mnemonic == "INR_A"]
                inr_b_tokens = [t for t in parser.tokens if t.mnemonic == "INR_B"] 
                inr_c_tokens = [t for t in parser.tokens if t.mnemonic == "INR_C"]
                
                assert len(inr_a_tokens) == 1
                assert len(inr_b_tokens) == 1
                assert len(inr_c_tokens) == 1
                
            finally:
                os.unlink(f.name)
    
    def test_nested_macro_invocations(self):
        """Test that one macro can call another macro"""
        asm_content = """
        MACRO CLEAR_REG reg
            LDI reg, #$00
        ENDM
        
        MACRO INIT_REGS
            CLEAR_REG A
            CLEAR_REG B
            CLEAR_REG C
        ENDM
        
        INIT_REGS
        """
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.asm', delete=False) as f:
            f.write(asm_content)
            f.flush()
            
            try:
                parser = Parser(f.name)
                
                # Should have 3 LDI instructions
                ldi_tokens = [t for t in parser.tokens if t.mnemonic and t.mnemonic.startswith("LDI_")]
                assert len(ldi_tokens) == 3
                
                # All should load #$00
                assert all(t.operand == "#$00" for t in ldi_tokens)
                
            finally:
                os.unlink(f.name)


class TestMacroErrors:
    """Test macro error handling"""
    
    def test_undefined_macro_invocation(self):
        """Test error when invoking undefined macro"""
        asm_content = """
        UNDEFINED_MACRO
        """
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.asm', delete=False) as f:
            f.write(asm_content)
            f.flush()
            
            try:
                with pytest.raises(ParserError, match="Unknown mnemonic or macro"):
                    Parser(f.name)
                    
            finally:
                os.unlink(f.name)
    
    def test_macro_parameter_count_mismatch(self):
        """Test error when parameter count doesn't match"""
        asm_content = """
        MACRO TWO_PARAM_MACRO param1, param2
            LDI A, param1
            LDI B, param2
        ENDM
        
        TWO_PARAM_MACRO #$10
        """
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.asm', delete=False) as f:
            f.write(asm_content)
            f.flush()
            
            try:
                with pytest.raises(ParserError, match="Parameter count mismatch"):
                    Parser(f.name)
                    
            finally:
                os.unlink(f.name)
    
    def test_duplicate_macro_definition(self):
        """Test error when macro is defined twice"""
        asm_content = """
        MACRO TEST_MACRO
            NOP
        ENDM
        
        MACRO TEST_MACRO
            HLT
        ENDM
        """
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.asm', delete=False) as f:
            f.write(asm_content)
            f.flush()
            
            try:
                with pytest.raises(ParserError, match="Macro.*already defined"):
                    Parser(f.name)
                    
            finally:
                os.unlink(f.name)
    
    def test_macro_missing_endm(self):
        """Test error when ENDM is missing"""
        asm_content = """
        MACRO INCOMPLETE_MACRO
            NOP
            HLT
        """
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.asm', delete=False) as f:
            f.write(asm_content)
            f.flush()
            
            try:
                with pytest.raises(ParserError, match="Macro.*not closed.*ENDM"):
                    Parser(f.name)
                    
            finally:
                os.unlink(f.name)
    
    def test_endm_without_macro(self):
        """Test error when ENDM appears without MACRO"""
        asm_content = """
        NOP
        ENDM
        """
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.asm', delete=False) as f:
            f.write(asm_content)
            f.flush()
            
            try:
                with pytest.raises(ParserError, match="ENDM without.*MACRO"):
                    Parser(f.name)
                    
            finally:
                os.unlink(f.name)


class TestMacroIntegration:
    """Test macro integration with existing assembler features"""
    
    def test_macros_with_labels_and_symbols(self):
        """Test macros work with labels and symbol definitions"""
        asm_content = """
        STACK_TOP EQU $01FF
        
        MACRO SETUP_STACK
            LDI A, HIGH_BYTE(STACK_TOP)
            LDI B, LOW_BYTE(STACK_TOP)
        ENDM
        
        START:
            SETUP_STACK
            NOP
        """
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.asm', delete=False) as f:
            f.write(asm_content)
            f.flush()
            
            try:
                parser = Parser(f.name)
                
                # Check symbol table has START label
                assert "START" in parser.symbol_table
                
                # Check macro was expanded
                ldi_tokens = [t for t in parser.tokens if t.mnemonic and t.mnemonic.startswith("LDI_")]
                assert len(ldi_tokens) == 2
                
            finally:
                os.unlink(f.name)
    
    def test_macros_in_included_files(self):
        """Test macros work with INCLUDE directive"""
        # Create macro definition file
        macro_content = """
        MACRO DELAY
            NOP
            NOP
        ENDM
        """
        
        main_content = """
        INCLUDE "macros.inc"
        
        START:
            DELAY
            HLT
        """
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.inc', delete=False) as macro_file:
            macro_file.write(macro_content)
            macro_file.flush()
            
            with tempfile.NamedTemporaryFile(mode='w', suffix='.asm', delete=False) as main_file:
                # Update main content to use actual macro file name
                actual_main_content = main_content.replace("macros.inc", os.path.basename(macro_file.name))
                main_file.write(actual_main_content)
                main_file.flush()
                
                try:
                    parser = Parser(main_file.name)
                    
                    # Check macro was loaded from include
                    assert "DELAY" in parser.macros
                    
                    # Check macro was expanded
                    nop_tokens = [t for t in parser.tokens if t.mnemonic == "NOP"]
                    assert len(nop_tokens) == 2
                    
                finally:
                    os.unlink(macro_file.name)
                    os.unlink(main_file.name)
    
    def test_full_assembly_with_macros(self):
        """Test complete assembly process with macros"""
        asm_content = """
        MACRO LOAD_AND_ADD reg, value
            LDI A, value
            ADD reg
            MOV reg, A
        ENDM
        
        ORG $F000
        
        START:
            LDI B, #$10
            LOAD_AND_ADD B, #$05
            HLT
        """
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.asm', delete=False) as f:
            f.write(asm_content)
            f.flush()
            
            try:
                # Test full assembly process
                with tempfile.TemporaryDirectory() as output_dir:
                    assembler = Assembler(f.name, os.path.join(output_dir, "test.hex"), None)
                    assembler.assemble()
                    assembler.write_output_files()
                    
                    # Check output file was created
                    output_file = os.path.join(output_dir, "test.hex")
                    assert os.path.exists(output_file)
                    
                    # Basic check that content was written
                    with open(output_file, 'r') as out_f:
                        content = out_f.read()
                        assert len(content.strip()) > 0
                        
            finally:
                os.unlink(f.name)