#!/bin/bash
set -e
set -o pipefail

# --- Configuration & Logging ---
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; CYAN='\033[0;36m'; NC='\033[0m'
log_info()    { echo -e "${CYAN}[$(date +"%T")] INFO:${NC} $1"; }
log_debug()   { [ "$VERBOSE" = true ] && echo -e "${YELLOW}[$(date +"%T")] DEBUG:${NC} $1"; }
log_success() { echo -e "${GREEN}[$(date +"%T")] SUCCESS:${NC} $1"; }
log_error()   { echo -e "${RED}[$(date +"%T")] ERROR:${NC} $1" >&2; }

usage() {
    echo "Usage: $0 [--verbose|-v] --top <top_module_name> [--asm_src <assembly_file.asm>] [verilog_files...]"
    echo "       If no verilog_files are provided, sources from _files_synth.f will be used."
    echo "       If --asm_src is not provided, a default ROM path will be attempted."
    echo "       sv2v is ALWAYS used for .sv files."
    echo "       Source sources are ALWAYS loaded from hardware/src/_files_synth.f."
    exit 1
}

run_cmd() {
    local log_file="$1"; shift
    if [ "$VERBOSE" = true ]; then "$@" 2>&1 | tee "$log_file"; else "$@" > "$log_file" 2>&1; fi
}

# --- Argument Parsing ---
VERBOSE=false
VERILOG_FILES_ARG=()
USE_SV2V=true
TOP_MODULE=""
ASSEMBLY_SOURCE_FILE="" # Path to the .asm file for ROM

if [[ $# -eq 0 ]]; then usage; fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        --verbose|-v) VERBOSE=true; shift ;;
        --top) if [[ -z "$2" ]]; then log_error "--top requires a module name."; usage; fi; TOP_MODULE="$2"; shift 2 ;;
        --asm_src) if [[ -z "$2" ]]; then log_error "--asm_src requires a file path."; usage; fi; ASSEMBLY_SOURCE_FILE="$2"; shift 2 ;;
        -*) log_error "Unknown option: $1"; usage ;;
        *) VERILOG_FILES_ARG+=("$1"); shift ;;
    esac
done

# --- Determine Project and Sub-Directories ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
HARDWARE_DIR="$PROJECT_DIR/hardware"
SOFTWARE_DIR="$PROJECT_DIR/software"
BUILD_OUT_DIR="$PROJECT_DIR/build"

[ "$VERBOSE" = true ] && { log_debug "Project dir: $PROJECT_DIR"; log_debug "Hardware dir: $HARDWARE_DIR"; log_debug "Software dir: $SOFTWARE_DIR"; log_debug "Build dir: $BUILD_OUT_DIR"; }

# --- Validate Essential Arguments ---
if [[ -z "$TOP_MODULE" ]]; then log_error "Top module not specified (--top)."; usage; fi

# --- Setup Build Directories ---
LOG_DIR="$BUILD_OUT_DIR/logs"
mkdir -p "$BUILD_OUT_DIR"
mkdir -p "$LOG_DIR"

# --- Prepare ROM Hex File for Synthesis ---
# This is the name your Verilog ROM module expects via its HEX_INIT_FILE parameter
SYNTHESIS_ROM_MODULE_EXPECTS="default_synth_rom.hex"
ROM_CONTENT_SOURCE_PATH="" # Will point to the .hex file to be used

