# Assembly Language Syntax and Directives

This document outlines the syntax conventions and assembler directives supported by the custom Python assembler for the 8-bit CPU project.

## 1. General Line Structure

An assembly language line generally follows this structure:

`[label:] [mnemonic [operand(s)]] [;comment]`

Each part is optional, but certain combinations are required (e.g., a mnemonic often requires operands).

* **Label (Optional):**
  * A symbolic name for the memory address of the current line.
  * Must start in the first column or after leading whitespace.
  * Must end with a colon (`:`).
  * Consists of alphanumeric characters and underscores (`_`), starting with a letter or underscore (e.g., `my_label:`, `loop_start:`, `DATA_VALUE_1:`).
  * Labels are case-sensitive.
  * A label can be on a line by itself, applying to the next instruction or data directive.

        ```assembly
        my_label_on_own_line:
                    NOP
        ```

* **Mnemonic (Optional):**
  * The instruction name (e.g., `LDA`, `ADD`) or an assembler directive (e.g., `ORG`, `DB`).
  * Mnemonics are case-insensitive (the assembler typically converts them to uppercase internally).

        ```assembly
        start:      LDA data_value  ; LDA is the mnemonic
                    ORG $F000       ; ORG is the mnemonic (a directive)
        ```

* **Operand(s) (If required by mnemonic):**
  * Values, registers, addresses, or symbols that the mnemonic operates on.
  * If an instruction or directive takes multiple "parts" for its operand (e.g., `LDI reg, value` or `MOV dest, src`), these parts are separated by a comma (`,`). Whitespace around the comma is optional.

        ```assembly
        LDI A, #$10     ; Operands are A and #$10
        MOV B, C        ; Operands are B and C
        ADD B           ; Operand is B
        DB  MY_VALUE    ; Operand is MY_VALUE
        ```

* **Comment (Optional):**
  * Anything following a semicolon (`;`) on a line is treated as a comment and ignored by the assembler.
  * A line can also be entirely a comment if it starts with a semicolon (after optional leading whitespace).

        ```assembly
        LDA value   ; This is a trailing comment
        ; This entire line is a comment
        ```

* **Blank Lines:**
  * Lines containing only whitespace are ignored by the assembler.

## 2. Numeric Literals

Numeric values provided as operands or to directives can be expressed in several bases:

* **Decimal:** Standard base-10 numbers.
  * Example: `LDI A, #20`, `EQU 100`
* **Hexadecimal:** Prefixed with a dollar sign (`$`). Case-insensitive for hex digits A-F.
  * Example: `LDI B, #$F0`, `ORG $F000`, `DB $0A`
* **Binary:** Prefixed with a percent sign (`%`).
  * Example: `XRI #%10101010`, `DB %00001111`

**Immediate Values:**
For instructions that take an immediate data value as an operand (e.g., `LDI`, `ANI`, `ORI`, `XRI`), the value should be prefixed with a hash symbol (`#`). The `#` indicates that the following value is to be used directly, not as a memory address.

* Example: `LDI A, #$C0`, `ANI #128`, `ORI #MY_CONSTANT`

## 3. Symbols and Labels

* **Labels:** As described in section 1, labels define a symbolic name for a memory address. The assembler calculates and assigns the actual address during its first pass.
  * Example: `main_loop: JMP main_loop` (Here, `main_loop` is a label representing an address).

* **EQU Constants:** Constants defined with the `EQU` directive (see below) also create symbols. These symbols represent fixed numeric values, not necessarily memory addresses (though they can hold address values).

* **Symbol Usage:** Symbols (whether labels or `EQU` constants) can generally be used wherever a numeric value is expected in an operand field.
  * For addresses (e.g., in `LDA`, `STA`, `JMP`): `LDA my_variable`, `JMP target_label`
  * For data values (e.g., in `DB`, `DW`): `DB CONST_VALUE`
  * For immediate values (must be prefixed with `#`): `LDI A, #MY_IMMEDIATE_CONST`

## 4. Assembler Directives

Assembler directives instruct the assembler to perform certain actions during the assembly process. They do not typically translate directly into machine code instructions executed by the CPU.

