# Scripts Directory

This directory contains all utility scripts for the FPGA 8-Bit SAP2 project, organized by purpose and usage context.

## Directory Structure

```
scripts/
├── README.md              # This file
├── devtools/               # Developer utilities for day-to-day development
│   └── test_manager.py     # Subcommand-based test management CLI
├── ci/                     # CI pipeline scripts for automated testing
│   ├── build_all_fixtures.py   # Generate all test fixtures
│   └── run_test_suite.py       # Execute complete test suite
├── build.sh               # FPGA synthesis and build
└── simulate.sh            # Single test simulation
```

## Script Categories

### 🔧 Developer Tools (`devtools/`)

Scripts designed for interactive development, debugging, and individual test management.

**When to use:** During active development when working on specific tests or features.

### 🚀 CI Scripts (`ci/`)

High-level scripts designed for CI pipelines and full project validation.

**When to use:** For complete project builds, full test suite execution, or CI/CD pipelines.

### ⚙️ Build & Simulation Scripts

Core build and simulation utilities that work with individual modules or testbenches.

---

## Script Reference

### `devtools/test_manager.py`

**Purpose:** Interactive test case management with subcommand-based CLI.

**Common Use Cases:**
- Creating new test cases
- Assembling individual tests during development
- Cleaning up test artifacts
- Batch assembly of all test sources

#### Subcommands

##### `init` - Initialize New Test
Creates new test files from templates.

```bash
python3 scripts/devtools/test_manager.py init \
    --test-name <TEST_NAME> \
    --sub-dir {instruction_set|cpu_control|modules} \
    [--force] [--dry-run]
```

**Example:**
```bash
# Create a new instruction test
python3 scripts/devtools/test_manager.py init \
    --test-name SUB_C --sub-dir instruction_set

# Force overwrite existing files
python3 scripts/devtools/test_manager.py init \
    --test-name SUB_C --sub-dir instruction_set --force
```

**What it creates:**
- `software/asm/src/<TEST_NAME>.asm` (from template)
- `hardware/test/<SUB_DIR>/<TEST_NAME>_tb.sv` (from template)
- Assembles the new .asm file to generate initial fixtures

##### `assemble` - Assemble Single Test
Assembles a specific test's .asm file to .hex fixtures.

```bash
python3 scripts/devtools/test_manager.py assemble \
    --test-name <TEST_NAME> \
    [--asm-args "<ASSEMBLER_ARGS>"] [--dry-run]
```

**Examples:**
```bash
# Assemble with default ROM/RAM regions
python3 scripts/devtools/test_manager.py assemble --test-name ADD_B

# Assemble with custom regions
python3 scripts/devtools/test_manager.py assemble \
    --test-name CUSTOM_TEST \
    --asm-args "--region VRAM D000 DFFF --region ROM F000 FFFF"

# Dry run to see what would happen
python3 scripts/devtools/test_manager.py assemble \
    --test-name ADD_B --dry-run
```

**Output:** Creates `.hex` files in `hardware/test/fixtures_generated/<TEST_NAME>/`

**Default Assembler Regions:**
- ROM: `F000-FFFF` (4KB)
- RAM: `0000-1FFF` (8KB)

##### `assemble-all-sources` - Batch Assembly
Assembles all .asm files found in `software/asm/src/`.

```bash
python3 scripts/devtools/test_manager.py assemble-all-sources \
    [--asm-args "<ASSEMBLER_ARGS>"] [--dry-run]
```

**Examples:**
```bash
# Assemble all tests with default regions
python3 scripts/devtools/test_manager.py assemble-all-sources

# Assemble all with custom regions
python3 scripts/devtools/test_manager.py assemble-all-sources \
    --asm-args "--region ROM F000 FFFF --region VRAM D000 DFFF"
```

##### `clean` - Remove Test Artifacts
Removes all generated files for a specific test.

```bash
python3 scripts/devtools/test_manager.py clean \
    --test-name <TEST_NAME> \
    --sub-dir {instruction_set|cpu_control|modules} \
    [--dry-run]
```

**Example:**
```bash
python3 scripts/devtools/test_manager.py clean \
    --test-name OLD_TEST --sub-dir instruction_set
```

**What it removes:**
- `software/asm/src/<TEST_NAME>.asm`
- `hardware/test/<SUB_DIR>/<TEST_NAME>_tb.sv`
- `hardware/test/fixtures_generated/<TEST_NAME>/` (entire directory)

---

### `ci/build_all_fixtures.py`

**Purpose:** Generate .hex fixtures for all testbenches in the project.

**Usage:**
```bash
python3 scripts/ci/build_all_fixtures.py
```

**What it does:**
1. Scans `hardware/test/{instruction_set,cpu_control,modules}/` for `*_tb.sv` files
2. For each testbench, derives the test name (removes `_tb` suffix)
3. Calls `test_manager.py assemble` for each derived test name
4. Skips module tests that don't have corresponding .asm files
5. Exits with error code if any assembly fails

**When to use:**
- Before running the full test suite
- In CI pipelines to ensure all fixtures are up-to-date
- When you want to regenerate all test fixtures at once

---

### `ci/run_test_suite.py`

**Purpose:** Compile and execute the complete Verilog test suite.

**Usage:**
```bash
python3 scripts/ci/run_test_suite.py
```