if [ -n "$ASSEMBLY_SOURCE_FILE" ]; then
    # Resolve assembly source path if it's relative
    if [[ "$ASSEMBLY_SOURCE_FILE" != /* ]]; then ASSEMBLY_SOURCE_FILE="$PROJECT_DIR/$ASSEMBLY_SOURCE_FILE"; fi
    
    if [ ! -f "$ASSEMBLY_SOURCE_FILE" ]; then log_error "Assembly source file not found: $ASSEMBLY_SOURCE_FILE"; exit 1; fi

    # Assembler output will go to a temporary spot in BUILD_OUT_DIR
    TEMP_ASM_OUTPUT_DIR="$BUILD_OUT_DIR/asm_out_synth"
    mkdir -p "$TEMP_ASM_OUTPUT_DIR"
    ROM_CONTENT_SOURCE_PATH="$TEMP_ASM_OUTPUT_DIR/ROM.hex" # Assuming assembler outputs ROM.hex for the ROM region

    log_info "Assembling $ASSEMBLY_SOURCE_FILE for ROM..."
    ASSEMBLER_SCRIPT="$SOFTWARE_DIR/assembler/src/assembler.py"
    # Adjust ROM region as needed (e.g., F000 FFFF for a 4K ROM at $F000)
    if python3 "$ASSEMBLER_SCRIPT" "$ASSEMBLY_SOURCE_FILE" "$TEMP_ASM_OUTPUT_DIR" --region ROM F000 FFFF; then
        log_success "Assembly for ROM complete."
    else
        log_error "ROM assembly failed for $ASSEMBLY_SOURCE_FILE."; exit 1
    fi
else
    # Use a default manual fixture if no assembly source is provided
    ROM_CONTENT_SOURCE_PATH="$HARDWARE_DIR/test/_fixtures_generated/fpga/default_synth_rom.hex" # ADJUST THIS DEFAULT
    log_info "Using default manual ROM: $ROM_CONTENT_SOURCE_PATH"
    if [ ! -f "$ROM_CONTENT_SOURCE_PATH" ]; then log_error "Default ROM fixture not found: $ROM_CONTENT_SOURCE_PATH"; exit 1; fi
fi

# Copy the chosen ROM content to the name/location synthesis tools expect
cp "$ROM_CONTENT_SOURCE_PATH" "$BUILD_OUT_DIR/$SYNTHESIS_ROM_MODULE_EXPECTS"
log_info "Prepared $SYNTHESIS_ROM_MODULE_EXPECTS in $BUILD_OUT_DIR for synthesis."

# --- Load Verilog Files for Synthesis ---
ALL_VERILOG_SOURCES=()
if [[ ${#VERILOG_FILES_ARG[@]} -eq 0 ]]; then
    SYNTH_FILE_LIST="$HARDWARE_DIR/src/_files_synth.f"
    if [[ -f "$SYNTH_FILE_LIST" ]]; then
        log_info "Loading Verilog sources from: $SYNTH_FILE_LIST"
        while IFS= read -r line || [ -n "$line" ]; do
            line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
            [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
            # Assuming paths in _files_synth.f are relative to HARDWARE_DIR/src/
            ALL_VERILOG_SOURCES+=("$HARDWARE_DIR/src/$line")
        done < "$SYNTH_FILE_LIST"
    else log_error "$SYNTH_FILE_LIST not found."; usage; fi
else
    for file_arg in "${VERILOG_FILES_ARG[@]}"; do
         if [[ "$file_arg" != /* ]]; then file_arg="$PROJECT_DIR/$file_arg"; fi # Make absolute if relative
         ALL_VERILOG_SOURCES+=("$file_arg")
    done
fi

# --- Optional sv2v Conversion ---
FINAL_SYNTH_VERILOG_FILES=()
if [ "$USE_SV2V" = true ]; then
    log_info "sv2v conversion enabled..."
    SV_FILES=(); NON_SV_FILES=()
    for file in "${ALL_VERILOG_SOURCES[@]}"; do
        if [[ "$file" == *.sv ]]; then SV_FILES+=("$file"); else NON_SV_FILES+=("$file"); fi
    done
    for file in "${SV_FILES[@]}"; do log_info "sv2v will convert: $file"; done
    
    COMBINED_SV2V_FILE="$BUILD_OUT_DIR/combined_synth.v"
    log_info "Converting ${#SV_FILES[@]} SystemVerilog files to $COMBINED_SV2V_FILE"
    if sv2v -DSYNTHESIS "${SV_FILES[@]}" > "$COMBINED_SV2V_FILE"; then
        FINAL_SYNTH_VERILOG_FILES+=("$COMBINED_SV2V_FILE")
        FINAL_SYNTH_VERILOG_FILES+=("${NON_SV_FILES[@]}")
    else log_error "sv2v conversion failed."; exit 1; fi
else
    FINAL_SYNTH_VERILOG_FILES=("${ALL_VERILOG_SOURCES[@]}")
fi

# --- Prepare Constraint Files ---
MERGED_PCF="$BUILD_OUT_DIR/merged_constraints.pcf"
MERGED_SDC="$BUILD_OUT_DIR/merged_constraints.sdc"
CONSTRAINT_DIR="$HARDWARE_DIR/constraints"

PROJECT_PCF_FILES=( $(find "$CONSTRAINT_DIR" -maxdepth 1 -type f -name "*.pcf" 2>/dev/null) )
if [[ ${#PROJECT_PCF_FILES[@]} -eq 0 ]]; then log_error "No .pcf files in $CONSTRAINT_DIR"; exit 1; fi
log_info "Merging PCF files..."; > "$MERGED_PCF"
for file in "${PROJECT_PCF_FILES[@]}"; do cat "$file" >> "$MERGED_PCF"; echo "" >> "$MERGED_PCF"; done
log_info "Merged PCF: $MERGED_PCF"

PROJECT_SDC_FILES=( $(find "$CONSTRAINT_DIR" -maxdepth 1 -type f -name "*.sdc" 2>/dev/null) )
if [[ ${#PROJECT_SDC_FILES[@]} -gt 0 ]]; then
    log_info "Merging SDC files..."; > "$MERGED_SDC"
    for file in "${PROJECT_SDC_FILES[@]}"; do cat "$file" >> "$MERGED_SDC"; echo "" >> "$MERGED_SDC"; done
    log_info "Merged SDC: $MERGED_SDC"
else
    log_info "No SDC files found in $CONSTRAINT_DIR. Skipping SDC merge."
    MERGED_SDC="" # Ensure it's empty if not used
fi

# --- Define Output File Names ---
YOSYS_JSON="hardware.json"    # Relative to BUILD_OUT_DIR
NEXTPNR_ASC="hardware.asc"    # Relative to BUILD_OUT_DIR
ICEPACK_BIN="hardware.bin"    # Relative to BUILD_OUT_DIR

# --- Change to Build Directory for Tool Execution ---
log_info "Changing to build directory: $BUILD_OUT_DIR"
pushd "$BUILD_OUT_DIR" > /dev/null

# --- Yosys ---
log_info "Running Yosys synthesis..."
YOSYS_CMD_STR="synth_ice40 -top $TOP_MODULE -json $YOSYS_JSON"
# Yosys needs paths to Verilog files. Since we cd'd, pass absolute paths.
YOSYS_FULL_CMD=(yosys -q -p "$YOSYS_CMD_STR" "${FINAL_SYNTH_VERILOG_FILES[@]}")
[ "$VERBOSE" = true ] && log_debug "Yosys command: ${YOSYS_FULL_CMD[*]}"
if run_cmd "$LOG_DIR/yosys.log" "${YOSYS_FULL_CMD[@]}"; then log_success "Yosys completed."; else log_error "Yosys failed. Check $LOG_DIR/yosys.log."; cat "$LOG_DIR/yosys.log"; popd >/dev/null; exit 1; fi

# --- nextpnr ---
log_info "Running nextpnr-ice40..."
NEXTPNR_FULL_CMD=(nextpnr-ice40 --hx8k --package cb132 --json "$YOSYS_JSON" --asc "$NEXTPNR_ASC" --pcf "$MERGED_PCF")
if [ -n "$MERGED_SDC" ] && [ -f "$MERGED_SDC" ]; then NEXTPNR_FULL_CMD+=(--sdc "$MERGED_SDC"); fi
[ "$VERBOSE" = true ] && log_debug "nextpnr-ice40 command: ${NEXTPNR_FULL_CMD[*]}"
if run_cmd "$LOG_DIR/nextpnr.log" "${NEXTPNR_FULL_CMD[@]}"; then log_success "nextpnr-ice40 completed."; else log_error "nextpnr-ice40 failed. Check $LOG_DIR/nextpnr.log."; cat "$LOG_DIR/nextpnr.log"; popd >/dev/null; exit 1; fi

# --- icepack ---
log_info "Packing bitstream with icepack..."
if run_cmd "$LOG_DIR/icepack.log" icepack "$NEXTPNR_ASC" "$ICEPACK_BIN"; then log_success "Bitstream packed: $ICEPACK_BIN"; else log_error "icepack failed. Check $LOG_DIR/icepack.log."; cat "$LOG_DIR/icepack.log"; popd >/dev/null; exit 1; fi

# --- Upload (Optional - uncomment to enable) ---
log_info "Uploading bitstream to FPGA with iceprog..."
if run_cmd "$LOG_DIR/iceprog.log" iceprog "$ICEPACK_BIN"; then log_success "Bitstream uploaded."; else log_error "iceprog upload failed. Check $LOG_DIR/iceprog.log."; fi

popd > /dev/null # Return from BUILD_OUT_DIR
log_success "Build process complete!"