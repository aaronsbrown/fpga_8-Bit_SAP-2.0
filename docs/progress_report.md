# CPU Project Progress Report

**Date:** [Insert Date Here]

**Based On:** Code analysis after implementing and testing LDA Absolute.

**Overall Summary:** The project has successfully implemented the core architectural changes defined in Phase 3. This includes the transition to a 16-bit address space, 8-bit opcodes, a multi-byte instruction fetch FSM within the control unit, dedicated temporary operand registers, and memory-mapped address decoding logic. The reset vector mechanism is functional. Key instructions including `NOP`, `HLT`, `LDI A`, and `LDA Absolute` are now implemented in microcode and have been tested successfully with the new architecture, validating both 1-byte, 2-byte, and 3-byte instruction fetch/execute sequences. Key areas for immediate focus are implementing microcode for the remaining target instructions (especially STA and JMP), comprehensively updating the rest of the test suite, completing the PC loading mechanism for jumps, and adding the first MMIO peripheral.

---

## Prerequisites

- [x] **Stable Core v0.1**: (Effectively superseded by Phase 3, but initial modularity goals were met).
- [x] **Modular Structure**: CPU logic encapsulated (`cpu.sv`), separated from memory (`ram_8k.sv`, `vram_4k.sv`, `rom_4k.sv`) and top-level wrapper (`computer.sv`, `top.v`).
- [x] **Toolchain & Testbench**: Working simulation (Icarus + GTKWave), open‑source synthesis (Yosys + nextpnr for iCE40), basic testbenches (some updated, others need rework), ability to load `.hex` files.
- [x] **Target Platform:** Confirmed FPGA board and toolchain (Alchitry Cu - iCE40HX8K + Yosys/nextpnr).

---

## Phase 2: Memory‑Mapped I/O (MMIO) Infrastructure

*(Goal: Establish the hardware mechanism for CPU interaction with peripheral registers at specific memory addresses, independent of final address width)*

- [x] **1. Conceptual I/O Address Range:** Defined ($E000-$EFFF in `computer.sv` decoding).
- [x] **2. Implement Address Decoder Logic (in `computer.sv`):** Done. Full 16-bit decoding implemented, generating `ce_ram_8k`, `ce_vram_4k`, `ce_rom_4k`, and `ce_mmio`.
- [x] **3. Implement Bus Routing Logic (in `computer.sv`):** Done. `cpu_mem_data_in` is muxed based on chip selects. Memory write enables (`we`) are gated by chip selects.
- [ ] **4. Add Basic Output Register (LEDs):** **Not Done.** No peripheral is instantiated and connected within the MMIO address space ($E000-$EFFF).
- [ ] **5. Update Testbench:** **Not Done.** No tests specifically verify MMIO read/write functionality (Requires MMIO peripheral and STA instruction).

> **Phase 2 Status:** **Partially Complete.** The core address decoding and bus routing infrastructure for MMIO is implemented and functional. However, no actual MMIO peripheral device has been added or tested yet.

---

## Phase 3: Architecture Overhaul - 64KB Address Space & Expanded ISA Foundation

*(Goal: Transition to a 16-bit address space and lay the foundation for a richer instruction set by adopting 8-bit opcodes and implementing multi-byte instruction fetching)*

