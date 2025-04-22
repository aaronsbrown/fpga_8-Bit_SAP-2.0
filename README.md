# CPU Development Roadmap (FPGA)

This document outlines the planned evolution of a custom 8-bit CPU implemented on an FPGA, starting from a simple SAP-like base and progressing towards a more capable 6502-inspired architecture with 64KB addressing and expanded capabilities.

---

## Prerequisites

- **Stable Core v0.1**: 8‑bit data (`DATA_WIDTH=8`), 4‑bit address (`ADDR_WIDTH=4`), microcoded control unit, 16‑instruction set (`OPCODE_WIDTH=4`), shared internal bus, synchronous design. (Your current state).
- **Modular Structure**: CPU logic encapsulated (`cpu.sv`), separated from memory (`ram.sv`) and top-level wrapper (`computer.sv`, `top.v`). (Phase 1 completed).
- **Toolchain & Testbench**: Working simulation (Icarus + GTKWave), open‑source synthesis (Yosys + nextpnr for iCE40), testbenches for current instructions, ability to load `.hex` files.
- **Target Platform:** Confirmed FPGA board and toolchain (e.g., iCE40 + Yosys/nextpnr).

---

## Phase 2: Memory‑Mapped I/O (MMIO) Infrastructure

*(Goal: Establish the hardware mechanism for CPU interaction with peripheral registers at specific memory addresses, independent of final address width)*

1. **Conceptual I/O Address Range:**
    - Mentally reserve a block of addresses for future I/O peripherals (e.g., high addresses like `$E000-$EFFF` or `$F000-$FFFF` in the eventual 16-bit space). *Question: Why might placing I/O high be advantageous for address decoding?*
    - Document intended registers (e.g., UART Status, UART Data, LED Output, Timer Control).

2. **Implement Address Decoder Logic (in `computer.sv` / `top.sv`):**
    - Add logic that monitors the CPU's `mem_address` output.
    - Based on the address range detected (initially just RAM vs. non-RAM), generate basic chip-select signals (e.g., `cs_ram`, `cs_io`). *Note: This decoder will become more complex as address width increases and more devices are added.*

3. **Implement Bus Routing Logic (in `computer.sv` / `top.sv`):**
    - Use the chip selects (`cs_ram`, `cs_io`) to control data flow:
        - Route `cpu_mem_write` signal to either RAM's `we` input *or* to the load enable of I/O registers.
        - Multiplex data onto the `cpu_mem_data_in` lines: select either `ram_data_out` *or* the output of an I/O device based on which chip select is active during a CPU read (`cpu_mem_read`).
        - Route `cpu_mem_data_out` to either RAM's `data_in` *or* to the data inputs of I/O devices during a CPU write.

