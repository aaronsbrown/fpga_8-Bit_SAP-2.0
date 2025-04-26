# CPU Project Progress Report

**Date:** [Insert Date Here]

**Based On:** Code analysis of the branch implementing Phase 3 architectural changes.

**Overall Summary:** The project has successfully implemented the core architectural changes defined in Phase 3. This includes the transition to a 16-bit address space, 8-bit opcodes, a multi-byte instruction fetch FSM within the control unit, dedicated temporary operand registers, and memory-mapped address decoding logic. The reset vector mechanism is functional. A minimal set of instructions (NOP, HLT, LDI_A) are implemented in microcode and the HLT instruction has been tested successfully with the new architecture. Key areas for immediate focus are implementing the microcode for the remaining target instructions, comprehensively updating testbenches and fixtures for the new ISA, completing the PC loading mechanism for jumps, and adding the first MMIO peripheral.

---

## Prerequisites

- [x] **Stable Core v0.1**: (Effectively superseded by Phase 3, but initial modularity goals were met) 8‑bit data (`DATA_WIDTH=8`), 4‑bit address (`ADDR_WIDTH=4`), microcoded control unit, 16‑instruction set (`OPCODE_WIDTH=4`), shared internal bus, synchronous design.
- [x] **Modular Structure**: CPU logic encapsulated (`cpu.sv`), separated from memory (now `ram_8k.sv`, `vram_4k.sv`, `rom_4k.sv`) and top-level wrapper (`computer.sv`, `top.v`).
- [x] **Toolchain & Testbench**: Working simulation (Icarus + GTKWave), open‑source synthesis (Yosys + nextpnr for iCE40), basic testbenches (many need updating), ability to load `.hex` files.
- [x] **Target Platform:** Confirmed FPGA board and toolchain (Alchitry Cu - iCE40HX8K + Yosys/nextpnr).

---

## Phase 2: Memory‑Mapped I/O (MMIO) Infrastructure

*(Goal: Establish the hardware mechanism for CPU interaction with peripheral registers at specific memory addresses, independent of final address width)*

- [x] **1. Conceptual I/O Address Range:** Defined ($E000-$EFFF in `computer.sv` decoding).
- [x] **2. Implement Address Decoder Logic (in `computer.sv`):** Done. Full 16-bit decoding implemented, generating `ce_ram_8k`, `ce_vram_4k`, `ce_rom_4k`, and `ce_mmio`.
- [x] **3. Implement Bus Routing Logic (in `computer.sv`):** Done. `cpu_mem_data_in` is muxed based on chip selects. Memory write enables (`we`) are gated by chip selects.
- [ ] **4. Add Basic Output Register (LEDs):** **Not Done.** No peripheral is instantiated and connected within the MMIO address space ($E000-$EFFF). The old `register_OUT` is not currently MMIO.
- [ ] **5. Update Testbench:** **Not Done.** No tests specifically verify MMIO read/write functionality.

> **Phase 2 Status:** **Partially Complete.** The core address decoding and bus routing infrastructure for MMIO is implemented and functional. However, no actual MMIO peripheral device has been added or tested yet.

---

## Phase 3: Architecture Overhaul - 64KB Address Space & Expanded ISA Foundation

*(Goal: Transition to a 16-bit address space and lay the foundation for a richer instruction set by adopting 8-bit opcodes and implementing multi-byte instruction fetching)*

- [x] **1. Redefine Core Architecture Parameters (in `arch_defs_pkg.sv`):** Done. `ADDR_WIDTH=16`, `OPCODE_WIDTH=8`. `RESET_VECTOR=16'hF000`. New `fsm_state_t` and expanded `control_word_t` defined. New 8-bit `opcode_t` enum started. (`OPERAND_WIDTH` definition is potentially misleading but functionally handled by FSM).
- [x] **2. Resize Core Hardware Components:** Done. `program_counter` is 16-bit. `register_memory_address` handles 16 bits. Port widths updated. Specific memory blocks (`ram_8k`, `vram_4k`, `rom_4k`) instantiated in `computer.sv`.
- [x] **3. Re-architect MAR Loading (in `cpu.sv`):** Done. Uses `register_memory_address` module which accepts control signals (`load_mar_pc`, `load_mar_addr_low`, `load_mar_addr_high`) to load MAR either from PC or byte-wise from the internal bus.
- [x] **4. Adapt Instruction Register (in `cpu.sv`):** Done. `u_register_instr` is an 8-bit `register_nbit` instance, correctly latching the fetched opcode byte.
- [x] **5. Overhaul Control Unit (`control_unit.sv`) for Multi-Byte Fetching:** Done. New FSM (`S_INIT`..`S_EXECUTE`) implemented. `num_operand_bytes` logic determines fetch length. PC increment occurs per byte via `pc_enable` in `S_LATCH_BYTE`. Temporary registers (`temp_1_out`, `temp_2_out`) are loaded in `S_LATCH_BYTE`. Microcode ROM resized to `[256][8]`. Reset sequence uses `S_INIT` and `load_origin` to load PC from `RESET_VECTOR`.
- [/] **6. Define & Implement Initial 8-bit ISA:** **Partially Done.**
  - 8-bit opcodes defined for `NOP`, `HLT`, `LDI_A`, `LDA` in `arch_defs_pkg.sv`.
  - Microcode implemented only for `NOP` (0x00), `HLT` (0x01), `LDI_A` (0x0C).
  - *Microcode for `LDA` (0x0A) and other target instructions ($02-$0B, $0D-$2C) is missing.*
