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
# Assuming this script (test_manager.py) is in project_root/scripts/devtools/
PROJECT_ROOT = SCRIPT_FILE_PATH.parent.parent.parent

# --- Define Template and Target Directory Paths (relative to PROJECT_ROOT) ---
ASM_TEMPLATE_FILE = PROJECT_ROOT / "software/asm/templates/test_template.asm"
SV_TEMPLATE_FILE = PROJECT_ROOT / "hardware/test/templates/test_template.sv"

# AIDEV-NOTE: Updated for reorganized asm src structure with programs/ and hardware_validation/
ASM_SRC_DIR = PROJECT_ROOT / "software/asm/src"
HARDWARE_VALIDATION_DIR = ASM_SRC_DIR / "hardware_validation"
PROGRAMS_DIR = ASM_SRC_DIR / "programs"
SV_TEST_BASE_DIR = PROJECT_ROOT / "hardware/test"
GENERATED_FIXTURES_BASE_DIR = PROJECT_ROOT / "hardware/test/_fixtures_generated"

ASSEMBLER_SCRIPT_PATH = PROJECT_ROOT / "software/assembler/src/assembler.py"

# Define valid categories for tests
VALID_VERILOG_CATEGORIES = ["instruction_set", "cpu_control", "modules"]
VALID_ASM_CATEGORIES = ["instruction_set", "integration", "peripherals"]


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


def run_assembler(asm_file_path: Path, fixture_output_dir: Path, asm_args_str: str, dry_run: bool) -> bool:
    """
    Runs the assembler for a given .asm file.
    The fixture_output_dir is passed as the 'output_specifier' to assembler.py,
    which assembler.py uses as the base directory for its region-named .hex files.
    Returns True on success, False on error.
    """
    print(f"\n--- Assembling: {asm_file_path.name} (Output to: {fixture_output_dir.relative_to(PROJECT_ROOT)}) ---")

    if not asm_file_path.is_file() and not dry_run:
        print(f"Error: ASM source file not found: {asm_file_path.relative_to(PROJECT_ROOT)}")
        return False
    elif not asm_file_path.is_file() and dry_run:
         print(f"[DRY RUN] ASM source file {asm_file_path.relative_to(PROJECT_ROOT)} would be used.")

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

    # Base command: python assembler.py <input_asm> <output_dir_for_regions>
    asm_command_base = [
        sys.executable,
        str(ASSEMBLER_SCRIPT_PATH),
        str(asm_file_path),
        str(fixture_output_dir), # This is the 'output_specifier' for assembler.py
    ]

    # Determine the region arguments to pass to assembler.py
    final_region_args = []
    if asm_args_str: # If --asm-args are explicitly provided to this script
        print(f"INFO: Using custom assembler arguments passed via --asm-args: \"{asm_args_str}\"")
        final_region_args = asm_args_str.split()
    else:
        # Default to defining both ROM and RAM regions for assembler.py
        print("INFO: No explicit --asm-args provided. Using default ROM and RAM regions for assembler.py.")
        # Adjust these addresses and names as per your CPU architecture and assembler.py expectations
        default_regions = [
            "--region", "ROM", "F000", "FFFF",  # Example ROM region
            "--region", "RAM", "0000", "1FFF"   # Example RAM region (covers $1234)
                                                # Ensure this range is appropriate for your RAM
        ]
        final_region_args.extend(default_regions)

    asm_command_final = asm_command_base + final_region_args

    print(f"\nExecuting assembler command:")
    # Create a display-friendly version of the command
    display_command_parts = [Path(sys.executable).name]
    for part in asm_command_final[1:]: # Skip the python executable itself for display
        p_path = Path(part)
        try:
            # Try to make paths relative for cleaner display
            if p_path.is_absolute() and PROJECT_ROOT in p_path.parents:
                display_command_parts.append(str(p_path.relative_to(PROJECT_ROOT)))
            else:
                display_command_parts.append(str(part)) # Use string representation
        except OSError: # Handle cases where part is not a valid path component (e.g. "--region")
            display_command_parts.append(str(part))

    print(f"  $ {' '.join(display_command_parts)}")
    print(f"(Running from: {PROJECT_ROOT})")

    if dry_run:
        print("[DRY RUN] Assembler command would be executed.")
        return True

    try:
        # Ensure all command parts are strings for subprocess.run
        str_asm_command_final = [str(p) for p in asm_command_final]
        process = subprocess.run(
            str_asm_command_final,
            check=True,
            capture_output=True,
            text=True,
            cwd=PROJECT_ROOT
        )
        if process.stdout: print("\nAssembler STDOUT:\n" + process.stdout.strip())
        if process.stderr: print("\nAssembler STDERR:\n" + process.stderr.strip()) # assembler.py logs here
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


