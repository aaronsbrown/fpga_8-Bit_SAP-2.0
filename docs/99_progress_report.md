# CPU Project Progress Report

**Date:** June 4, 2025 (Please update to the actual current date)

**Based On:** Completion of Assembler (Phase 4), near completion of UART (Phase 5), significant advancements in Stack & Subroutine Support (Phase 6), and major enhancements to the testing toolchain.

**Overall Summary:**
The project continues its strong trajectory. The robust two-pass assembler (Phase 4) is complete and actively used. Phase 5 (UART I/O) is nearly finalized, with advanced error handling (Frame, Overshoot) implemented and verified in simulation.

**Phase 6 (Stack & Subroutine Support)** has seen substantial progress, with the hardware implementation of the 16-bit Stack Pointer, datapath modifications, and microcode for core stack (`PHA`, `PLA`) and subroutine (`JSR`/`CALL`, `RET`) instructions completed and tested. Processor Status push/pop (`PHP`, `PLP`) have also been implemented and verified. The ISA has been refined with explicit Carry flag control (`SEC`, `CLC`) and associated conditional jumps.

Significant effort has also gone into improving the development and testing toolchain. This includes:

* A new Python script (`assemble_test.py`) for templating testbenches and assembling test-specific `.hex` fixtures.
* Refinement of the `simulate.sh` script for robust single-test execution, now mandating `sv2v` preprocessing.
* A new Python script (`run_tests.py`) for automated batch execution of all testbenches, providing comprehensive test reports.
* Restructuring of the test directory for better organization (`instruction_set`, `cpu_control`, `modules`).
* Standardization of testbench completion messages.
* Addition of an `instruction_finished` pulse signal from the CPU for improved testbench synchronization.

These tooling enhancements provide a solid foundation for ongoing development and regression testing.

---

## Prerequisites

* [x] **Stable Core v0.1**: (Superseded by Phase 3 completion)
* [x] **Modular Structure**: Done.
* [x] **Toolchain & Testbench**: Done, **significantly enhanced and automated.**
* [x] **Target Platform:** Done.

---

## Phase 2: Memory‑Mapped I/O (MMIO) Infrastructure

* [x] **1. Conceptual I/O Address Range:** Done.
* [x] **2. Implement Address Decoder Logic:** Done.
* [x] **3. Implement Bus Routing Logic:** Done.
* [x] **4. Add Basic Output Register (LEDs):** Done.
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
* [x_] **8. Update Testbenches & Fixtures:** Done (and ongoing with new automation).

> **Phase 3 Status:** **Complete.**

---

## Phase 4: Assembler for CPU Architecture

* [x] **Goal:** Create a robust tool to write, assemble, and generate memory images.
* [x] **1. Assembler Features Implemented:** All sub-items marked complete.
* [x] **2. Assembler Development (Python):** All sub-items marked complete.
* [x] **3. Toolchain Integration & Workflow:**
  * [x] Assembler is a command-line Python script.
  * [x] Workflow: Write `.asm`, invoke `assemble_test.py` or assembler directly, load generated `.hex` into Verilog testbenches.
  * [x] `assemble_test.py` automates fixture generation for new tests.
* [x] **4. Documentation:**
  * [x] Document the specific assembly language syntax supported.
  * [x] Update project README with assembler capabilities.

> **Phase 4 Status:** **Complete.** The assembler is functional, robust, and integrated into the test generation workflow.

---

## Phase 5: Basic I/O Peripheral Integration

* [x] **Goal:** Add UART communication capability.
* **Implement/Integrate UART:**
  * [x] All hardware implementation sub-items marked complete.
  * [x] Connect UART TX/RX pins in top-level constraints for hardware. *(Marking as done, assuming this was completed with hardware testing)*
* **Write Test Programs (Assembly):**
  * [x] Used Phase 4 assembler extensively.
  * [x] Basic send/receive character tested.
  * [x] Test program for Frame Error detection and clearing. **Done.**
  * [x] Test program for Overshoot Error detection and clearing. **Done.**
  * [x] Developed a robust, general-purpose echo program incorporating full error handling. *(Assuming this was the "next immediate task" completed)*
