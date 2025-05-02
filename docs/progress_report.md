# CPU Project Progress Report

**Date:** [Insert Date Here]

**Based On:** Code analysis after implementing and testing LDA Absolute.

**Overall Summary:** The project has successfully implemented the core architectural changes defined in Phase 3. This includes the transition to a 16-bit address space, 8-bit opcodes, a multi-byte instruction fetch FSM within the control unit, dedicated temporary operand registers, memory-mapped address decoding logic, and **functional PC loading for jumps**. The reset vector mechanism is functional. Key instructions including `NOP`, `HLT`, Loads (`LDI A/B/C`, `LDA`), Branches (`JMP`, `JZ`, `JNZ`, `JN`), and core Arithmetic (`ADD B/C`, `ADC B/C`, `SUB B/C`, `SBC B/C`, `INR A`, `DCR A`) are now implemented in microcode and have been tested successfully. Key areas for immediate focus are implementing microcode for the remaining target instructions (especially STA for MMIO), comprehensively testing remaining instructions, and adding the first MMIO peripheral
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

*(Goal: Transition to 16-bit address space, 8-bit opcodes, multi-byte fetching)*

- [x] **1. Redefine Core Architecture Parameters:** Done.
- [x] **2. Resize Core Hardware Components:** Done.
- [x] **3. Re-architect MAR Loading:** Done & Tested (via LDA).
- [x] **4. Adapt Instruction Register:** Done.
- [x] **5. Overhaul Control Unit:** Done & Tested (FSM handles 1, 2, 3 bytes; `num_operand_bytes` covers implemented ops; **PC load signals implemented and tested via Jumps**).
- [x] **6. Define & Implement Initial 8-bit ISA:** **Mostly Done.**
  - Opcodes defined for target base set.
  - Microcode implemented & tested for: `NOP`, `HLT`, `LDI A/B/C`, `LDA`, `ADD B/C`, `ADC B/C`, `SUB B/C`, `SBC B/C`, `INR A`, `DCR A`, `JMP`, `JZ`, `JNZ`, `JN`.
  - *Microcode missing/untested for:* `STA`, Logic (`ANA`/`ANI`, `ORA`/`ORI`, `XRA`/`XRI`, `CMA`), Rotates (`RAL`/`RAR`), Compares (`CMP B/C`), Moves (`MOV`), `CALL`/`RET` (needs stack).
- [x] **7. Update Address Decoder:** Done.
- [x] **8. Update Testbenches & Fixtures:** **Mostly Done.**
  - Testbenches created/updated for most implemented instructions including Jumps/Branches.
  - ALU testbench updated.
  - *Testbenches needed for:* STA, Logic, Rotates, Compares, Moves, CALL/RET.
  - Default ROM fixture for synthesis needs update.
  - Test utilities (`run_until_halt` path) may need check/fix.

> **Phase 3 Status:** **Very Close to Complete.** Core architecture and a large portion of the base ISA are implemented and tested, including multi-byte fetch, memory access, ALU ops, and branching. Key remaining items are STA, remaining ALU/MOV ops, stack support (for CALL/RET), and associated tests.

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

1. **Implement `STA` Microcode:** Implement the store accumulator instruction (essential for MMIO and general use). Create `op_STA_tb.sv`.
2. **Implement Basic MMIO Peripheral & Test:** Add the `$E000` LED register and test MMIO writes using `LDI A` / `STA $E000`. Test MMIO reads using `LDA $E000`.
3. **Implement Remaining Microcode:** Add microcode for Logic ops (`ANA`/`ANI`, etc.), Rotates (`RAL`/`RAR`), CMP, and MOV instructions.
4. **Update/Create Testbenches:** Create/update tests for STA, Logic, Rotates, CMP, MOV.
5. **Stack Implementation (Phase 6 Prep):**
    - Add 16-bit SP register (`stack_pointer.sv` with inc/dec logic).
    - Implement `LDI SPH/SPL` or similar instructions to load SP.
    - Implement `PHA`/`PLA`.
    - Implement `CALL`/`RET`.
    - Create testbenches for stack operations.
6. **Finalize Definitions:** Ensure `num_operand_bytes` and ALU `case` statements cover all instructions.
7. **Cleanup:** Remove old files, update synthesis ROM fixture path.
8. **Review Phase 4 (Assembler):** Begin planning the assembler.