4. **Add Basic Output Register (LEDs):**
    - Instantiate an 8-bit register in the wrapper (`computer.sv`).
    - Assign it a specific address within your conceptual I/O range (even if the CPU can't address it yet, the decoding logic can be designed).
    - Generate its specific chip select (e.g., `cs_led_reg` based on the full target address).
    - Connect its load input: `load_led_reg = cpu_mem_write & cs_led_reg`.
    - Connect its data input: `data_in_led_reg = cpu_mem_data_out`.
    - Connect its output to physical board LEDs.

5. **Update Testbench:**
    - Simulate basic RAM access.
    - *Optional:* Manually drive the `mem_address` bus in the testbench to test the I/O address decoding and LED register functionality, even if the CPU can't generate those addresses yet. Verify chip selects and data routing.

> **Prerequisite:** Phase 1 complete.
> **Goal:** Hardware infrastructure in place for address decoding and routing to support memory-mapped peripherals.

---

## Phase 3: Architecture Overhaul - 64KB Address Space & Expanded ISA Foundation

*(Goal: Transition to a 16-bit address space and lay the foundation for a richer instruction set by adopting 8-bit opcodes and implementing multi-byte instruction fetching)*

1. **Redefine Core Architecture Parameters (in `arch_defs_pkg.sv`):**
    - Set `ADDR_WIDTH = 16`. *Consider: How does this affect `RAM_DEPTH`?*
    - Set `OPCODE_WIDTH = 8`. *Consider: How many instruction types are now possible?*
    - Set `OPERAND_WIDTH = 0`. *Consider: What does this imply about how operands (immediate data, addresses) must be provided to instructions?*
    - Update `instruction_t` struct if necessary.

2. **Resize Core Hardware Components:**
    - Modify `program_counter.sv` to handle 16 bits.
    - Modify `register_nbit.sv` instance used for the Memory Address Register (MAR) to be 16 bits (`cpu.sv`).
    - Modify `ram.sv` to use the 16-bit address and new `RAM_DEPTH`.
    - Update `mem_address` port width in `cpu.sv` and `computer.sv`.

3. **Re-architect MAR Loading (in `cpu.sv`):**
    - The MAR can no longer be loaded directly from the 8-bit `internal_bus` in one step.
    - *Design Decision:* How will the 16-bit MAR be loaded?
        - Option A: Direct 16-bit path from PC for fetches, plus byte-wise loading from `internal_bus` for address operands?
        - Option B: Multiplex the external `mem_address` bus source (PC vs MAR output), with MAR loaded byte-wise from `internal_bus`?
    - Implement the chosen mechanism. *Prompt: What new control signals might the MAR need (e.g., `load_mar_low`, `load_mar_high`, `load_mar_from_pc`)?*

4. **Adapt Instruction Register (in `cpu.sv` / `register_instruction.sv`):**
    - With `OPERAND_WIDTH = 0`, how should `register_instruction.sv` function? Does it still need separate `opcode` and `operand` outputs? Or just output the full 8-bit fetched instruction byte?

5. **Overhaul Control Unit (`control_unit.sv`) for Multi-Byte Fetching:**
    - The existing Fetch/Decode/Execute FSM is insufficient.
    - Design a new FSM capable of fetching 1, 2, or 3 bytes per instruction based on the 8-bit opcode. *Sketch state transitions:* Fetch Opcode -> Decode Opcode -> Fetch Operand Byte 1 (if needed) -> Fetch Operand Byte 2 (if needed) -> Execute.
    - *Prompt: How does the control unit know how many operand bytes an instruction requires? How does the PC increment correctly during these fetch cycles? What new states are needed?*
    - Restructure the microcode ROM access to use the 8-bit opcode.
    - *Prompt: What new control signals are needed to manage the multi-byte fetch and load operands (e.g., signals related to MAR loading, potentially temporary operand storage)?*

6. **Define & Implement Initial 8-bit ISA:**
    - Define the 8-bit encodings for a *basic* set of instructions necessary for testing. Examples:
        - `NOP` (1 byte)
        - `LDI A, #imm8` (2 bytes: Opcode, Imm8)
        - `LDA abs16` (3 bytes: Opcode, AddrLow, AddrHigh)
        - `STA abs16` (3 bytes: Opcode, AddrLow, AddrHigh)
        - `JMP abs16` (3 bytes: Opcode, AddrLow, AddrHigh)
        - `HLT` (1 byte)
    - Implement the microcode sequences for these instructions within the new multi-byte FSM structure. Pay close attention to fetching/storing operand bytes and loading the MAR correctly.

7. **Update Address Decoder (Phase 2 Logic):**
    - Modify the address decoder in `computer.sv` to handle the full 16-bit `mem_address`, correctly selecting RAM vs. the I/O space (e.g., `$E000-$FFFF`).

8. **Update Testbenches & Fixtures:**
    - Create new testbenches focusing on the multi-byte fetch sequences and basic instructions (LDI, LDA abs, STA abs, JMP abs, HLT).
    - Create new `.hex` files using the 8-bit opcodes and multi-byte formats. Initialize a larger RAM space.

> **Prerequisite:** Phase 2 complete.
> **Goal:** CPU core capable of fetching multi-byte instructions, addressing 64KB of memory, and executing a minimal set of instructions using 8-bit opcodes. Foundational architecture for future expansion is established.

---

## Phase 4: Assembler for New Architecture

*(Goal: Create a tool to simplify writing programs for the new 16-bit address, 8-bit opcode, multi-byte ISA)*

1. **Design Assembler Features:**
    - Support for labels (address resolution).
    - Mnemonics for the instructions defined in Phase 3.
    - Parsing of 8-bit immediate values and 16-bit absolute addresses.
    - Generation of correct 1, 2, or 3-byte machine code sequences.
    - Output `.hex` format suitable for `$readmemh`.

2. **Develop Assembler (e.g., Python):**
    - Implement tokenization, parsing, symbol table management (two-pass approach recommended for labels).
    - Map mnemonics and operands to binary machine code based on your ISA definition.

3. **Toolchain Integration:**
    - Integrate assembler into build scripts (e.g., `build.sh` could optionally run `assemble.py` first).

> **Prerequisite:** Phase 3 complete.
> **Goal:** Ability to write and assemble programs using symbolic labels and mnemonics, targeting the new CPU architecture.

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
