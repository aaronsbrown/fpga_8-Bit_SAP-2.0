# Instruction Set Architecture (ISA) v0.3

This table defines the instruction set for the custom 8-bit CPU.

**Legend (Flags Columns Z, N, C):**

* `+/-`: Flag is set (1) or cleared (0) based on the operation's result value.
* `0` / `1`: Flag is explicitly cleared to 0 or set to 1 by the instruction.
* `=` : Flag is set based on the ALU's natural carry/borrow or rotate output.
* `-` : Flag value is not affected by the instruction.
* `*` : All flags are restored from the stack for PLP.

| Category             | OPCODE (Hex) | Mnemonic | Operand Type | Addr Mode | Bytes | Z   | N   | C   | Notes                                                                                   |
| :------------------- | :----------- | :------- | :----------- | :-------- | :---- | :-- | :-- | :-- | :-------------------------------------------------------------------------------------- |
| **CONTROL / FLOW**   |              |          |              |           |       |     |     |     |                                                                                         |
|                      | `$00`        | `NOP`    |              | Implied   | 1     | `-` | `-` | `-` | No operation                                                                            |
|                      | `$01`        | `HLT`    |              | Implied   | 1     | `-` | `-` | `-` | Halt processor                                                                          |
| **BRANCHING**        |              |          |              |           |       |     |     |     |                                                                                         |
|                      | `$10`        | `JMP`    | address      | Immediate | 3     | `-` | `-` | `-` | Jump to 16-bit address                                                                  |
|                      | `$11`        | `JZ`     | address      | Immediate | 3     | `-` | `-` | `-` | Jump if Zero (Z=1)                                                                      |
|                      | `$12`        | `JNZ`    | address      | Immediate | 3     | `-` | `-` | `-` | Jump if not Zero (Z=0)                                                                  |
|                      | `$13`        | `JN`     | address      | Immediate | 3     | `-` | `-` | `-` | Jump if Negative (N=1)                                                                  |
|                      | `$14`        | `JNN`    | address      | Immediate | 3     | `-` | `-` | `-` | Jump if not Negative (N=0)                                                              |
|                      | `$15`        | `JC`     | address      | Immediate | 3     | `-` | `-` | `-` | Jump if Carry (C=1)                                                                     |
|                      | `$16`        | `JNC`    | address      | Immediate | 3     | `-` | `-` | `-` | Jump if not Carry (C=0)                                                                 |
| **SUBROUTINES**      |              |          |              |           |       |     |     |     |                                                                                         |
|                      | `$18`        | `JSR`    | address      | Immediate | 3     | `-` | `-` | `-` | Call subroutine at 16-bit address                                                       |
|                      | `$19`        | `RET`    |              | Implied   | 1     | `-` | `-` | `-` | Return from subroutine                                                                  |
| **REG_A ARITHMETIC** |              |          |              |           |       |     |     |     |                                                                                         |
|                      | `$20`        | `ADD B`  |              | Register  | 1     | `+/-` | `+/-` | `=` | A = A + B                                                                               |
|                      | `$21`        | `ADD C`  |              | Register  | 1     | `+/-` | `+/-` | `=` | A = A + C                                                                               |
|                      | `$22`        | `ADC B`  |              | Register  | 1     | `+/-` | `+/-` | `=` | A = A + B + Carry                                                                       |
|                      | `$23`        | `ADC C`  |              | Register  | 1     | `+/-` | `+/-` | `=` | A = A + C + Carry                                                                       |
|                      | `$24`        | `SUB B`  |              | Register  | 1     | `+/-` | `+/-` | `=` | A = A - B (C=1 if no borrow, C=0 if borrow)                                             |
|                      | `$25`        | `SUB C`  |              | Register  | 1     | `+/-` | `+/-` | `=` | A = A - C (C=1 if no borrow, C=0 if borrow)                                             |
|                      | `$26`        | `SBC B`  |              | Register  | 1     | `+/-` | `+/-` | `=` | A = A - B - ~Carry (Borrow = ~Carry)                                                     |
|                      | `$27`        | `SBC C`  |              | Register  | 1     | `+/-` | `+/-` | `=` | A = A - C - ~Carry (Borrow = ~Carry)                                                     |
|                      | `$28`        | `INR A`  |              | Register  | 1     | `+/-` | `+/-` | `-` | Increment A (A=A+1), C unaffected                                                       |
|                      | `$29`        | `DCR A`  |              | Register  | 1     | `+/-` | `+/-` | `-` | Decrement A (A=A-1), C unaffected                                                       |
| **REG_A LOGIC**      |              |          |              |           |       |     |     |     |                                                                                         |
|                      | `$30`        | `ANA B`  |              | Register  | 1     | `+/-` | `+/-` | `0` | A = A & B, Clears C                                                                     |
|                      | `$31`        | `ANA C`  |              | Register  | 1     | `+/-` | `+/-` | `0` | A = A & C, Clears C                                                                     |
|                      | `$32`        | `ANI`    | byte         | Immediate | 2     | `+/-` | `+/-` | `0` | A = A & immediate, Clears C                                                             |
|                      | `$34`        | `ORA B`  |              | Register  | 1     | `+/-` | `+/-` | `0` | A = A \| B, Clears C                                                                    |
|                      | `$35`        | `ORA C`  |              | Register  | 1     | `+/-` | `+/-` | `0` | A = A \| C, Clears C                                                                    |
|                      | `$36`        | `ORI`    | byte         | Immediate | 2     | `+/-` | `+/-` | `0` | A = A \| immediate, Clears C                                                            |
|                      | `$38`        | `XRA B`  |              | Register  | 1     | `+/-` | `+/-` | `0` | A = A ^ B, Clears C                                                                     |
|                      | `$39`        | `XRA C`  |              | Register  | 1     | `+/-` | `+/-` | `0` | A = A ^ C, Clears C                                                                     |
|                      | `$3A`        | `XRI`    | byte         | Immediate | 2     | `+/-` | `+/-` | `0` | A = A ^ immediate, Clears C                                                             |
|                      | `$3C`        | `CMP B`  |              | Register  | 1     | `+/-` | `+/-` | `=` | Compare A with B (A-B), sets flags                                                      |
|                      | `$3D`        | `CMP C`  |              | Register  | 1     | `+/-` | `+/-` | `=` | Compare A with C (A-C), sets flags                                                      |
| **REG_A MISC/ROT**   |              |          |              |           |       |     |     |     |                                                                                         |
|                      | `$40`        | `RAL`    |              | Implied   | 1     | `+/-` | `+/-` | `=` | Rotate A Left through Carry. Sets Z,N from result.                                      |
|                      | `$41`        | `RAR`    |              | Implied   | 1     | `+/-` | `+/-` | `=` | Rotate A Right through Carry. Sets Z,N from result.                                     |
|                      | `$42`        | `CMA`    |              | Implied   | 1     | `+/-` | `+/-` | `0` | Complement A (A=~A). Sets Z,N. Clears C (as per current ALU_INV).                     |
| **REG_B / REG_C**    |              |          |              |           |       |     |     |     |                                                                                         |
|                      | `$50`        | `INR B`  |              | Register  | 1     | `+/-` | `+/-` | `-` | Increment B (B=B+1), C unaffected                                                       |
|                      | `$51`        | `DCR B`  |              | Register  | 1     | `+/-` | `+/-` | `-` | Decrement B (B=B-1), C unaffected                                                       |
|                      | `$54`        | `INR C`  |              | Register  | 1     | `+/-` | `+/-` | `-` | Increment C (C=C+1), C unaffected                                                       |
|                      | `$55`        | `DCR C`  |              | Register  | 1     | `+/-` | `+/-` | `-` | Decrement C (C=C-1), C unaffected (Note: Spreadsheet said Z/N only, C typically unaffected) |
| **REGISTER MOVES**   |              |          |              |           |       |     |     |     | (Convention: MOV Source, Destination => Destination = Source)                             |
|                      | `$60`        | `MOV A,B`|              | Register  | 1     | `-` | `-` | `-` | Move A to B (`B = A`)                                                                     |
|                      | `$61`        | `MOV A,C`|              | Register  | 1     | `-` | `-` | `-` | Move A to C (`C = A`)                                                                     |
|                      | `$62`        | `MOV B,A`|              | Register  | 1     | `-` | `-` | `-` | Move B to A (`A = B`)                                                                     |
|                      | `$63`        | `MOV B,C`|              | Register  | 1     | `-` | `-` | `-` | Move B to C (`C = B`)                                                                     |
|                      | `$64`        | `MOV C,A`|              | Register  | 1     | `-` | `-` | `-` | Move C to A (`A = C`)                                                                     |
|                      | `$65`        | `MOV C,B`|              | Register  | 1     | `-` | `-` | `-` | Move C to B (`B = C`)                                                                     |
| **STATUS REG CONTROL**|             |          |              |           |       |     |     |     |                                                                                         |
|                      | `$70`        | `SEC`    |              | Implied   | 1     | `-` | `-` | `1` | Set Carry flag (C=1)                                                                    |
|                      | `$71`        | `CLC`    |              | Implied   | 1     | `-` | `-` | `0` | Clear Carry flag (C=0)                                                                  |
| **STACK**            |              |          |              |           |       |     |     |     |                                                                                         |
|                      | `$80`        | `PHA`    |              | Implied   | 1     | `-` | `-` | `-` | Push Accumulator A onto Stack                                                             |
|                      | `$81`        | `PLA`    |              | Implied   | 1     | `+/-` | `+/-` | `-` | Pull Accumulator A from Stack. Sets Z,N. C unaffected.                                  |
|                      | `$82`        | `PHP`    |              | Implied   | 1     | `-` | `-` | `-` | Push Processor Status (Flags) onto Stack                                                |
|                      | `$83`        | `PLP`    |              | Implied   | 1     | `*` | `*` | `*` | Pull Processor Status (Flags) from Stack. All flags (Z,N,C,...) restored.             |
| **MEMORY R/W**       |              |          |              |           |       |     |     |     |                                                                                         |
|                      | `$A0`        | `LDA`    | address      | Absolute  | 3     | `+/-` | `+/-` | `-` | Load A from Memory. Sets Z,N. C unaffected.                                           |
|                      | `$A1`        | `STA`    | address      | Absolute  | 3     | `-` | `-` | `-` | Store A to Memory. Flags unaffected.                                                    |
| **IMMEDIATE LOADS**  |              |          |              |           |       |     |     |     |                                                                                         |
|                      | `$B0`        | `LDI A`  | byte         | Immediate | 2     | `+/-` | `+/-` | `-` | Load A with Immediate. Sets Z,N. C unaffected.                                        |
|                      | `$B1`        | `LDI B`  | byte         | Immediate | 2     | `+/-` | `+/-` | `-` | Load B with Immediate. Sets Z,N. C unaffected.                                        |
|                      | `$B2`        | `LDI C`  | byte         | Immediate | 2     | `+/-` | `+/-` | `-` | Load C with Immediate. Sets Z,N. C unaffected.                                        |
