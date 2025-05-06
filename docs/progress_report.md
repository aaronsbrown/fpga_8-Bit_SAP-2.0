# CPU Project Progress Report

**Date:** [Insert Current Date]

**Based On:** Completion of base ISA implementation and initial MMIO hardware test.

**Overall Summary:** The project has successfully implemented the core architectural changes defined in Phase 3. This includes a 16-bit address space, 8-bit opcodes, a multi-byte FSM, temporary operand registers, memory-mapped address decoding, and functional PC loading for jumps. The reset vector mechanism is functional. **The entire initial target instruction set (opcodes $00-$65, excluding IN/OUT) has been implemented in microcode and successfully tested through simulation.** This covers loads, stores, arithmetic (including with carry), logic, rotates, moves, and all conditional/unconditional branches. Furthermore, **a basic 8-bit MMIO output port at address $E000 has been implemented and successfully tested on FPGA hardware**, confirming the MMIO infrastructure and `STA` instruction. The CPU is now a significantly capable 8-bit processor. The immediate next major steps are implementing stack support (Phase 6 for CALL/RET functionality) and then developing an assembler (Phase 4).

---

## Prerequisites

- [x] **Stable Core v0.1**: (Superseded)
- [x] **Modular Structure**: Done.
- [x] **Toolchain & Testbench**: Done.
- [x] **Target Platform:** Done.

---

## Phase 2: Memory‑Mapped I/O (MMIO) Infrastructure

- [x] **1. Conceptual I/O Address Range:** Done.
- [x] **2. Implement Address Decoder Logic:** Done.
- [x] **3. Implement Bus Routing Logic:** Done.
- [x] **4. Add Basic Output Register (LEDs):** **Done.** Implemented `$E000` output port and tested on hardware.
- [x] **5. Update Testbench:** **Done.** `op_STA_MMIO_tb.sv` created and passed. (Further MMIO read tests can be added once an input peripheral is designed).

> **Phase 2 Status:** **Complete.**

---

## Phase 3: Architecture Overhaul - 64KB Address Space & Expanded ISA Foundation

- [x] **1. Redefine Core Architecture Parameters:** Done.
- [x] **2. Resize Core Hardware Components:** Done.
- [x] **3. Re-architect MAR Loading:** Done.
- [x] **4. Adapt Instruction Register:** Done.
- [x] **5. Overhaul Control Unit:** Done. PC loading for Jumps fully tested.
- [x] **6. Define & Implement Initial 8-bit ISA:** **Done.** All opcodes in the `docs/0_ISA.md` table (excluding those marked for removal or future phases like Stack) are implemented in microcode and tested.
- [x] **7. Update Address Decoder:** Done.
- [x] **8. Update Testbenches & Fixtures:** **Done.** Testbenches exist and pass for all currently implemented instructions in the base set. Synthesis ROM fixture (`op_STA_MMIO_prog.hex`) used for hardware test.

> **Phase 3 Status:** **Complete.**

---

## Phase 4: Assembler for New Architecture

- [ ] **Goal:** Create a tool to simplify writing programs.

> **Status:** **Not Started.**

---

## Phase 5: Basic I/O Peripheral Integration

- [/] **Goal:** Add UART communication capability.

> **Status:** **Blocked.** MMIO infrastructure is ready. A simple MMIO output port is done. UART itself and assembler are pending.

---

## Phase 6: Stack & Subroutine Support

- [ ] **Goal:** Enable structured programming constructs.

> **Status:** **Not Started.** Instructions `CALL`/`RET` defined but need stack implementation.

---

*(Phases 7-11 remain Not Started)*
---

## Critical Next Steps

1. **Stack Implementation (Phase 6):**
    - Design and implement `stack_pointer.sv` (16-bit, with inc/dec capabilities).
    - Add SP to `cpu.sv` datapath.
    - Implement microcode for `PHA`, `PLA` (Push/Pop Accumulator).
    - Implement microcode for `CALL`, `RET` (using SP to push/pop PC).
    - Create testbenches for all stack-related instructions.
    - (Optional: `PHP`/`PLP` for flags).
2. **Assembler (Phase 4):** Begin design and development of the assembler.
3. **Further MMIO Peripherals (Phase 5):** After STA is solid and perhaps with assembler, plan for UART or other input/output devices.
4. **Cleanup & Refinement:** Review synthesis ROM fixture strategy, ensure all documentation is up-to-date.
