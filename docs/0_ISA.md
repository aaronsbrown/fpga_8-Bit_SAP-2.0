# Instruction Set Architecture (ISA)

This table defines the initial instruction set for the custom 8-bit CPU.

| OPCODE (Hex) | Instruction Mnemonic | Operand Type | Addressing Mode | # Bytes | Notes                                                      |
| :----------- | :------------------- | :----------- | :-------------- | :------ | :--------------------------------------------------------- |
| `$00`        | `NOP`                |              | Implied         | 1       | No operation                                               |
| `$01`        | `HLT`                |              | Implied         | 1       | Halt processor                                             |
| `$02`        | `JMP`                | address      | Immediate       | 3       | Jump to 16-bit address                                     |
| `$03`        | `JZ`                 | address      | Immediate       | 3       | Jump if Zero flag is set                                   |
| `$04`        | `JNZ`                | address      | Immediate       | 3       | Jump if Zero flag is not set                               |
| `$05`        | `JN`                 | address      | Immediate       | 3       | Jump if Negative flag is set                               |
| `$06`        | `CALL`               | address      | Immediate       | 3       | Call subroutine at 16-bit address                          |
| `$07`        | `RET`                |              | Implied         | 1       | Return from subroutine                                     |
| `$08`        | `IN`                 | port         | Direct Port     | 2       | **REMOVE** (Not used with MMIO architecture)               |
| `$09`        | `OUT`                | port         | Direct Port     | 2       | **REMOVE** (Not used with MMIO architecture)               |
| `$0A`        | `LDA`                | address      | Absolute        | 3       | Load Accumulator A from 16-bit address, sets Z/N flags   |
| `$0B`        | `STA`                | address      | Absolute        | 3       | Store Accumulator A to 16-bit address                    |
| `$0C`        | `LDI A`              | byte         | Immediate       | 2       | Load Accumulator A with immediate byte, sets Z/N flags   |
| `$0D`        | `LDI B`              | byte         | Immediate       | 2       | Load Register B with immediate byte, sets Z/N flags      |
| `$0E`        | `LDI C`              | byte         | Immediate       | 2       | Load Register C with immediate byte, sets Z/N flags      |
| `$0F`        | `ADD B`              |              | Register        | 1       | A = A + B, sets Z/N/C flags                              |
| `$10`        | `ADD C`              |              | Register        | 1       | A = A + C, sets Z/N/C flags                              |
| `$11`        | `SUB B`              |              | Register        | 1       | A = A - B, sets Z/N/C flags (Carry=Borrow)               |
| `$12`        | `SUB C`              |              | Register        | 1       | A = A - C, sets Z/N/C flags (Carry=Borrow)               |
| `$13`        | `INR A`              |              | Register        | 1       | Increment Accumulator A (A = A + 1), sets Z/N flags        |
| `$14`        | `INR B`              |              | Register        | 1       | Increment Register B (B = B + 1), sets Z/N flags        |
| `$15`        | `INR C`              |              | Register        | 1       | Increment Register C (C = C + 1), sets Z/N flags        |
| `$16`        | `DCR A`              |              | Register        | 1       | Decrement Accumulator A (A = A - 1), sets Z/N flags        |
| `$17`        | `DCR B`              |              | Register        | 1       | Decrement Register B (B = B - 1), sets Z/N flags        |
| `$18`        | `DCR C`              |              | Register        | 1       | Decrement Register C (C = C - 1), sets Z/N flags        |
| `$19`        | `RAL`                |              | Implied         | 1       | Rotate Accumulator Left through Carry, sets C flag         |
| `$1A`        | `RAR`                |              | Implied         | 1       | Rotate Accumulator Right through Carry, sets C flag        |
| `$1B`        | `CMA`                |              | Implied         | 1       | Complement Accumulator A (A = ~A) (Logical NOT)          |
| `$1C`        | `ANA B`              |              | Register        | 1       | A = A & B (Logical AND), sets Z/N flags, clears C        |
| `$1D`        | `ANA C`              |              | Register        | 1       | A = A & C, sets Z/N flags, clears C                      |
| `$1E`        | `ANI`                | byte         | Immediate       | 2       | A = A & immediate byte, sets Z/N flags, clears C         |
| `$1F`        | `ORA B`              |              | Register        | 1       | A = A \| B (Logical OR), sets Z/N flags, clears C        |
| `$20`        | `ORA C`              |              | Register        | 1       | A = A \| C, sets Z/N flags, clears C                     |
| `$21`        | `ORI`                | byte         | Immediate       | 2       | A = A \| immediate byte, sets Z/N flags, clears C        |
| `$22`        | `XRA B`              |              | Register        | 1       | A = A ^ B (Logical XOR), sets Z/N flags, clears C        |
| `$23`        | `XRA C`              |              | Register        | 1       | A = A ^ C, sets Z/N flags, clears C                      |
| `$24`        | `XRI`                | byte         | Immediate       | 2       | A = A ^ immediate byte, sets Z/N flags, clears C         |
| `$25`        | `CMP B`              |              | Register        | 1       | Compare A with B (A - B), sets Z/N/C flags, discards result |
| `$26`        | `CMP C`              |              | Register        | 1       | Compare A with C (A - C), sets Z/N/C flags, discards result |
| `$27`        | `MOV A,B`            |              | Register        | 1       | Move B to A (A = B)                                        |
| `$28`        | `MOV A,C`            |              | Register        | 1       | Move C to A (A = C)                                        |
| `$29`        | `MOV B,A`            |              | Register        | 1       | Move A to B (B = A)                                        |
| `$2A`        | `MOV B,C`            |              | Register        | 1       | Move C to B (B = C)                                        |
| `$2B`        | `MOV C,A`            |              | Register        | 1       | Move A to C (C = A)                                        |
| `$2C`        | `MOV C,B`            |              | Register        | 1       | Move B to C (C = B)                                        |

**Legend/Notes:**

* **OPCODE:** The 8-bit hexadecimal value identifying the instruction.
* **Operand Type:** Describes the type of data expected after the opcode byte(s).
  * `address`: A 16-bit memory address (fetched as two subsequent bytes: low byte, then high byte).
  * `byte`: An 8-bit immediate data value (fetched as one subsequent byte).
  * `port`: _(Marked for removal)_ An 8-bit I/O port address.
* **Addressing Mode:** How the CPU accesses data/operands.
  * `Implied`: Operands are implicit in the instruction (e.g., HLT, RET, operations on Accumulator).
  * `Immediate`: The operand is the byte(s) immediately following the opcode in memory.
  * `Absolute`: The operand bytes form a direct 16-bit memory address.
  * `Register`: Operands are CPU internal registers (A, B, C).
  * `Direct Port`: _(Marked for removal)_ Operand byte specifies an 8-bit address in a dedicated I/O port space.
* **\# Bytes:** Total number of bytes the instruction occupies in memory (Opcode + Operand Bytes).
* **Flags:** Many instructions affect the Zero (Z), Negative (N), and Carry (C) flags.
  * `LDx`, `LDIx`, `INR`, `DCR`, Logic ops (`ANA`/`ANI`, `ORA`/`ORI`, `XRA`/`XRI`) set Z/N based on the result.
  * Arithmetic (`ADD`, `SUB`, `CMP`) and Rotate (`RAL`, `RAR`) ops set Z/N/C flags.
  * Logic ops typically clear the Carry flag (C=0).
  * `MOV`, `STA`, `JMP`, `CALL`, `RET`, `NOP`, `HLT` do not affect flags.
