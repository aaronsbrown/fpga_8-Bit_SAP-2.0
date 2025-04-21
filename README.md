# SAP‑1.5 Extensions: Phased Roadmap (Revised)

This document organizes all proposed extensions to the SAP‑1.5 FPGA CPU into discrete phases, ordered by prerequisites. Use this as a checklist to progressively evolve the design toward a SAP‑2–style architecture and richer I/O capabilities.

---

## Prerequisites

- **Stable SAP‑1.5 Core**: 8‑bit data, 4‑bit address, microcoded control unit, 16‑instruction set (including conditional jumps and flags register), shared bus, synchronous design.
- **Toolchain & Testbench**: Working simulation (Icarus + GTKWave), open‑source synthesis (Yosys + nextpnr for iCE40), existing monitor code & assembler for hex file loading (if any, maybe just hand-assembled hex initially).
- **Target Platform:** Confirmed FPGA board and toolchain (e.g., iCE40 + Yosys/nextpnr).

---

## ~~Phase 1: Core Bus Interface Refactor~~ (DONE)

1. **Extract CPU Core (`cpu_core.sv`)**
    - Rename `cpu.sv` → `cpu_core.sv`.
    - Expose a minimal memory bus interface:
        - `mem_addr[ADDR_WIDTH-1:0]`
        - `mem_data_out[DATA_WIDTH-1:0]` (Data CPU writes TO bus)
        - `mem_data_in[DATA_WIDTH-1:0]` (Data CPU reads FROM bus)
        - `mem_write` (Write enable strobe from CPU)
        - `oe_ram` (Used internally/externally to indicate CPU read cycle)
    - Expose necessary signals for external Output Register (`load_o`, `oe_a`, `a_out_bus`).
    - Internally replace direct `ram` and `u_register_OUT` instantiations with bus signals connected to ports. Update internal bus logic.

2. **Create Top‑Level Wrapper (`computer.sv` or `top.sv`)**
    - Instantiate `cpu_core.sv`, `ram.sv`, and the Output Register (`register_nbit`).
    - Connect the memory interface between the core and RAM.
    - Implement logic to drive the Output Register based on control signals from the core.

> **Prerequisite:** Existing SAP‑1.5 design, familiarity with Verilog module I/O refactoring.
> **Goal:** Modular CPU core separated from memory system.

---

## Phase 2: Memory‑Mapped I/O Infrastructure

1. **Define I/O Address Map**
    - Decide on an address range (e.g., `0xF0–0xFF` if still 4-bit address, or higher range after expansion) reserved for peripherals.
    - Document each planned I/O address’s function (LEDs, UART status, UART data, etc.).

2. **Implement Address Decoder in Wrapper**
    - In the top-level module (`computer.sv`), add logic that checks the `mem_addr` from the CPU core.
    - Generate chip-select signals (`cs_ram`, `cs_io_device_1`, etc.) based on the address.

3. **Route Bus Signals based on Decode**
    - Use chip selects to route `mem_write` and `mem_read` (`oe_ram`) signals appropriately (to RAM or I/O).
    - Multiplex data read onto `mem_data_in`: If `cs_ram` is active during a read, route `ram.data_out`; if `cs_io_device_1` is active, route data from that device.
    - Route `mem_data_out` to RAM *or* I/O devices based on chip selects during a write.

4. **Add Basic I/O Register (e.g., LEDs)**
    - Instantiate a simple register (e.g., 8-bit flip-flop) in the wrapper at a specific I/O address (e.g., `0xF0`).
    - Connect its `load` input to `mem_write` ANDed with its chip select (`cs_led_reg`).
    - Connect its `data_in` to `mem_data_out`.
    - Connect its output to board LEDs.

5. **Update Testbench**
    - Simulate reads/writes to RAM and the new I/O LED register address. Verify correct behavior and chip select logic.

> **Prerequisite:** Phase 1 complete.
> **Goal:** Mechanism to interact with specific memory addresses as distinct I/O devices.

---

## Phase 3: Address Bus Expansion

