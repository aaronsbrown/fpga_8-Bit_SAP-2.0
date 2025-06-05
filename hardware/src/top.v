module top (
    input           clk,
    input           rst_n,
    output [7:0]    led,
    output [23:0]   io_led,
    output [6:0]    io_segment,
    output [3:0]    io_select,
    input           usb_rx,
    output          usb_tx
);
    
    // Derive 20MHz clock from 100MHz input
    wire clk_out, clk_div;
    wire pll_locked;

    pll u_pll (
        .clock_in(clk),
        .clock_out(clk_out),
        .locked(pll_locked)
    );

    wire conditioned_rst_n_btn;
    button_conditioner u_btn_cond (
        .clk(clk),
        .raw_button(rst_n),
        .conditioned_button(conditioned_rst_n_btn)
    );

    // Generate a system reset that remains active until both rst_n is high and the PLL is locked
    // sys_reset is active-high: asserted if external reset is active (rst_n is low) or PLL is not locked
    wire sys_reset;
    assign sys_reset = ~conditioned_rst_n_btn || ~pll_locked;

    wire [7:0] output_value;
    assign io_led[23:16] = output_value;
    assign io_led[15:0] = 16'h00;
    
    computer u_computer (
        .clk(clk_out),
        .reset(sys_reset),
        .output_port_1(output_value),
        .cpu_flag_zero_o(led[0]),    
        .cpu_flag_carry_o(led[1]),
        .cpu_flag_negative_o(led[2]),
        .uart_rx(usb_rx),
        .uart_tx(usb_tx)
    );
  
    // Assign the remaining LEDs to 0
    assign led[7:3] = 5'b00000;
    
    seg7_display u_display (
        .clk(clk_out),
        .reset(sys_reset),
        .number(output_value),
        .seg7( io_segment ),
        .select(io_select)
    );

endmodule
