#!/usr/bin/env python3

import argparse
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import List, Tuple, Dict

# --- Configuration ---
SCRIPT_FILE_PATH = Path(__file__).resolve()
PROJECT_ROOT = SCRIPT_FILE_PATH.parent.parent.parent
HARDWARE_DIR = PROJECT_ROOT / "hardware"
BUILD_DIR = PROJECT_ROOT / "build"

SIM_TEMP_DIR_NAME = "sim_run_all_temp"
SIM_TEMP_LOG_DIR = BUILD_DIR / SIM_TEMP_DIR_NAME

MAIN_LOG_FILE = PROJECT_ROOT / "test_run_all.log"
REPORT_FILE = PROJECT_ROOT / "test_report_all.txt"

IVERILOG_CMD = "iverilog"
VVP_CMD = "vvp"
SV2V_CMD = "sv2v"

IVERILOG_COMPILER_FLAGS = ["-DSIMULATION", "-g2012"] # No -s flag
IVERILOG_INCLUDE_PATHS_REL = [
    "hardware/src", "hardware/src/constants", "hardware/src/cpu",
    "hardware/src/peripherals", "hardware/src/utils", "hardware/test"
]
SV2V_DEFINE_FLAGS = ["-DSIMULATION"]
SV2V_INCLUDE_PATHS_REL = [
    "hardware/src", "hardware/src/constants", "hardware/test"
]

# Updated for new directory structure
TEST_CATEGORIES: Dict[str, Path] = {
    "Instruction_Set_Tests": HARDWARE_DIR / "test" / "instruction_set",
    "CPU_Control_Tests": HARDWARE_DIR / "test" / "cpu_control",
    "Module_Tests": HARDWARE_DIR / "test" / "modules",
}
DUT_FILE_LIST_PATH_REL = "hardware/src/_files_sim.f" # Relative to PROJECT_ROOT
TIMESCALEP_FILE_PATH_REL = "hardware/src/utils/timescale.v" # Relative to PROJECT_ROOT
TEST_UTILITIES_PKG_PATH_REL = "hardware/test/test_utilities_pkg.sv" # Relative to PROJECT_ROOT

VVP_DEFAULT_FLAGS = [] # Define this as it was missing

# --- Helper Functions ---
def run_command(cmd: List[str], cwd: Path, log_file_path: Path, specific_log_path: Path) -> Tuple[int, str, str]:
    try:
        # For debugging the exact command being run
        # print(f"DEBUG CMD: cd {cwd} && {' '.join(str(c) for c in cmd)}")

        process = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, check=False)
        # Append to main log
        with open(log_file_path, "a", encoding="utf-8") as main_log:
            main_log.write(f"\n--- CMD: {' '.join(str(c) for c in cmd)} (CWD: {cwd}) ---\n")
            main_log.write(f"--- STDOUT ---\n{process.stdout}\n")
            if process.stderr:
                main_log.write(f"--- STDERR ---\n{process.stderr}\n")
        # Write to specific log
        with open(specific_log_path, "w", encoding="utf-8") as specific_log:
            specific_log.write(f"CMD: {' '.join(str(c) for c in cmd)} (CWD: {cwd})\n")
            specific_log.write("--- STDOUT ---\n")
            specific_log.write(process.stdout)
            if process.stderr:
                specific_log.write("\n--- STDERR ---\n")
                specific_log.write(process.stderr)
        return process.returncode, process.stdout, process.stderr
    except FileNotFoundError:
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
    if not output_log_path.exists(): return False
    with open(output_log_path, "r", encoding="utf-8") as f: content = f.read()
    has_assertion_failed = bool(re.search(r"Assertion Failed:", content, re.IGNORECASE))
    has_simulation_timeout = bool(re.search(r"Simulation timed out.", content, re.IGNORECASE))
    vvp_failed_exit_code = (vvp_exit_code != 0)
    if vvp_failed_exit_code or has_assertion_failed or has_simulation_timeout: return False
    
    # Check for your specific success message from the template
    success_pattern_regex = re.compile(r"^\s*.* test finished\.===========================\s*$", re.MULTILINE)
    has_test_finished_msg = bool(success_pattern_regex.search(content))
    if not has_test_finished_msg: return False
    return True

