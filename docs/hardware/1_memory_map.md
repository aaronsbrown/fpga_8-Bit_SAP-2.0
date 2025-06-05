# Memory Map

This document details the 64KB memory map for the custom 8-bit CPU.

| USE             | START | END   | # ADDRS | Size KB | HW Resource | Verilog Module   | Notes                                                  |
| --------------- | ----- | ----- | ------- | ------- | ----------- | ---------------- | ------------------------------------------------------ |
| RAM: Zero Page  | `$0000` | `$00FF` | 256     | 0.25    | BRAM        | `ram_8k.sv`      | supports zero page addressing                          |
| RAM: Stack Page | `$0100` | `$01FF` | 256     | 0.25    | BRAM        | `ram_8k.sv`      | hardware stack                                         |
| RAM: General    | `$0200` | `$1FFF` | 7680    | 7.5     | BRAM        | `ram_8k.sv`      | user program ram                                       |
| `__unused__`    | `$2000` | `$CFFF` | 45056   | 44      | n/a         | n/a              | (doesn't exist in hardware)                            |
| VRAM            | `$D000` | `$DFFF` | 4096    | 4       | BRAM        | `vram_4k.sv`     | text or simple bitmap                                  |
| MMIO            | `$E000` | `$EFFF` | 4096    | 4       | LUT/FF      | `computer.sv`    | Reserved. Decoded: $E000-$E07F (e.g., 8 devices @ 16B) |
| ROM/Sys         | `$F000` | `$FFF9` | 4090    | 4       | BRAM        | `rom_4k.sv`      | Program ROM                                            |
| ROM/NMI         | `$FFFA` | `$FFFB` | 2       | 2B      | BRAM        | `rom_4k.sv`      | Vectors: NMI                                           |
| ROM/Reset       | `$FFFC` | `$FFFD` | 2       | 2B      | BRAM        | `rom_4k.sv`      | Vectors: Reset                                         |
| ROM/IRQ         | `$FFFE` | `$FFFF` | 2       | 2B      | BRAM        | `rom_4k.sv`      | Vectors: IRQ                                           |

**Notes:**

* The System RAM ($0000 - $1FFF) is implemented using a single `ram_8k.sv` module, utilizing 8KB of BRAM. The subdivisions for Zero Page and Stack Page are logical conventions within this physical block.
* The MMIO region uses standard logic elements (LUTs/Flip-Flops) and does not consume BRAM. Address decoding is implemented within `computer.sv`.
* The total physical BRAM allocated matches the target FPGA's capacity: 8KB (RAM) + 4KB (VRAM) + 4KB (ROM) = **16KB**.