def cmd_init(args):
    """Initialize new test files (.asm, .sv) from templates."""
    if args.dry_run:
        print("********* DRY RUN MODE ENABLED *********")
        print("* No files will be created/modified.   *")
        print("**************************************\n")

    test_name = args.test_name
    # AIDEV-NOTE: Use specified asm-category for new test files
    new_asm_file_path = HARDWARE_VALIDATION_DIR / args.asm_category / f"{test_name}.asm"
    target_sv_test_dir = SV_TEST_BASE_DIR / args.verilog_category
    new_sv_file_path = target_sv_test_dir / f"{test_name}_tb.sv"
    test_fixture_output_dir = GENERATED_FIXTURES_BASE_DIR / test_name

    print(f"\n--- Initializing test: {test_name} in hardware/test/{args.verilog_category}/ ---")

    # Create ASM file from template
    asm_status = create_file_from_template(ASM_TEMPLATE_FILE, new_asm_file_path, test_name, args.dry_run, args.force)
    
    # Create SV file from template
    sv_status = create_file_from_template(SV_TEMPLATE_FILE, new_sv_file_path, test_name, args.dry_run, args.force)

    proceed_to_asm = False
    if args.dry_run:
        proceed_to_asm = True
    elif asm_status in ["created", "overwritten"] and sv_status in ["created", "overwritten"]:
        proceed_to_asm = True
    elif asm_status == "skipped" and sv_status == "skipped":
        print(f"\nBoth files already exist for test '{test_name}'. Use --force to overwrite.")
        print("Proceeding with assembly of existing .asm file...")
        proceed_to_asm = True
    elif asm_status in ["created", "overwritten", "skipped"] and sv_status in ["created", "overwritten", "skipped"]:
        proceed_to_asm = True
    else:
        print(f"\n--- Initialization FAILED for '{test_name}' due to template creation errors. ---")
        if not args.dry_run:
            sys.exit(1)
        proceed_to_asm = False

    if proceed_to_asm:
        if not run_assembler(new_asm_file_path, test_fixture_output_dir, getattr(args, 'asm_args', ''), args.dry_run):
            if not args.dry_run:
                print(f"\n--- Assembly FAILED after initialization for '{test_name}'. ---")
                sys.exit(1)
        elif not args.dry_run:
            print(f"\n--- Assembly successful after initialization for '{test_name}'. ---")

    print("Initialization complete.")


def cmd_assemble(args):
    """Assemble a single test."""
    if args.dry_run:
        print("********* DRY RUN MODE ENABLED *********")
        print("* No commands will be executed.        *")
        print("**************************************\n")

    test_name = args.test_name
    # AIDEV-NOTE: Look for existing assembly file in hardware_validation subdirectories
    new_asm_file_path = None
    for subdir in ["instruction_set", "integration", "peripherals"]:
        candidate_path = HARDWARE_VALIDATION_DIR / subdir / f"{test_name}.asm"
        if candidate_path.exists():
            new_asm_file_path = candidate_path
            break
    if new_asm_file_path is None:
        print(f"Error: Assembly file {test_name}.asm not found in any hardware_validation subdirectory.")
        return
    test_fixture_output_dir = GENERATED_FIXTURES_BASE_DIR / test_name

    if not run_assembler(new_asm_file_path, test_fixture_output_dir, args.asm_args, args.dry_run):
        if not args.dry_run:
            sys.exit(1)

    print("Assembly complete.")


def cmd_assemble_all_sources(args):
    """Assemble all .asm files in software/asm/src/."""
    if args.dry_run:
        print("********* DRY RUN MODE ENABLED *********")
        print("* No commands will be executed.        *")
        print("**************************************\n")

    print("\n--- Starting Batch Assembly of all .asm files in hardware_validation/ subdirectories ---")
    # AIDEV-NOTE: Search hardware_validation subdirectories for test assembly files
    asm_files_found = []
    for subdir in ["instruction_set", "integration", "peripherals"]:
        subdir_path = HARDWARE_VALIDATION_DIR / subdir
        if subdir_path.exists():
            asm_files_found.extend(list(subdir_path.glob("*.asm")))
    asm_files_found = sorted(asm_files_found)
    if not asm_files_found:
        print(f"No .asm files found in {ASM_SRC_DIR.relative_to(PROJECT_ROOT)}.")
        return

    print(f"Found {len(asm_files_found)} .asm files to process.")
    success_count = 0
    failure_count = 0
    failed_files_list = []

    for asm_file_path in asm_files_found:
        test_name_from_file = asm_file_path.stem
        fixture_dir = GENERATED_FIXTURES_BASE_DIR / test_name_from_file
        if run_assembler(asm_file_path, fixture_dir, args.asm_args, args.dry_run):
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
        if not args.dry_run:
            sys.exit(1)