# --- Main Script ---
def main():
    # sv2v is now mandatory, so --sv2v flag is removed from argparse
    parser = argparse.ArgumentParser(description="Run Verilog testbenches (sv2v is always used).")
    args = parser.parse_args()

    SIM_TEMP_LOG_DIR.mkdir(parents=True, exist_ok=True)
    if MAIN_LOG_FILE.exists(): MAIN_LOG_FILE.unlink()
    if REPORT_FILE.exists(): REPORT_FILE.unlink()
    MAIN_LOG_FILE.touch(); REPORT_FILE.touch()

    print(f"Running tests (sv2v always enabled). Main log: {MAIN_LOG_FILE.relative_to(PROJECT_ROOT)}, Report: {REPORT_FILE.relative_to(PROJECT_ROOT)}")
    print(f"Individual test logs in: {SIM_TEMP_LOG_DIR.relative_to(PROJECT_ROOT)}")

    summary = {"total": 0, "passed": 0, "failed": 0, "comp_failed": 0, "exec_error": 0, "sv2v_failed": 0}
    overall_report_content = []

    # --- Load DUT files once ---
    all_dut_src_files_abs: List[Path] = []
    dut_file_list_f_abs_path = PROJECT_ROOT / DUT_FILE_LIST_PATH_REL
    if dut_file_list_f_abs_path.is_file():
        hardware_src_dir = PROJECT_ROOT / "hardware" / "src"
        with open(dut_file_list_f_abs_path, "r") as f_list:
            for line in f_list:
                line = line.strip()
                if line and not line.startswith("#"):
                    dut_file = (hardware_src_dir / line).resolve()
                    if dut_file.is_file():
                        all_dut_src_files_abs.append(dut_file)
                    else:
                        print(f"FATAL: File from _files_sim.f not found: {dut_file}")
                        sys.exit(1)
    else:
        print(f"FATAL: _files_sim.f not found at {dut_file_list_f_abs_path}")
        sys.exit(1)

    test_utils_pkg_abs = (PROJECT_ROOT / TEST_UTILITIES_PKG_PATH_REL).resolve()
    if not test_utils_pkg_abs.is_file():
        print(f"WARNING: {test_utils_pkg_abs.name} not found, testbenches may fail.")
        # This could be a fatal error depending on your setup
        # sys.exit(f"FATAL: {test_utils_pkg_abs.name} not found.")


    for category_name, test_dir_abs_path in TEST_CATEGORIES.items():
        if not test_dir_abs_path.is_dir():
            print(f"Warning: Test directory not found for {category_name}: {test_dir_abs_path}")
            continue
        
        cat_report = [f"\n--------------------\nRUNNING TESTS IN: {category_name} ({test_dir_abs_path.relative_to(PROJECT_ROOT)})\n--------------------"]
        print(f"\nProcessing category: {category_name}")

        testbench_files = list(test_dir_abs_path.glob("*_tb.sv")) + list(test_dir_abs_path.glob("*_tb.v"))
        if not testbench_files:
            msg = f"No testbenches (*_tb.sv or *_tb.v) found in {test_dir_abs_path}"
            print(msg); cat_report.append(msg)
            overall_report_content.extend(cat_report); continue

        for tb_path_abs in testbench_files:
            test_name_full = tb_path_abs.name
            test_name_short = tb_path_abs.stem.replace("_tb", "")
            
            specific_compile_log = SIM_TEMP_LOG_DIR / f"{test_name_short}_compile.log"
            specific_sv2v_log = SIM_TEMP_LOG_DIR / f"{test_name_short}_sv2v.log"
            specific_run_log = SIM_TEMP_LOG_DIR / f"{test_name_short}_run.log"
            sim_vvp_file = BUILD_DIR / f"{test_name_short}_sim.vvp"
            combined_sv_file = BUILD_DIR / f"{test_name_short}_combined_from_sv.v"

            summary["total"] += 1
            msg_prefix = f"Running {test_name_full} ... "
            print(msg_prefix, end="", flush=True)

            # --- Build list of all files for this specific test run ---
            current_test_all_sources = []
            current_test_all_sources.extend(all_dut_src_files_abs)
            if test_utils_pkg_abs.is_file(): current_test_all_sources.append(test_utils_pkg_abs)
            current_test_all_sources.append(tb_path_abs)
            
            # Deduplicate while preserving order (important for compilation)
            seen_paths = set()
            unique_current_test_all_sources = []
            for p in current_test_all_sources:
                if p not in seen_paths:
                    unique_current_test_all_sources.append(p)
                    seen_paths.add(p)
            current_test_all_sources = unique_current_test_all_sources


            # --- sv2v conversion (ALWAYS RUN) ---
            sv_files_to_convert = [f for f in current_test_all_sources if f.suffix == ".sv"]
            original_v_files = [f for f in current_test_all_sources if f.suffix == ".v"]
            
            iverilog_input_files = []

            if sv_files_to_convert:
                sv2v_cmd_list = [SV2V_CMD] + SV2V_DEFINE_FLAGS
                for p_rel in SV2V_INCLUDE_PATHS_REL: sv2v_cmd_list.extend(["-I", str(PROJECT_ROOT / p_rel)])
                sv2v_cmd_list.extend([str(p) for p in sv_files_to_convert])
                
                # print(f"\nDEBUG sv2v CMD: {' '.join(str(c) for c in sv2v_cmd_list + ['-w', str(combined_sv_file)])}\n")
                ret_code, _, _ = run_command(sv2v_cmd_list + ["-w", str(combined_sv_file)], PROJECT_ROOT, MAIN_LOG_FILE, specific_sv2v_log)

                if ret_code != 0:
                    status = "SV2V FAILED"; print(status); cat_report.append(f"{msg_prefix}{status} (see {specific_sv2v_log.relative_to(PROJECT_ROOT)})")
                    summary["failed"] += 1; summary["sv2v_failed"] += 1
                    if combined_sv_file.exists(): combined_sv_file.unlink()
                    continue
                iverilog_input_files.append(combined_sv_file) # Add the big combined file
                iverilog_input_files.extend(original_v_files) # Add original .v files
            else:
                iverilog_input_files.extend(current_test_all_sources) # Only .v files were present


            # --- Order files for iverilog: timescale.v first ---
            ordered_iverilog_input_files = []
            timescale_file_abs = (PROJECT_ROOT / TIMESCALEP_FILE_PATH_REL).resolve()
            
            if timescale_file_abs.is_file():
                ordered_iverilog_input_files.append(timescale_file_abs)
            else:
                print(f"WARNING: Timescale file {timescale_file_abs.name} not found for {test_name_full}!")

            for f_path in iverilog_input_files:
                if f_path != timescale_file_abs: # Avoid duplicating timescale.v
                    ordered_iverilog_input_files.append(f_path)
            
            # --- Compile with iverilog ---
            iverilog_cmd_list = [IVERILOG_CMD]
            iverilog_cmd_list.extend(IVERILOG_COMPILER_FLAGS) # Has -DSIM, -g2012
            iverilog_cmd_list.extend(["-o", str(sim_vvp_file)])
            for p_rel in IVERILOG_INCLUDE_PATHS_REL: iverilog_cmd_list.extend(["-I", str(PROJECT_ROOT / p_rel)])
            iverilog_cmd_list.extend([str(p) for p in ordered_iverilog_input_files])

            # print(f"\nDEBUG IVERILOG CMD: {' '.join(str(c) for c in iverilog_cmd_list)}\n")
            ret_code, _, _ = run_command(iverilog_cmd_list, PROJECT_ROOT, MAIN_LOG_FILE, specific_compile_log)

            if ret_code != 0:
                status = "IVERILOG COMPILATION FAILED"; print(status); cat_report.append(f"{msg_prefix}{status} (see {specific_compile_log.relative_to(PROJECT_ROOT)})")
                summary["failed"] += 1; summary["comp_failed"] += 1
                if sim_vvp_file.exists(): sim_vvp_file.unlink()
                continue

            # --- Run with vvp ---
            vvp_cmd_list = [VVP_CMD] + VVP_DEFAULT_FLAGS + [sim_vvp_file.name]
            ret_code, _, _ = run_command(vvp_cmd_list, BUILD_DIR, MAIN_LOG_FILE, specific_run_log)

            if check_test_pass(specific_run_log, ret_code):
                status = "PASS"; print(status); cat_report.append(f"{msg_prefix}{status}"); summary["passed"] += 1
            else:
                status = "FAIL (SIMULATION)"; print(status); cat_report.append(f"{msg_prefix}{status} (see {specific_run_log.relative_to(PROJECT_ROOT)})"); summary["failed"] += 1
                if ret_code < 0: summary["exec_error"] += 1
            
            if sim_vvp_file.exists(): sim_vvp_file.unlink()
            if combined_sv_file.exists(): combined_sv_file.unlink() # Clean up sv2v output
        
        overall_report_content.extend(cat_report)
    
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

    if summary["failed"] > 0: print("THERE WERE TEST FAILURES!"); sys.exit(1)
    elif summary["total"] == 0: print("NO TESTS WERE RUN."); sys.exit(0) 
    else: print("ALL TESTS PASSED!"); sys.exit(0)

if __name__ == "__main__":
    main()