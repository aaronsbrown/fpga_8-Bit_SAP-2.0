#!/usr/bin/env python3

import argparse
import sys
import os

def main():
    parser = argparse.ArgumentParser(
        description="Pads a Verilog .hex file to a specified length.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Example Usage:
  # Pad input.hex to 4096 lines, output to padded_rom.hex, using default '00' padding
  python pad_hex.py input.hex padded_rom.hex -l 4096

  # Pad input.hex to 8192 lines, output to padded_ram.hex, padding with 'FF'
  python pad_hex.py input.hex padded_ram.hex --length 8192 --padding FF
"""
    )

    parser.add_argument("input_file", help="Path to the input .hex file.")
    parser.add_argument("output_file", help="Path for the padded output .hex file.")
    parser.add_argument("-l", "--length", type=int, required=True,
                        help="The desired total number of lines (entries) in the output file.")
    parser.add_argument("-p", "--padding", default="00",
                        help="The hexadecimal string value to use for padding lines (default: '00').")
    # Add an optional argument to specify comment characters if needed
    # parser.add_argument("-c", "--comment", default="#", help="Character indicating a comment line to ignore.")

    args = parser.parse_args()

    if args.length <= 0:
        print(f"Error: Target length (--length) must be positive.", file=sys.stderr)
        sys.exit(1)

    # Validate padding value format (simple check for hex chars, adjust if needed)
    valid_hex_chars = set("0123456789abcdefABCDEF")
    if not all(c in valid_hex_chars for c in args.padding):
         print(f"Warning: Padding value '{args.padding}' contains non-hexadecimal characters.", file=sys.stderr)
         # Decide if this should be an error or just a warning

    padding_value = args.padding.strip()

    valid_lines = []
    try:
        with open(args.input_file, 'r') as infile:
            lines = infile.readlines()
            for line in lines:
                stripped_line = line.strip()
                # Ignore empty lines and simple comments (can enhance comment handling)
                if stripped_line and not stripped_line.startswith(('#', '//')):
                    valid_lines.append(stripped_line)
    except FileNotFoundError:
        print(f"Error: Input file not found: {args.input_file}", file=sys.stderr)
        sys.exit(1)
    except IOError as e:
        print(f"Error reading input file '{args.input_file}': {e}", file=sys.stderr)
        sys.exit(1)


    num_read = len(valid_lines)
    target_length = args.length

    if num_read > target_length:
        print(f"Warning: Input file '{args.input_file}' ({num_read} valid lines) is longer than target length ({target_length}). Truncating output.")
        lines_to_write = valid_lines[:target_length]
        padding_needed = 0
    else:
        lines_to_write = valid_lines
        padding_needed = target_length - num_read

    try:
        # Ensure output directory exists if specified in the path
        output_dir = os.path.dirname(args.output_file)
        if output_dir and not os.path.exists(output_dir):
            os.makedirs(output_dir) # Create directories recursively

        with open(args.output_file, 'w') as outfile:
            for line in lines_to_write:
                outfile.write(line + '\n')
            for _ in range(padding_needed):
                outfile.write(padding_value + '\n')
    except IOError as e:
         print(f"Error writing to output file '{args.output_file}': {e}", file=sys.stderr)
         sys.exit(1)
    except OSError as e:
         print(f"Error creating output directory for '{args.output_file}': {e}", file=sys.stderr)
         sys.exit(1)


    print(f"Successfully created padded file: '{args.output_file}'")
    print(f"  Target length: {target_length}")
    print(f"  Valid lines read: {num_read}")
    print(f"  Lines truncated: {max(0, num_read - target_length)}")
    print(f"  Lines padded:    {padding_needed}")

if __name__ == "__main__":
    main()