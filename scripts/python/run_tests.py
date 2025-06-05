#!/usr/bin/env python3

import argparse
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import List, Tuple, Dict, Set # Added Set for seen_paths

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

IVERILOG_COMPILER_FLAGS = ["-DSIMULATION", "-g2012"]
IVERILOG_INCLUDE_PATHS_REL = [
    "hardware/src", "hardware/src/constants", "hardware/src/cpu",
    "hardware/src/peripherals", "hardware/src/utils", "hardware/test"
]
SV2V_DEFINE_FLAGS = ["-DSIMULATION"]
SV2V_INCLUDE_PATHS_REL = [
    "hardware/src", "hardware/src/constants", "hardware/test"
]

TEST_CATEGORIES: Dict[str, Path] = {
    "Instruction_Set_Tests": HARDWARE_DIR / "test" / "instruction_set",
    "CPU_Control_Tests": HARDWARE_DIR / "test" / "cpu_control",
    "Module_Tests": HARDWARE_DIR / "test" / "modules",
}
DUT_FILE_LIST_PATH_REL = "hardware/src/_files_sim.f"
TIMESCALEP_FILE_PATH_REL = "hardware/src/utils/timescale.v"
TEST_UTILITIES_PKG_PATH_REL = "hardware/test/test_utilities_pkg.sv"

VVP_DEFAULT_FLAGS = []

# --- Helper Functions ---
def run_command(cmd: List[str], cwd: Path, log_file_path: Path, specific_log_path: Path) -> Tuple[int, str, str]:
    try:
        process = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, check=False)
        with open(log_file_path, "a", encoding="utf-8") as main_log:
            main_log.write(f"\n--- CMD: {' '.join(str(c) for c in cmd)} (CWD: {cwd}) ---\n")
            main_log.write(f"--- STDOUT ---\n{process.stdout}\n")
            if process.stderr:
                main_log.write(f"--- STDERR ---\n{process.stderr}\n")
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
    
    success_pattern_regex = re.compile(r"^\s*.* test finished\.===========================\s*$", re.MULTILINE)
    has_test_finished_msg = bool(success_pattern_regex.search(content))
    if not has_test_finished_msg: return False
    return True

