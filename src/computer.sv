import arch_defs_pkg::*;

module computer (

    input wire clk,
    input wire reset,
    output wire [DATA_WIDTH-1:0] final_out,
    output wire flag_zero_o,
    output wire flag_carry_o,
    output wire flag_negative_o,
    output wire [DATA_WIDTH-1:0] debug_out_B,
    output wire [DATA_WIDTH-1:0] debug_out_IR,
    output wire [ADDR_WIDTH-1:0] debug_out_PC
);

    logic [ADDR_WIDTH-1:0] mem_address;
    logic [DATA_WIDTH-1:0] mem_data_in;
    logic [DATA_WIDTH-1:0] mem_data_out;
    logic mem_write;
    logic mem_read;
    
    logic load_o;
    logic oe_ram;
    logic oe_a;
    logic [DATA_WIDTH-1:0] a_out_bus;

    logic halt;

    cpu u_cpu (
        .clk(clk),
        .reset(reset),
        
        // MEMORY INTERFACE
        .mem_address(mem_address),
        .mem_read(mem_read),
        .mem_data_in(mem_data_out),
        .mem_write(mem_write),
        .mem_data_out(mem_data_in),
        .oe_ram(oe_ram),
        
        // OUTPUT INTERFACE 
        .load_o(load_o),
        .oe_a(oe_a),
        .a_out_bus(a_out_bus),

        .halt(halt),

        // DEBUG SIGNALS
        .flag_zero_o(flag_zero_o),
        .flag_carry_o(flag_carry_o),
        .flag_negative_o(flag_negative_o),
        .debug_out_B(debug_out_B),
        .debug_out_IR(debug_out_IR),
        .debug_out_PC(debug_out_PC)
    );

    ram u_ram (
        .clk(clk),
        .we(mem_write),
        .address(mem_address),  
        .data_in(mem_data_in),
        .data_out(mem_data_out)
    );

    logic [DATA_WIDTH-1:0] output_reg_data_source;
    
    always_comb begin
        if (oe_a) begin
            output_reg_data_source = a_out_bus;
        end else if (oe_ram) begin
            output_reg_data_source = mem_data_out; 
        end else begin
            output_reg_data_source = { DATA_WIDTH{1'b0} };
        end
    end

    register_nbit #( .N(DATA_WIDTH) ) u_register_OUT (
        .clk(clk),
        .reset(reset),
        .load(load_o),
        .data_in(output_reg_data_source),
        .latched_data(final_out)
    );

endmodule