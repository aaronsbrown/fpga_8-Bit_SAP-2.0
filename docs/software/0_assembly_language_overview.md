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

## 5. Macro System

The assembler supports a comprehensive macro system for creating reusable blocks of assembly code with parameters and automatic local label management.

### 5.1 Macro Definition

**Syntax:** 
```assembly
MACRO <macro_name> [parameter1, parameter2, ...]
    ; macro body with assembly instructions
    ; can reference parameters and use local labels
ENDM
```

* **Macro Name:** Must be a valid identifier (alphanumeric and underscore, starting with letter or underscore).
* **Parameters:** Optional comma-separated list of parameter names for substitution.
* **Body:** Assembly instructions, directives, and comments that form the macro template.
* **ENDM:** Required directive to mark the end of the macro definition.

**Example:**
```assembly
MACRO LOAD_REG reg, value
    LDI reg, value
ENDM

MACRO DELAY_LOOP count
    LDI A, count
@@loop:
    DCR A
    JNZ @@loop
ENDM
```

### 5.2 Macro Invocation

**Syntax:** `<macro_name> [argument1, argument2, ...]`

* The number of arguments must match the number of parameters in the macro definition.
* Arguments are substituted for parameters throughout the macro body.
* Arguments can be registers, immediate values, labels, or expressions.

**Example:**
```assembly
; Invoke macros defined above
LOAD_REG A, #$42        ; Expands to: LDI A, #$42
LOAD_REG B, #MY_CONST   ; Expands to: LDI B, #MY_CONST
DELAY_LOOP #$10         ; Expands to delay loop with count $10
```

### 5.3 Local Labels in Macros

**Problem:** Regular labels in macros would conflict if the macro is invoked multiple times.

**Solution:** Use `@@label` syntax for macro-local labels that are automatically made unique.

* **Syntax:** `@@identifier` creates a local label within the macro.
* **Automatic Uniqueness:** Each macro expansion gets unique local labels to prevent conflicts.
* **Scope:** Local labels are only visible within the same macro expansion.

**Example:**
```assembly
MACRO COUNT_DOWN start_value
    LDI A, start_value
@@loop:                 ; This becomes unique label like __MACRO_1_loop
    DCR A
    JNZ @@loop          ; References the same unique label
@@done:                 ; Another unique label __MACRO_1_done
    HLT
ENDM

; Multiple invocations create separate unique labels
COUNT_DOWN #$05         ; Uses __MACRO_1_loop, __MACRO_1_done
COUNT_DOWN #$0A         ; Uses __MACRO_2_loop, __MACRO_2_done
```

### 5.4 Nested Macro Invocations

Macros can invoke other macros, enabling hierarchical code organization.

**Example:**
```assembly
MACRO CLEAR_REG reg
    LDI reg, #$00
ENDM

MACRO INIT_ALL_REGS
    CLEAR_REG A
    CLEAR_REG B  
    CLEAR_REG C
ENDM

INIT_ALL_REGS           ; Expands to three LDI instructions
```

### 5.5 Macros in Include Files

Macros can be defined in include files and used in the main assembly file:

**macros.inc:**
```assembly
MACRO SAVE_REGS
    PHA
    PHB  
    PHC
ENDM
```

**main.asm:**
```assembly
INCLUDE "macros.inc"

START:
    SAVE_REGS           ; Uses macro from included file
    ; ... other code
```

### 5.6 Macro Limitations and Guidelines

* **No Recursion:** A macro cannot invoke itself directly or indirectly.
* **Parameter Scope:** Parameters are simple text substitution; they don't have type checking.
* **Definition Order:** Macros must be defined before they are used (including in include files processed first).
* **Global Labels:** Regular global labels in macros create shared labels across all invocations.
* **Best Practices:**
  * Use `@@label` for all labels that should be local to each macro expansion
  * Use descriptive macro and parameter names
  * Keep macros focused on a single, well-defined task
  * Document complex macros with comments

**Error Handling:**
* **Unknown Macro:** Invoking an undefined macro generates an error.
* **Parameter Mismatch:** Wrong number of arguments generates an error.
* **Duplicate Definition:** Defining a macro twice generates an error.
* **Missing ENDM:** Macro definition without ENDM generates an error.

## 6. Conditional Assembly Directives

The assembler supports conditional assembly directives that allow code to be included or excluded based on whether symbols are defined. These directives support nesting and are useful for creating configurable library code and managing build variants.

* **`IFDEF <symbol_name>`** (If Defined)
  * Begins a conditional block that is assembled only if `<symbol_name>` has been previously defined (via a label or EQU directive).
  * Must be paired with a matching `ENDIF`.
  * Example:
    ```assembly
    DEBUG_MODE EQU 1
    IFDEF DEBUG_MODE
        ; This code will be assembled since DEBUG_MODE is defined
        LDI A, #$FF
        DB "Debug build"
    ENDIF
    ```

* **`IFNDEF <symbol_name>`** (If Not Defined)
  * Begins a conditional block that is assembled only if `<symbol_name>` has NOT been previously defined.
  * Must be paired with a matching `ENDIF`.
  * Example:
    ```assembly
    IFNDEF USER_CONFIG
        ; This code will be assembled only if USER_CONFIG is not defined
        USER_CONFIG EQU $10  ; Provide default value
    ENDIF
    ```

* **`ELSE`** (Conditional Else)
  * Used optionally within an `IFDEF` or `IFNDEF` block to specify code that should be assembled when the initial condition is false.
  * Can only appear once per conditional block.
  * Example:
    ```assembly
    IFDEF FAST_MODE
        LDI A, #$01    ; Fast configuration
    ELSE
        LDI A, #$10    ; Normal configuration
    ENDIF
    ```

* **`ENDIF`** (End Conditional)
  * Marks the end of an `IFDEF`, `IFNDEF`, or `ELSE` block.
  * Every `IFDEF` or `IFNDEF` must have a corresponding `ENDIF`.

* **Nesting Support:**
  * Conditional blocks can be nested to create complex conditional logic.
  * Each `IFDEF`/`IFNDEF` must be properly matched with its own `ENDIF`.
  * Example:
    ```assembly
    IFDEF UART_ENABLED
        LDI A, #UART_BASE
        IFDEF DEBUG_MODE
            ; Both UART_ENABLED and DEBUG_MODE are defined
            LDI B, #VERBOSE_LOGGING
        ELSE
            ; UART_ENABLED is defined but DEBUG_MODE is not
            LDI B, #NORMAL_LOGGING
        ENDIF
    ENDIF
    ```

* **Common Use Case - Library Defaults:**
  * Conditional assembly is particularly useful for providing default constants in library files while allowing users to override them:
  ```assembly
  ; In main program:
  USER_DELAY_TIME EQU $50  ; User override
  INCLUDE "delay_library.inc"
  
  ; In delay_library.inc:
  IFNDEF USER_DELAY_TIME
      USER_DELAY_TIME EQU $10  ; Default if not overridden
  ENDIF
  
  delay_routine:
      LDI A, #USER_DELAY_TIME  ; Uses $50 (user value) or $10 (default)
      ; ... delay implementation
  ```

* **Error Handling:**
  * Unmatched `IFDEF`/`IFNDEF` directives without corresponding `ENDIF` will result in assembly errors.
  * `ELSE` or `ENDIF` without a preceding `IFDEF`/`IFNDEF` will result in assembly errors.
  * Multiple `ELSE` blocks within the same conditional are not allowed.

## 7. Instruction Mnemonics and Operands

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
