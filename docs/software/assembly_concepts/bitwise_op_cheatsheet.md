---

**Bitwise Logic Quick Guide (Markdown)**

1.  **Goal:** Turn Specific Bits **ON**
    *   **Question:** Want to make sure these bits are `1`?
    *   **Op:** `ORI #mask`
        *   *Mask Logic:* `mask` has `1`s for bits to set.

2.  **Goal:** Turn Specific Bits **OFF**
    *   **Question:** Want to force these bits to `0`?
    *   **Op:** `ANI #mask`
        *   *Mask Logic:* `mask` has `0`s for bits to clear, `1`s for bits to keep.

3.  **Goal:** **Isolate Bits** / Check if **Any** of a Group are Set
    *   **Question:** Only care about these bits? Are any of them `1`?
    *   **Op:** `ANI #mask`
        *   *Mask Logic:* `mask` has `1`s for bits of interest.
        *   *(Then check Z flag: if result non-zero (Z=0), at least one was set).*

4.  **Goal:** **Toggle/Flip** Specific Bits
    *   **Question:** Want to invert these bits?
    *   **Op:** `XRI #mask`
        *   *Mask Logic:* `mask` has `1`s for bits to flip.

5.  **Goal:** Check if `A` is **Exactly Equal** to a Value
    *   **Question:** Does `A == my_value`?
    *   **Op:** `XRI #my_value`
        *   *(Then check Z flag: `JZ` means they were equal. A is changed by this operation).*

6.  **Goal:** Check if `A` is **Zero** (A's value unchanged, flags set)
    *   **Question:** Is `A == 0`? (Need flags set, but keep A's value for later)
    *   **Op:** `ORI #$00`
        *   *(Then check Z flag: `JZ` means A was zero).*

---