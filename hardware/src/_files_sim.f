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
src/peripherals/uart_receiver.sv
src/peripherals/uart_peripheral.sv

# constants
src/constants/arch_defs_pkg.sv

# cpu components
src/cpu/alu.sv
src/cpu/status_logic_unit.sv
src/cpu/program_counter.sv
src/cpu/stack_pointer.sv
src/cpu/register_memory_address.sv
src/cpu/register_nbit.sv
src/cpu/control_unit.sv

# main components
src/cpu.sv
src/rom_4k.sv
src/vram_4k.sv
src/ram_8k.sv
src/computer.sv
src/top.v