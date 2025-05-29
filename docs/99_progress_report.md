# CPU Project Progress Report

**Date:** [Insert Current Date - e.g., October 26, 2023]

**Based On:** Completion of Assembler (Phase 4) and significant progress in UART Peripheral Integration (Phase 5), including advanced error handling.

**Overall Summary:**
The project has made substantial advancements, successfully completing the robust two-pass assembler (Phase 4), which now enables efficient programming for the established 16-bit address space and multi-byte instruction set (from Phase 3).
Significant progress has been made in **Phase 5 (Basic I/O Peripheral Integration)** with the implementation and thorough testing of a UART peripheral. This UART now supports:

* Basic serial transmission and reception.
* A level-sensitive `RX_DATA_READY` flag.
* Detection and status reporting for **Frame Errors** and **Overshoot/Overrun Errors**.
* A memory-mapped **Command Register** allowing CPU-driven clearing of these error flags.
Comprehensive testbenches and assembly programs have been developed to validate these UART features, including forcing and correctly handling error conditions. The MMIO infrastructure continues to prove effective. The CPU system is evolving into a capable platform with foundational communication abilities.

---

## Prerequisites

* [x] **Stable Core v0.1**: (Superseded by Phase 3 completion)
* [x] **Modular Structure**: Done.
* [x] **Toolchain & Testbench**: Done, continuously updated.
* [x] **Target Platform:** Done.

---

## Phase 2: Memory‑Mapped I/O (MMIO) Infrastructure

* [x] **1. Conceptual I/O Address Range:** Done.
* [x] **2. Implement Address Decoder Logic:** Done.
* [x] **3. Implement Bus Routing Logic:** Done.
* [x] **4. Add Basic Output Register (LEDs):** Done. (`$E004` used in recent tests, originally `$E000` was mentioned).
* [x] **5. Update Testbench:** Done.

> **Phase 2 Status:** **Complete.**

---

## Phase 3: Architecture Overhaul - 64KB Address Space & Expanded ISA Foundation

* [x] **1. Redefine Core Architecture Parameters:** Done.
* [x] **2. Resize Core Hardware Components:** Done.
* [x] **3. Re-architect MAR Loading:** Done.
* [x] **4. Adapt Instruction Register:** Done.
* [x] **5. Overhaul Control Unit:** Done.
* [x] **6. Define & Implement Initial 8-bit ISA:** Done.
* [x] **7. Update Address Decoder:** Done.
* [x] **8. Update Testbenches & Fixtures:** Done.

> **Phase 3 Status:** **Complete.**

---

## Phase 4: Assembler for CPU Architecture

* [x] **Goal:** Create a robust tool to write, assemble, and generate memory images for the custom 8-bit CPU with a 16-bit address space.
* [x] **1. Assembler Features Implemented:**
  * [x] Labels & Symbols (`EQU`).
  * [x] Mnemonics for the current ISA.
  * [x] Operand Parsing (8-bit immediate, 16-bit absolute).
  * [x] Machine Code Generation (1, 2, or 3-byte, little-endian).
  * [x] Directives: `ORG`, `EQU`, `DB`, `DW`.
  * [x] Output Format: `.hex` for `$readmemh` (single combined or multi-region).
  * [x] Error Handling & Range Checking.
  * [x] Comments & Formatting.
* [x] **2. Assembler Development (Python):**
  * [x] Implemented using a two-pass approach.
  * [x] Distinct tokenization/parsing and code generation stages.
  * [x] Includes symbol table and instruction set definition.
* [x] **3. Toolchain Integration & Workflow:**
  * [x] Assembler is a command-line Python script.
  * [x] Workflow: Write `.asm`, invoke assembler, load generated `.hex` into Verilog testbenches.
  * [ ] Future: Consider options for more automated integration into `simulate.sh` if desired.
* [ ] **4. Documentation:**
  * [ ] Document the specific assembly language syntax supported. *(Partially done via discussions, formal document pending)*
  * [x] Update project README with assembler capabilities. *(Partially done)*

> **Phase 4 Status:** **Complete.** The assembler is functional, robust, and has been instrumental in developing test programs for Phase 5. Minor documentation tasks remain.

---

## Phase 5: Basic I/O Peripheral Integration

* [x] **Goal:** Add UART communication capability using the MMIO infrastructure and the new assembler.
* **Implement/Integrate UART:**
  * [x] Added UART Verilog modules (`uart_peripheral` wrapping `uart_transmitter`, `uart_receiver`).
  * [x] Assigned specific 16-bit addresses:
    * `$E000` Config Register (placeholder for runtime config)
    * `$E001` Status Register
    * `$E002` Data Register
    * `$E003` Command Register
  * [x] Connected UART to system bus via MMIO logic.
  * [x] Implemented level-sensitive `RX_DATA_READY` flag.
  * [x] Implemented Frame Error detection, status bit, and command-driven clear.
  * [x] Implemented Overshoot/Overrun Error detection, status bit, and command-driven clear.
  * [ ] Connect UART TX/RX pins in top-level constraints for hardware (if not already done).
* **Write Test Programs (Assembly):**
  * [x] Used Phase 4 assembler extensively.
  * [x] Basic send character (implicitly tested).
  * [x] Basic receive character (implicitly tested).
  * [x] Test program for Frame Error detection and clearing. **Done.**
  * [x] Test program for Overshoot Error detection and clearing. **Done.**
  * [ ] Develop a robust, general-purpose echo program incorporating full error handling. *(Next immediate task)*
* **Test via Simulation & Hardware:**
  * [x] Extensive simulation of UART interaction, including error conditions.
  * [ ] Synthesize and test full UART functionality (including error echo) on hardware with a external serial terminal.

> **Phase 5 Status:** **Significantly Advanced / Nearing Completion.** Core UART hardware with advanced error detection (frame, overshoot) and CPU control via MMIO (Status, Data, Command registers) is implemented and verified in simulation. The assembler has been crucial. Remaining tasks include creating a robust echo program and comprehensive hardware testing.

---

## Phase 6: Stack & Subroutine Support

* [ ] **Goal:** Enable structured programming constructs.

> **Status:** **Not Started.** This is the next major phase after completing Phase 5.

---

*(Phases 7-11 remain Not Started)*
---

## Critical Next Steps

1. **Finalize Phase 5 (UART):**
    * Develop and test a **robust echo assembly program** that correctly handles good data, frame errors, and overshoot errors (e.g., by echoing specific characters or logging to an output port and then clearing errors).
    * Perform comprehensive **hardware testing** of the UART (including the robust echo and potentially trying to induce errors) with an external serial terminal.
    * Update UART datasheet (markdown) to v0.2. **(Done)**
    * Once confident, tag a release for Phase 5 completion.
2. **Begin Phase 6 (Stack & Subroutine Support):**
    * Design and implement `stack_pointer.sv` (16-bit).
    * Integrate SP into `cpu.sv`.
    * Implement microcode for stack operations (e.g., `PHA`, `PLA` - if adding to ISA) and subroutine instructions (`CALL`/`JSR`, `RET`/`RTS`).
    * Update assembler to support new stack/subroutine mnemonics.
    * Create testbenches.
3. **Documentation (Phase 4 - Assembler):**
    * Complete the formal documentation for the assembler's syntax and directives.

---
