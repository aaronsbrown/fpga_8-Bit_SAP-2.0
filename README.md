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

This is a good, concise README section for Phase 4. Based on what we've accomplished with the assembler, here are a few suggestions for updates to make it accurately reflect the current state and capabilities:

---

## Phase 4: Assembler for CPU Architecture

*(Goal: Create a robust tool to write, assemble, and generate memory images for the custom 8-bit CPU with a 16-bit address space.)*

1. **Assembler Features Implemented:**
    - **Labels & Symbols:** Full support for labels for address resolution and `EQU` for defining named constants.
    - **Mnemonics:** Comprehensive support for the instruction set architecture (ISA) mnemonics.
    - **Operand Parsing:**
        - Parses 8-bit immediate values (hex `$`, binary `%`, decimal, symbolic via `EQU`).
        - Parses 16-bit absolute addresses (hex `$`, binary `%`, decimal, symbolic via `EQU` or labels).
    - **Machine Code Generation:**
        - Generates correct 1, 2, or 3-byte machine code sequences based on the ISA.
        - Ensures little-endian encoding for multi-byte operands (addresses, `DW`).
    - **Directives:** Supports `ORG`, `EQU`, `DB` (Define Byte), `DW` (Define Word).
    - **Output Format:**
        - Generates `.hex` files suitable for Verilog's `$readmemh`.
        - Supports outputting to a **single combined hex file** (default behavior).
        - Supports outputting to **multiple, region-specific hex files** (e.g., `ROM.hex`, `RAM.hex`) based on user-defined memory regions (`--region NAME START_ADDR END_ADDR`), with addresses relative to the start of each region in the respective files.
    - **Error Handling:** Includes robust error detection and reporting for common syntax issues, undefined symbols, duplicate labels, out-of-range values, and malformed directives/instructions.
    - **Range Checking:** Validates that immediate values and addresses conform to the CPU's 8-bit data width and 16-bit address width.
    - **Comments & Formatting:** Handles various comment styles, blank lines, and label formatting.

2. **Assembler Development (Python):**
    - Implemented using a **two-pass approach** for effective label and symbol resolution.
    - Features distinct tokenization/parsing (Pass 1) and code generation (Pass 2) stages.
    - Includes a detailed symbol table and instruction set definition (`INSTRUCTION_SET`).

3. **Toolchain Integration & Usage:**
    - The assembler is a command-line Python script (`python/src/assembler.py`).
    - Assembly source files (`.asm`) are processed to generate `.hex` memory image files.
    - **Workflow:**
        1. Write assembly programs (`.asm` files, typically stored in `asm_source/`).
        2. Manually invoke the assembler to generate `.hex` files for specific memory regions (e.g., `ROM.hex`, `RAM.hex`) into a fixture directory (e.g., `test/generated_fixtures/<test_name>/`).
        3. Verilog testbenches load these generated `.hex` files using `$readmemh` for simulation.
    - Build scripts (`scripts/simulate.sh`) currently focus on Verilog compilation and simulation, using pre-generated hex files as fixtures. *(Future: `simulate.sh` could be enhanced to optionally call the assembler).*

> **Prerequisite:** Phase 3 (ISA Definition) complete.
> **Current Status:** Core assembler functionality is complete and robustly tested. The tool successfully generates memory images for the defined CPU architecture, supporting complex programs and various assembly language constructs.
> **Next Steps (Tooling):** Further integration into automated build/simulation flows if desired; documentation of the specific assembly language syntax supported.

---

## Phase 5: Basic I/O Peripheral Integration

*(Goal: Add UART communication capability using the MMIO infrastructure and the new assembler)*

1. **Implement/Integrate UART:**
    - Add UART Verilog modules (transmitter, receiver).
    - Assign specific 16-bit addresses (e.g., `$E000` Status, `$E001` Data) within the I/O range defined in Phase 2.
    - Connect UART registers to the system bus using the MMIO decoding/routing logic in `computer.sv`. Ensure `cs_uart_status`, `cs_uart_data` are generated correctly.
    - Connect UART TX/RX pins in top-level constraints (`top.v`, `.pcf`).

2. **Write Test Programs (Assembly):**
    - Use the Phase 4 assembler to write simple programs to:
        - Send a character or string out via the UART TX.
        - Poll the UART RX status register and echo received characters back.
    - *Prompt: How do you read/write to the specific UART addresses using your defined instructions (e.g., `LDA $E001`, `STA $E001`)?*

3. **Test via Simulation & Hardware:**
    - Simulate UART interaction.
    - Synthesize and test on hardware using a serial terminal connected to the FPGA.

