# SAP‑1.5 Extensions: Phased Roadmap

This document organizes all proposed extensions to the SAP‑1.5 FPGA CPU into discrete phases, ordered by prerequisites. Use this as a checklist to progressively evolve the design toward a SAP‑2–style architecture and richer I/O capabilities.

---

## Prerequisites

- **Stable SAP‑1.5 Core**: 8‑bit data, 4‑bit address, microcoded control unit, 16‑instruction set (including conditional jumps and flags register), shared bus, synchronous design.  
- **Toolchain & Testbench**: Working simulation (Icarus + GTKWave), open‑source synthesis (Yosys + nextpnr), existing monitor code & assembler for hex file loading.

---

## Phase 1: Core Bus Interface Refactor

1. **Extract CPU Core (`cpu.sv`)**  
   - Rename `computer.sv` → `cpu.sv`.  
   - Expose a minimal memory‑bus interface:  
     - `mem_addr[7:0]`, `mem_data_out[7:0]`, `mem_data_in[7:0]`, `mem_read`, `mem_write`.  
   - Internally replace direct `ram` and `u_register_OUT` instantiations with bus signals.

2. **Create Top‑Level Wrapper (`computer.sv`)**  
   - Instantiate `cpu.sv` and implement address decode + bus multiplexer.  
   - Route `mem_read/write` & `mem_addr` to underlying RAM or I/O blocks.

> **Prerequisite:** Existing SAP‑1.5 design, familiarity with Verilog module I/O refactoring.

---

## Phase 2: Memory‑Mapped I/O Infrastructure

1. **Define I/O Address Map**  
   - Reserve high addresses, e.g. `0xF0–0xFF`, for peripherals.  
   - Document each address’s function (LEDs, status, command, data registers).

2. **Implement I/O Registers in Wrapper**  
   - For each reserved address, add flip‑flops or small logic in `computer.sv`:  
     ```verilog
     if (mem_write && mem_addr == 8'hF0) led_reg <= mem_data_out;
     if (mem_read  && mem_addr == 8'hF1) mem_data_in = key_status_reg;
     ```
3. **Update Testbench**  
   - Simulate reads/writes to I/O addresses and verify register behavior.

> **Prerequisite:** Phase 1 complete.

---

## Phase 3: Basic Peripherals (UART/Keyboard & Display)

1. **UART Receiver & Transmitter**  
   - Build memory‑mapped UART with status & data registers.  
   - Map to addresses, e.g. `0xF2` (status), `0xF3` (data).

2. **Character LCD Controller (HD44780, 4‑bit mode)**  
   - Create an FSM that latches `cmd` and `data` registers and toggles RS/E, D4–D7 with proper timing.  
   - Memory‑map to `LCD_CMD_ADDR` and `LCD_DATA_ADDR`.

3. **PS/2 Keyboard (Optional)**  
   - Add a small PS/2 interface FSM.  
   - Expose scancode and status via memory‑mapped registers.

### Demo Project: Snake on OLED

- **Hardware:** SPI‑driven SSD1306 or SH1106 128×64 OLED module, PS/2 keyboard or directional buttons for input. Utilize memory‑mapped SPI command and data registers defined in Phase 3.  
- **Software:**  
  1. Allocate a portion of RAM as a framebuffer (8×8 or 16×16 pixel grid, scaled to 128×64).  
  2. Implement framebuffer routines in assembly: `DRAW_PIXEL`, `CLEAR_SCREEN`, `BLIT_FRAMEBUFFER` via SPI.  
  3. Develop a game loop: maintain a linked list or circular buffer of snake segments in memory; poll input for direction changes; advance the head; detect collisions (self or walls); update tail.  
  4. Use a simple timer or delay loop (`OUT TIMER_REG`) to pace movement.  
- **Learning Goals:**  
  - Memory‑mapped SPI I/O and OLED controller timing.  
  - Framebuffer organization and efficient screen updates.  
  - Real‑time game logic in constrained assembly (list management, collision detection).  
  - Integration of peripherals, timer, and CPU in a cohesive demo.

> **Prerequisite:** Phase 2 complete.

---

## Phase 4: Monitor & Assembler Integration

1. **Monitor Program**  
   - Write a bootloader in RAM that:  
     - Prompts for commands (`LOAD`, `GO`, `DUMP`).  
     - Reads hex bytes via UART/keyboard.  
     - Stores them to memory (`STA addr`).  
     - Jumps to user code on `GO`.

2. **Custom Python Assembler**  
   - Adapt your Hack assembler: map mnemonics → opcodes, support labels, generate `.hex` files.  
   - Automate building monitor+user programs into FPGA ROM or `.hex` fixtures.

> **Prerequisite:** Phases 1–3 complete.

---

## Phase 5: Stack & Subroutine Support

1. **Stack Pointer (`SP`) Register**  
   - Add an 8‑bit `SP` register initialized to `0xFF`.  
   - Memory at `0x0100+SP` becomes the hardware stack.

2. **`CALL` / `RET` Instructions**  
   - Microcode for `CALL addr`:  
     1. Push `PC+1` high & low bytes onto stack.  
     2. Set `PC ← addr`.  
   - Microcode for `RET`:  
     1. Pop low & high bytes, set `PC ← popped + 1`.

3. **Assembler Support**  
   - Recognize `CALL`/`RET`, manage label resolution.

> **Prerequisite:** Phases 1–4 complete.

---

## Phase 6: Expanded Instruction Set

1. **Compare & Branch**  
   - Add `CMP addr` (sets flags only).  
   - Add `BNE`, `BCC`, `BCS`, etc., as needed.

2. **Arithmetic & Logic**  
   - Implement `XOR`, `INC`, `DEC`, `SHL`, `SHR`, `ROL`, `ROR`.

3. **Immediate & Accumulator Variants**  
   - Extend microcode or addressing‑mode sequencer to support immediate operands.

> **Prerequisite:** Phases 1–5 complete.

---

## Phase 7: Two‑Phase Microcode (Towards SAP‑2)

1. **Address‑Mode ROM**  
   - Extract common fetch & operand‑fetch sequences into a small table indexed by mode.

2. **Operation ROM**  
   - Extract ALU/memory‑write sequences into a table indexed by operation.

3. **Microsequencer FSM**  
   - Three phases: Fetch → Addr‑Mode → Execute.

> **Prerequisite:** Phases 1–6 complete.

---

## Phase 8: Wider Address & Multi‑Byte Instructions

1. **Increase `ADDR_WIDTH` to 8**  
   - Parameterize address bus & RAM depth.

2. **Multi‑Byte Fetch FSM**  
   - Support 2‑ or 3‑byte instructions (op + immediate or 16‑bit address) in your microsequencer.

3. **Assembler & Monitor Updates**  
   - Emit 2‑byte or 3‑byte instruction words in `.hex` output.

> **Prerequisite:** Phases 1–7 complete.

---

**By following these phases in order, you’ll gradually transform your SAP‑1.5 FPGA CPU into a far more powerful, modular companion—ultimately approaching a full SAP‑2/6502‑style architecture with robust I/O and software support.**
