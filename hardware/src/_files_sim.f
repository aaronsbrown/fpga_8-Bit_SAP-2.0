# src/_files.f 

# TODO remove leading 'src/', but have to handle test files separate

# clocks
src/clock/pll.v

# test specific
test/test_utilities_pkg.sv

# utilities
src/utils/timescale.v 
src/utils/button_conditioner.v
src/utils/seg7_display.v
src/utils/digit_to_7seg.v
src/utils/clock_divider.sv

#peripherals
src/peripherals/uart_transmitter.sv

# core
src/core/arch_defs_pkg.sv

# logic h
src/alu.sv
src/program_counter.sv
src/rom_4k.sv
src/vram_4k.sv
src/ram_8k.sv
src/register_memory_address.sv
src/register_nbit.sv
src/control_unit.sv
src/cpu.sv
src/computer.sv
src/top.v