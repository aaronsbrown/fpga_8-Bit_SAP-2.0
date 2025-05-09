
**Phase 1: Expanding Operand Types & Addressing (Still fairly linear code)**

1. **More `LDI` Variants & Immediate Values:**
    * Test `LDI A, #value`, `LDI C, #value`.
    * Use different immediate values: `#$FF`, `#%10101010`, `#128`.
    * Verify that `_parse_value_or_symbol` correctly handles the `#` prefix and different bases for these.
    * **Goal:** Confirm all `LDI_reg` variants work and immediate value parsing is robust.

2. **More Data Directives (`DB`, `DW`):**
    * Introduce `DW` (Define Word - 2 bytes).
        * `my_word: DW $1234` -> should produce `34 12` (little-endian).
        * `my_word2: DW some_label` -> where `some_label` is an address.
        * `my_word3: DW SOME_EQU_CONST` -> where `SOME_EQU_CONST` is a 16-bit value.
    * Mix `DB` and `DW` to ensure address calculation remains correct.
    * **Goal:** Test `DW` implementation, especially little-endian encoding and symbol resolution for `DW`.

3. **All Register-to-Register `MOV` Instructions:**
    * Systematically test all `MOV_XY` combinations (`MOV_AB`, `MOV_AC`, `MOV_BA`, `MOV_BC`, `MOV_CA`, `MOV_CB`).
    * **Goal:** Confirm all `MOV` opcodes are correct.

4. **All Single-Register ALU Ops (`INR`, `DCR`, `CMA`, `RAL`, `RAR`):**
    * Test `INR_A`, `DCR_A`, `CMA` (on A), `RAL` (on A), `RAR` (on A).
    * Test `INR_B`, `DCR_B`, `INR_C`, `DCR_C`.
    * **Goal:** Confirm opcodes for these 1-byte instructions.

5. **All Register-Pair ALU Ops (`ADD`, `ADC`, `SUB`, `SBC`, `ANA`, `ORA`, `XRA`, `CMP`):**
    * Test `ADD_B`, `ADD_C`.
    * Test `ADC_B`, `ADC_C` (you'll need to set/clear carry manually or conceptually for now if your CPU doesn't have explicit carry set instructions).
    * Test the `SUB`, `SBC`, `ANA`, `ORA`, `XRA`, `CMP` variants with registers B and C.
    * **Goal:** Confirm opcodes for these arithmetic/logical ops involving register A and another register.

6. **Immediate ALU Ops (`ANI`, `ORI`, `XRI`):**
    * These are already in `INSTRUCTION_SET` like `ANI` (opcode `0x32`, size 2) but your parser logic for `LDI A, #imm` was `full_mnem = f"{base}_{reg.upper()}"`.
    * You'll need to ensure your parser logic correctly creates `ANI` (implying register A) with the immediate operand, not `ANI_A`. Your `INSTRUCTION_SET` has `ANI`, `ORI`, `XRI` without `_A`.
        * `ANI #$F0` -> Mnemonic: `ANI`, Operand: `#$F0`
    * Test with different immediate values.
    * **Goal:** Confirm immediate ALU operations, ensuring parser handles them correctly if they differ slightly from `LDI` parsing. *(Self-correction: Your parser already handles `LDI A, #imm` -> `LDI_A`, so `ANI #imm` should become `ANI` with operand `#imm`. The `INSTRUCTION_SET` seems correct for this.)*

**Phase 2: Control Flow - Jumps and Branches**

7. **Unconditional Jump (`JMP`):**
    * `JMP forward_label`
    * `JMP backward_label`
    * `JMP an_equ_address` (where `an_equ_address EQU $F100`)
    * **Goal:** Test `JMP` with various label types and directions, verify little-endian address encoding.

8. **Conditional Jumps (`JZ`, `JNZ`, `JN`):**
    * These are harder to test in isolation without "running" the code to set flags, but you can test the assembler's encoding.
    * Include all: `JZ target`, `JNZ target`, `JN target`.
    * Use forward and backward labels.
    * **Goal:** Test encoding of all conditional jumps.

9. **Simple Loops:**

    * ```assembly

      loop:
          ; ... some code ...
          ; (conceptually decrement a counter in a register)
          JNZ loop  ; or JZ depending on logic

      ```

    * **Goal:** Test common branching patterns.

**Phase 3: More Complex Structures & Edge Cases**

10. **Labels and Comments:**
    * Test labels on lines by themselves: `mylabel:`
    * Test labels followed by comments: `mylabel: ; this is a label`
    * Test instructions with trailing comments.
    * Test lines with only comments.
    * Test blank lines.
    * **Goal:** Stress-test comment and whitespace handling in the parser.

11. **Forward References for Labels (if not already implicitly tested):**

    * ```assembly

      JMP later_defined_label
      ; ...
      later_defined_label: NOP

      ```

    * Your two-pass assembler should handle this naturally.
    * **Goal:** Explicitly confirm forward label resolution.

12. **Expression Evaluation (Future Enhancement, not in current code):**
    * (This is a bigger step) `DB label + 1` or `LDA array_base + offset_reg` (if your ISA supports indexed addressing).
    * For now, your assembler only handles simple symbols or literals.
    * **Goal (Future):** Test simple arithmetic in operands.

13. **Error Handling Tests:**
    * Create assembly files *designed* to fail:
        * Unknown mnemonic: `FOOBAR A, B`
        * Duplicate label: `label1: NOP \n label1: HLT`
        * Undefined symbol in operand: `LDA undefined_symbol`
        * Incorrect operand count/type for an instruction (if your parser gets sophisticated enough to check, otherwise this might be a runtime CPU error).
        * Malformed `EQU`: `MYVAL EQU` (missing value)
        * Malformed `ORG`: `ORG %AXBY` (bad binary)
        * `EQU` referencing an undefined symbol: `CONST1 EQU UNDEFINED_CONST` (if you decide to allow this, it needs careful pass ordering or restrictions).
    * **Goal:** Ensure your assembler produces clear and accurate error messages.

**General Tips for Test Programs:**

* **Keep them short and focused:** Each test program should ideally test one or a small group of related features.
* **Include comments:** Explain what the test program is trying to achieve and what the expected outcome is (even if just for your own reference).
* **Predict the output:** Before running the assembler, try to manually assemble the test program to predict the hex output. This is a great way to understand your ISA and assembler logic.
* **Use `ORG` to place code/data in different memory areas** to ensure it's not just working for address 0.

By following a progression like this, you'll systematically build out the capabilities of your assembler and gain confidence in its correctness. Start with Phase 1, item by item. Good luck!
