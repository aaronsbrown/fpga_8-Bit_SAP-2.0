#!/usr/bin/env python3

import subprocess
import sys
from pathlib import Path

# --- Determine Project Root (assuming script is run from project root) ---
PROJECT_ROOT = Path.cwd()
print(f"INFO: Project Root detected as: {PROJECT_ROOT}")

# --- Define Paths (relative to PROJECT_ROOT) ---
HARDWARE_TEST_BASE_DIR = PROJECT_ROOT / "hardware/test"
SOFTWARE_ASM_SRC_DIR = PROJECT_ROOT / "software/asm/src"
ASSEMBLE_TEST_SCRIPT_PATH = PROJECT_ROOT / "scripts/python/assemble_test.py"

# Define test categories and their subdirectories
TEST_CATEGORIES = {
    "instruction_set": HARDWARE_TEST_BASE_DIR / "instruction_set",
    "cpu_control": HARDWARE_TEST_BASE_DIR / "cpu_control",
    "modules": HARDWARE_TEST_BASE_DIR / "modules",
}

def run_command(command_list, cwd=None):
    """Helper function to run a shell command and print its output."""
    str_command_list = [str(c) for c in command_list]
    print(f"\nExecuting: {' '.join(str_command_list)}")
    if cwd:
        print(f"(In directory: {cwd})")
    try:
        process = subprocess.run(
            str_command_list,
            check=True,
            capture_output=True,
            text=True,
            cwd=cwd or PROJECT_ROOT
        )
        if process.stdout:
            print("STDOUT:\n" + process.stdout.strip())
        if process.stderr:
            print("STDERR:\n" + process.stderr.strip())
        return True # Command was successful
    except subprocess.CalledProcessError as e:
        print(f"--- ERROR executing command ---")
        print(f"Command failed with return code {e.returncode}")
        if e.stdout:
            print("STDOUT:\n" + e.stdout.strip())
        if e.stderr:
            print("STDERR:\n" + e.stderr.strip())
        return False # Command failed
    except FileNotFoundError:
        print(f"Error: Could not find command: {str_command_list[0]}")
        return False # Command failed
    except Exception as e:
        print(f"An unexpected error occurred: {e}")
        return False # Command failed

def generate_fixtures_for_category(category_name: str, test_dir: Path):
    """
    Finds _tb.sv files in the given directory and attempts to assemble
    corresponding .asm files using assemble_test.py.
    Returns True if all assemblies in this category succeed, False otherwise.
    """
    print(f"\n--- Generating .hex files for {category_name.replace('_', ' ').title()} tests ---")

    if not test_dir.is_dir():
        print(f"WARNING: Test directory not found: {test_dir.relative_to(PROJECT_ROOT)}")
        print(f"         Skipping category: {category_name}")
        return True

    print(f"Searching for testbenches in: {test_dir.relative_to(PROJECT_ROOT)}")
    tb_files_found = list(test_dir.glob("*_tb.sv"))

    if not tb_files_found:
        print(f"No '*_tb.sv' files found in {test_dir.relative_to(PROJECT_ROOT)}.")
        return True

    for tb_file in tb_files_found:
        test_name = tb_file.stem.removesuffix("_tb")
        asm_file_path = SOFTWARE_ASM_SRC_DIR / f"{test_name}.asm"

        print(f"\nProcessing Testbench: {tb_file.name} (Derived Test Name: {test_name})")

        if not asm_file_path.is_file():
            if category_name == "modules":
                print(f"INFO: No ASM file at '{asm_file_path.relative_to(PROJECT_ROOT)}'. Skipping assembly for module test: {test_name}.")
                continue
            else:
                # For non-module tests, if assemble_test.py is robust, it will print an error
                # and run_command will return False.
                print(f"WARNING: ASM source file not found: {asm_file_path.relative_to(PROJECT_ROOT)}")
                print(f"         Assembly will likely fail for test: {test_name}")


        print(f"Attempting to assemble for: {test_name}")
        assemble_command = [
            sys.executable,
            str(ASSEMBLE_TEST_SCRIPT_PATH),
            "--test-name",
            test_name,
            "--sub-dir",
            category_name,
        ]

        if not run_command(assemble_command):
            # If run_command returns False, it means assemble_test.py failed
            print(f"--- FAILED to generate/assemble fixtures for test: {test_name} ---")
            print(f"Stopping script due to error in category '{category_name}'.")
            return False # Stop processing this category and signal failure

    return True # All assemblies in this category succeeded


def main():
    print("Starting Verilog fixture generation process...\n")

    if not ASSEMBLE_TEST_SCRIPT_PATH.is_file():
        print(f"CRITICAL ERROR: The 'assemble_test.py' script was not found at {ASSEMBLE_TEST_SCRIPT_PATH.relative_to(PROJECT_ROOT)}")
        print("Please ensure the path is correct and the script exists.")
        sys.exit(1)

    for category, directory in TEST_CATEGORIES.items():
        if not generate_fixtures_for_category(category, directory):
            # If any category fails (which now happens on first assembly error within it)
            print(f"\n\n--- Verilog fixture generation FAILED during '{category}' processing. ---")
            print("Please review the output above for the specific error details.")
            sys.exit(1) # Exit the entire script

    print("\n\n--- Verilog fixture generation completed successfully for all categories. ---")
    sys.exit(0)

if __name__ == "__main__":
    main()