1. **Increase `ADDR_WIDTH` Parameter**
    - Update `ADDR_WIDTH` in `arch_defs_pkg.sv` (e.g., to 8 for 256 bytes).
    - Update dependent parameters like `RAM_DEPTH`.

2. **Update Core Components**
    - Modify `program_counter.sv` and `register_nbit.sv` (for MAR) to use the new `ADDR_WIDTH`.
    - Ensure `cpu_core.sv` uses the updated width for `mem_address` port and internal connections.

3. **Expand RAM Module**
    - Update `ram.sv` to use the new `ADDR_WIDTH` and `RAM_DEPTH`.

4. **Update Top-Level Wrapper**
    - Ensure address decoding logic (Phase 2) handles the wider address bus correctly. Adjust I/O address map if necessary (e.g., move to `0xFFF0` if using 16-bit address).

5. **Update Testbenches & Fixtures**
    - Adapt tests to use wider addresses.
    - Update `.hex` file fixtures if needed, potentially clearing or initializing larger RAM space.

> **Prerequisite:** Phase 2 complete.
> **Goal:** Provide sufficient memory space for more complex software. Crucial blocker removed.

---

## Phase 4: Basic I/O & Assembler

1. **UART Receiver & Transmitter**
    - Implement or integrate memory-mapped UART Verilog modules.
    - Assign addresses (e.g., `0xFFF0` status, `0xFFF1` data if using 8-bit address) and connect via MMIO infrastructure.
    - Connect UART TX/RX pins in top-level constraints.

2. **Custom Python Assembler**
    - Develop or adapt a simple two-pass assembler (Python recommended).
    - Map current instruction mnemonics to opcodes.
    - Support labels for addresses and jumps.
    - Generate `.hex` files suitable for `$readmemh`.
    - *Develop this concurrently with UART testing.* Use the assembler to write test programs for the UART.

3. **(Optional) Other Basic Peripherals**
    - Implement PS/2 Keyboard interface if needed early.
    - Refine LED output register (if added in Phase 2).

4. **Toolchain Integration**
    - Integrate assembler into build scripts (e.g., `build.sh` could optionally run `assemble.py` first).

> **Prerequisite:** Phase 3 complete.
> **Goal:** Enable text-based I/O and significantly improve software development efficiency. Crucial blocker removed.

---

## Phase 5: Monitor Program

1. **Design Monitor Functionality**
    - Define simple commands (`LOAD`, `GO`, `DUMP`, `PEEK`, `POKE`?).
    - Plan how commands and data (hex characters) will be input via UART/Keyboard.

2. **Implement Monitor in Assembly**
    - Write the monitor program using your new assembler.
    - Implement routines for reading input, parsing hex, writing to memory (`STA`), reading from memory (`LDA`), jumping (`JMP`), outputting to UART.

3. **Loading the Monitor**
    - Decide how the monitor gets into RAM initially (e.g., initialized via `$readmemh` in simulation/synthesis, or a smaller hardware bootloader). Update `.hex` fixtures.

4. **Test Monitor**
    - Use simulation or hardware with a serial terminal to interact with the monitor. Load and run simple test programs via the monitor.

> **Prerequisite:** Phase 4 complete.
> **Goal:** Basic operating environment on the CPU for loading and running user code.

---

## Phase 6: Stack & Subroutine Support

1. **Stack Pointer (`SP`) Register**
    - Add an 8‑bit `SP` register to `cpu_core.sv` (or wider if data width increases later). Initialize appropriately (e.g., `0xFF`).
    - Define stack memory area (implicitly `0x0100 + SP` if `ADDR_WIDTH` becomes > 8, or within the current address space if SP is only 8-bit and `ADDR_WIDTH`=8).

2. **`PUSH A`/`POP A` Instructions (Example)**
    - Add microcode for `PUSH A`: Decrement SP, write A to address SP.
    - Add microcode for `POP A`: Read from address SP, increment SP, load A.
    - (Consider PUSH/POP B, or maybe PUSH/POP Flags later).

