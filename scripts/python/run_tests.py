#!/usr/bin/env python3

import argparse
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import List, Tuple, Dict

# --- Configuration (matching simulate.sh closely) ---
SCRIPT_FILE_PATH = Path(__file__).resolve()
PROJECT_ROOT = SCRIPT_FILE_PATH.parent.parent.parent # Assumes script is in scripts/python/
HARDWARE_DIR = PROJECT_ROOT / "hardware"
BUILD_DIR = PROJECT_ROOT / "build" # For sim.vvp, combined_from_sv.v, etc.

SIM_TEMP_DIR_NAME = "sim_run_all_temp" # For individual test logs
SIM_TEMP_LOG_DIR = BUILD_DIR / SIM_TEMP_DIR_NAME # Where individual test logs go

MAIN_LOG_FILE = PROJECT_ROOT / "test_run_all.log"
REPORT_FILE = PROJECT_ROOT / "test_report_all.txt"

IVERILOG_CMD = "iverilog"
VVP_CMD = "vvp"
VVP_DEFAULT_FLAGS = []
SV2V_CMD = "sv2v"

# From simulate.sh: -DSIMULATION -g2012
IVERILOG_COMPILER_FLAGS = ["-DSIMULATION", "-g2012"]
# From simulate.sh: -I hardware/test -I hardware/src -I hardware/src/constants ...
IVERILOG_INCLUDE_PATHS_REL = [ # Relative to PROJECT_ROOT
    "hardware/src",
    "hardware/src/constants",
    "hardware/src/cpu",
    "hardware/src/peripherals",
    "hardware/src/utils",
    "hardware/test"
]

SV2V_DEFINE_FLAGS = ["-DSIMULATION"] # Defines for sv2v
SV2V_INCLUDE_PATHS_REL = [ # For sv2v to find packages etc.
    "hardware/src",
    "hardware/src/constants",
    "hardware/test"
]


TEST_CATEGORIES: Dict[str, Path] = {
    "All_Tests": HARDWARE_DIR / "test",
    # Future:
    # "ISA_Tests": HARDWARE_DIR / "test" / "ISA",
    # "CPU_Control_Tests": HARDWARE_DIR / "test" / "cpu_control",
}

# --- Helper Functions (run_command, check_test_pass - can remain similar) ---
def run_command(cmd: List[str], cwd: Path, log_file_path: Path, specific_log_path: Path) -> Tuple[int, str, str]:
    # ... (same as before, ensure it logs cmd and cwd if verbose) ...
    try:
        # print(f"DEBUG CMD: cd {cwd} && {' '.join(str(c) for c in cmd)}") # For debugging
        process = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, check=False)
        with open(log_file_path, "a", encoding="utf-8") as main_log:
            main_log.write(f"\n--- CMD: {' '.join(str(c) for c in cmd)} (CWD: {cwd}) ---\n")
            main_log.write(f"--- STDOUT ---\n{process.stdout}\n")
            if process.stderr: main_log.write(f"--- STDERR ---\n{process.stderr}\n")
        with open(specific_log_path, "w", encoding="utf-8") as specific_log:
            specific_log.write(f"CMD: {' '.join(str(c) for c in cmd)} (CWD: {cwd})\n")
            specific_log.write("--- STDOUT ---\n"); specific_log.write(process.stdout)
            if process.stderr: specific_log.write("\n--- STDERR ---\n"); specific_log.write(process.stderr)
        return process.returncode, process.stdout, process.stderr
    except FileNotFoundError:
        # ... (same error handling) ...
        error_msg = f"Error: Command not found: {cmd[0]}"
        with open(log_file_path, "a", encoding="utf-8") as main_log: main_log.write(error_msg + "\n")
        with open(specific_log_path, "w", encoding="utf-8") as specific_log: specific_log.write(error_msg + "\n")
        return -1, "", error_msg
    except Exception as e:
        error_msg = f"Exception during command execution: {e}"
        with open(log_file_path, "a", encoding="utf-8") as main_log: main_log.write(error_msg + "\n")
        with open(specific_log_path, "w", encoding="utf-8") as specific_log: specific_log.write(error_msg + "\n")
        return -2, "", str(e)


