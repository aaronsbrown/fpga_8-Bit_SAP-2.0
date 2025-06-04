<meta prompt 1 = "FPGA_Project_Overview">
I'm working on an 8-bit custom CPU project, "FPGA_8-Bit_SAP2", primarily written in SystemVerilog with some Verilog modules. The target is an iCE40 FPGA (Alchitry Cu board).

Key Tools & Workflow:

- Simulation: Icarus Verilog (`iverilog` + `vvp`) with GTKWave for waveforms. SystemVerilog code is typically transpiled to Verilog using `sv2v` before simulation with Icarus.
- Synthesis Toolchain: Yosys for synthesis, nextpnr-ice40 for place-and-route, icepack/iceprog for bitstream generation and upload.
- Assembler: A custom Python assembler (`software/assembler/src/assembler.py`) generates .hex files from .asm source.
- Scripts:
  - `scripts/simulate.sh`: Used for running individual Verilog/SystemVerilog testbenches, supports --sv2v.
  - `scripts/build.sh`: Handles the full synthesis flow (Yosys, nextpnr, etc.) and can assemble .asm source for ROM initialization.
  - `scripts/python/assemble_test.py`: Generates test case ASM/SV file templates and .hex fixtures.
  - `scripts/python/run_tests.py`: (Under development/refinement) Intended for batch execution of all testbenches.

Core Project Structure:

- DUT Verilog/SystemVerilog sources: Located in `hardware/src/`.
  - Package definitions (parameters, types like `control_word_t`, enums like `opcode_t`, `alu_op_t`): `hardware/src/constants/arch_defs_pkg.sv`.
  - CPU core: `hardware/src/cpu.sv` with submodules in `hardware/src/cpu/` (e.g., `control_unit.sv`, `alu.sv`).
  - File lists for DUT: `hardware/src/_files_sim.f` (for simulation) and `hardware/src/_files_synth.f` (for synthesis), with paths relative to `hardware/src/`.
- Testbenches & Utilities: Located in `hardware/test/`, using `hardware/test/test_utilities_pkg.sv`.
- Constraints: `.pcf` and `.sdc` files are in `hardware/constraints/`.
- Documentation: Project phases, ISA, memory map, etc., are in the `docs/` directory.
</meta prompt 1>

================= END OF PHASE 6, BEG OF PHASE 7 =====================

<meta prompt 1 = "FPGA_Project_Overview">
This chat continues work on my 8-bit custom CPU project, "FPGA_8-Bit_SAP2," primarily written in SystemVerilog, targeting an iCE40 FPGA.

Project State & Toolchain:

- Key Parameters: DATA_WIDTH=8, ADDR_WIDTH=16, OPCODE_WIDTH=8 (defined in `hardware/src/constants/arch_defs_pkg.sv`).
- CPU Architecture: Microcoded (`hardware/src/cpu/control_unit.sv`), with a 16-bit Stack Pointer. ALU operations that modify registers/flags generally take 3 execute microsteps (MS0: latch ALU op, MS1: ALU computes & registers results/flags, MS2: commit results/flags to registers/status).
- Assembler: A custom Python two-pass assembler (`software/assembler/src/assembler.py`) generates .hex files from .asm.
- Simulation Flow:
  - Individual tests are run with `scripts/simulate.sh --tb <path_to_tb>`. This script *always* uses `sv2v` to transpile SystemVerilog to Verilog-2005, then compiles with Icarus Verilog (`iverilog`) and runs with `vvp`.
  - DUT source files are listed in `hardware/src/_files_sim.f` (paths relative to `hardware/src/`). `utils/timescale.v` is listed early and explicitly prepended in scripts to ensure `1ns/1ps` timescale.
- Automated Testing:
  - A Python script `scripts/python/assemble_test.py` generates testbench templates (`.sv`) and assembly file templates (`.asm`), and assembles the `.asm` to `.hex` fixtures. Testbenches are placed into categorized subdirectories (`hardware/test/{instruction_set,cpu_control,modules}`).
  - A Python script `scripts/python/run_tests.py` automates running all testbenches using the same `sv2v` -> `iverilog` -> `vvp` flow as `simulate.sh`.
- CPU Features: Includes an `instruction_finished` pulse signal for testbench synchronization.

Recent Accomplishments (Phase 6 - Stack & Subroutines):

- Hardware implemented and microcode written/tested for SP, `PHA`, `PLA`, `JSR`, `RET`, `PHP`, `PLP`.
- ISA refined with `SEC`, `CLC`, and associated conditional jumps (`JC`, `JNC`).
- Assembler updated for all new mnemonics.
- Significant improvements to test scripts (`simulate.sh`, `run_tests.py`) and test organization. Most tests are now passing with the automated flow.

Current Focus / Next Steps:

- Finalizing Phase 6: Primarily documentation updates for new instructions and ensuring all testbenches are robustly using the `instruction_finished` signal and have standardized completion messages for `run_tests.py`.
- Addressing any remaining test failures identified by `run_tests.py`.
- Planning for Phase 7 (Monitor Program).
</meta prompt 1>
