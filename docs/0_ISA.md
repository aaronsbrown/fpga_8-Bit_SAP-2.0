# Instruction Set Architecture (ISA)

This table defines the initial instruction set for the custom 8-bit CPU, organized by opcode groups. Flags column indicates effect on Zero, Negative, Carry (ZNC). (Instructions marked 'X' are implemented and tested).

| OPCODE (Hex) | Mnemonic | Operand Type | Addr Mode | Bytes | Zero (Z) | Negative (N) | Carry (C)  | Notes / Status                             |
| :----------- | :------- | :----------- | :-------- | :---- | :------- | :----------- | :--------- | :----------------------------------------- |
| **Control / Basic Flow** |          |              |           |       |          |              |            |                                            |
| `$00`        | `NOP`    |              | Implied   | 1     | `-`      | `-`          | `-`        | No operation (Implemented)                 |
| `$01`        | `HLT`    |              | Implied   | 1     | `-`      | `-`          | `-`        | Halt processor (X - Implemented)           |
| _($02-$0F)_  |          |              |           |       |          |              |            | _Reserved_                                 |
| **Branching** |          |              |           |       |          |              |            |                                            |
| `$10`        | `JMP`    | address      | Immediate | 3     | `-`      | `-`          | `-`        | Jump to 16-bit address (X - Implemented)   |
| `$11`        | `JZ`     | address      | Immediate | 3     | `-`      | `-`          | `-`        | Jump if Z=1 (X - Implemented)              |
| `$12`        | `JNZ`    | address      | Immediate | 3     | `-`      | `-`          | `-`        | Jump if Z=0 (X - Implemented)              |
| `$13`        | `JN`     | address      | Immediate | 3     | `-`      | `-`          | `-`        | Jump if N=1 (X - Implemented)              |
| _($14-$17)_  |          |              |           |       |          |              |            | _Reserved for JC, JNC, etc._             |
| **Subroutines** |        |              |           |       |          |              |            |                                            |
| `$18`        | `CALL`   | address      | Immediate | 3     | `-`      | `-`          | `-`        | Call subroutine (Requires Stack)           |
| `$19`        | `RET`    |              | Implied   | 1     | `-`      | `-`          | `-`        | Return from subroutine (Requires Stack)      |
| _($1A-$1F)_  |          |              |           |       |          |              |            | _Reserved for Stack Ops (PHA/PLA etc.)_    |
| **Register A Arithmetic** | |            |           |       |          |              |            |                                            |
| `$20`        | `ADD B`  |              | Register  | 1     | `+/-`    | `+/-`        | `=`        | A = A + B (X - Implemented)                |
| `$21`        | `ADD C`  |              | Register  | 1     | `+/-`    | `+/-`        | `=`        | A = A + C (X - Implemented)                |
| `$22`        | `ADC B`  |              | Register  | 1     | `+/-`    | `+/-`        | `=`        | A = A + B + Carry (X - Implemented)        |
| `$23`        | `ADC C`  |              | Register  | 1     | `+/-`    | `+/-`        | `=`        | A = A + C + Carry (X - Implemented)        |
| `$24`        | `SUB B`  |              | Register  | 1     | `+/-`    | `+/-`        | `=`        | A = A - B (C=NOT Borrow) (X - Implemented) |
| `$25`        | `SUB C`  |              | Register  | 1     | `+/-`    | `+/-`        | `=`        | A = A - C (C=NOT Borrow) (X - Implemented) |
| `$26`        | `SBC B`  |              | Register  | 1     | `+/-`    | `+/-`        | `=`        | A = A - B - Borrow (X - Implemented)       |
| `$27`        | `SBC C`  |              | Register  | 1     | `+/-`    | `+/-`        | `=`        | A = A - C - Borrow (X - Implemented)       |
| `$28`        | `INR A`  |              | Register  | 1     | `+/-`    | `+/-`        | `-`        | A = A + 1, C Unaffected (X - Implemented)  |
| `$29`        | `DCR A`  |              | Register  | 1     | `+/-`    | `+/-`        | `-`        | A = A - 1, C Unaffected (X - Implemented)  |
| _($2A-$2F)_  |          |              |           |       |          |              |            | _Reserved for Imm/Mem Arith_               |
| **Register A Logic** |   |              |           |       |          |              |            |                                            |
| `$30`        | `ANA B`  |              | Register  | 1     | `+/-`    | `+/-`        | `0`        | A = A & B, Clear C                         |
| `$31`        | `ANA C`  |              | Register  | 1     | `+/-`    | `+/-`        | `0`        | A = A & C, Clear C                         |
| `$32`        | `ANI`    | byte         | Immediate | 2     | `+/-`    | `+/-`        | `0`        | A = A & immediate, Clear C                 |
| _($33)_      |          |              |           |       |          |              |            | _Reserved_                                 |
| `$34`        | `ORA B`  |              | Register  | 1     | `+/-`    | `+/-`        | `0`        | A = A \| B, Clear C                        |
| `$35`        | `ORA C`  |              | Register  | 1     | `+/-`    | `+/-`        | `0`        | A = A \| C, Clear C                        |
| `$36`        | `ORI`    | byte         | Immediate | 2     | `+/-`    | `+/-`        | `0`        | A = A \| immediate, Clear C                |
| _($37)_      |          |              |           |       |          |              |            | _Reserved_                                 |
| `$38`        | `XRA B`  |              | Register  | 1     | `+/-`    | `+/-`        | `0`        | A = A ^ B, Clear C                         |
| `$39`        | `XRA C`  |              | Register  | 1     | `+/-`    | `+/-`        | `0`        | A = A ^ C, Clear C                         |
| `$3A`        | `XRI`    | byte         | Immediate | 2     | `+/-`    | `+/-`        | `0`        | A = A ^ immediate, Clear C                 |
| _($3B)_      |          |              |           |       |          |              |            | _Reserved_                                 |
| `$3C`        | `CMP B`  |              | Register  | 1     | `+/-`    | `+/-`        | `=`        | Compare A with B (A-B), sets flags         |
| `$3D`        | `CMP C`  |              | Register  | 1     | `+/-`    | `+/-`        | `=`        | Compare A with C (A-C), sets flags         |
| _($3E-$3F)_  |          |              |           |       |          |              |            | _Reserved for CPI/CMP Abs_                 |
| **Register A Misc / Rotate** | |        |           |       |          |              |            |                                            |
| `$40`        | `RAL`    |              | Implied   | 1     | `+/-`    | `+/-`        | `=`        | Rotate A Left through Carry                |
| `$41`        | `RAR`    |              | Implied   | 1     | `+/-`    | `+/-`        | `=`        | Rotate A Right through Carry               |
| `$42`        | `CMA`    |              | Implied   | 1     | `-`      | `-`          | `-`        | Complement A (A=~A), Flags Unaffected    |
| _($43-$4F)_  |          |              |           |       |          |              |            | _Reserved_                                 |
| **Register B/C Operations** | |        |           |       |          |              |            |                                            |
| `$50`        | `INR B`  |              | Register  | 1     | `+/-`    | `+/-`        | `-`        | B = B + 1, C Unaffected                    |
| `$51`        | `DCR B`  |              | Register  | 1     | `+/-`    | `+/-`        | `-`        | B = B - 1, C Unaffected                    |
| _($52-$53)_  |          |              |           |       |          |              |            | _Reserved_                                 |
| `$54`        | `INR C`  |              | Register  | 1     | `+/-`    | `+/-`        | `-`        | C = C + 1, C Unaffected                    |
| `$55`        | `DCR C`  |              | Register  | 1     | `+/-`    | `+/-`        | `-`        | C = C - 1, C Unaffected                    |
| _($56-$5F)_  |          |              |           |       |          |              |            | _Reserved_                                 |
| **Register Moves** |     |              |           |       |          |              |            |                                            |
| `$60`        | `MOV A,B`|              | Register  | 1     | `-`      | `-`          | `-`        | Move B to A (A = B)                        |
| `$61`        | `MOV A,C`|              | Register  | 1     | `-`      | `-`          | `-`        | Move C to A (A = C)                        |
| `$62`        | `MOV B,A`|              | Register  | 1     | `-`      | `-`          | `-`        | Move A to B (B = A)                        |
| `$63`        | `MOV B,C`|              | Register  | 1     | `-`      | `-`          | `-`        | Move C to B (B = C)                        |
| `$64`        | `MOV C,A`|              | Register  | 1     | `-`      | `-`          | `-`        | Move A to C (C = A)                        |
| `$65`        | `MOV C,B`|              | Register  | 1     | `-`      | `-`          | `-`        | Move B to C (C = B)                        |
| _($66-$9F)_  |          |              |           |       |          |              |            | _Reserved for Stack, Index Regs, etc._     |
| **Memory Load/Store (Absolute)** | |    |           |       |          |              |            |                                            |
| `$A0`        | `LDA`    | address      | Absolute  | 3     | `+/-`    | `+/-`        | `0`        | Load A from Memory, Clear C (X - Impl.)    |
| `$A1`        | `STA`    | address      | Absolute  | 3     | `-`      | `-`          | `-`        | Store A to Memory                          |
| _($A2-$AF)_  |          |              |           |       |          |              |            | _Reserved for ZP, Indexed Load/Store_      |
| **Immediate Loads** |    |              |           |       |          |              |            |                                            |
| `$B0`        | `LDI A`  | byte         | Immediate | 2     | `+/-`    | `+/-`        | `0`        | Load A with Immediate, Clear C (X - Impl.) |
| `$B1`        | `LDI B`  | byte         | Immediate | 2     | `+/-`    | `+/-`        | `0`        | Load B with Immediate, Clear C (X - Impl.) |
| `$B2`        | `LDI C`  | byte         | Immediate | 2     | `+/-`    | `+/-`        | `0`        | Load C with Immediate, Clear C (X - Impl.) |
| _($B3-$FF)_  |          |              |           |       |          |              |            | _Reserved_                                 |

**Legend (Flags Columns):**

* `+/-`: Flag is set (1) or cleared (0) based on the operation's result value.
* `0` / `1`: Flag is explicitly cleared to 0 or set to 1.
* `=`: Flag is set based on the ALU's natural carry/borrow output for that operation.
* `-`: Flag value is not affected by the instruction.
