#!/bin/bash
set -e
set -o pipefail

# --- Configuration & Logging ---
# ... (Keep your existing RED, GREEN, etc. and log functions) ...
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; CYAN='\033[0;36m'; NC='\033[0m';
VERBOSE=false
log_info()    { echo -e "${CYAN}[$(date +"%T")] INFO:${NC} $1"; }
log_debug()   { [ "$VERBOSE" = true ] && echo -e "${YELLOW}[$(date +"%T")] DEBUG:${NC} $1"; }
log_success() { echo -e "${GREEN}[$(date +"%T")] SUCCESS:${NC} $1"; }
log_error()   { echo -e "${RED}[$(date +"%T")] ERROR:${NC} $1" >&2; }
log_warning() { echo -e "${YELLOW}[$(date +"%T")] WARNING:${NC} $1"; }

usage() {
    echo "Usage: $0 --tb path/from/project_root/testbench_file.sv [--verbose|-v] [--no-viz]"
    echo "  The --tb flag is REQUIRED."
    echo "  sv2v is ALWAYS used for .sv files."
    echo "  DUT sources are ALWAYS loaded from hardware/src/_files_sim.f."
    exit 1
}

run_cmd() {
    local log_file="$1"; shift; log_debug "Executing in $(pwd): $@";
    if [ "$VERBOSE" = true ]; then "$@" 2>&1 | tee -a "$log_file"; else "$@" >> "$log_file" 2>&1; fi
    return $?
}

# --- Parse Arguments ---
NO_VIZ=false; TB_FILE_ARG=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --verbose|-v) VERBOSE=true; shift ;;
        --no-viz) NO_VIZ=true; shift ;;
        --tb) if [[ -z "$2" || "$2" == -* ]]; then log_error "--tb requires a file."; usage; fi; TB_FILE_ARG="$2"; shift 2 ;;
        -*) log_error "Unknown option: $1"; usage ;;
        *) log_error "Unknown positional argument: $1. DUT files from _files_sim.f"; usage ;;
    esac
done
if [ -z "$TB_FILE_ARG" ]; then log_error "The --tb <testbench_file> argument is required."; usage; fi

# --- Determine Project and Sub-Directories ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
HARDWARE_DIR="$PROJECT_DIR/hardware"; BUILD_OUT_DIR="$PROJECT_DIR/build"
log_debug "PROJECT_DIR: $PROJECT_DIR"

# --- Prepare List of ALL Verilog/SystemVerilog Source Files (Absolute Paths) ---
ALL_SOURCE_FILES_FOR_PROCESSING=()
FILE_LIST_F_PATH="$HARDWARE_DIR/src/_files_sim.f"
if [[ -f "$FILE_LIST_F_PATH" ]]; then
    log_info "Loading DUT sources from: $FILE_LIST_F_PATH"
    pushd "$HARDWARE_DIR/src" > /dev/null
    while IFS= read -r line || [ -n "$line" ]; do
        line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
        if [ -f "$line" ]; then ALL_SOURCE_FILES_FOR_PROCESSING+=("$(pwd)/$line");
        else log_error "File in _files_sim.f not found: $line (from $(pwd))"; popd >/dev/null; exit 1; fi
    done < "_files_sim.f"; popd > /dev/null
else log_error "_files_sim.f not found: $FILE_LIST_F_PATH"; usage; fi

TESTBENCH_FILE_ABS=""
CANDIDATE_PATH="$PROJECT_DIR/$TB_FILE_ARG"
if [ -f "$CANDIDATE_PATH" ]; then
    TESTBENCH_FILE_ABS="$(cd "$(dirname "$CANDIDATE_PATH")" && pwd)/$(basename "$CANDIDATE_PATH")"
    log_info "Using specified testbench file: $TESTBENCH_FILE_ABS (from --tb $TB_FILE_ARG)"
else log_error "Specified testbench file '$TB_FILE_ARG' (resolved to '$CANDIDATE_PATH') not found."; exit 1; fi
is_present=false; for f in "${ALL_SOURCE_FILES_FOR_PROCESSING[@]}"; do if [[ "$f" == "$TESTBENCH_FILE_ABS" ]]; then is_present=true; break; fi; done
if [ "$is_present" = false ]; then ALL_SOURCE_FILES_FOR_PROCESSING+=("$TESTBENCH_FILE_ABS"); fi