- [x] **1. Redefine Core Architecture Parameters (in `arch_defs_pkg.sv`):** Done. `ADDR_WIDTH=16`, `OPCODE_WIDTH=8`. `RESET_VECTOR=16'hF000`. New `fsm_state_t` and expanded `control_word_t` defined. New 8-bit `opcode_t` enum includes LDA.
- [x] **2. Resize Core Hardware Components:** Done. PC=16b, MAR=16b, ports updated, specific memory blocks instantiated.
- [x] **3. Re-architect MAR Loading (in `cpu.sv`):** Done. Uses `register_memory_address` module which accepts control signals for loading from PC or byte-wise from bus (tested via LDA).
- [x] **4. Adapt Instruction Register (in `cpu.sv`):** Done. `u_register_instr` is an 8-bit `register_nbit` instance.
- [x] **5. Overhaul Control Unit (`control_unit.sv`) for Multi-Byte Fetching:** Done. New FSM implemented and validated for 1, 2, and 3-byte instruction fetches. `num_operand_bytes` logic updated for LDA. Temp registers loaded correctly. Reset vector logic functional. Microcode ROM resized.
- [/] **6. Define & Implement Initial 8-bit ISA:** **Partially Done.**
  - 8-bit opcodes defined for `NOP` (0x00), `HLT` (0x01), `LDA` (0x0A), `LDI_A` (0x0C) in `arch_defs_pkg.sv`.
  - Microcode implemented and tested for `NOP`, `HLT`, `LDI_A`, `LDA`.
  - *Microcode for other target instructions ($02-$09(Removed), $0B, $0D-$2C) is missing.*
- [x] **7. Update Address Decoder (Phase 2 Logic):** Done. Integrated into the 16-bit decoding in `computer.sv`.
- [/] **8. Update Testbenches & Fixtures:** **Partially Done.**
  - Testbenches for `HLT`, `LDI_A`, `LDA`, and `program_counter` are updated and passing for the new architecture.
  - Most other testbenches (`op_STA_tb.sv`, jumps, arithmetic, logic, etc.) are **outdated**.
  - `.hex` fixtures created for tested instructions. More needed for remaining instructions.
  - `rom_4k.sv` still loads an old fixture file by default for synthesis builds.
  - Test utilities (`run_until_halt`, `clear_ram`) may need minor path/logic updates (e.g., halt signal path).

> **Phase 3 Status:** **Mostly Complete.** Core architecture validated with 1, 2, and 3-byte instructions. Major remaining work is implementing microcode for the rest of the target instruction set (STA, JMP, arithmetic, etc.) and updating/creating corresponding testbenches. PC Load logic for Jumps is needed.

---

## Phase 4: Assembler for New Architecture

- [ ] **Goal:** Create a tool to simplify writing programs for the new 16-bit address, 8-bit opcode, multi-byte ISA.

> **Status:** **Not Started.**

---

## Phase 5: Basic I/O Peripheral Integration

- [ ] **Goal:** Add UART communication capability using the MMIO infrastructure and the new assembler.

> **Status:** **Not Started.** (Blocked by MMIO peripheral in Phase 2, Assembler in Phase 4, and STA instruction).

---

*(Phases 6-11 remain unchanged - Not Started)*
---

## Critical Next Steps

1. **Implement Microcode:** Add microcode sequences for `STA` (critical for MMIO), `JMP` (requires PC load logic), and then arithmetic/logic operations.
2. **Implement PC Load for Jumps:** Add control signals to `control_word_t` and drive `load_pc_high_byte`/`load_pc_low_byte` in `program_counter.sv` from `cpu.sv` during JMP execution steps. Create `op_JMP_tb.sv`.
3. **Update/Create Testbenches:** Create/update testbenches for STA, JMP, and other implemented instructions.
4. **Implement Basic MMIO Peripheral:** Add a simple MMIO register (e.g., LED output at $E000) in `computer.sv` and test with the now-implemented LDA and newly implemented STA instructions.
5. **Update Fixtures:** Create new `.hex` files for new tests. Update the default hex loaded by `rom_4k.sv` for synthesis.
6. **Fix Test Utilities:** Verify/correct the path in `run_until_halt` (e.g., `uut.u_cpu.halt` or `uut.cpu_halt_wire`) and update `clear_ram` if needed.
7. **Expand Opcode Definitions:** Ensure `num_operand_bytes` logic in `control_unit.sv` covers all newly implemented opcodes.
8. **Cleanup:** Remove `control_unit_2.sv`.