**What it does:**
1. Compiles all testbenches using `sv2v` + `iverilog`
2. Executes tests with `vvp`
3. Parses output for pass/fail status
4. Generates comprehensive test report
5. Exits with error code if any tests fail

**Requirements:**
- All necessary .hex fixtures must exist (run `build_all_fixtures.py` first)
- `sv2v`, `iverilog`, and `vvp` must be in PATH

**Output Files:**
- `test_run_all.log` - Detailed execution log
- `test_report_all.txt` - Summary report
- `build/sim_run_all_temp/` - Individual test logs

**When to use:**
- Full project validation
- CI/CD pipeline test execution
- Before making pull requests
- Regression testing

---

### `build.sh`

**Purpose:** FPGA synthesis and build using Yosys/nextpnr toolchain.

**Usage:**
```bash
./scripts/build.sh --top <module_name> [--asm_src <file.asm>]
```

**Examples:**
```bash
# Synthesize top module with monitor program
./scripts/build.sh --top top --asm_src software/asm/src/monitor.asm

# Synthesize without assembly
./scripts/build.sh --top computer
```

---

### `simulate.sh`

**Purpose:** Run a single testbench with simulation and optional waveform viewing.

**Usage:**
```bash
./scripts/simulate.sh --tb <testbench_path> [--no-viz]
```

**Examples:**
```bash
# Run test with GTKWave visualization
./scripts/simulate.sh --tb hardware/test/instruction_set/ADD_B_tb.sv

# Run test without opening GTKWave
./scripts/simulate.sh --tb hardware/test/instruction_set/ADD_B_tb.sv --no-viz
```

---

## Workflow Examples

### 🆕 Creating a New Instruction Test

```bash
# 1. Create new test files
python3 scripts/devtools/test_manager.py init \
    --test-name SBB_C --sub-dir instruction_set

# 2. Edit the generated files
# - software/asm/src/SBB_C.asm
# - hardware/test/instruction_set/SBB_C_tb.sv

# 3. Test your changes
./scripts/simulate.sh --tb hardware/test/instruction_set/SBB_C_tb.sv

# 4. Re-assemble if you modify the .asm
python3 scripts/devtools/test_manager.py assemble --test-name SBB_C
```

### 🔄 Development Workflow

```bash
# Make changes to assembly or testbench
vim software/asm/src/ADD_B.asm

# Re-assemble the test
python3 scripts/devtools/test_manager.py assemble --test-name ADD_B

# Run the simulation
./scripts/simulate.sh --tb hardware/test/instruction_set/ADD_B_tb.sv
```

### 🚀 CI/Full Project Validation

```bash
# Generate all fixtures
python3 scripts/ci/build_all_fixtures.py

# Run complete test suite
python3 scripts/ci/run_test_suite.py

# Check results
cat test_report_all.txt
```

### 🧹 Cleaning Up

```bash
# Remove a specific test
python3 scripts/devtools/test_manager.py clean \
    --test-name OLD_TEST --sub-dir instruction_set

# See what would be deleted first
python3 scripts/devtools/test_manager.py clean \
    --test-name OLD_TEST --sub-dir instruction_set --dry-run
```

---

## Environment Requirements

### Required Tools
- **Python 3.8+** - For all Python scripts
- **sv2v** - SystemVerilog to Verilog conversion
- **Icarus Verilog** (`iverilog`, `vvp`) - Verilog simulation
- **GTKWave** (optional) - Waveform viewing

### Python Dependencies
Install project dependencies:
```bash
pip install -r requirements.txt
```

### Tool Installation

**Ubuntu/Debian:**
```bash
sudo apt-get install iverilog gtkwave
# sv2v: Download from https://github.com/zachjs/sv2v/releases
```

**macOS:**
```bash
brew install icarus-verilog gtkwave
# sv2v: Download from https://github.com/zachjs/sv2v/releases
```

---

## Troubleshooting

### Common Issues

**Q: "Command not found: sv2v"**
A: Download sv2v from the [official releases](https://github.com/zachjs/sv2v/releases) and add to PATH.

**Q: Assembly fails with "region not found"**
A: Check that your custom `--asm-args` define all required memory regions for your assembly code.

**Q: Test fixtures not found during simulation**
A: Run `python3 scripts/ci/build_all_fixtures.py` to generate all fixtures before testing.

**Q: "Template file not found"**
A: Ensure template files exist:
- `software/asm/templates/test_template.asm`
- `hardware/test/templates/test_template.sv`

### Debug Mode

Use `--dry-run` with any `test_manager.py` command to see what would happen without executing:

```bash
python3 scripts/devtools/test_manager.py assemble --test-name ADD_B --dry-run
```

### Verbose Output

Check log files for detailed information:
- Individual test logs: `build/sim_run_all_temp/<test_name>_*.log`
- Full suite log: `test_run_all.log`
- Assembly output: Displayed in terminal during execution

---

## Contributing

When adding new scripts:

1. **Developer tools** → `scripts/devtools/`
2. **CI/automation** → `scripts/ci/`
3. **Build/simulation** → `scripts/` (root level)

Follow the existing patterns:
- Use argparse for command-line interfaces
- Include `--dry-run` for destructive operations
- Provide helpful error messages
- Update this README with new functionality

---

## See Also

- [Project Root CLAUDE.md](../CLAUDE.md) - Overall project guidance
- [Assembly Language Overview](../docs/software/0_assembly_language_overview.md)
- [Hardware Documentation](../docs/hardware/) - CPU architecture details