3. **`CALL addr` / `RET` Instructions**
    - Microcode for `CALL addr`: Push `PC+1` (return address) onto stack (handle high/low bytes if PC > 8 bits), Set `PC ← addr`.
    - Microcode for `RET`: Pop return address from stack into PC.

4. **Assembler Support**
    - Add mnemonics for new stack/subroutine instructions.

> **Prerequisite:** Phase 5 complete (Monitor helps test).
> **Goal:** Enable structured programming with subroutines.

---

## Phase 7: Expanded Instruction Set

1. **Add More Instructions**
    - Add `CMP` (sets flags based on A - Mem).
    - Add more conditional branches (`BNE`, `BCC`, `BCS`, `BMI`, `BPL` etc.) using flags.
    - Implement missing logical/arithmetic (`XOR`, `INC A`, `DEC A`, `SHL`, `SHR`, `ROL`, `ROR`).
    - Consider `INX`, `DEX`, `INY`, `DEY` if Index Registers are planned.

2. **Update Microcode**
    - Add entries to the microcode ROM for all new instructions.

3. **Update Assembler**
    - Add mnemonics and operand handling for new instructions.

> **Prerequisite:** Phase 6 complete.
> **Goal:** Increase the computational power and flexibility of the CPU.

---

## Phase 8: Two‑Phase Microcode (Optimization - Optional)

1. **Analyze Microcode Redundancy**
    - Identify common sequences (e.g., operand fetch based on addressing mode).

2. **Split ROMs (Conceptual)**
    - Design an Address‑Mode ROM/sequencer.
    - Design an Operation ROM/sequencer.

3. **Implement Microsequencer FSM**
    - Refactor `control_unit.sv` to use the two-phase approach (e.g., Fetch Opcode -> Fetch Operand/Address -> Execute).

> **Prerequisite:** Phase 7 complete (provides a rich instruction set to optimize).
> **Goal:** Potentially reduce microcode ROM size and complexity, structure control flow. May not be necessary depending on complexity.

---

## Phase 9: Multi‑Byte Instructions & Addressing Modes

1. **Multi‑Byte Fetch FSM**
    - Modify the microsequencer (Phase 8 or existing) to fetch 2 or 3 bytes for instructions needing immediate data or 16-bit addresses (if `ADDR_WIDTH` >= 16). Example: `LDA #$12`, `LDA $1234`.

2. **Implement Addressing Modes**
    - Add microcode sequences to handle different addressing modes (Immediate, Zero Page, Absolute, Indexed Indirect, etc.) if desired, potentially linking to Phase 8.

3. **Assembler & Monitor Updates**
    - Modify assembler to generate multi-byte instruction encodings.
    - Update monitor (if necessary) to handle loading multi-byte values correctly.

> **Prerequisite:** Phase 3 (Wide Address), Phase 7 (Expanded Instructions), Phase 8 (useful for complex modes).
> **Goal:** Support more complex instructions and memory access patterns similar to 6502/Z80.

---

## Phase 10: Advanced Peripherals & Demo Projects (e.g., Snake)

1. **Implement Advanced Peripherals**
    - Add SPI controller (memory-mapped registers for control/data).
    - Interface with target device (e.g., SSD1306 OLED).
    - Finish PS/2 Keyboard or other input devices.

2. **Demo Project: Snake on OLED**
    - **Hardware:** Requires SPI OLED, input device (Keyboard/buttons).
    - **Software (using Assembler):**
        - Allocate framebuffer in RAM (now feasible due to Phase 3).
        - Write graphics primitives (`DRAW_PIXEL`, `CLEAR_SCREEN`, etc.) using MMIO SPI.
        - Implement game loop, snake logic (list/buffer management), collision detection, input handling in assembly.
        - Utilize timer/delay loops if needed.

> **Prerequisite:** Phase 3 (Wide Address), Phase 4 (Assembler, Basic I/O), Phase 5 (Monitor helps load), Phase 9 (if needed for SPI), MMIO SPI controller.
> **Goal:** Integrate multiple components into a functional, interactive application. Showcase the capabilities of the expanded SAP CPU.
