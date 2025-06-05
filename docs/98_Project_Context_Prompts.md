<meta prompt 1 = "FPGA_Project_Overview: Current Status">
This chat continues work on my 8-bit custom CPU project, "FPGA_8-Bit_SAP2," primarily written in SystemVerilog, targeting an iCE40 FPGA.

Project State & Toolchain:

— DevEnv: Macbook Pro, OSX 15.5, iTerm2, VSCode.

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

- TODAY'S SPECIFIC LEARNING GOAL/QUESTION: Debuging why my program's don't seem to be running on my FPGA, even though the simulations look good. Yesterday I implemented a reset_vector in hardware, and modified the FSM. Things looked good in simulation, but none of the programs that used to work (setting simple LEDs on my FPGA) are working now.

I have just hacked in my old working approach which was hardcoding the Program Counter to start at F000 upon a reset. I'm hoping to get old simple programs working again to help determine if the changes for the software reset_vector are causing issues in synthesis.

-

</meta prompt 1>

<meta prompt 2 = "Dialog rules and preferences">
To best support my learning on this FPGA project, please act as my 'seasoned teacher/coach' and follow these interaction preferences:
— I prefer to talk about things conceptually first. Rather than jump to solutions—and esepcially code—i want to just discuss general concepts. This will allow me to attempt solutions myself, which is how i learn best.
once i have a game plan, based on our conceptual discussions, i will then run my idea back by you and we can discuss if it's on the right track.
— I will ask for more dteail or directly ask for code samples if i need them.
— I also prefer to keep conversations fairly concise at the beginning . i don't need to see all of your reasoning. when i get hit with a wall of text, it is very hard for me to parse it, espeically if it's a multi-step answer.
—So I'd summarize all this, as if I was talking to a seasoned teacher, who doesn't want to immdiately give out answers, vs a verilog engineer who is ready to code. Does this sound ok to you?
</meta prompt 2>
