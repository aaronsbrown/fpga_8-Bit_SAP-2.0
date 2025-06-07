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
  * **Global Labels:** Consist of alphanumeric characters and underscores (`_`), starting with a letter or underscore (e.g., `my_label:`, `loop_start:`, `DATA_VALUE_1:`). Global labels are case-sensitive.
  * **Local Labels:** Start with a dot (`.`) followed by alphanumeric characters and underscores (e.g., `.loop:`, `.data_handler:`). Local labels are scoped to the last defined global label. See "Local Labels" section for details.
  * A label can be on a line by itself, applying to the next instruction or data directive.

        ```assembly
        my_label_on_own_line:
                    NOP
        .local_label_on_own_line:
                    HLT
        ```

* **Mnemonic (Optional):**
  * The instruction name (e.g., `LDA`, `ADD`) or an assembler directive (e.g., `ORG`, `DB`).
  * Mnemonics are case-insensitive (the assembler typically converts them to uppercase internally).

* **Operand(s) (If required by mnemonic):**
  * Values, registers, addresses, symbols, or expressions that the mnemonic operates on.
  * If an instruction or directive takes multiple "parts" for its operand (e.g., `LDI reg, value`), these parts are separated by a comma (`,`). Whitespace around the comma is optional.
  * For the `MOV` instruction, the syntax is `MOV <SourceRegister>, <DestinationRegister>` (e.g., `MOV A, B` copies the content of register A to register B).
  * For the `DB` directive, multiple comma-separated byte values or string literals can be provided.

        ```assembly
        LDI A, #$10             ; Operands are A and expression #$10
        MOV A, B                ; Operands are A (source) and B (destination)
        DB  "HELLO", $0A, COUNT ; Operands are "HELLO", $0A, and COUNT
        ```

* **Comment (Optional):**
  * Anything following a semicolon (`;`) on a line is treated as a comment.

* **Blank Lines:** Ignored by the assembler.

## 2. Numeric Literals and Expressions

  Numeric values and expressions can be used as operands or with directives, with enhanced
   parsing capabilities for more complex expressions.

* Numeric Literals:
  * Decimal: 20, 100
  * Hexadecimal: Prefixed with $ (e.g., $F0, $12AB)
  * Binary: Prefixed with % (e.g., %10101010, %0011)
  * Character Literals: Single characters enclosed in single quotes, evaluated to their ASCII values
    * Basic characters: 'A' (65), 'a' (97), '0' (48), ' ' (32), '!' (33)
    * Escape sequences: '\n' (10), '\r' (13), '\t' (9), '\0' (0), '\\' (92), '\'' (39)
    * Example: `LDI A, #'H'` loads 72 (ASCII 'H') into register A
* Expressions and Operators:
  The assembler now supports more complex expressions with the following operators (in
  order of precedence, from highest to lowest):

    a. Parentheses ( ):
        - Used for grouping and controlling evaluation order
  * Example: #(UART_ENABLE | (UART_8_BITS & UART_PARITY_EVEN))
    b. Unary Operators:
    * Bitwise NOT ~: Inverts all bits of an expression
  * Example: #~$0F (bitwise complement of 0x0F)
    c. Shift Operators:
    * Left shift <<: Shifts bits to the left
  * Right shift >>: Shifts bits to the right
  * Example: #(MY_VALUE << 2), #(BITS >> 1)
    d. Bitwise Logical Operators:
    * AND &: Bitwise AND operation
  * XOR ^: Bitwise exclusive OR operation
  * OR |: Bitwise OR operation
  * Example: #(FLAG_A & FLAG_B), #(MASK_1 | MASK_2)
    e. Arithmetic Operators:
    * Addition +: Adds two values
  * Subtraction -: Subtracts one value from another
  * Example: #(BASE_ADDR + OFFSET), #(COUNTER - 1)
* Immediate Values:
  * For instructions taking immediate data (e.g., LDI, ANI), the value/expression must
  be prefixed with #.
  * Supports complex expressions with the operators mentioned above
  * Character literals can be used directly in expressions
  * Example:
    LDI A, #(UART_ENABLE | UART_8_BITS)  ; Bitwise OR of constants
  ANI #(~MASK)                         ; Bitwise NOT of a mask
  LDI B, #(CONFIG_REG << 2)            ; Left shift
  LDI A, #'A'                          ; Load ASCII value of 'A' (65)
  LDI B, #'A' + 1                      ; Load ASCII value of 'B' (66)
  ANI #'\n'                            ; AND with newline character (10)
