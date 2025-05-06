# CPU Development Roadmap (FPGA)

This document outlines the planned evolution of a custom 8-bit CPU implemented on an FPGA, starting from a simple SAP-like base and progressing towards a more capable 6502-inspired architecture with 64KB addressing and expanded capabilities.

---

## Prerequisites

- **Stable Core v0.1**: (Conceptual starting point) 8‑bit data (`DATA_WIDTH=8`), 4‑bit address (`ADDR_WIDTH=4`), microcoded control unit, 16‑instruction set (`OPCODE_WIDTH=4`), shared internal bus, synchronous design.
- **Modular Structure**: CPU logic encapsulated (`cpu.sv`), separated from memory (`ram_8k.sv`, etc.) and top-level wrapper (`computer.sv`, `top.v`).
- **Toolchain & Testbench**: Working simulation (Icarus + GTKWave), open‑source synthesis (Yosys + nextpnr for iCE40), testbenches for current instructions, ability to load `.hex` files.
- **Target Platform:** Confirmed FPGA board and toolchain (Alchitry Cu - iCE40HX8K + Yosys/nextpnr).

---

## Phase 2: Memory‑Mapped I/O (MMIO) Infrastructure

*(Goal: Establish the hardware mechanism for CPU interaction with peripheral registers at specific memory addresses, independent of final address width)*

1. **Conceptual I/O Address Range:**
    - Mentally reserve a block of addresses for future I/O peripherals (e.g., high addresses like `$E000-$EFFF` or `$F000-$FFFF` in the eventual 16-bit space).
    - Document intended registers (e.g., UART Status, UART Data, LED Output, Timer Control).
2. **Implement Address Decoder Logic (in `computer.sv` / `top.sv`):**
    - Add logic that monitors the CPU's `mem_address` output.
    - Based on the address range detected, generate chip-select signals (e.g., `cs_ram`, `cs_vram`, `cs_rom`, `cs_mmio`).
3. **Implement Bus Routing Logic (in `computer.sv` / `top.sv`):**
    - Use the chip selects to control data flow for reads and writes to the appropriate memory or I/O region.
4. **Add Basic Output Register (LEDs):**
    - Instantiate an 8-bit register in the wrapper (`computer.sv`).
    - Assign it a specific address within the I/O range (e.g., `$E000`).
    - Connect its load input to `cpu_mem_write` gated by its chip select.
    - Connect its data input to `cpu_mem_data_out`.
    - Connect its output to physical board LEDs.
5. **Update Testbench:**
    - Simulate basic RAM access and MMIO writes/reads to the test peripheral.

> **Prerequisite:** Phase 1 complete.
> **Goal:** Hardware infrastructure in place for address decoding and routing to support memory-mapped peripherals, and a simple test peripheral.

---

## Phase 3: Architecture Overhaul - 64KB Address Space & Expanded ISA Foundation

*(Goal: Transition to a 16-bit address space and lay the foundation for a richer instruction set by adopting 8-bit opcodes and implementing multi-byte instruction fetching)*

1. **Redefine Core Architecture Parameters (in `arch_defs_pkg.sv`):**
    - Set `ADDR_WIDTH = 16`.
    - Set `OPCODE_WIDTH = 8`.
    - Set `OPERAND_WIDTH = 0` (operands fetched as separate bytes).
    - Define initial 8-bit opcodes, FSM states for multi-byte fetch, `RESET_VECTOR`.
2. **Resize Core Hardware Components:**
    - Modify `program_counter.sv` to handle 16 bits (including PC load from reset vector and for jumps).
    - Modify Memory Address Register (MAR) to be 16 bits.
    - Implement specific memory blocks (`ram_8k`, `vram_4k`, `rom_4k`) based on the memory map.
3. **Re-architect MAR Loading (in `cpu.sv`):**
    - Implement mechanism for MAR to be loaded from PC (for fetches) or from temporary registers (for addresses assembled from operand bytes).
4. **Adapt Instruction Register (in `cpu.sv`):**
    - Instruction Register (IR) latches the 8-bit opcode.
5. **Overhaul Control Unit (`control_unit.sv`) for Multi-Byte Fetching:**
    - Design new FSM capable of fetching 1, 2, or 3 bytes per instruction based on the 8-bit opcode.
    - Implement `num_operand_bytes` logic based on opcode.
    - Implement temporary operand registers (`temp_1`, `temp_2`) for multi-byte instructions.
    - Restructure microcode ROM access to use the 8-bit opcode.
6. **Define & Implement Initial 8-bit ISA:**
    - Define 8-bit encodings for a base set of instructions (e.g., NOP, HLT, LDI, LDA, STA, JMP, basic ALU ops).
    - Implement microcode sequences for these instructions, handling operand fetching and 16-bit address formation.
7. **Update Address Decoder (Phase 2 Logic):**
    - Ensure the address decoder in `computer.sv` handles the full 16-bit `mem_address` for the defined memory map.
8. **Update Testbenches & Fixtures:**
    - Create new testbenches and `.hex` files for the 8-bit, multi-byte ISA.

> **Prerequisite:** Phase 2 complete.
> **Goal:** CPU core capable of fetching multi-byte instructions, addressing 64KB of memory, and executing a functional base set of instructions using 8-bit opcodes.
