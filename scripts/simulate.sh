#!/bin/bash
set -e
set -o pipefail

# simulate.sh - Run simulation for project-specific sources.
#
# Usage:
#   ./simulate.sh [--verbose|-v] [--tb testbench_file.v] [--no-viz] [path/to/verilog_file.v ...]

# --- Configuration & Logging ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info()    { echo -e "${CYAN}[$(date +"%T")] INFO:${NC} $1"; }
log_debug()   { [ "$VERBOSE" = true ] && echo -e "${YELLOW}[$(date +"%T")] DEBUG:${NC} $1"; }
log_success() { echo -e "${GREEN}[$(date +"%T")] SUCCESS:${NC} $1"; }
log_error()   { echo -e "${RED}[$(date +"%T")] ERROR:${NC} $1" >&2; }

usage() {
    echo "Usage: $0 [--verbose|-v] [--sv2v] [--no-viz] [--tb testbench_file.sv] [path/to/verilog_file.v ...]"
    echo "  If no Verilog files are provided, sources are loaded from hardware/src/_files_sim.f"
    echo "  If no --tb is provided, it searches for a single *_tb.sv or *_tb.v in hardware/test/"
    exit 1
}

# --- Helper function to run commands ---
run_cmd() {
    local log_file="$1"
    shift
    log_debug "Executing: $@"
    if [ "$VERBOSE" = true ]; then
        # Log stdout and stderr to file, and also show stdout on console
        # Stderr from command will appear on console due to 2>&1
        "$@" > >(tee -a "$log_file") 2>&1
    else
        "$@" >> "$log_file" 2>&1
    fi
    return $? # Return the exit code of the command
}

# --- Parse Arguments ---
VERBOSE=false
NO_VIZ=false
TB_FILE_ARG="" # Argument passed to --tb
USE_SV2V=false
VERILOG_FILES_ARGS=() # Files passed as positional arguments

while [[ $# -gt 0 ]]; do
    case "$1" in
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --sv2v)
            USE_SV2V=true
            shift
            ;;
        --no-viz)
            NO_VIZ=true
            shift
            ;;
        --tb)
            if [[ -z "$2" || "$2" == -* ]]; then # Check if $2 is empty or another option
                log_error "--tb flag requires a testbench file."
                usage
            fi
            TB_FILE_ARG="$2"
            shift 2
            ;;
        -*)
            log_error "Unknown option: $1"
            usage
            ;;
        *)
            VERILOG_FILES_ARGS+=("$1")
            shift
            ;;
    esac
done

# --- Determine Project and Sub-Directories ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
HARDWARE_DIR="$PROJECT_DIR/hardware"
BUILD_OUT_DIR="$PROJECT_DIR/build"

log_debug "Project directory: $PROJECT_DIR"
log_debug "Hardware directory: $HARDWARE_DIR"
log_debug "Build output directory: $BUILD_OUT_DIR"

# --- Prepare Final List of Verilog Source Files (Absolute Paths) ---
# This list will include DUT files and the testbench.
# test_utilities_pkg.sv will be added separately to ensure it's always there.
ALL_SRC_FILES_TO_COMPILE=()