> **Prerequisite:** Phase 3 (CPU Arch), Phase 4 (Assembler).
> **Goal:** Functional serial communication, proving MMIO and assembler viability.

---

## Phase 6: Stack & Subroutine Support

*(Goal: Enable structured programming constructs)*

1. **Design Stack Implementation:**
    - *Decision:* Will the Stack Pointer (SP) be 8-bit (fixed page, e.g., `$0100-$01FF`) or 16-bit (flexible location)? Given the 16-bit address space, a 16-bit SP is more flexible.
    - Add the chosen SP register to `cpu.sv`. Initialize appropriately (e.g., to top of intended RAM stack area like `$BFFF` if RAM is below).

2. **Implement Stack Instructions:**
    - Define 8-bit opcodes for `PHA` (Push A), `PLA` (Pull A), potentially others (`PHF`/`PLF` for flags?).
    - Implement microcode: Handle SP increment/decrement, memory read/write using the address in SP. *Prompt: Does the stack grow up or down in memory? How are 16-bit values (like PC) pushed/pulled if needed?*

3. **Implement Subroutine Instructions:**
    - Define 8-bit opcodes for `JSR abs16` (Jump to Subroutine) and `RTS` (Return from Subroutine).
    - Implement microcode:
        - `JSR`: Push the return address (`PC + 2` for a 3-byte JSR) onto the stack (handle high/low bytes). Load PC with the target subroutine address (fetched as operand bytes).
        - `RTS`: Pop the return address from the stack into the PC. Add 1? *Check 6502 RTS behavior carefully.*

4. **Assembler Support:**
    - Add mnemonics for all new stack/subroutine instructions.

> **Prerequisite:** Phase 3 complete. Assembler from Phase 4 helpful.
> **Goal:** CPU support for stack operations and subroutine calls/returns.

---

## Phase 7: Monitor Program

*(Goal: Create a basic interactive operating environment on the CPU)*

1. **Design Monitor Functionality:**
    - Define simple commands (`DUMP addr [len]`, `POKE addr data`, `GO addr`, `PEEK addr`?).
    - Plan command parsing and hex value handling via UART (Phase 5).

2. **Implement Monitor (Assembly):**
    - Use the assembler (Phase 4) and subroutine capabilities (Phase 6).
    - Write routines for UART I/O, string handling, hex conversion, memory access (`LDA`/`STA`), jumping (`JMP`/`JSR`/`RTS`).

3. **"ROM" Integration:**
    - Decide on Monitor location (e.g., high memory `$F000-$FFFF`).
    - *Decision:* How does the CPU start executing the Monitor on reset? Implement the Reset Vector mechanism (e.g., fetch start address from `$FFFC`/`$FFFD`). Update control unit reset sequence.
    - Generate monitor `.hex` file and configure `ram.sv`'s `$readmemh` to load it into the designated "ROM" area (or use separate ROM module if preferred).

4. **Test Monitor:**
    - Use simulation and hardware with a serial terminal to interact with the monitor. Load/run simple programs entered via `POKE`.

> **Prerequisite:** Phase 5 (UART), Phase 6 (Stack/Subroutines).
> **Goal:** A self-hosted environment for loading and running small user programs. Reset vector implemented.

---

## Phase 8: Expanded Instruction Set & Addressing Modes

*(Goal: Increase the computational power and flexibility of the CPU beyond the basics)*

1. **Add More ALU Instructions:**
    - Define opcodes and implement microcode for missing logical/arithmetic (`XOR`, `INC A`/`DEC A`, Shifts/Rotates like `ASL`, `LSR`, `ROL`, `ROR`). Consider implied addressing (acting on Accumulator A).

2. **Add Comparison & Conditional Branches:**
    - Define opcode/microcode for `CMP imm8 / abs16` (Compare A with memory/immediate, sets flags Z, N, C based on `A - operand`). *Note: Does not store result, only sets flags.*
    - Define opcodes/microcode for conditional branches (`BEQ`, `BNE`, `BCC`, `BCS`, `BMI`, `BPL`).
    - *Design Decision:* Use relative addressing? Fetch an 8-bit signed offset operand byte. Calculate target address `PC + 2 + offset`. Update control unit branch logic.

3. **Consider Zero Page Addressing:**
    - Define instructions like `LDA zp`, `STA zp` (2 bytes: Opcode, ZP Address Byte).
    - *Prompt: How does the control unit microcode form the 16-bit address `$00xx`?*