# --- Main Script ---
def main():
    parser = argparse.ArgumentParser(description="Run Verilog testbenches (sv2v is always used).")
    args = parser.parse_args() # args is not used in this version, but keep for future

    SIM_TEMP_LOG_DIR.mkdir(parents=True, exist_ok=True)
    if MAIN_LOG_FILE.exists(): MAIN_LOG_FILE.unlink()
    if REPORT_FILE.exists(): REPORT_FILE.unlink()
    MAIN_LOG_FILE.touch(); REPORT_FILE.touch()

    print(f"Running tests (sv2v always enabled). Main log: {MAIN_LOG_FILE.relative_to(PROJECT_ROOT)}, Report: {REPORT_FILE.relative_to(PROJECT_ROOT)}")
    print(f"Individual test logs in: {SIM_TEMP_LOG_DIR.relative_to(PROJECT_ROOT)}")

    summary = {"total": 0, "passed": 0, "failed": 0, "comp_failed": 0, "exec_error": 0, "sv2v_failed": 0}
    overall_report_content = []

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

    sorted_category_names = sorted(TEST_CATEGORIES.keys())

    for category_name in sorted_category_names:
        test_dir_abs_path = TEST_CATEGORIES[category_name]

        if not test_dir_abs_path.is_dir():
            print(f"Warning: Test directory not found for {category_name}: {test_dir_abs_path}")
            continue
        
        cat_report = [f"\n--------------------\nRUNNING TESTS IN: {category_name} ({test_dir_abs_path.relative_to(PROJECT_ROOT)})\n--------------------"]
        print(f"\nProcessing category: {category_name}")

        testbench_files_sv = list(test_dir_abs_path.glob("*_tb.sv"))
        testbench_files_v = list(test_dir_abs_path.glob("*_tb.v"))
        all_testbench_files_in_category = testbench_files_sv + testbench_files_v
        
        sorted_testbench_files = sorted(all_testbench_files_in_category, key=lambda p: p.name)

        if not sorted_testbench_files:
            msg = f"No testbenches (*_tb.sv or *_tb.v) found in {test_dir_abs_path}"
            print(msg); cat_report.append(msg)
            overall_report_content.extend(cat_report); continue

        for tb_path_abs in sorted_testbench_files:
            test_name_full = tb_path_abs.name
            test_name_short = tb_path_abs.stem.replace("_tb", "")
            
            specific_compile_log = SIM_TEMP_LOG_DIR / f"{test_name_short}_compile.log"
            specific_sv2v_log = SIM_TEMP_LOG_DIR / f"{test_name_short}_sv2v.log"
            specific_run_log = SIM_TEMP_LOG_DIR / f"{test_name_short}_run.log"
            sim_vvp_file = BUILD_DIR / f"{test_name_short}_sim.vvp"
            combined_sv_file = BUILD_DIR / f"{test_name_short}_combined_from_sv.v" # sv2v output

            summary["total"] += 1
            msg_prefix = f"Running {test_name_full} ... "
            print(msg_prefix, end="", flush=True)

            current_test_all_sources: List[Path] = []
            current_test_all_sources.extend(all_dut_src_files_abs)
            if test_utils_pkg_abs.is_file(): current_test_all_sources.append(test_utils_pkg_abs)
            current_test_all_sources.append(tb_path_abs)
            
            seen_paths: Set[Path] = set()
            unique_current_test_all_sources: List[Path] = []
            for p in current_test_all_sources:
                if p not in seen_paths:
                    unique_current_test_all_sources.append(p)
                    seen_paths.add(p)
            current_test_all_sources = unique_current_test_all_sources

            sv_files_to_convert = [f for f in current_test_all_sources if f.suffix == ".sv"]
            original_v_files = [f for f in current_test_all_sources if f.suffix == ".v"]
            
            iverilog_input_files: List[Path] = []

            if sv_files_to_convert:
                sv2v_cmd_list = [SV2V_CMD] + SV2V_DEFINE_FLAGS
                for p_rel in SV2V_INCLUDE_PATHS_REL: sv2v_cmd_list.extend(["-I", str(PROJECT_ROOT / p_rel)])
                sv2v_cmd_list.extend([str(p) for p in sv_files_to_convert])
                
                ret_code, _, _ = run_command(sv2v_cmd_list + ["-w", str(combined_sv_file)], PROJECT_ROOT, MAIN_LOG_FILE, specific_sv2v_log)

                if ret_code != 0:
                    status = "SV2V FAILED"; print(status); cat_report.append(f"{msg_prefix}{status} (see {specific_sv2v_log.relative_to(PROJECT_ROOT)})")
                    summary["failed"] += 1; summary["sv2v_failed"] += 1
                    if combined_sv_file.exists(): combined_sv_file.unlink(missing_ok=True)
                    continue
                iverilog_input_files.append(combined_sv_file)
                iverilog_input_files.extend(original_v_files)
            else:
                iverilog_input_files.extend(current_test_all_sources)

            ordered_iverilog_input_files: List[Path] = []
            timescale_file_abs = (PROJECT_ROOT / TIMESCALEP_FILE_PATH_REL).resolve()
            
            if timescale_file_abs.is_file():
                ordered_iverilog_input_files.append(timescale_file_abs)
            else:
                print(f"WARNING: Timescale file {timescale_file_abs.name} not found for {test_name_full}!")

            for f_path in iverilog_input_files:
                if f_path != timescale_file_abs:
                    ordered_iverilog_input_files.append(f_path)
            
            iverilog_cmd_list = [IVERILOG_CMD]
            iverilog_cmd_list.extend(IVERILOG_COMPILER_FLAGS)
            iverilog_cmd_list.extend(["-o", str(sim_vvp_file)])
            for p_rel in IVERILOG_INCLUDE_PATHS_REL: iverilog_cmd_list.extend(["-I", str(PROJECT_ROOT / p_rel)])
            iverilog_cmd_list.extend([str(p) for p in ordered_iverilog_input_files])

            ret_code, _, _ = run_command(iverilog_cmd_list, PROJECT_ROOT, MAIN_LOG_FILE, specific_compile_log)

            if ret_code != 0:
                status = "IVERILOG COMPILATION FAILED"; print(status); cat_report.append(f"{msg_prefix}{status} (see {specific_compile_log.relative_to(PROJECT_ROOT)})")
                summary["failed"] += 1; summary["comp_failed"] += 1
                if sim_vvp_file.exists(): sim_vvp_file.unlink(missing_ok=True)
                continue

            vvp_cmd_list = [VVP_CMD] + VVP_DEFAULT_FLAGS + [sim_vvp_file.name] # Use .name as vvp runs from BUILD_DIR
            ret_code, _, _ = run_command(vvp_cmd_list, BUILD_DIR, MAIN_LOG_FILE, specific_run_log)

            if check_test_pass(specific_run_log, ret_code):
                status = "PASS"; print(status); cat_report.append(f"{msg_prefix}{status}"); summary["passed"] += 1
            else:
                status = "FAIL (SIMULATION)"; print(status); cat_report.append(f"{msg_prefix}{status} (see {specific_run_log.relative_to(PROJECT_ROOT)})"); summary["failed"] += 1
                if ret_code < 0: summary["exec_error"] += 1 # For FileNotFoundError etc. from run_command
            
            if sim_vvp_file.exists(): sim_vvp_file.unlink(missing_ok=True)
            if combined_sv_file.exists(): combined_sv_file.unlink(missing_ok=True)
        
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