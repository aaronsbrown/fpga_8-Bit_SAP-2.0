# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an FPGA-based 8-bit CPU project implementing a custom SAP2-style computer with 16-bit addressing. The project includes:

- Custom CPU with ALU, control unit, and registers
- Memory-mapped I/O (MMIO) infrastructure 
- UART peripheral for serial communication
- Complete assembler toolchain for the custom instruction set
- Comprehensive test suite with simulation infrastructure

## Development Commands

### Build Commands
- **FPGA Synthesis**: `./scripts/build.sh --top <module_name> [--asm_src <file.asm>]`
  - Synthesizes hardware using Yosys/nextpnr toolchain for iCE40 FPGA
  - Optionally assembles source code for ROM initialization
  - Example: `./scripts/build.sh --top top --asm_src software/asm/src/monitor.asm`

### Simulation Commands
- **Run single test**: `./scripts/simulate.sh --tb <testbench_path>`
  - Example: `./scripts/simulate.sh --tb hardware/test/instruction_set/ADD_B_tb.sv`
- **Run all tests**: `python3 scripts/python/run_tests.py [--category <name>]`
  - Categories: Instruction_Set_Tests, CPU_Control_Tests, Module_Tests
- **Skip visualization**: Add `--no-viz` flag to simulate.sh

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
- Stack grows down from `$01FF`

### Key SystemVerilog Modules
- `computer.sv`: Top-level system integration with memory mapping
- `cpu.sv`: Main CPU with control unit, ALU, and registers
- `control_unit.sv`: Multi-byte instruction fetch FSM
- `uart_peripheral.sv`: UART with error handling
- Architecture constants defined in `arch_defs_pkg.sv`

### Test Infrastructure
- Uses Icarus Verilog + GTKWave for simulation
- sv2v automatically converts SystemVerilog to Verilog
- Test utilities package provides assertion helpers
- Generated test fixtures from assembly source code
- Waveform files (`.gtkw`) in `hardware/sim/` for signal viewing

### Assembler
- Two-pass assembler supporting full instruction set
- Supports labels, EQU constants, ORG directive, DB/DW data
- Multi-region output (ROM.hex, RAM.hex) with address mapping
- Comprehensive error handling and validation
- Located in `software/assembler/src/`

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
- `hardware/sim/`: GTKWave session files

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

## Project Memories
- Remember the unconventional operand ordering of this ISA's MOV instructon: MOV Src, Dest