if [[ ${#VERILOG_FILES_ARGS[@]} -eq 0 ]]; then
    # No specific DUT files provided, load from _files_sim.f
    FILE_LIST_F_PATH="$HARDWARE_DIR/src/_files_sim.f"
    if [[ -f "$FILE_LIST_F_PATH" ]]; then
        log_info "Loading DUT sources from: $FILE_LIST_F_PATH"
        
        pushd "$HARDWARE_DIR/src" > /dev/null # Go to where _files_sim.f is
        log_debug "Changed CWD to $(pwd) for reading $FILE_LIST_F_PATH"

        while IFS= read -r line || [ -n "$line" ]; do
            line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
            [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue

            if [ -f "$line" ]; then # $line is now relative to hardware/src/
                 ALL_SRC_FILES_TO_COMPILE+=("$(pwd)/$line") # Make it absolute
                 log_debug "Added from _files_sim.f: $(pwd)/$line"
            else
                 log_error "File listed in $FILE_LIST_F_PATH not found: $line (searched from $(pwd))"
                 popd > /dev/null; exit 1
            fi
        done < "_files_sim.f" # Read _files_sim.f directly
        popd > /dev/null
        log_debug "Returned CWD to $(pwd)"
    else
        log_error "_files_sim.f not found at $FILE_LIST_F_PATH. Provide DUT files or ensure it exists."
        usage
    fi
else
    # DUT files were provided as arguments
    log_info "Using DUT sources provided on command line."
    for file_arg in "${VERILOG_FILES_ARGS[@]}"; do
        if [[ "$file_arg" != /* ]]; then # If not absolute, make it so (relative to current PWD)
            resolved_file="$(cd "$(dirname "$file_arg")" && pwd)/$(basename "$file_arg")"
        else
            resolved_file="$file_arg"
        fi
        if [ -f "$resolved_file" ]; then
            ALL_SRC_FILES_TO_COMPILE+=("$resolved_file")
            log_debug "Added from CLI arg: $resolved_file"
        else
            log_error "File from CLI arg not found: $file_arg (resolved to $resolved_file)"
            exit 1
        fi
    done
fi

# --- Determine and Add Testbench File ---
TESTBENCH_FILE_ABS=""
if [ -n "$TB_FILE_ARG" ]; then
    # Testbench specified with --tb
    if [[ "$TB_FILE_ARG" != /* ]]; then # If not absolute
        # Try common locations or assume relative to PWD
        if [[ -f "$PROJECT_DIR/$TB_FILE_ARG" ]]; then
             TESTBENCH_FILE_ABS="$(cd "$(dirname "$PROJECT_DIR/$TB_FILE_ARG")" && pwd)/$(basename "$PROJECT_DIR/$TB_FILE_ARG")"
        elif [[ -f "$HARDWARE_DIR/test/$TB_FILE_ARG" && "$TB_FILE_ARG" != *"/"* ]]; then
             TESTBENCH_FILE_ABS="$(cd "$(dirname "$HARDWARE_DIR/test/$TB_FILE_ARG")" && pwd)/$(basename "$HARDWARE_DIR/test/$TB_FILE_ARG")"
        elif [[ -f "$TB_FILE_ARG" ]]; then # Relative to current dir
             TESTBENCH_FILE_ABS="$(cd "$(dirname "$TB_FILE_ARG")" && pwd)/$(basename "$TB_FILE_ARG")"
        else
            log_error "Specified testbench file with --tb not found: $TB_FILE_ARG"
            exit 1
        fi
    else # Already absolute
        TESTBENCH_FILE_ABS="$TB_FILE_ARG"
    fi
    if [ ! -f "$TESTBENCH_FILE_ABS" ]; then
        log_error "Specified testbench file $TESTBENCH_FILE_ABS does not exist (after path resolution)."
        exit 1
    fi
    log_info "Using specified testbench file: $TESTBENCH_FILE_ABS"
else
    # Auto-detect testbench
    TEST_DIR="$HARDWARE_DIR/test"
    if [ -d "$TEST_DIR" ]; then
        log_info "Searching for testbench files in $TEST_DIR..."
        # Find .sv first, then .v
        TEST_FILES_FOUND=( $(find "$TEST_DIR" -maxdepth 1 -type f -name "*_tb.sv" 2>/dev/null) )
        if [ ${#TEST_FILES_FOUND[@]} -eq 0 ]; then
            TEST_FILES_FOUND=( $(find "$TEST_DIR" -maxdepth 1 -type f -name "*_tb.v" 2>/dev/null) )
        fi

        if [ ${#TEST_FILES_FOUND[@]} -eq 0 ]; then
            log_error "No testbench files (*_tb.sv or *_tb.v) found in $TEST_DIR."
            exit 1
        elif [ ${#TEST_FILES_FOUND[@]} -gt 1 ]; then
            log_error "Multiple testbench files found in $TEST_DIR. Use the --tb flag to specify one:"
            for f in "${TEST_FILES_FOUND[@]}"; do echo "  - $(basename "$f")"; done
            exit 1
        else
            TESTBENCH_FILE_ABS="$(cd "$(dirname "${TEST_FILES_FOUND[0]}")" && pwd)/$(basename "${TEST_FILES_FOUND[0]}")"
            log_info "Auto-detected testbench file: $TESTBENCH_FILE_ABS"
        fi
    else
        log_error "Test directory $TEST_DIR not found."
        exit 1
    fi
fi
ALL_SRC_FILES_TO_COMPILE+=("$TESTBENCH_FILE_ABS")

# --- Add test_utilities_pkg.sv ---
TEST_UTILITIES_PKG_PATH="$HARDWARE_DIR/test/test_utilities_pkg.sv"
if [ -f "$TEST_UTILITIES_PKG_PATH" ]; then
    # Avoid duplicates if it was somehow already added
    is_present=false
    for f_path in "${ALL_SRC_FILES_TO_COMPILE[@]}"; do
        if [[ "$f_path" == "$TEST_UTILITIES_PKG_PATH" ]]; then
            is_present=true; break
        fi
    done
    if [ "$is_present" = false ]; then
        ALL_SRC_FILES_TO_COMPILE+=("$TEST_UTILITIES_PKG_PATH")
        log_debug "Added $TEST_UTILITIES_PKG_PATH to compilation list."
    fi
else
    log_warning "$TEST_UTILITIES_PKG_PATH not found, critical for testbenches!"
    # Consider exiting if this file is essential: exit 1
fi


# --- Setup Build and Log Directories ---
LOG_DIR="$BUILD_OUT_DIR/logs"
mkdir -p "$LOG_DIR" # Ensure log directory exists
rm -f "$LOG_DIR/iverilog.log" "$LOG_DIR/vvp.log" # Clear old main logs for this run

# --- Optional sv2v Conversion ---
# FINAL_VERILOG_FILES will hold the list of files to pass to iverilog
FINAL_VERILOG_FILES=()
if [ "$USE_SV2V" = true ]; then
    log_info "sv2v conversion enabled."
    SV_FILES_TO_CONVERT=()
    NON_SV_FILES=() # .v files or other non-convertible sources
    for file_path in "${ALL_SRC_FILES_TO_COMPILE[@]}"; do
        if [[ "$file_path" == *.sv ]]; then
            SV_FILES_TO_CONVERT+=("$file_path")
        else
            NON_SV_FILES+=("$file_path")
        fi
    done

    if [ ${#SV_FILES_TO_CONVERT[@]} -gt 0 ]; then
        combined_sv2v_output_file="$BUILD_OUT_DIR/combined_from_sv.v"
        log_info "Converting ${#SV_FILES_TO_CONVERT[@]} SystemVerilog files to $combined_sv2v_output_file:"
        for sv_file in "${SV_FILES_TO_CONVERT[@]}"; do log_debug "  - $sv_file"; done
        
        # Run sv2v
        sv2v_cmd=(sv2v -DSIMULATION)
        # Add include paths for sv2v to find packages etc.
        sv2v_cmd+=(-I "$HARDWARE_DIR/src")
        sv2v_cmd+=(-I "$HARDWARE_DIR/src/constants") # Where arch_defs_pkg.sv is
        sv2v_cmd+=(-I "$HARDWARE_DIR/test")         # Where test_utilities_pkg.sv is
        
        # Add specific sv files to convert
        sv2v_cmd+=("${SV_FILES_TO_CONVERT[@]}")
        
        log_debug "sv2v command: ${sv2v_cmd[*]}"
        if "${sv2v_cmd[@]}" > "$combined_sv2v_output_file"; then
            log_success "sv2v conversion successful."
            FINAL_VERILOG_FILES+=("$combined_sv2v_output_file")
            FINAL_VERILOG_FILES+=("${NON_SV_FILES[@]}") # Add back the non-SV files
        else
            log_error "sv2v conversion failed. Output was not generated."
            # Consider dumping sv2v error output if it goes to stderr
            exit 1
        fi
    else
        log_info "No .sv files found to convert with sv2v. Using original files."
        FINAL_VERILOG_FILES=("${ALL_SRC_FILES_TO_COMPILE[@]}")
    fi
else
    FINAL_VERILOG_FILES=("${ALL_SRC_FILES_TO_COMPILE[@]}")
fi

# --- Compile Simulation Sources with Icarus Verilog ---
SIM_VVP="$BUILD_OUT_DIR/sim.vvp" # Output .vvp file
log_info "Compiling simulation sources..."

IVERILOG_ARGS=(-DSIMULATION -g2012 -o "$SIM_VVP")
# Include paths for `include directives and module path resolution
IVERILOG_ARGS+=(-I "$HARDWARE_DIR/src")
IVERILOG_ARGS+=(-I "$HARDWARE_DIR/src/constants") # For arch_defs_pkg
IVERILOG_ARGS+=(-I "$HARDWARE_DIR/src/cpu")
IVERILOG_ARGS+=(-I "$HARDWARE_DIR/src/peripherals")
IVERILOG_ARGS+=(-I "$HARDWARE_DIR/src/utils")
IVERILOG_ARGS+=(-I "$HARDWARE_DIR/test")      # For test_utilities_pkg

# Construct the full iverilog command
IVERILOG_FULL_CMD=(iverilog "${IVERILOG_ARGS[@]}" "${FINAL_VERILOG_FILES[@]}")

log_debug "Final list of files for iverilog:"
for f in "${FINAL_VERILOG_FILES[@]}"; do log_debug "  - $f"; done
log_debug "Iverilog command: ${IVERILOG_FULL_CMD[*]}"

if run_cmd "$LOG_DIR/iverilog.log" "${IVERILOG_FULL_CMD[@]}"; then
    log_success "Iverilog compilation completed."
else
    log_error "Iverilog compilation failed. Check $LOG_DIR/iverilog.log."
    exit 1
fi

# --- Run Simulation with vvp ---
# Run vvp from the directory where sim.vvp is located (BUILD_OUT_DIR)
# Waveform.vcd will also be created here.
pushd "$BUILD_OUT_DIR" > /dev/null
log_info "Running simulation with vvp (sim.vvp)..."
if run_cmd "$LOG_DIR/vvp.log" vvp "sim.vvp"; then # vvp automatically finds sim.vvp in CWD
    log_success "vvp simulation completed."
else
    log_error "vvp simulation failed. Check $LOG_DIR/vvp.log."
    popd > /dev/null # Ensure we popd even on failure
    exit 1
fi
popd > /dev/null

# --- Optionally Open Waveform in gtkwave ---
WAVEFORM_FILE="$BUILD_OUT_DIR/waveform.vcd"
# Try to find a .gtkw session file associated with the testbench name
TB_BASENAME_NO_EXT=$(basename "$TESTBENCH_FILE_ABS")
TB_BASENAME_NO_EXT=${TB_BASENAME_NO_EXT%_tb.sv}
TB_BASENAME_NO_EXT=${TB_BASENAME_NO_EXT%_tb.v}

SESSION_FILE_GUESS_1="$HARDWARE_DIR/sim/${TB_BASENAME_NO_EXT}.gtkw"
SESSION_FILE_DEFAULT="$HARDWARE_DIR/sim/multi_byte_cpu_full.gtkw" # Your previous default
SESSION_FILE_TO_USE=""

if [ -f "$SESSION_FILE_GUESS_1" ]; then
    SESSION_FILE_TO_USE="$SESSION_FILE_GUESS_1"
elif [ -f "$SESSION_FILE_DEFAULT" ]; then
    SESSION_FILE_TO_USE="$SESSION_FILE_DEFAULT"
fi

if [ -f "$WAVEFORM_FILE" ]; then
    if [ "$NO_VIZ" = false ]; then
        log_info "Opening waveform $WAVEFORM_FILE in gtkwave..."
        if [ -n "$SESSION_FILE_TO_USE" ] && [ -f "$SESSION_FILE_TO_USE" ]; then
            log_info "Using session file: $SESSION_FILE_TO_USE"
            gtkwave "$WAVEFORM_FILE" "$SESSION_FILE_TO_USE" &
        else
            log_warning "No specific .gtkw session file found for $TB_BASENAME_NO_EXT nor default $SESSION_FILE_DEFAULT. Opening waveform only."
            gtkwave "$WAVEFORM_FILE" &
        fi
    else
        log_info "Waveform generated at $WAVEFORM_FILE, skipping visualization (--no-viz)."
    fi
else
    log_warning "Waveform file $WAVEFORM_FILE not found. Ensure your testbench ($TESTBENCH_FILE_ABS) generates a VCD file named waveform.vcd in $BUILD_OUT_DIR."
fi

log_success "Simulation script complete!"