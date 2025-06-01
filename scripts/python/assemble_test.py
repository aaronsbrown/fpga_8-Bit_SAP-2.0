#!/usr/bin/env python3

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

# Placeholder for <<test_name>> in templates
TEST_NAME_PLACEHOLDER = "<<test_name>>"

# --- Determine Project Root ---
SCRIPT_FILE_PATH = Path(__file__).resolve()
PROJECT_ROOT = SCRIPT_FILE_PATH.parent.parent.parent

# --- Define Template and Target Directory Paths (relative to PROJECT_ROOT) ---
ASM_TEMPLATE_FILE = PROJECT_ROOT / "software/asm/templates/test_template.asm"
SV_TEMPLATE_FILE = PROJECT_ROOT / "hardware/test/templates/test_template.sv"

ASM_SRC_DIR = PROJECT_ROOT / "software/asm/src"
SV_TEST_DIR = PROJECT_ROOT / "hardware/test"
GENERATED_FIXTURES_BASE_DIR = PROJECT_ROOT / "hardware/test/fixtures_generated"

ASSEMBLER_SCRIPT_PATH = PROJECT_ROOT / "software/assembler/src/assembler.py"


def create_file_from_template(template_path: Path, output_path: Path, test_name_value: str, dry_run: bool, force: bool) -> str:
    """
    Creates a new file from a template, replacing the TEST_NAME_PLACEHOLDER.
    Returns a status string: "created", "overwritten", "skipped", "error", "dry_run_ok".
    """
    if not template_path.is_file():
        print(f"Error: Template file not found at {template_path}")
        return "error"

    if output_path.exists() and not force:
        print(f"Warning: Output file {output_path.relative_to(PROJECT_ROOT)} already exists. Use --force to overwrite. Skipping creation.")
        return "skipped"

    if dry_run:
        action = "create"
        if output_path.exists() and force:
            action = "overwrite"
            print(f"[DRY RUN] --force specified, would overwrite.")
        elif output_path.exists() and not force: # Should have been caught above, but for completeness
             action = "skip (already exists)"
        print(f"[DRY RUN] Would {action} file: {output_path.relative_to(PROJECT_ROOT)} from template {template_path.relative_to(PROJECT_ROOT)}")
        return "dry_run_ok"

    try:
        output_path.parent.mkdir(parents=True, exist_ok=True)
        with open(template_path, 'r', encoding='utf-8') as f_template:
            content = f_template.read()
        modified_content = content.replace(TEST_NAME_PLACEHOLDER, test_name_value)

        was_existing = output_path.exists()
        with open(output_path, 'w', encoding='utf-8') as f_output:
            f_output.write(modified_content)

        if was_existing and force:
            print(f"Successfully overwrote: {output_path.relative_to(PROJECT_ROOT)}")
            return "overwritten"
        else:
            print(f"Successfully created: {output_path.relative_to(PROJECT_ROOT)}")
            return "created"
    except IOError as e:
        print(f"Error during file operation for {output_path}: {e}")
        return "error"
    except Exception as e:
        print(f"An unexpected error occurred while creating file from template: {e}")
        return "error"

def clean_test_artifacts(test_name: str, asm_file: Path, sv_file: Path, fixture_dir: Path, dry_run: bool):
    """
    Removes artifacts for a given test_name.
    """
    print(f"\n--- Cleaning artifacts for test: {test_name} ---")
    paths_to_delete = []
    if asm_file.exists():
        paths_to_delete.append(asm_file)
    if sv_file.exists():
        paths_to_delete.append(sv_file)
    if fixture_dir.exists() and fixture_dir.is_dir():
        paths_to_delete.append(fixture_dir)

    if not paths_to_delete:
        print(f"No artifacts found for test '{test_name}' to clean.")
        return

    print("The following files/directories will be DELETED:")
    for p in paths_to_delete:
        print(f"  - {p.relative_to(PROJECT_ROOT)}")

    if dry_run:
        print("[DRY RUN] No files will be deleted.")
        return

    try:
        confirm = input("Are you sure you want to delete these artifacts? (yes/No): ")
        if confirm.lower() != 'yes':
            print("Clean operation cancelled by user.")
            return
    except EOFError:
        print("Confirmation required. Clean operation cancelled (non-interactive environment).")
        return


    for p in paths_to_delete:
        try:
            if p.is_file():
                p.unlink()
                print(f"Deleted file: {p.relative_to(PROJECT_ROOT)}")
            elif p.is_dir():
                shutil.rmtree(p)
                print(f"Deleted directory: {p.relative_to(PROJECT_ROOT)}")
        except OSError as e:
            print(f"Error deleting {p.relative_to(PROJECT_ROOT)}: {e}")
    print(f"--- Cleaning for '{test_name}' complete ---")