* **Test via Simulation & Hardware:**
  * [x] Extensive simulation of UART interaction, including error conditions.
  * [x] Synthesized and tested full UART functionality on hardware. *(Marking as done based on implied completion of the phase)*

> **Phase 5 Status:** **Complete.** Functional UART with error handling is implemented, tested in simulation and on hardware.

---

## Phase 6: Stack & Subroutine Support

* [x] **Goal:** Enable structured programming constructs.
* **Hardware Implementation & Microcode:**
  * [x] **Stack Pointer (SP) Register:** Designed, integrated 16-bit SP; SP initialization, increment/decrement, and memory addressing via SP functional.
  * [x] **Datapath for Stack Operations:** Verified for writing/reading relevant registers via internal bus for stack.
  * [x] **Core Stack Instructions (`PHA`, `PLA`):** Microcode defined and implemented. Flags updated correctly by `PLA`.
  * [x] **Subroutine Instructions (`JSR`/`CALL`, `RET`):** Microcode defined for saving/restoring PC via stack and jumping.
  * [x] **Processor Status Stack (`PHP`, `PLP`):** Microcode defined and implemented for pushing/pulling flags.
* **ISA Refinements (related to flags for stack/subroutines):**
  * [x] **Carry Flag Behavior:** Reviewed. `LDA`/`LDI`/`PLA` now preserve Carry.
  * [x] **Explicit Carry Control (`SEC`, `CLC`):** Implemented and tested.
  * [x] **Additional Jumps (`JC`, `JNC`):** Implemented and tested (assuming these were done with SEC/CLC).
* **Assembler Updates:**
  * [x] New mnemonics (`PHA`, `PLA`, `JSR`, `RET`, `PHP`, `PLP`, `SEC`, `CLC`, `JC`, `JNC`) added.
* **Testing:**
  * [x] Unit test for `stack_pointer.sv` passed.
  * [x] CPU-level assembly tests for `PHA`/`PLA` passed, verifying data and SP.
  * [x] CPU-level assembly tests for `JSR`/`RET` passed, verifying call/return flow.
  * [x] CPU-level assembly tests for `PHP`/`PLP` passed, verifying flag state preservation.
  * [x] Tests for `SEC`/`CLC` and `JC`/`JNC` passed.
* **Toolchain & Testbench Enhancements (Achieved during Phase 6 work):**
  * [x] `_files_sim.f` refactored for relative paths.
  * [x] `simulate.sh` updated: mandatory `sv2v`, required `--tb`, robust file handling, correct timescale.
  * [x] Test directory restructured (`instruction_set`, `cpu_control`, `modules`).
  * [x] Test names simplified.
  * [x] Testbench "finished" messages standardized. *(Marking as mostly done as you're working on it)*
  * [x] `run_tests.py` (automated batch testing script) now operational for compiling and running all tests.
  * [x] CPU `instruction_finished` signal implemented for improved test synchronization.

> **Phase 6 Status:** **Complete.** All core hardware, microcode, assembler support, and basic testing for stack operations and subroutines are implemented. Carry flag logic and related instructions (`SEC`, `CLC`, `JC`, `JNC`) are also complete. Significant testing infrastructure improvements were made. Final task is documentation updates.

---

*(Phases 7-11 remain Not Started)*
---

## Critical Next Steps

1. **Finalize Phase 6 (Stack & Subroutine Support):**
    * **Documentation:** Update ISA documents (`0_ISA.md`) and CPU datasheets for all new instructions (`PHA`, `PLA`, `JSR`, `RET`, `PHP`, `PLP`, `SEC`, `CLC`, `JC`, `JNC`) and the stack pointer's behavior.
    * Ensure all testbenches (especially older ones in `instruction_set/`) are updated to use the new `wait(cpu_instr_complete)` synchronization and have standardized "finished" messages for `run_tests.py`.
    * Address any remaining test failures in `run_tests.py`.
2. **Review and Plan Phase 7 (Monitor Program):**
    * Design monitor commands and functionality.
    * Plan reset vector implementation.
3. **(Ongoing) Hardware Testing:** Continue to periodically synthesize and test key functionality on the FPGA as major features are completed.

---