def check_test_pass(output_log_path: Path, vvp_exit_code: int) -> bool:
    if not output_log_path.exists():
        # print(f"DEBUG: Log file {output_log_path.name} not found.")
        return False # Log file wasn't created, treat as fail

    with open(output_log_path, "r", encoding="utf-8") as f:
        content = f.read()

    # Check for explicit failure indicators first
    has_assertion_failed = bool(re.search(r"Assertion Failed:", content, re.IGNORECASE))
    has_simulation_timeout = bool(re.search(r"Simulation timed out.", content, re.IGNORECASE))
    
    # Check vvp exit code. 0 is pass for vvp unless $finish(non_zero) was called.
    vvp_failed_exit_code = (vvp_exit_code != 0)

    if vvp_failed_exit_code:
        # print(f"DEBUG: Test {output_log_path.name} failed due to vvp_exit_code {vvp_exit_code}")
        return False
    if has_assertion_failed:
        # print(f"DEBUG: Test {output_log_path.name} failed due to assertion.")
        return False
    if has_simulation_timeout:
        # print(f"DEBUG: Test {output_log_path.name} failed due to timeout.")
        return False

    # Now, check for the success message pattern
    # It looks for "<any_chars> test finished.==========================="
    # The re.MULTILINE is important if the message might not be the only thing on its line
    # or if content has multiple lines.
    # The re.IGNORECASE can be useful if casing might vary, though your template is specific.
    # Breaking down the regex:
    # r".*"       : any character (except newline), zero or more times (matches the test_name part)
    # r" test finished\.=" : literal string " test finished." followed by "=" (escaped dot)
    # r"=*"      : zero or more equal signs
    # The example uses "===========================" (27 equals signs)
    # We can make it more general or specific. Let's be specific for now.
    
    # Specific pattern from your template:
    # Waits for "<some_test_name> test finished.==========================="
    # The \s* allows for potential leading/trailing whitespace on the line if any
    success_pattern_regex = re.compile(r"^\s*.* test finished\.===========================\s*$", re.MULTILINE)
    has_test_finished_msg = bool(success_pattern_regex.search(content))

    if not has_test_finished_msg:
        # print(f"DEBUG: Test {output_log_path.name} failed due to missing specific finish message.")
        # print(f"DEBUG: Last 200 chars of log for {output_log_path.name}: '{content[-200:]}'")
        return False
            
    return True