TEST_UTILITIES_PKG_ABS="$HARDWARE_DIR/test/test_utilities_pkg.sv"
if [ -f "$TEST_UTILITIES_PKG_ABS" ]; then
    is_present=false; for f in "${ALL_SOURCE_FILES_FOR_PROCESSING[@]}"; do if [[ "$f" == "$TEST_UTILITIES_PKG_ABS" ]]; then is_present=true; break; fi; done
    if [ "$is_present" = false ]; then ALL_SOURCE_FILES_FOR_PROCESSING+=("$TEST_UTILITIES_PKG_ABS"); fi
else log_warning "$TEST_UTILITIES_PKG_ABS not found!"; fi

# --- Setup Build and Log Dirs ---
LOG_DIR="$BUILD_OUT_DIR/logs"; mkdir -p "$LOG_DIR"; rm -f "$LOG_DIR/"*.log

# --- sv2v Conversion (ALWAYS RUN) ---
log_info "Performing sv2v conversion for .sv files..."
SV_FILES_TO_CONVERT=(); ORIGINAL_V_FILES=() # Store original .v files separately
TIMESCALEP_FILE_ABS="$HARDWARE_DIR/src/utils/timescale.v" # Define absolute path to timescale.v

for file_path in "${ALL_SOURCE_FILES_FOR_PROCESSING[@]}"; do
    if [[ "$file_path" == *.sv ]]; then
        SV_FILES_TO_CONVERT+=("$file_path")
    elif [[ "$file_path" != "$TIMESCALEP_FILE_ABS" ]]; then # Collect .v files, EXCLUDING timescale.v
        ORIGINAL_V_FILES+=("$file_path")
    fi
done

FILES_FOR_IVERILOG_FINAL_ORDER=() # This will be the final list for iverilog

# 1. Add timescale.v FIRST to this new list
if [ -f "$TIMESCALEP_FILE_ABS" ]; then
    FILES_FOR_IVERILOG_FINAL_ORDER+=("$TIMESCALEP_FILE_ABS")
    log_debug "Prepending $TIMESCALEP_FILE_ABS to iverilog compile list."
else
    log_warning "$TIMESCALEP_FILE_ABS not found! Timescale might be incorrect."
fi