* **`ORG <address>` (Originate)**
  * Sets the current assembly address (location counter) to `<address>`. Subsequent instructions or data will be placed starting at this address.
  * `<address>` can be a numeric literal (decimal, `$hex`, `%bin`) or a pre-defined `EQU` symbol representing an address.
  * Range: `0x0000` to `0xFFFF`.
  * Example:

        ```assembly
        ROM_START EQU $F000
                    ORG ROM_START
        ```

* **`<label>: EQU <value>` (Equate)**
  * Assigns the constant numeric `<value>` to `<label>`. The label becomes a symbolic constant.
  * `<value>` can be a numeric literal or the value of another symbol that has already been defined (either another `EQU` or a label representing an address).
  * Example:

        ```assembly
        SCREEN_WIDTH: EQU 80
        MAX_RETRIES:  EQU 5
        LED_PORT_ADDR:EQU $E000
        CODE_START:   EQU main_program_label ; Assigns address of main_program_label
        ```

* **`DB <value>` (Define Byte)**
  * Allocates one byte of memory and initializes it with `<value>`.
  * `<value>` must resolve to an 8-bit number (0 to 255, or 0x00 to 0xFF). It can be a numeric literal or an 8-bit `EQU` symbol/label.
  * **Limitation:** Only one value per `DB` directive is currently supported. For multiple bytes, use multiple `DB` lines.
  * Example:

        ```assembly
        my_byte:    DB $41          ; Stores ASCII 'A'
        count:      DB 10
        flags:      DB %00001001
        ```

* **`DW <value>` (Define Word)**
  * Allocates two bytes of memory and initializes them with the 16-bit `<value>`.
  * The value is stored in **little-endian** format (the low byte is stored at the lower address, and the high byte at the next higher address).
  * `<value>` must resolve to a 16-bit number (0 to 65535, or 0x0000 to 0xFFFF). It can be a numeric literal or a 16-bit `EQU` symbol/label (often used for storing addresses).
  * **Limitation:** Only one value per `DW` directive is currently supported.
  * Example:

        ```assembly
        word_value: DW $1234        ; Stores $34 at word_value, $12 at word_value+1
        jump_table: DW routine1_addr  ; Stores the 16-bit address of routine1_addr
        ```

## 5. Instruction Mnemonics and Operands

This section provides a general overview. For the complete list of supported CPU instructions, their opcodes, byte sizes, and precise operand requirements, refer to the **`docs/0_ISA.md`** document.

**Common Operand Patterns:**

* **Zero-Operand Instructions:** These instructions require no operands.
  * Examples: `NOP`, `HLT`, `CMA` (complements accumulator A), `RAL` (rotate A left), `RAR` (rotate A right)

* **Single Register Operand (operating on that register or using Accumulator A as implicit second operand):**
  * Examples:
    * `INR reg` (Increment register: `A`, `B`, or `C`)
    * `DCR reg` (Decrement register: `A`, `B`, or `C`)
    * `ADD reg` (Add register `B` or `C` to Accumulator `A`)
    * `SUB reg` (Subtract register `B` or `C` from `A`)
    * `ADC reg`, `SBC reg`, `ANA reg`, `ORA reg`, `XRA reg`, `CMP reg` (all operate with `A` and register `B` or `C`)
  * Syntax: `ADD B`, `INR A`, `CMP C`

* **Immediate Operand (Accumulator `A` is implied destination/source):**
  * The operand is an 8-bit immediate value, prefixed with `#`.
  * Examples: `ANI #value`, `ORI #value`, `XRI #value`
  * Syntax: `ANI #$F0`, `ORI #%00001111`

* **Register and Immediate Operand:**
  * The first operand is a destination register (`A`, `B`, or `C`), and the second is an 8-bit immediate value prefixed with `#`.
  * Example: `LDI reg, #value`
  * Syntax: `LDI A, #$10`, `LDI B, #MY_INIT_VALUE`

* **Register and Register Operand:**
  * The first operand is the destination register, the second is the source register. Both can be `A`, `B`, or `C`.
  * Example: `MOV dest_reg, src_reg`
  * Syntax: `MOV A, B`, `MOV C, A`

* **16-bit Address Operand:**
  * The operand is a 16-bit memory address (can be a numeric literal, a label, or an `EQU` constant representing an address).
  * Examples: `LDA address`, `STA address`, `JMP address`, `JZ address`, `JNZ address`, `JN address`
  * Syntax: `LDA my_data_location`, `JMP main_loop`, `STA $E000`

---