# --- Main Script ---
def main():
    parser = argparse.ArgumentParser(description="Run Verilog testbenches.")
    parser.add_argument("--sv2v", action="store_true", help="Enable sv2v conversion for .sv files.")
    # Add --no-viz, --tb if needed, though this script will run all found tests.
    args = parser.parse_args()

    SIM_TEMP_LOG_DIR.mkdir(parents=True, exist_ok=True)
    if MAIN_LOG_FILE.exists(): MAIN_LOG_FILE.unlink()
    if REPORT_FILE.exists(): REPORT_FILE.unlink()
    MAIN_LOG_FILE.touch(); REPORT_FILE.touch()

    print(f"Running tests. Main log: {MAIN_LOG_FILE.relative_to(PROJECT_ROOT)}, Report: {REPORT_FILE.relative_to(PROJECT_ROOT)}")
    print(f"Individual test logs in: {SIM_TEMP_LOG_DIR.relative_to(PROJECT_ROOT)}")

    summary = {"total": 0, "passed": 0, "failed": 0, "comp_failed": 0, "exec_error": 0, "sv2v_failed": 0}
    overall_report_content = []

    for category_name, test_dir_abs_path in TEST_CATEGORIES.items():
        if not test_dir_abs_path.is_dir():
            print(f"Warning: Test directory not found for {category_name}: {test_dir_abs_path}")
            continue
        
        cat_report = [f"\n--------------------\nRUNNING TESTS IN: {category_name}\n--------------------"]
        print(f"\nProcessing category: {category_name}")

        testbench_files = list(test_dir_abs_path.glob("*_tb.sv")) + list(test_dir_abs_path.glob("*_tb.v"))
        if not testbench_files:
            msg = f"No testbenches (*_tb.sv or *_tb.v) found in {test_dir_abs_path}"
            print(msg); cat_report.append(msg)
            overall_report_content.extend(cat_report); continue

        for tb_path_abs in testbench_files:
            test_name_full = tb_path_abs.name
            test_name_short = tb_path_abs.stem.replace("_tb", "")
            
            # Logs for this specific test
            specific_compile_log = SIM_TEMP_LOG_DIR / f"{test_name_short}_compile.log"
            specific_sv2v_log = SIM_TEMP_LOG_DIR / f"{test_name_short}_sv2v.log"
            specific_run_log = SIM_TEMP_LOG_DIR / f"{test_name_short}_run.log"
            # Output files for this specific test (placed in BUILD_DIR for simplicity like simulate.sh)
            sim_vvp_file = BUILD_DIR / f"{test_name_short}_sim.vvp" # Unique name
            combined_sv_file = BUILD_DIR / f"{test_name_short}_combined_from_sv.v" # Unique name

            summary["total"] += 1
            msg_prefix = f"Running {test_name_full} ... "
            print(msg_prefix, end="", flush=True)

            # 1. Gather all DUT source files (absolute paths)
            all_dut_src_files_abs = []
            dut_file_list_f_path = HARDWARE_DIR / "src" / "_files_sim.f"
            if dut_file_list_f_path.is_file():
                hardware_src_dir = HARDWARE_DIR / "src"
                with open(dut_file_list_f_path, "r") as f_list:
                    for line in f_list:
                        line = line.strip()
                        if line and not line.startswith("#"):
                            # Paths in _files_sim.f are relative to hardware/src
                            all_dut_src_files_abs.append( (hardware_src_dir / line).resolve() )
            else:
                print(f"FATAL: _files_sim.f not found at {dut_file_list_f_path}")
                sys.exit(1)

            # 2. Add test utilities package (absolute path)
            test_utils_pkg_abs = (HARDWARE_DIR / "test" / "test_utilities_pkg.sv").resolve()
            if not test_utils_pkg_abs.is_file():
                print(f"WARNING: {test_utils_pkg_abs.name} not found, test may fail.")
            
            # List of files for sv2v or iverilog (excluding TB for now)
            files_for_processing = all_dut_src_files_abs + ([test_utils_pkg_abs] if test_utils_pkg_abs.is_file() else [])
            
            # 3. sv2v conversion (if enabled)
            final_files_for_iverilog = []
            if args.sv2v:
                sv_files_to_convert = [f for f in files_for_processing if f.suffix == ".sv"]
                v_files_to_keep = [f for f in files_for_processing if f.suffix == ".v"]

                if sv_files_to_convert:
                    # Add the testbench itself to the list of SV files if it's .sv
                    if tb_path_abs.suffix == ".sv" and tb_path_abs not in sv_files_to_convert:
                        sv_files_to_convert.append(tb_path_abs)
                    
                    sv2v_cmd_list = [SV2V_CMD] + SV2V_DEFINE_FLAGS
                    for p_rel in SV2V_INCLUDE_PATHS_REL: sv2v_cmd_list.extend(["-I", str(PROJECT_ROOT / p_rel)])
                    sv2v_cmd_list.extend([str(p) for p in sv_files_to_convert]) # Pass absolute paths
                    
                    # Redirect sv2v output to file
                    ret_code, stdout, stderr = run_command(sv2v_cmd_list + ["-w", str(combined_sv_file)], PROJECT_ROOT, MAIN_LOG_FILE, specific_sv2v_log)

                    if ret_code != 0:
                        status = "SV2V FAILED"
                        print(status); cat_report.append(f"{msg_prefix}{status} (see {specific_sv2v_log.relative_to(PROJECT_ROOT)})")
                        summary["failed"] += 1; summary["sv2v_failed"] += 1
                        if combined_sv_file.exists(): combined_sv_file.unlink()
                        continue # Next testbench
                    final_files_for_iverilog.append(combined_sv_file)
                    final_files_for_iverilog.extend(v_files_to_keep)
                else: # No .sv files to convert among DUT/utils
                    final_files_for_iverilog.extend(files_for_processing)
                    if tb_path_abs.suffix == ".v": # If TB is plain Verilog
                         final_files_for_iverilog.append(tb_path_abs)
                    else: # Should not happen if no .sv files found and TB is .sv
                         print(f"Warning: sv2v enabled but no .sv files including TB {tb_path_abs.name}")


            else: # No sv2v
                final_files_for_iverilog.extend(files_for_processing)
                final_files_for_iverilog.append(tb_path_abs) # Add the testbench

            # 4. Compile with iverilog
            iverilog_cmd_list = [IVERILOG_CMD] + IVERILOG_COMPILER_FLAGS + ["-o", str(sim_vvp_file)]
            for p_rel in IVERILOG_INCLUDE_PATHS_REL: iverilog_cmd_list.extend(["-I", str(PROJECT_ROOT / p_rel)])
            iverilog_cmd_list.extend([str(p) for p in final_files_for_iverilog]) # Pass absolute paths

            ret_code, _, _ = run_command(iverilog_cmd_list, PROJECT_ROOT, MAIN_LOG_FILE, specific_compile_log)

            if ret_code != 0:
                status = "IVERILOG COMPILATION FAILED"
                print(status); cat_report.append(f"{msg_prefix}{status} (see {specific_compile_log.relative_to(PROJECT_ROOT)})")
                summary["failed"] += 1; summary["comp_failed"] += 1
                if sim_vvp_file.exists(): sim_vvp_file.unlink()
                continue

            # 5. Run with vvp
            vvp_cmd_list = [VVP_CMD] + VVP_DEFAULT_FLAGS + [sim_vvp_file.name] # vvp uses name in CWD
            ret_code, _, _ = run_command(vvp_cmd_list, BUILD_DIR, MAIN_LOG_FILE, specific_run_log)

            if check_test_pass(specific_run_log, ret_code):
                status = "PASS"; print(status); cat_report.append(f"{msg_prefix}{status}"); summary["passed"] += 1
            else:
                status = "FAIL (SIMULATION)"; print(status); cat_report.append(f"{msg_prefix}{status} (see {specific_run_log.relative_to(PROJECT_ROOT)})"); summary["failed"] += 1
                if ret_code < 0: summary["exec_error"] += 1
            
            # Cleanup for this test
            if sim_vvp_file.exists(): sim_vvp_file.unlink()
            if args.sv2v and combined_sv_file.exists(): combined_sv_file.unlink()
        
        overall_report_content.extend(cat_report)
    
    # ... (Final Summary printing as before) ...
    summary_lines = [f"\n======================================\nTEST SUMMARY\n======================================"]
    summary_lines.append(f"Total tests attempted: {summary['total']}")
    summary_lines.append(f"Passed: {summary['passed']}")
    summary_lines.append(f"Failed: {summary['failed']}")
    if summary['comp_failed'] > 0: summary_lines.append(f"  Compilation Failures: {summary['comp_failed']}")
    if summary['sv2v_failed'] > 0: summary_lines.append(f"  sv2v Failures: {summary['sv2v_failed']}")
    if summary['exec_error'] > 0: summary_lines.append(f"  Execution/Script Errors: {summary['exec_error']}")
    summary_lines.append("======================================")
    final_summary_str = "\n".join(summary_lines)
    print(final_summary_str)
    with open(REPORT_FILE, "a", encoding="utf-8") as f:
        for line in overall_report_content: f.write(line + "\n")
        f.write(final_summary_str + "\n")

    # ... (Exit status logic as before) ...
    if summary["failed"] > 0: print("THERE WERE TEST FAILURES!"); sys.exit(1)
    elif summary["total"] == 0: print("NO TESTS WERE RUN."); sys.exit(0) 
    else: print("ALL TESTS PASSED!"); sys.exit(0)


if __name__ == "__main__":
    main()