def cmd_clean(args):
    """Clean test artifacts for a specific test."""
    if args.dry_run:
        print("********* DRY RUN MODE ENABLED *********")
        print("* No files will be deleted.            *")
        print("**************************************\n")

    test_name = args.test_name
    # AIDEV-NOTE: Look for existing assembly file in hardware_validation subdirectories
    new_asm_file_path = None
    for subdir in ["instruction_set", "integration", "peripherals"]:
        candidate_path = HARDWARE_VALIDATION_DIR / subdir / f"{test_name}.asm"
        if candidate_path.exists():
            new_asm_file_path = candidate_path
            break
    if new_asm_file_path is None:
        print(f"Error: Assembly file {test_name}.asm not found in any hardware_validation subdirectory.")
        return
    target_sv_test_dir = SV_TEST_BASE_DIR / args.verilog_category
    new_sv_file_path = target_sv_test_dir / f"{test_name}_tb.sv"
    test_fixture_output_dir = GENERATED_FIXTURES_BASE_DIR / test_name

    clean_test_artifacts(test_name, new_asm_file_path, new_sv_file_path, test_fixture_output_dir, args.dry_run)


def main():
    parser = argparse.ArgumentParser(
        description="Developer utility for managing test case files and assembly.",
        formatter_class=argparse.RawTextHelpFormatter
    )
    
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be done without actually making any changes or running commands."
    )

    subparsers = parser.add_subparsers(dest='command', help='Available commands')

    # Init subcommand
    init_parser = subparsers.add_parser('init', help='Initialize new test files (.asm, .sv) from templates')
    init_parser.add_argument('--test-name', type=str, required=True, help='The name of the test (e.g., "ADD_B")')
    init_parser.add_argument('--asm-category', type=str, choices=VALID_ASM_CATEGORIES, default='instruction_set',
                           help=f'Assembly category. Choices: {", ".join(VALID_ASM_CATEGORIES)} (default: instruction_set)')
    init_parser.add_argument('--verilog-category', type=str, choices=VALID_VERILOG_CATEGORIES, default='instruction_set',
                           help=f'Verilog testbench category. Choices: {", ".join(VALID_VERILOG_CATEGORIES)} (default: instruction_set)')
    init_parser.add_argument('--force', action='store_true', help='Force overwrite of existing files')
    init_parser.add_argument('--dry-run', action='store_true', help='Show what would be done without execution')

    # Assemble subcommand
    assemble_parser = subparsers.add_parser('assemble', help='Assemble a single test')
    assemble_parser.add_argument('--test-name', type=str, required=True, help='The name of the test to assemble')
    assemble_parser.add_argument('--asm-args', type=str, default='',
                               help='Raw arguments to pass to assembler.py (e.g., "--region FOO 0000 0FFF")')
    assemble_parser.add_argument('--dry-run', action='store_true', help='Show what would be done without execution')

    # Assemble-all-sources subcommand
    assemble_all_parser = subparsers.add_parser('assemble-all-sources', 
                                              help='Assemble all .asm files in software/asm/src/')
    assemble_all_parser.add_argument('--asm-args', type=str, default='',
                                   help='Raw arguments to pass to assembler.py for all files')
    assemble_all_parser.add_argument('--dry-run', action='store_true', help='Show what would be done without execution')

    # Clean subcommand
    clean_parser = subparsers.add_parser('clean', help='Remove generated artifacts for a test')
    clean_parser.add_argument('--test-name', type=str, required=True, help='The name of the test to clean')
    clean_parser.add_argument('--verilog-category', type=str, choices=VALID_VERILOG_CATEGORIES, required=True,
                            help=f'Verilog testbench category. Choices: {", ".join(VALID_VERILOG_CATEGORIES)}')
    clean_parser.add_argument('--dry-run', action='store_true', help='Show what would be done without execution')

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        sys.exit(1)

    # Execute the appropriate command
    if args.command == 'init':
        cmd_init(args)
    elif args.command == 'assemble':
        cmd_assemble(args)
    elif args.command == 'assemble-all-sources':
        cmd_assemble_all_sources(args)
    elif args.command == 'clean':
        cmd_clean(args)
    else:
        print(f"Unknown command: {args.command}")
        sys.exit(1)

    print("Script finished successfully.")


if __name__ == "__main__":
    main()