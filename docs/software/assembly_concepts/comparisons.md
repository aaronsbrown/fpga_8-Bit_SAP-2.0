# Assembly Language Comparison Patterns (6502-Style Carry)

This document maps common high-level language comparison operators to assembly language patterns, assuming a CPU with 6502-style flag behavior after a `CMP target_value` or `SUB target_value` instruction (where the operation is `A - target_value`).

**Flags after `CMP target_value` (or `SUB target_value`):**

* **Z (Zero Flag):**
  * `Z = 1` if `A == target_value`
  * `Z = 0` if `A != target_value`
* **N (Negative Flag):**
  * `N = 1` if bit 7 of the result `(A - target_value)` is 1.
  * `N = 0` if bit 7 of the result `(A - target_value)` is 0.
* **C (Carry Flag) - 6502 Style (Set on No Borrow):**
  * `C = 1` if `A >= target_value` (unsigned comparison, no borrow occurred).
  * `C = 0` if `A < target_value` (unsigned comparison, a borrow occurred).

---

## Unsigned Comparisons

| High-Level Operator | Condition after `CMP B` (A vs B) | Assembly Pattern                                                                 | Branch Instruction(s)                                       | Notes                                          |
| :------------------ | :------------------------------- | :------------------------------------------------------------------------------- | :---------------------------------------------------------- | :--------------------------------------------- |
| `A == B`            | `Z = 1`                          | `JZ IS_EQUAL`                                                                    | `JZ` (Jump if Zero)                                         |                                                |
| `A != B`            | `Z = 0`                          | `JNZ IS_NOT_EQUAL`                                                               | `JNZ` (Jump if Not Zero)                                    |                                                |
| `A < B` (unsigned)  | `C = 0`                          | `BCC IS_LESS_UNSIGNED`                                                           | `BCC` (Branch if Carry Clear)                               | Also known as BLO (Branch if Lower)            |
| `A >= B` (unsigned) | `C = 1`                          | `BCS IS_GREATER_OR_EQUAL_UNSIGNED`                                               | `BCS` (Branch if Carry Set)                                 | Also known as BHS (Branch if Higher or Same)   |
| `A > B` (unsigned)  | `C = 1` AND `Z = 0`              | `BCC Path_A_Not_Strictly_Greater`<br/>`BEQ Path_A_Not_Strictly_Greater`<br/>`; Code for A > B`<br/>`JMP AfterCompare`<br/>`Path_A_Not_Strictly_Greater:` | `BCC` then `BEQ` (or vice-versa to structure differently) | Many CPUs have BHI (Branch if Higher)          |
| `A <= B` (unsigned) | `C = 0` OR `Z = 1`               | `BCS Path_A_Is_Strictly_Greater`<br/>`; Code for A <= B`<br/>`JMP AfterCompare`<br/>`Path_A_Is_Strictly_Greater:` | `BCS` (then fall through if C=0 or Z=1) or `BEQ` then `BCC` | Many CPUs have BLS (Branch if Lower or Same) |

---

**Example for `A > B` (Unsigned):**

```assembly
    CMP  B             ; Compare A with B (sets flags based on A-B)
    BCC  NotGreater    ; If A < B (Carry Clear), then A is not strictly greater
    BEQ  NotGreater    ; If A == B (Zero Set, Carry also Set), then A is not strictly greater
IsGreater:
    ; ... code to execute if A > B ...
    JMP  AfterComparison
NotGreater:
    ; ... code to execute if A <= B (i.e., A < B or A == B) ...
AfterComparison:
    ; ... continue execution ...


**Example for A <= B (Unsigned):**
```assembly
    CMP  B             ; Compare A with B
    BCS  IsStrictlyGreater ; If A >= B (Carry Set). If Z=0 here, then A > B.
IsLessOrEqual:
    ; ... code to execute if A < B OR A == B ...
    JMP  AfterComparison
IsStrictlyGreater:
    ; ... code to execute if A > B ...
AfterComparison:
    ; ... continue execution ...