def main():
    parser = argparse.ArgumentParser(
        description="Automate test case setup and assembly for the 8-bit computer project.",
        formatter_class=argparse.RawTextHelpFormatter
    )
    parser.add_argument(
        "test_name",
        help="The name of the test (e.g., 'my_alu_test'). This will be used for filenames and placeholders."
    )
    parser.add_argument(
        "--init",
        action="store_true",
        help="Initialize new test files (.asm, .sv) from templates and create fixture directory."
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Force overwrite of existing .asm and .sv files during --init."
    )
    parser.add_argument(
        "--clean",
        action="store_true",
        help="Remove all generated artifacts for the specified <test_name> (prompts for confirmation)."
    )
    parser.add_argument(
        "--asm-args",
        type=str,
        default="",
        help="Additional arguments to pass to the assembler, e.g., \"--region RAM 0000 1FFF\"."
              "\nDefault ROM region: --region ROM F000 FFFF"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be done without actually making any changes or running commands."
    )

    args = parser.parse_args()
    test_name = args.test_name
    dry_run = args.dry_run

    if dry_run:
        print("********* DRY RUN MODE ENABLED *********")
        print("* No files will be created/modified. *")
        print("* No commands will be executed.      *")
        print("**************************************\n")

    new_asm_file_path = ASM_SRC_DIR / f"{test_name}.asm"
    new_sv_file_path = SV_TEST_DIR / f"{test_name}_tb.sv"
    test_fixture_output_dir = GENERATED_FIXTURES_BASE_DIR / test_name

    if args.clean:
        clean_test_artifacts(test_name, new_asm_file_path, new_sv_file_path, test_fixture_output_dir, dry_run)
        sys.exit(0)

    init_skipped_any_file = False
    init_errors_occurred = False

    if args.init:
        print(f"\n--- Initializing test: {test_name} ---")

        print(f"\nProcessing ASM source file...")
        asm_status = create_file_from_template(ASM_TEMPLATE_FILE, new_asm_file_path, test_name, dry_run, args.force)
        if asm_status == "skipped":
            init_skipped_any_file = True
        elif asm_status == "error":
            init_errors_occurred = True


        print(f"\nEnsuring fixture directory exists...")
        if dry_run:
            print(f"[DRY RUN] Would ensure directory exists: {test_fixture_output_dir.relative_to(PROJECT_ROOT)}")
        else:
            try:
                test_fixture_output_dir.mkdir(parents=True, exist_ok=True)
                print(f"Successfully ensured directory exists: {test_fixture_output_dir.relative_to(PROJECT_ROOT)}")
            except OSError as e:
                print(f"Error: Could not create directory {test_fixture_output_dir}: {e}")
                init_errors_occurred = True # Count this as an error for init

        print(f"\nProcessing SystemVerilog testbench file...")
        sv_status = create_file_from_template(SV_TEMPLATE_FILE, new_sv_file_path, test_name, dry_run, args.force)
        if sv_status == "skipped":
            init_skipped_any_file = True
        elif sv_status == "error":
            init_errors_occurred = True


        if not dry_run and init_errors_occurred:
            print(f"\n--- Initialization for '{test_name}' failed due to errors. Aborting. ---")
            sys.exit(1)
        elif not dry_run and init_skipped_any_file:
            print(f"\n--- Initialization for '{test_name}' involved skipping some existing files. ---")
            print(f"To overwrite these files, use the --force flag.")
            print(f"Assembly step will be SKIPPED as not all files were newly created/overwritten.")
            sys.exit(0) # Successful exit, but indicate action was not fully completed as expected
        else:
            print(f"\n--- Initialization for '{test_name}' complete. ---")


    # --- Assembler section ---
    print(f"\n--- Assembling: {new_asm_file_path.name} ---")

    if not new_asm_file_path.is_file() and not dry_run:
        print(f"Error: ASM source file not found: {new_asm_file_path.relative_to(PROJECT_ROOT)}")
        print(f"If this is a new test, please run with the --init flag first.")
        sys.exit(1)
    elif not new_asm_file_path.is_file() and dry_run:
         print(f"[DRY RUN] ASM source file {new_asm_file_path.relative_to(PROJECT_ROOT)} would be used (assuming it's created by --init).")

    if not ASSEMBLER_SCRIPT_PATH.is_file():
        print(f"Error: Assembler script not found: {ASSEMBLER_SCRIPT_PATH.relative_to(PROJECT_ROOT)}")
        if not dry_run: sys.exit(1)

    if not dry_run:
        try:
            test_fixture_output_dir.mkdir(parents=True, exist_ok=True)
        except OSError as e:
            print(f"Error: Could not create/ensure fixture directory {test_fixture_output_dir} for assembler output: {e}")
            sys.exit(1)
    else:
        if not test_fixture_output_dir.exists():
            print(f"[DRY RUN] Fixture output directory {test_fixture_output_dir.relative_to(PROJECT_ROOT)} would be created if it doesn't exist.")

    asm_command_base = [
        sys.executable,
        str(ASSEMBLER_SCRIPT_PATH),
        str(new_asm_file_path),
        str(test_fixture_output_dir),
    ]
    if args.asm_args:
        additional_asm_args = args.asm_args.split()
        asm_command_final = asm_command_base + additional_asm_args
    else:
        default_region_args = ["--region", "ROM", "F000", "FFFF"]
        asm_command_final = asm_command_base + default_region_args

    print(f"\nExecuting assembler command:")
    display_command = [Path(sys.executable).name] + [str(Path(p).relative_to(PROJECT_ROOT) if Path(p).is_absolute() and PROJECT_ROOT in Path(p).parents else p) for p in asm_command_final[1:]]
    print(f"  $ {' '.join(display_command)}")
    print(f"(Running from: {PROJECT_ROOT})")

    if dry_run:
        print("[DRY RUN] Assembler command would be executed.")
        print("\nScript finished (DRY RUN).")
        sys.exit(0)

    try:
        process = subprocess.run(
            asm_command_final,
            check=True,
            capture_output=True,
            text=True,
            cwd=PROJECT_ROOT
        )
        if process.stdout: print("\nAssembler STDOUT:\n" + process.stdout.strip())
        if process.stderr: print("\nAssembler STDERR:\n" + process.stderr.strip())
        print(f"\n--- Assembly for '{test_name}' successful. ---")
        print(f"Output HEX file should be in: {test_fixture_output_dir.relative_to(PROJECT_ROOT)}")
    except subprocess.CalledProcessError as e:
        print("\n--- Error during assembly! ---")
        print(f"Command failed with return code {e.returncode}")
        if e.stdout: print("\nAssembler STDOUT:\n" + e.stdout.strip())
        if e.stderr: print("\nAssembler STDERR:\n" + e.stderr.strip())
        sys.exit(1)
    except FileNotFoundError:
        print(f"Error: Could not find Python interpreter or assembler script: {ASSEMBLER_SCRIPT_PATH}")
        sys.exit(1)
    except Exception as e:
        print(f"An unexpected error occurred during assembly: {e}")
        sys.exit(1)

    print("\nScript finished successfully.")

if __name__ == "__main__":
    main()