# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an FPGA-based 8-bit CPU project implementing a custom SAP2-style computer with 16-bit addressing. The project includes:

- Custom CPU with ALU, control unit, and registers
  - Supports compile time configuration of reset behavior, choosing from:
  - Static reset vector (ROM start = F000); default setting
  - Dynamic reset vector table at FFFC/FFFD (modeled on 6502)
- Custom ISA (see docs/hardware/0_ISA.md; please note unconventional MOV instruction (Src => Dest)
- Memory-mapped I/O (MMIO) infrastructure (see docs/hardware/1_memory_map.md)
- UART peripheral for serial communication (see docs/hardware/2_uart_datasheet.md))
- Complete custom assembler toolchain for the custom instruction set
- Comprehensive test suite with simulation infrastructure, support by continuous integration workflow on github
- Robust dev tools in scripts/

## Targeted Hardware

— Alchtiry Cu FPGA development board (<https://shop.alchitry.com/products/alchitry-cu-v2>)
— ICE40HX8K-CB132 FPGA (<https://www.latticesemi.com/ice40>)

---

## Non-negotiable golden rules

| #: | AI *may* do                                                            | AI *must NOT* do                                                                    |
|---|------------------------------------------------------------------------|-------------------------------------------------------------------------------------|
| G-0 | Whenever unsure about something that's related to the project, ask the developer for clarification before making changes.    |  ❌ Write changes or use tools when you are not sure about something project specific, or if you don't have context for a particular feature/decision. |
| G-1 | Add/update **`AIDEV-NOTE:` anchor comments** near non-trivial edited code. | ❌ Delete or mangle existing `AIDEV-` comments.                                     |
| G-2 | For changes >300 LOC or >3 files, **ask for confirmation**.            | ❌ Refactor large modules without human guidance.                                     |
| G-3 | Stay within the current task context. Inform the dev if it'd be better to start afresh.     | ❌ Continue work from a prior prompt after "new task" – start a fresh session.      |

---

## Coding standards

- **Python**: 3.12+
- **Formatting**: double quotes, sorted imports.
- **Typing**: Strict (Pydantic v2 models preferred); `from __future__ import annotations`.
- **Naming**: `snake_case` (functions/variables), `PascalCase` (classes), `SCREAMING_SNAKE` (constants).
- **Error Handling**: Typed exceptions
- **Documentation**: Google-style docstrings for public functions/classes.
- **Testing**: Separate test files matching source file patterns.

**Error handling patterns**:

- Use typed, hierarchical exceptions defined in `exceptions.py`
- Catch specific exceptions, not general `Exception`

Example:

```python
try:
    val = int(num_str, base_to_use)
    return val
except ValueError:
    type_str = "hexadecimal" if base_to_use == 16 else "binary" if base_to_use == 2 else "decimal"
    raise AssemblerError(f"Bad {type_str} value for {context_description}: '{value_str}'. Not a known symbol.",
                          source_file=current_token.source_file, line_no=current_token.line_no)
```

---

## Anchor comments

Add specially formatted comments throughout the codebase, where appropriate, for yourself as inline knowledge that can be easily `grep`ped for.

### Guidelines

- Use `AIDEV-NOTE:`, `AIDEV-TODO:`, or `AIDEV-QUESTION:` (all-caps prefix) for comments aimed at AI and developers.
- Keep them concise (≤ 120 chars).
- **Important:** Before scanning files, always first try to **locate existing anchors** `AIDEV-*` in relevant subdirectories.
- **Update relevant anchors** when modifying associated code.
- **Do not remove `AIDEV-NOTE`s** without explicit human instruction.
- Make sure to add relevant anchor comments, whenever a file or piece of code is:
  - too long, or
  - too complex, or
  - very important, or
  - confusing, or
  - could have a bug unrelated to the task you are currently working on.

Example:

```python
# AIDEV-NOTE: perf-hot-path; avoid extra allocations (see ADR-24)
async def render_feed(...):
    ...
```

---

## Commit discipline

- **Granular commits**: One logical change per commit.
- **Tag AI-generated commits**: e.g., `feat: optimise feed query [AI]`.
- **Clear commit messages**: Explain the *why*; link to issues/ADRs if architectural.
- **Use `git worktree`** for parallel/long-running AI branches (e.g., `git worktree add ../wip-foo -b wip-foo`).
- **Review AI-generated code**: Never merge code you don't understand.

---

## Dev Environment

- DevEnv: Macbook Pro, OSX 15.5, iTerm2, VSCode, Claude Code

## Development Commands

### Build Commands

- **FPGA Synthesis**: `./scripts/build.sh --top <module_name> [--asm_src <file.asm>]`
  - Synthesizes hardware using Yosys/nextpnr toolchain for iCE40 FPGA
  - Optionally assembles source code for ROM initialization
  - Example: `./scripts/build.sh --top top --asm_src software/asm/src/monitor.asm`

### Simulation Commands

- **Run single test**: `./scripts/simulate.sh --tb <testbench_path>`
  - Example: `./scripts/simulate.sh --tb hardware/test/instruction_set/ADD_B_tb.sv`
- **Skip visualization**: Add `--no-viz` flag to simulate.sh
- **Run all tests**: `python3 scripts/ci/run_test_suite.py`
  - Runs comprehensive test suite across all categories

### Test Management Commands (Developer Tools)

- **Initialize new test**: `python3 scripts/devtools/test_manager.py init --test-name <name> --sub-dir <category> [--force] [--dry-run]`
- **Assemble single test**: `python3 scripts/devtools/test_manager.py assemble --test-name <name> [--asm-args "<args>"] [--dry-run]`
- **Assemble all tests**: `python3 scripts/devtools/test_manager.py assemble-all-sources [--asm-args "<args>"] [--dry-run]`
- **Clean test artifacts**: `python3 scripts/devtools/test_manager.py clean --test-name <name> --sub-dir <category> [--dry-run]`

### CI/Build Commands

- **Generate all fixtures**: `python3 scripts/ci/build_all_fixtures.py`
  - Builds .hex fixtures for all testbenches before running tests
- **Run complete test suite**: `python3 scripts/ci/run_test_suite.py`
  - Executes all Verilog tests (assumes fixtures are already built)

### Assembly Development

- **Assemble program**: `python3 software/assembler/src/assembler.py <input.asm> <output_dir> [--region <name> <start> <end>]`
- **Run assembler tests**: `python3 -m pytest software/assembler/test/` (from assembler directory)

## Architecture

### Memory Map

- `0000-1FFF`: RAM (8KB)
- `D000-DFFF`: VRAM (4KB)
- `E000-EFFF`: MMIO space
  - `E000-E003`: UART registers (Control, Status, Data, Command)
  - `E004`: LED output register
- `F000-FFFF`: ROM (4KB)

### CPU Architecture

- 8-bit data width, 16-bit address space
- 8-bit opcodes with multi-byte instruction support
- Registers: A (accumulator), B, C, PC (16-bit), SP (16-bit), IR, MAR (16-bit)
- Status flags: Zero, Negative, Carry
- Stack is "empty descending (SP points to next *free* locations); grows down from `$01FF`
— 100Mhz FPGA clock / 20Mhz System Clock (via PLL)

### Key SystemVerilog Modules

- `computer.sv`: Top-level system integration with memory mapping
- `cpu.sv`: Main CPU with control unit, ALU, and registers
- `control_unit.sv`: Multi-byte instruction fetch FSM
— `status_control_unit.sv`: Status register / flag determination logic
- `uart_peripheral.sv`: UART with error handling
- Architecture constants defined in `arch_defs_pkg.sv`

### Test Infrastructure

- Uses Icarus Verilog + GTKWave for simulation
- sv2v automatically converts SystemVerilog to Verilog
- Test utilities package provides assertion helpers and safe readmemh tasks
- Generated test fixtures from assembly source code
- Waveform files (`.gtkw`) in `hardware/sim/` for signal viewing

### Assembler

- Two-pass assembler supporting full instruction set
- Supports labels, EQU constants, ORG directive, DB/DW data
- Multi-region output (ROM.hex, RAM.hex) with address mapping
- Comprehensive error handling and validation
- Located in `software/assembler/src/`
- docs/software/0_assembly_language_overview.md

## File Organization

### Source Code

- `hardware/src/`: RTL source code organized by module type
  - `_files_sim.f`: File list for simulation
  - `_files_synth.f`: File list for synthesis
- `software/asm/src/`: Assembly source programs
- `software/assembler/`: Python assembler implementation

### Test Files

- `hardware/test/`: All testbenches organized by category
- `hardware/test/fixtures_generated/`: Test data generated from assembly
- `hardware/sim/`: GTKWave session and filter files

### Scripts Organization

- `scripts/devtools/`: Developer utilities for test management
  - `test_manager.py`: Subcommand-based CLI for test file creation, assembly, and cleanup
- `scripts/ci/`: CI pipeline scripts for automated testing
  - `build_all_fixtures.py`: Generates .hex fixtures for all testbenches
  - `run_test_suite.py`: Compiles and runs complete Verilog test suite
- `scripts/build.sh` & `scripts/simulate.sh`: Hardware build and simulation

### Build Outputs

- `build/`: All build artifacts and logs
- Generated hex files for memory initialization

## Development Tips

### Simulation Workflow

1. Write assembly program in `software/asm/src/`
2. Generate test fixtures using assembler with region mapping
3. Create/update testbench to load fixtures
4. Run simulation with `./scripts/simulate.sh --tb <testbench>`

### Adding New Instructions

1. Update opcode enum in `arch_defs_pkg.sv`
2. Add microcode sequence in `control_unit.sv`
3. Update assembler's `INSTRUCTION_SET` in `constants.py`
4. Create testbench and assembly test program

### UART Communication

Access UART via memory-mapped registers at E000-E003. Status register indicates data ready, errors (frame, overshoot). Use assembler MMIO constants from `includes/mmio_defs.inc`.

### Debugging

- Use `--verbose` flag with build/simulation scripts for detailed output
- GTKWave sessions auto-load when available for testbench
- CPU debug signals exposed: PC, IR, registers, flags

---

## AI Assistant Workflow: Step-by-Step Methodology

When responding to user instructions, the AI assistant (Claude, Cursor, GPT, etc.) should follow this process to ensure clarity, correctness, and maintainability:

1. **Consult Relevant Guidance**: When the user gives an instruction, consult the relevant files in the project directory to gather insight
2. **Clarify Ambiguities**: Based on what you could gather, see if there's any need for clarifications. If so, ask the user targeted questions before proceeding.
3. **Break Down & Plan**: Break down the task at hand and chalk out a rough plan for carrying it out, referencing project conventions and best practices.
4. **Trivial Tasks**: If the plan/request is trivial, go ahead and get started immediately.
5. **Non-Trivial Tasks**: Otherwise, present the plan to the user for review and iterate based on their feedback.
6. **Track Progress**: Use a to-do list (internally, or optionally in a `TODOS.md` file) to keep track of your progress on multi-step or complex tasks.
7. **If Stuck, Re-plan**: If you get stuck or blocked, return to step 3 to re-evaluate and adjust your plan.
8. **Update Documentation**: Once the user's request is fulfilled, update relevant anchor comments (`AIDEV-NOTE`, etc.) and `AGENTS.md` files in the files and directories you touched.
9. **User Review**: After completing the task, ask the user to review what you've done, and repeat the process as needed.
10. **Session Boundaries**: If the user's request isn't directly related to the current context and can be safely started in a fresh session, suggest starting from scratch to avoid context confusion.

--

## Project Memories

- Remember the unconventional operand ordering of this ISA's MOV instructon: MOV Src, Dest
- When creating new verilog test benches, base code on hardware/test/templates/test_template.sv
- When creating new assembly files, base code on software/asm/templates/test_template.asm
