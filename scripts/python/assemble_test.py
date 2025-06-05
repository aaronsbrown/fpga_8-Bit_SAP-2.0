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
SV_TEST_BASE_DIR = PROJECT_ROOT / "hardware/test"
GENERATED_FIXTURES_BASE_DIR = PROJECT_ROOT / "hardware/test/fixtures_generated"

ASSEMBLER_SCRIPT_PATH = PROJECT_ROOT / "software/assembler/src/assembler.py"

# Define valid subdirectories for tests
VALID_TEST_SUBDIRS = ["instruction_set", "cpu_control", "modules"]


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
        elif output_path.exists() and not force:
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
    Removes artifacts for a given test_name. sv_file now includes the sub-directory.
    """
    print(f"\n--- Cleaning artifacts for test: {test_name} (SV file at {sv_file.relative_to(PROJECT_ROOT)}) ---")
    paths_to_delete = []
    if asm_file.exists():
        paths_to_delete.append(asm_file)
    if sv_file.exists(): # sv_file can be None if --sub-dir not applicable
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
    except EOFError: # Handle non-interactive environments
        print("Confirmation required (yes/No). Clean operation cancelled (non-interactive environment or no input).")
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


def run_assembler(asm_file_path: Path, fixture_output_dir: Path, asm_args_str: str, dry_run: bool) -> bool:
    """
    Runs the assembler for a given .asm file.
    Returns True on success, False on error.
    """
    print(f"\n--- Assembling: {asm_file_path.name} (Output to: {fixture_output_dir.relative_to(PROJECT_ROOT)}) ---")

    if not asm_file_path.is_file() and not dry_run:
        print(f"Error: ASM source file not found: {asm_file_path.relative_to(PROJECT_ROOT)}")
        return False
    elif not asm_file_path.is_file() and dry_run:
         print(f"[DRY RUN] ASM source file {asm_file_path.relative_to(PROJECT_ROOT)} would be used.")
         # Allow dry run to proceed to show command, even if file doesn't exist yet

    if not ASSEMBLER_SCRIPT_PATH.is_file():
        print(f"Error: Assembler script not found: {ASSEMBLER_SCRIPT_PATH.relative_to(PROJECT_ROOT)}")
        if not dry_run: return False


    if not dry_run:
        try:
            fixture_output_dir.mkdir(parents=True, exist_ok=True)
        except OSError as e:
            print(f"Error: Could not create/ensure fixture directory {fixture_output_dir} for assembler output: {e}")
            return False
    else:
        if not fixture_output_dir.exists():
            print(f"[DRY RUN] Fixture output directory {fixture_output_dir.relative_to(PROJECT_ROOT)} would be created if it doesn't exist.")


    asm_command_base = [
        sys.executable,
        str(ASSEMBLER_SCRIPT_PATH),
        str(asm_file_path),
        str(fixture_output_dir),
    ]
    if asm_args_str:
        additional_asm_args = asm_args_str.split()
        asm_command_final = asm_command_base + additional_asm_args
    else:
        default_region_args = ["--region", "ROM", "F000", "FFFF"] # Default for each assembly
        asm_command_final = asm_command_base + default_region_args

    print(f"\nExecuting assembler command:")
    display_command = [Path(sys.executable).name]
    for p_str in asm_command_final[1:]:
        p_path = Path(p_str)
        # Check if path is absolute and can be made relative to PROJECT_ROOT
        # Also handle cases where p_str might not be a path (e.g. "--region")
        try:
            if p_path.is_absolute() and PROJECT_ROOT in p_path.parents:
                display_command.append(str(p_path.relative_to(PROJECT_ROOT)))
            else:
                display_command.append(p_str)
        except OSError: # Handle cases where p_str is not a valid path component
            display_command.append(p_str)

    print(f"  $ {' '.join(display_command)}")
    print(f"(Running from: {PROJECT_ROOT})")


    if dry_run:
        print("[DRY RUN] Assembler command would be executed.")
        return True

    try:
        process = subprocess.run(
            asm_command_final,
            check=True, # Will raise CalledProcessError for non-zero exit codes
            capture_output=True,
            text=True,
            cwd=PROJECT_ROOT # Important to run assembler from consistent location
        )
        if process.stdout: print("\nAssembler STDOUT:\n" + process.stdout.strip())
        if process.stderr: print("\nAssembler STDERR:\n" + process.stderr.strip())
        print(f"\n--- Assembly for '{asm_file_path.stem}' successful. ---")
        return True
    except subprocess.CalledProcessError as e:
        print("\n--- Error during assembly! ---")
        print(f"Command failed with return code {e.returncode}")
        if e.stdout: print("\nAssembler STDOUT:\n" + e.stdout.strip())
        if e.stderr: print("\nAssembler STDERR:\n" + e.stderr.strip())
        return False
    except FileNotFoundError:
        print(f"Error: Could not find Python interpreter or assembler script: {ASSEMBLER_SCRIPT_PATH}")
        return False
    except Exception as e:
        print(f"An unexpected error occurred during assembly: {e}")
        return False

def main():
    parser = argparse.ArgumentParser(
        description="Automate test case setup and assembly for the 8-bit computer project.",
        formatter_class=argparse.RawTextHelpFormatter
    )
    # Group for mutually exclusive operations
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument(
        "--test-name",
        type=str,
        help="The name of the test (e.g., 'ADD_B'). Used for init, clean, or single assembly."
    )
    group.add_argument(
        "--batch-assemble-all",
        action="store_true",
        help="Reassemble all .asm files found in software/asm/src/."
    )

    parser.add_argument(
        "--sub-dir",
        type=str,
        choices=VALID_TEST_SUBDIRS,
        help=(
            "The sub-directory within 'hardware/test/' where the .sv testbench will be created. "
            f"Required if --test-name and (--init or --clean) are used. Choices: {', '.join(VALID_TEST_SUBDIRS)}"
        )
    )
    parser.add_argument(
        "--init",
        action="store_true",
        help="Initialize new test files (.asm, .sv) from templates. Requires --test-name and --sub-dir."
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Force overwrite of existing .asm and .sv files during --init."
    )
    parser.add_argument(
        "--clean",
        action="store_true",
        help="Remove all generated artifacts for the specified --test-name. Requires --sub-dir to locate .sv file."
    )
    parser.add_argument(
        "--asm-args",
        type=str,
        default="",
        help="Additional arguments to pass to the assembler, e.g., \"--region RAM 0000 1FFF\"."
              "\nDefault ROM region for single test or batch items: --region ROM F000 FFFF"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be done without actually making any changes or running commands."
    )

    args = parser.parse_args()
    dry_run = args.dry_run

    if dry_run:
        print("********* DRY RUN MODE ENABLED *********")
        print("* No files will be created/modified. *")
        print("* No commands will be executed.      *")
        print("**************************************\n")

    if args.batch_assemble_all:
        print("\n--- Starting Batch Assembly of all .asm files in software/asm/src/ ---")
        asm_files_found = sorted(list(ASM_SRC_DIR.glob("*.asm")))
        if not asm_files_found:
            print(f"No .asm files found in {ASM_SRC_DIR.relative_to(PROJECT_ROOT)}.")
            sys.exit(0)

        print(f"Found {len(asm_files_found)} .asm files to process.")
        success_count = 0
        failure_count = 0
        failed_files_list = []

        for asm_file_path in asm_files_found:
            test_name_from_file = asm_file_path.stem
            fixture_dir = GENERATED_FIXTURES_BASE_DIR / test_name_from_file
            
            if run_assembler(asm_file_path, fixture_dir, args.asm_args, dry_run):
                success_count += 1
            else:
                failure_count += 1
                failed_files_list.append(str(asm_file_path.relative_to(PROJECT_ROOT)))

        print("\n--- Batch Assembly Summary ---")
        print(f"Successfully assembled: {success_count} file(s)")
        print(f"Failed to assemble:   {failure_count} file(s)")

        if failure_count > 0:
            print("\nList of failed files:")
            for failed_file in failed_files_list:
                print(f"  - {failed_file}")
            if not dry_run: # Only exit with error if not a dry run
                sys.exit(1)
        sys.exit(0)


    # --- Logic for individual test_name operations ---
    # test_name is guaranteed to be provided if not batch_assemble_all
    test_name = args.test_name
    new_asm_file_path = ASM_SRC_DIR / f"{test_name}.asm"
    test_fixture_output_dir = GENERATED_FIXTURES_BASE_DIR / test_name
    
    new_sv_file_path = None
    if args.sub_dir:
        target_sv_test_dir = SV_TEST_BASE_DIR / args.sub_dir
        new_sv_file_path = target_sv_test_dir / f"{test_name}_tb.sv"
    elif args.init or args.clean:
        parser.error("--sub-dir is required when using --init or --clean with --test-name.")


    if args.clean:
        # new_sv_file_path would be None if --sub-dir wasn't provided, caught by parser.error above.
        clean_test_artifacts(test_name, new_asm_file_path, new_sv_file_path, test_fixture_output_dir, dry_run)
        sys.exit(0)

    init_skipped_any_file = False
    init_errors_occurred = False

    if args.init:
        # --sub-dir is guaranteed by parser.error check above for --init
        print(f"\n--- Initializing test: {test_name} in hardware/test/{args.sub_dir}/ ---")

        print(f"\nProcessing ASM source file...")
        asm_status = create_file_from_template(ASM_TEMPLATE_FILE, new_asm_file_path, test_name, dry_run, args.force)
        if asm_status == "skipped": init_skipped_any_file = True
        elif asm_status == "error": init_errors_occurred = True

        print(f"\nEnsuring fixture directory exists...")
        if dry_run:
            print(f"[DRY RUN] Would ensure directory exists: {test_fixture_output_dir.relative_to(PROJECT_ROOT)}")
        else:
            if not test_fixture_output_dir.exists(): # Check before creating
                 try:
                    test_fixture_output_dir.mkdir(parents=True, exist_ok=True)
                    print(f"Successfully created directory: {test_fixture_output_dir.relative_to(PROJECT_ROOT)}")
                 except OSError as e:
                    print(f"Error: Could not create directory {test_fixture_output_dir}: {e}")
                    init_errors_occurred = True
            else:
                 print(f"Directory already exists: {test_fixture_output_dir.relative_to(PROJECT_ROOT)}")


        print(f"\nProcessing SystemVerilog testbench file in hardware/test/{args.sub_dir}/ ...")
        # new_sv_file_path is guaranteed to be set if --sub-dir was provided
        sv_status = create_file_from_template(SV_TEMPLATE_FILE, new_sv_file_path, test_name, dry_run, args.force)
        if sv_status == "skipped": init_skipped_any_file = True
        elif sv_status == "error": init_errors_occurred = True
        
        if not dry_run and init_errors_occurred:
            print(f"\n--- Initialization for '{test_name}' failed due to errors. Aborting. ---")
            sys.exit(1)
        
        # Determine if we should proceed to assembly
        proceed_to_asm = False
        if dry_run:
            print(f"[DRY RUN] Would assemble {new_asm_file_path.name} after initialization if successful.")
            proceed_to_asm = True # Show the command for dry run
        elif not init_errors_occurred: # No errors, proceed
            if init_skipped_any_file:
                print(f"\n--- Initialization for '{test_name}' involved skipping some existing files. ---")
                print(f"To overwrite these files, use the --force flag.")
                # Optionally, you might want to ask the user if they want to assemble skipped files
                # For now, we'll proceed to assemble.
            print(f"\n--- Initialization for '{test_name}' complete. Proceeding to assembly. ---")
            proceed_to_asm = True
        else: # init_errors_occurred is True and not dry_run
             print(f"\n--- Initialization for '{test_name}' failed. Assembly will be SKIPPED. ---")


        if proceed_to_asm:
            if not run_assembler(new_asm_file_path, test_fixture_output_dir, args.asm_args, dry_run):
                if not dry_run: # Only exit with error if not a dry run
                    print(f"\n--- Assembly FAILED after initialization for '{test_name}'. ---")
                    sys.exit(1)
            elif not dry_run: # Assembly was successful and not dry_run
                print(f"\n--- Assembly successful after initialization for '{test_name}'. ---")
        
        sys.exit(0) # Exit after --init path

    # --- If not --init, --clean, or --batch-assemble-all, then it's a single assembly run for --test-name ---
    if not run_assembler(new_asm_file_path, test_fixture_output_dir, args.asm_args, dry_run):
        if not dry_run: sys.exit(1) # Exit with error if assembly fails and not a dry run

    print("\nScript finished successfully.")

if __name__ == "__main__":
    main()