**Alternatively, for A <= B (branching to the "true" condition):**
```assembly
    CMP  B
    BCC  TargetLessOrEqual  ; If C=0 (A < B), it's true, so jump
    BEQ  TargetLessOrEqual  ; If C=1 AND Z=1 (A == B), it's true, so jump
    ; Fall through: Code if A > B
    ; ...
    JMP  AfterComparison    ; Skip the TargetLessOrEqual code
TargetLessOrEqual:
    ; ... code for A <= B ...
AfterComparison:
    ; ... continue execution ...


## Signed Comparisons (Using N and V flags)

*This section assumes your CPU implements an Overflow (V) flag correctly for signed arithmetic. The V flag is crucial for determining the true relationship between signed numbers after an arithmetic operation.*

The V (Overflow) flag is typically set if the result of an arithmetic operation on two signed numbers has exceeded the representable range for that signed number (e.g., for 8-bit signed numbers: -128 to +127).
*   Example of overflow: `$70 + $70 = $E0` (112 + 112 = 224, which is -32 signed 8-bit. Positive + Positive = Negative, so V=1).
*   Example of overflow: `$80 + $80 = $00` (with carry) (-128 + -128 = -256, result $00 is 0 signed. Negative + Negative = Positive, so V=1).

**Conditions for Signed Branches (after `CMP B`, which computes `A-B` and sets N, V, Z):**

*   **Signed Greater Than (`A > B` signed):** True if `(Z=0) AND (N == V)`
    *   (Result is not zero, AND (sign of result matches expected sign if no overflow OR sign of result is opposite of expected sign if overflow occurred, effectively meaning the true signed result is positive))
*   **Signed Greater Than or Equal (`A >= B` signed):** True if `(N == V)`
*   **Signed Less Than (`A < B` signed):** True if `(N != V)`
*   **Signed Less Than or Equal (`A <= B` signed):** True if `(Z=1) OR (N != V)`

| High-Level Operator | Condition (after `CMP B`) | Common Branch Mnemonic(s) (varies by CPU) | 6502 Equivalent                                      |
| :------------------ | :------------------------ | :---------------------------------------- | :----------------------------------------------------- |
| `A == B`            | `Z = 1`                   | `BEQ`, `JZ`                               | `BEQ`                                                  |
| `A != B`            | `Z = 0`                   | `BNE`, `JNZ`                              | `BNE`                                                  |
| `A < B` (signed)    | `N != V`                  | `BLT` (Branch if Less Than, signed)       | Sequence using `BPL`/`BMI` and `BVC`/`BVS` (see below) |
| `A >= B` (signed)   | `N == V`                  | `BGE` (Branch if Greater/Equal, signed) | Sequence using `BPL`/`BMI` and `BVC`/`BVS` (see below) |
| `A > B` (signed)    | `Z=0 AND (N == V)`        | `BGT` (Branch if Greater Than, signed)    | Sequence (more complex)                                |
| `A <= B` (signed)   | `Z=1 OR (N != V)`       | `BLE` (Branch if Less/Equal, signed)      | Sequence (more complex)                                |

**6502 Signed Comparison Logic (No direct signed branches other than based on N):**
The 6502 uses the N (Negative/Sign) and V (Overflow) flags. To determine signed relationships:
*   `A < B` (signed) is true if the N flag is different from the V flag (`N != V` or `N XOR V = 1`).
*   `A >= B` (signed) is true if the N flag is the same as the V flag (`N == V` or `N XOR V = 0`).

Since the 6502 doesn't have direct branches for `N != V` or `N == V`, programmers use sequences:

Example for `A < B` (signed) on a 6502 (conceptual branch to `IS_LESS_THAN_SIGNED`):
```assembly
    CMP B          ; A - B. Sets N, V, Z.
    BPL N_IS_CLEAR ; Branch if N=0 (result was positive or zero)
; N is SET (N=1) - result was negative
    BVC IS_LESS_THAN_SIGNED ; If N=1 and V=0 (no overflow), then A < B is true. Jump.
    ; If here, N=1 and V=1 (overflow occurred, true result positive/zero) => A >= B
    JMP NOT_LESS_THAN_SIGNED 
N_IS_CLEAR:
; N is CLEAR (N=0) - result was positive or zero
    BVS IS_LESS_THAN_SIGNED ; If N=0 and V=1 (overflow occurred, true result negative) => A < B is true. Jump.
    ; If here, N=0 and V=0 (no overflow, true result positive/zero) => A >= B
    ; JMP NOT_LESS_THAN_SIGNED ; (Fall through)
NOT_LESS_THAN_SIGNED:
    ; ... code for A >= B (signed) ...
    JMP AFTER_SIGNED_COMPARISON
IS_LESS_THAN_SIGNED:
    ; ... code for A < B (signed) ...
AFTER_SIGNED_COMPARISON:
