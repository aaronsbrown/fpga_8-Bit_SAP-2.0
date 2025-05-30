# _files.f 

# clocks
clock/pll.v

# utilities
utils/timescale.v 
utils/button_conditioner.v
utils/seg7_display.v
utils/digit_to_7seg.v
utils/clock_divider.sv

#peripherals
peripherals/uart_transmitter.sv
peripherals/uart_receiver.sv
peripherals/uart_peripheral.sv

# core
constants/arch_defs_pkg.sv

# cpu components
cpu/alu.sv
cpu/program_counter.sv
cpu/stack_pointer.sv
cpu/register_memory_address.sv
cpu/register_nbit.sv
cpu/control_unit.sv

# main components
cpu.sv
rom_4k.sv
vram_4k.sv
ram_8k.sv
computer.sv
top.v