# 2. Process SV files with sv2v and add its output
if [ ${#SV_FILES_TO_CONVERT[@]} -gt 0 ]; then
    combined_sv2v_output_file="$BUILD_OUT_DIR/combined_for_sim.v"
    log_info "Converting ${#SV_FILES_TO_CONVERT[@]} SystemVerilog files to $combined_sv2v_output_file"
    for svf in "${SV_FILES_TO_CONVERT[@]}"; do log_debug "  sv2v input: $svf"; done
    sv2v_cmd=(sv2v -DSIMULATION -I "$HARDWARE_DIR/src" -I "$HARDWARE_DIR/src/constants" -I "$HARDWARE_DIR/test" "${SV_FILES_TO_CONVERT[@]}")
    log_debug "sv2v command: ${sv2v_cmd[*]}"
    if sv2v_stdout=$("${sv2v_cmd[@]}" 2> "$LOG_DIR/sv2v_stderr.log"); then
        echo "$sv2v_stdout" > "$combined_sv2v_output_file"; log_success "sv2v conversion successful."
        FILES_FOR_IVERILOG_FINAL_ORDER+=("$combined_sv2v_output_file") # Add combined file
        if [ -s "$LOG_DIR/sv2v_stderr.log" ]; then log_warning "sv2v STDERR (see $LOG_DIR/sv2v.log)"; cat "$LOG_DIR/sv2v_stderr.log" >> "$LOG_DIR/sv2v.log"; fi
    else log_error "sv2v failed. Check logs."; if [ -s "$LOG_DIR/sv2v_stderr.log" ]; then cat "$LOG_DIR/sv2v_stderr.log"; fi; exit 1; fi
else
    log_info "No .sv files to convert."
fi

# 3. Add remaining original .v files (that were not timescale.v)
FILES_FOR_IVERILOG_FINAL_ORDER+=("${ORIGINAL_V_FILES[@]}")


# --- Compile Simulation Sources with Icarus Verilog ---
SIM_VVP="$BUILD_OUT_DIR/sim.vvp"
log_info "Compiling with Icarus Verilog..."
IVERILOG_CMD_ARGS=(-o "$SIM_VVP" -DSIMULATION -g2012) 
IVERILOG_CMD_ARGS+=(-I "$HARDWARE_DIR/src"); IVERILOG_CMD_ARGS+=(-I "$HARDWARE_DIR/src/constants")
IVERILOG_CMD_ARGS+=(-I "$HARDWARE_DIR/src/cpu"); IVERILOG_CMD_ARGS+=(-I "$HARDWARE_DIR/src/peripherals")
IVERILOG_CMD_ARGS+=(-I "$HARDWARE_DIR/src/utils"); IVERILOG_CMD_ARGS+=(-I "$HARDWARE_DIR/test")
# Use the newly ordered list of files
IVERILOG_FULL_CMD=(iverilog "${IVERILOG_CMD_ARGS[@]}" "${FILES_FOR_IVERILOG_FINAL_ORDER[@]}")

log_debug "Final list of files for iverilog (after ordering for timescale):"
for f in "${FILES_FOR_IVERILOG_FINAL_ORDER[@]}"; do log_debug "  - $f"; done
log_debug "Iverilog command: ${IVERILOG_FULL_CMD[*]}"

if run_cmd "$LOG_DIR/iverilog.log" "${IVERILOG_FULL_CMD[@]}"; then
    log_success "Iverilog compilation completed."
else
    log_error "Iverilog compilation failed. Check $LOG_DIR/iverilog.log."; cat "$LOG_DIR/iverilog.log"; exit 1
fi

# --- Run Simulation with vvp ---
pushd "$BUILD_OUT_DIR" > /dev/null
log_info "Running simulation with vvp (sim.vvp)..."
VVP_LOG_FILE="$LOG_DIR/vvp_run.log"; rm -f "$VVP_LOG_FILE"; touch "$VVP_LOG_FILE"

# Execute vvp and store its exit code
run_cmd "$VVP_LOG_FILE" vvp "sim.vvp"
VVP_EXIT_CODE=$? # Capture the exit code

# Now check both the exit code AND the log content
SIMULATION_SUCCESSFUL=true
if [ $VVP_EXIT_CODE -ne 0 ]; then
    log_error "vvp exited with a non-zero status ($VVP_EXIT_CODE)."
    SIMULATION_SUCCESSFUL=false
fi

# Also check for your specific FATAL ERROR message in the log
if grep -q "FATAL ERROR" "$VVP_LOG_FILE"; then
    # We don't need to log_error again if vvp_exit_code was already non-zero,
    # but we ensure the simulation is marked as failed.
    if [ "$SIMULATION_SUCCESSFUL" = true ]; then # Only log if not already caught by exit code
      log_error "vvp simulation reported a FATAL ERROR (see $VVP_LOG_FILE)."
    fi
    SIMULATION_SUCCESSFUL=false
fi


if [ "$SIMULATION_SUCCESSFUL" = true ]; then
    log_success "vvp simulation completed successfully."
else
    log_error "vvp simulation failed. Check $VVP_LOG_FILE for details."
    # Content of VVP_LOG_FILE would have been printed by run_cmd if VERBOSE,
    # or user can check it. We can optionally cat it here on error:
    # cat "$VVP_LOG_FILE"
    popd > /dev/null
    exit 1 # Exit the script on simulation failure
fi
popd > /dev/null


# --- Optionally Open Waveform ---
WAVEFORM_FILE="$BUILD_OUT_DIR/waveform.vcd"
TB_BASENAME_FOR_GTKW=$(basename "$TESTBENCH_FILE_ABS"); TB_BASENAME_FOR_GTKW=${TB_BASENAME_FOR_GTKW%.*}
SESSION_FILE_GUESS_1="$HARDWARE_DIR/sim/${TB_BASENAME_FOR_GTKW}.gtkw"
SESSION_FILE_DEFAULT="$HARDWARE_DIR/sim/multi_byte_cpu_full.gtkw"; SESSION_FILE_TO_USE=""
if [ -f "$SESSION_FILE_GUESS_1" ]; then SESSION_FILE_TO_USE="$SESSION_FILE_GUESS_1"; 
elif [ -f "$SESSION_FILE_DEFAULT" ]; then SESSION_FILE_TO_USE="$SESSION_FILE_DEFAULT"; fi
if [ -f "$WAVEFORM_FILE" ]; then
    if [ "$NO_VIZ" = false ]; then
        log_info "Opening waveform $WAVEFORM_FILE in gtkwave..."
        if [ -n "$SESSION_FILE_TO_USE" ] && [ -f "$SESSION_FILE_TO_USE" ]; then 
            log_info "Using session file: $SESSION_FILE_TO_USE"; gtkwave "$WAVEFORM_FILE" "$SESSION_FILE_TO_USE" &
        else 
            log_warning "No specific .gtkw session file found. Opening waveform only."; gtkwave "$WAVEFORM_FILE" &
        fi
    else log_info "Waveform generated at $WAVEFORM_FILE, skipping visualization."; fi
else log_warning "Waveform file $WAVEFORM_FILE not found."; fi

log_success "Simulation script complete!"