import arch_defs_pkg::*;

module computer (

    input wire clk,
    input wire reset,
    output wire [DATA_WIDTH-1:0] register_OUT,
    output wire cpu_flag_zero_o,
    output wire cpu_flag_carry_o,
    output wire cpu_flag_negative_o,
    output wire [DATA_WIDTH-1:0] cpu_debug_out_B,
    output wire [DATA_WIDTH-1:0] cpu_debug_out_IR,
    output wire [ADDR_WIDTH-1:0] cpu_debug_out_PC
);

    
    logic [ADDR_WIDTH-1:0]  cpu_mem_address;
    logic [DATA_WIDTH-1:0]  cpu_mem_data_in; 
    logic [DATA_WIDTH-1:0]  cpu_mem_data_out;
    logic [DATA_WIDTH-1:0]  ram_data_out;
    logic [DATA_WIDTH-1:0]  vram_data_out;
    logic [DATA_WIDTH-1:0]  rom_data_out;
    logic                   cpu_mem_write;
    logic                   cpu_mem_read;
    logic                   cpu_load_o;
    logic                   cpu_oe_ram;
    logic                   cpu_oe_a;
    logic [DATA_WIDTH-1:0]  cpu_a_out_bus;
    logic                   cpu_halt;

    cpu u_cpu (
        .clk(clk),
        .reset(reset),
        
        // MEMORY INTERFACE
        .mem_address(cpu_mem_address),
        .mem_read(cpu_mem_read),
        .mem_data_in(cpu_mem_data_in),
        .mem_write(cpu_mem_write),
        .mem_data_out(cpu_mem_data_out),
        
        // OUTPUT INTERFACE 
        .load_o(cpu_load_o),
        .oe_ram(cpu_oe_ram),
        .oe_a(cpu_oe_a),
        .a_out_bus(cpu_a_out_bus),

        .halt(cpu_halt),

        // DEBUG SIGNALS
        .flag_zero_o(cpu_flag_zero_o),
        .flag_carry_o(cpu_flag_carry_o),
        .flag_negative_o(cpu_flag_negative_o),
        .debug_out_B(cpu_debug_out_B),
        .debug_out_IR(cpu_debug_out_IR),
        .debug_out_PC(cpu_debug_out_PC)
    );

    // TODO map u_reg_OUT in E000-EFFF
    wire ce_ram_8k, ce_rom_4k, ce_vram_4k, ce_mmio;
    assign ce_ram_8k = cpu_mem_address[15:13] == 3'b000; // 0000–1FFF
    assign ce_vram_4k = cpu_mem_address[15:12] == 4'b1101; // D000–DFFF
    assign ce_mmio = cpu_mem_address[15:12] == 4'b1110; // E000–EFFF
    assign ce_rom_4k = cpu_mem_address[15:12] == 4'b1111; // F000–FFFF
    
    // Mux to decide which memory to read from
    assign cpu_mem_data_in = 
        (ce_ram_8k && cpu_mem_read)  ? ram_data_out : 
        (ce_rom_4k && cpu_mem_read)  ? rom_data_out : 
        (ce_vram_4k && cpu_mem_read) ? vram_data_out :
        (ce_mmio && cpu_mem_read)    ? { DATA_WIDTH{1'bx} } : // MMIO
        { DATA_WIDTH{1'bx} };

    // Memory Map: 0000–1FFF
    ram_8k u_ram (
        .clk(clk),
        .we(cpu_mem_write && ce_ram_8k),
        .address(cpu_mem_address[12:0]), // 13-bit address (2^13=8Kbytes)
        .data_in(cpu_mem_data_out),
        .data_out(ram_data_out)
    );

    // Memory Map: D000–DFFF
    vram_4k u_vram (
        .clk(clk),
        .we(cpu_mem_write && ce_vram_4k),
        .address(cpu_mem_address[11:0]), // 12-bit address (2^12=4096 bytes)
        .data_in(cpu_mem_data_out),
        .data_out(vram_data_out)
    );

    // Memory Map: F000–FFFF
    rom_4k u_rom (
        .clk(clk),
        .address(cpu_mem_address[11:0]), // 12-bit address (2^12=4096 bytes)
        .data_out(rom_data_out)
    );

    // TODO this will be MMIO, and use a STA instruction
    // Should be an 8 bit register, can make it a "LED Driver" to simulate a peripheral 'chip'
    // Memory Map: E000–EFFF
    logic [DATA_WIDTH-1:0] register_OUT_data_source;

    assign register_OUT_data_source = 
        (cpu_oe_a) ? cpu_a_out_bus : 
        (cpu_oe_ram) ? ram_data_out : 
        { DATA_WIDTH{1'b0} };


    register_nbit #( .N(DATA_WIDTH) ) u_register_OUT (
        .clk(clk),
        .reset(reset),
        .load(cpu_load_o),
        .data_in(register_OUT_data_source),
        .latched_data(register_OUT)
    );

endmodule