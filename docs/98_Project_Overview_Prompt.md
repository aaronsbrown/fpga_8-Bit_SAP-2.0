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