* Parentheses and Precedence:
  * Parentheses can be used to control the order of evaluation
  * Nested parentheses are supported
  * Example:
    ; Complex expression with controlled precedence
  LDI A, #((STATUS_REG & ENABLE_BIT) | (STATUS_REG & READY_BIT))
* Existing Label Address Manipulation Techniques Remain:
  * LOW_BYTE(label_or_16bit_value)
  * HIGH_BYTE(label_or_16bit_value)
  * Label arithmetic: label_name + N, label_name - N

  Notes and Limitations:

* Expressions are evaluated left-to-right within the same precedence level
* All expressions must resolve to an 8-bit value (0-255)
* Complex expressions are fully evaluated during the assembler's second pass
* Floating-point and division operations are not supported

## 3. Symbols and Labels

* **Global Labels:** As described in section 1, these define a symbolic name for a memory address and are accessible throughout the entire assembly code, including all included files.
  * Example: `main_loop: JMP main_loop`

* **Local Labels:**
  * **Syntax:** Labels starting with a dot (`.`), e.g., `.loop`, `.error_handler`.
  * **Scope:** A local label is associated with the most recently defined global label that appeared before it in the source code (excluding labels for `EQU` directives). This means the same local label name (e.g., `.loop`) can be reused under different global labels without conflict.
  * **Resolution:** When a local label is referenced (e.g., `JNZ .loop`), the assembler resolves it to the instance of `.loop` that falls under the current global label's scope.
  * Example:

        ```assembly
        FIRST_ROUTINE:
            LDI A, #5
        .loop:      ; This is FIRST_ROUTINE.loop
            DCR A
            JNZ .loop ; Jumps to FIRST_ROUTINE.loop
            RET

        SECOND_ROUTINE:
            LDI B, #10
        .loop:      ; This is SECOND_ROUTINE.loop
            DCR B
            JNZ .loop ; Jumps to SECOND_ROUTINE.loop
            RET
        ```

  * A local label must be defined after at least one global label (not an `EQU` label) has been established in the current file or an included file processed up to that point.

* **EQU Constants:** Constants defined with `EQU` also create symbols representing fixed numeric values.

* **Symbol Usage:** Symbols (global labels, local labels, `EQU` constants) and expressions involving them can be used wherever a numeric value is expected, respecting context (e.g., 8-bit or 16-bit values).

## 4. Assembler Directives

* **`ORG <address_expression>` (Originate)**
  * Sets the current assembly address to the result of `<address_expression>`.
  * `<address_expression>` can be a numeric literal, symbol, or an address arithmetic expression.
  * Range: `0x0000` to `0xFFFF`.
  * Example: `ORG ROM_START + $100`

* **`<label>: EQU <value_expression>` (Equate)**
  * Assigns the result of constant numeric `<value_expression>` to `<label>`. The label becomes a symbolic constant.
  * **Parser Limitation:** During the parser's first pass, `<value_expression>` must resolve to a simple numeric literal (decimal, `$hex`, `%bin`) or a symbol whose value is already numerically defined (e.g., another `EQU` that resolved to a number, or an address label). The parser does not evaluate complex expressions like `LOW_BYTE(...)` or arithmetic directly as the value for an `EQU` at definition time.
  * However, once an `EQU` symbol is defined with a numeric value, that symbol can then be freely used in more complex expressions as an operand for instructions or other directives (like `DB`, `DW`, `ORG`), where the assembler's second pass will perform the full expression evaluation.
  * Example:

        ```assembly
        SCREEN_WIDTH: EQU 80
        MAX_RETRIES:  EQU 5
        LED_PORT_ADDR:EQU $E000
        CODE_START:   EQU main_program_label ; Assigns address of main_program_label (if main_program_label is already known)
        
        ; Valid usage in operands:
        ; LDI A, #LOW_BYTE(LED_PORT_ADDR)
        ; DB SCREEN_WIDTH / 2 ; This expression would be evaluated by the assembler.
        ```