4. **Consider Indexed Addressing (Optional):**
    - Add X/Y index registers (8-bit).
    - Add instructions `INX`/`DEX`/`INY`/`DEY`, `LDX`/`LDY`, `STX`/`STY`.
    - Define addressing modes like `LDA abs,X`, `STA zp,X`. *Prompt: How is the effective address calculated in microcode? Does it require extra cycles?*

5. **Update Assembler:**
    - Add mnemonics and operand handling for all new instructions and addressing modes.

> **Prerequisite:** Phase 3 complete, Phase 4 (Assembler).
> **Goal:** A richer, more capable instruction set closer to standard 8-bit CPUs.

---

## Phase 9: Interrupt Handling

*(Goal: Allow external events to interrupt CPU execution for timely service)*

1. **Hardware Implementation:**
    - Add `IRQ_n` (maskable) and potentially `NMI_n` (non-maskable, active low) input pins to `cpu.sv`.
    - Implement logic in `control_unit.sv` to check these inputs (typically after each instruction completes).

2. **Interrupt Sequence Logic (Control Unit):**
    - If an enabled interrupt is detected:
        - Finish current instruction.
        - Push PC onto stack (high byte, then low byte).
        - Push Status Register (Flags) onto stack. *Consider 6502 B flag behavior if implementing `BRK`.*
        - Set the Interrupt Disable flag ('I' flag) in the status register (for IRQ, not NMI).
        - Fetch the ISR address vector: Load PC from fixed locations (e.g., NMI: `$FFFA`/`B`, IRQ/BRK: `$FFFE`/`F`). Place these vectors in the Monitor "ROM" area.

3. **Add Related Instructions:**
    - Define opcodes/microcode for `RTI` (Return from Interrupt): Pop Flags, Pop PC from stack.
    - Define opcodes/microcode for `SEI` (Set Interrupt Disable) / `CLI` (Clear Interrupt Disable) to manipulate the 'I' flag.
    - *(Optional)* Define opcode/microcode for `BRK` (Software Interrupt) which triggers the IRQ sequence.

4. **ISR Implementation (Monitor/ROM):**
    - Write basic Interrupt Service Routines in assembly, pointed to by the vectors.
    - *Prompt (if single IRQ vector):* How does the ISR determine which device caused the IRQ (polling device status registers)?
    - Ensure ISRs preserve registers they modify (push/pop) and end with `RTI`.

5. **Assembler & Testbench Updates:**
    - Add mnemonics for `RTI`, `SEI`, `CLI`, `BRK`.
    - Update testbenches to simulate IRQ/NMI signals and verify the interrupt sequence and ISR execution.

> **Prerequisite:** Phase 7 (Monitor), Phase 8 (Rich ISA). Requires stack.
> **Goal:** CPU can respond to external events asynchronously via interrupts.

---

## Phase 10: Debugging Features - Single-Step

*(Goal: Add hardware support for easier debugging)*

1. **Integrate Button Conditioner:**
    - Use `button_conditioner.v` for a physical "step" button input. Ensure it's synchronized and debounced, outputting a single-cycle pulse (`step_pulse`).

2. **Add Mode Switch:**
    - Use a DIP switch as a "Run/Step" mode selector. Synchronize its input (`sw_single_step_mode`).

3. **Implement Clock Enable Logic:**
    - Generate `cpu_clock_enable = sw_single_step_mode ? step_pulse : 1'b1;`
    - Modify *all* synchronous elements within `cpu.sv` (PC, A, B, IR, MAR, Flags, SP, Control Unit state regs) to only update `if (cpu_clock_enable)`.

4. **Enhance Debug Outputs:**
    - Connect more internal CPU state (MAR, SP, Control Word bits?) to unused `io_led` pins for visibility during single-stepping.

> **Prerequisite:** A working CPU (at least Phase 3).
> **Goal:** Ability to freeze CPU state and advance one clock cycle at a time for debugging.

---

## Phase 11: Advanced Peripherals & Demo Projects

*(Goal: Integrate more complex hardware and build showcase applications)*

1. **Implement Advanced Peripherals:**
    - Add SPI controller (memory-mapped registers).
    - Add Timer module (memory-mapped registers).
    - Interface with target devices (e.g., SSD1306 OLED via SPI, PS/2 Keyboard). Map via MMIO.

2. **Write Demo Applications (Assembly):**
    - Use the monitor to load more complex programs.
    - Example: Snake game on OLED (requires graphics primitives, game logic, input handling, timing).
    - Example: Simple command line interface using Keyboard and UART.

> **Prerequisite:** Most preceding phases, particularly MMIO, Assembler, Monitor, potentially Interrupts.
> **Goal:** Demonstrate the capabilities of the completed CPU system by interfacing with interesting peripherals and running non-trivial software.
