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
core/arch_defs_pkg.sv

# logic
alu.sv
program_counter.sv
rom_4k.sv
vram_4k.sv
ram_8k.sv
register_memory_address.sv
register_nbit.sv
control_unit.sv
cpu.sv
computer.sv
top.v