* **`DB <item1> [, <item2>, ...]` (Define Byte)**
  * Allocates one or more bytes of memory, initialized with the specified 8-bit values.
  * Operands can be:
    * Numeric literals or expressions resolving to an 8-bit value (0-255).
    * Character literals (e.g., `'A'`, `'\n'`) for individual characters.
    * Double-quoted string literals (e.g., `"HELLO"`). Each character in the string is converted to its 8-bit ASCII equivalent and emitted sequentially.
      * **String Escape Sequences:** The following escape sequences are supported within string literals:
        * `\n` - Newline (ASCII 10)
        * `\t` - Tab (ASCII 9)
        * `\r` - Carriage return (ASCII 13)
        * `\0` - Null terminator (ASCII 0)
        * `\\` - Literal backslash (ASCII 92)
        * `\"` - Literal double quote (ASCII 34)
        * `\xHH` - Hexadecimal escape sequence where HH are two hex digits (e.g., `\x41` for 'A', `\x0A` for newline)
  * Example:

        ```assembly
        message:    DB "Hello, world!\n", 0    ; String with newline and null terminator
        prompt:     DB "Enter value: \x22", 0  ; String with embedded quote character
        byte_data:  DB $01, MY_CONST, COUNT + 2, %11000011
        char_data:  DB 'H', 'e', 'l', 'l', 'o', '\0'  ; Individual character literals
        mixed:      DB 'A', $20, "BC", '\n'   ; Mix of character literals, numbers, and strings
        empty_str:  DB ""                      ; Emits zero bytes
        greeting:   DB "Say \"Hello\"\n"       ; Demonstrates quote escaping
        control:    DB "Line1\nLine2\tTabbed\x00" ; Mixed escape sequences
        ```

* **`DW <value_expression>` (Define Word)**
  * Allocates two bytes of memory, initialized with the 16-bit `<value_expression>`.
  * Stored in **little-endian** format (low byte at lower address, high byte at next).
  * `<value_expression>` must resolve to a 16-bit number (0-65535).
  * **Limitation:** Only one value per `DW` directive is currently supported. For multiple words, use multiple `DW` lines.
  * Example:

        ```assembly
        address_pointer: DW TARGET_LABEL
        config_word:     DW $1234          ; Stores $34 then $12
        table_entry:     DW DATA_START + OFFSET
        ```

* **`INCLUDE "<filename>"` (Include File)**
  * Includes and assembles the content of another assembly file at the current location.
  * `<filename>` is a string, typically relative to the directory of the current file.
  * Included files inherit the current address and global label scope from the point of inclusion.
  * Example: `INCLUDE "macros.asm"`

## 5. Instruction Mnemonics and Operands

This section provides a general overview. For the complete list of supported CPU instructions, their opcodes, byte sizes, and precise operand requirements, refer to the **`docs/0_ISA.md`** document. Operands can be complex expressions as described in Section 2.

**Common Operand Patterns:**

* **Zero-Operand Instructions:** These instructions require no operands.
  * Examples: `NOP`, `HLT`, `CMA` (complements accumulator A), `RAL` (rotate A left), `RAR` (rotate A right)

* **Single Register Operand (operating on that register or using Accumulator A as implicit second operand):**
  * Examples:
    * `INR reg` (Increment register: `A`, `B`, or `C`)
    * `DCR reg` (Decrement register: `A`, `B`, or `C`)
    * `ADD reg` (Add register `B` or `C` to Accumulator `A`)
  * Syntax: `ADD B`, `INR A`, `CMP C`

* **Immediate Operand (Accumulator `A` is implied destination/source):**
  * The operand is an 8-bit immediate value or expression, prefixed with `#`.
  * Can include character literals with their ASCII values.
  * Examples: `ANI #value`, `ORI #value`, `XRI #value`
  * Syntax: `ANI #$F0`, `ORI #%00001111`, `XRI #(CONST_A | CONST_B)`, `ANI #'A'`, `ORI #'\n'`

* **Register and Immediate Operand:**
  * The first operand is a destination register (`A`, `B`, or `C`), and the second is an 8-bit immediate value or expression prefixed with `#`.
  * Character literals can be used for readable character loading.
  * Example: `LDI reg, #expression`
  * Syntax: `LDI A, #$10`, `LDI B, #MY_INIT_VALUE`, `LDI C, #LOW_BYTE(TABLE_START)`, `LDI A, #'H'`, `LDI B, #'A' + 1`

* **Register and Register Operand (MOV):**
  * Syntax: `MOV <source_register>, <destination_register>`
  * The first operand is the source register, the second is the destination register. Both can be `A`, `B`, or `C`.
  * Example: `MOV A, B` (Copies content of register A to register B; `B = A`)
  * Example: `MOV C, A` (Copies content of register C to register A; `A = C`)

* **16-bit Address Operand:**
  * The operand is a 16-bit memory address or an expression resolving to one.
  * Examples: `LDA address_expression`, `STA address_expression`, `JMP address_expression`
  * Syntax: `LDA my_data_location`, `JMP main_loop`, `STA $E000 + OFFSET`

---