- [x] **7. Update Address Decoder (Phase 2 Logic):** Done. Integrated into the 16-bit decoding in `computer.sv`.
- [/] **8. Update Testbenches & Fixtures:** **Partially Done.**
  - `op_HLT_tb.sv` and `program_counter_tb.sv` appear updated for the new architecture.
  - Most other testbenches (`op_*.sv`, `prgm_*.sv`, `ram_tb.sv`, flag tests) are **outdated** (use 4-bit ISA concepts, wrong files, wrong cycle counts).
  - `.hex` fixtures need to be created/updated for the new 8-bit, multi-byte ISA.
  - `rom_4k.sv` still loads an old fixture file by default.
  - Test utilities (`run_until_halt`, `clear_ram`) need path/logic updates.

> **Phase 3 Status:** **Substantially Complete.** The fundamental architectural changes are implemented and the core fetch/reset logic is working. Significant work remains in populating the microcode ROM for the target instruction set and updating the test suite to validate the new architecture.

---

## Phase 4: Assembler for New Architecture

- [ ] **Goal:** Create a tool to simplify writing programs for the new 16-bit address, 8-bit opcode, multi-byte ISA.

> **Status:** **Not Started.**

---

## Phase 5: Basic I/O Peripheral Integration

- [ ] **Goal:** Add UART communication capability using the MMIO infrastructure and the new assembler.

> **Status:** **Not Started.** (Blocked by MMIO peripheral in Phase 2, Assembler in Phase 4, and relevant instructions).

---

## Phase 6: Stack & Subroutine Support

- [ ] **Goal:** Enable structured programming constructs.

> **Status:** **Not Started.**

---

## Phase 7: Monitor Program

- [ ] **Goal:** Create a basic interactive operating environment on the CPU.

> **Status:** **Not Started.**

---

## Phase 8: Expanded Instruction Set & Addressing Modes

- [ ] **Goal:** Increase the computational power and flexibility of the CPU beyond the basics.

> **Status:** **Not Started** (beyond the initial few defined in Phase 3).

---

## Phase 9: Interrupt Handling

- [ ] **Goal:** Allow external events to interrupt CPU execution for timely service.

> **Status:** **Not Started.**

---

## Phase 10: Debugging Features - Single-Step

- [ ] **Goal:** Add hardware support for easier debugging.

> **Status:** **Not Started.**

---

## Phase 11: Advanced Peripherals & Demo Projects

- [ ] **Goal:** Integrate more complex hardware and build showcase applications.

> **Status:** **Not Started.**

---

## Critical Next Steps

1. **Implement Microcode:** Add microcode sequences for the remaining target instructions (LDA, STA, JMP, arithmetic/logic ops as defined) in `control_unit.sv`.
2. **Update Testbenches:** Rewrite or replace existing testbenches (`op_LDA_tb.sv`, `op_STA_tb.sv`, etc.) to use new 8-bit instruction fixtures, validate multi-byte fetches, and check results against the new architecture.
3. **Update Fixtures:** Create new `.hex` files containing programs written using the 8-bit, multi-byte ISA. Ensure `rom_4k.sv` loads a valid program for the new architecture.
4. **Fix Test Utilities:** Correct the path in `run_until_halt` (e.g., `uut.u_cpu.halt`) and update `clear_ram` for the new memory structure.
5. **Implement PC Load for Jumps:** Add control signals to `control_word_t` and drive `load_pc_high_byte`/`load_pc_low_byte` in `program_counter.sv` from `cpu.sv` during JMP execution steps.
6. **Implement Basic MMIO Peripheral:** Add a simple MMIO register (e.g., LED output at $E000) in `computer.sv` and test with LDA/STA instructions.
7. **Expand Opcode Definitions:** Ensure `num_operand_bytes` logic in `control_unit.sv` covers all planned opcodes.
8. **Cleanup:** Remove `control_unit_2.sv`.
