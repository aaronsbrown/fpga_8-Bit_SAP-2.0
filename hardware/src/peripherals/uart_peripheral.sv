import arch_defs_pkg::*;

module uart_peripheral (
    

    input  logic clk,
    input  logic reset,
    
    input  uart_reg_offset_e address_offset,
    
    // CONTROL SIGNALS
    input  logic cmd_enable,
    input  logic cmd_write,
    input  logic cmd_read,

    // Bus Interface => Data to / from CPU
    input  [DATA_WIDTH-1:0] logic parallel_data_in,
    output [DATA_WIDTH-1:0] logic parallel_data_out,
    
    // Hardware Interface
    input  serial_rx,
    output serial_tx

);

    localparam TX_BUFFER_EMPTY_BIT  = 0;
    localparam RX_DATA_READY_BIT  = 1;
    localparam ERROR_FRAME_BIT      = 2;
    localparam ERROR_OVERSHOOT_BIT  = 3;
    localparam CONTROL_REG_DEFAULT  = {DATA_WIDTH{1'b0}};

    
    // =======================================================
    // Control Register
    // TODO: add control logic in future, for now just a place holder
    // =======================================================
    logic [DATA_WIDTH-1:0] control_reg, next_control_reg;

    // =======================================================
    // Status Register 
    // =======================================================
    logic rx_data_ready_i, tx_busy_i;
    logic [1:0] rx_status_flags_i;
    logic [DATA_WIDTH-1:0] status_reg_i;
    assign status_reg_i[TX_BUFFER_EMPTY_BIT] = ~tx_busy_i;
    assign status_reg_i[RX_DATA_READY_BIT] = rx_data_ready_i;
    assign status_reg_i[ERROR_FRAME_ERROR_BIT] = rx_status_flags_i[0]; // frame error
    assign status_reg_i[ERROR_OVERSHOOT_BIT] = rx_status_flags_i[1]; // overshoot error
    assign status_reg_i[DATA_WIDTH-1:4] = { (DATA_WIDTH-4){1'b0} };

    // =======================================================
    // UART_RECEIVER 
    // =======================================================
    logic [DATA_WIDTH-1:0] rx_data_out;
    uart_receiver u_receiver (
        .clk(clk),
        .reset(reset),
        .rx_serial_in_data(serial_rx),
        .rx_strobe_data_ready(rx_data_ready_i),
        .rx_parallel_data_out(rx_data_out),
        .rx_status_flags_i(rx_status_flags_i)
    );

    // =======================================================
    // UART TRANSMITTER 
    // =======================================================
    logic [DATA_WIDTH-1:0] tx_data_in;
    logic cmd_tx_start_strobe;
    uart_transmitter u_transmitter (
        .clk(clk),
        .reset(reset),
        .tx_parallel_data_in(tx_data_in),
        .tx_strobe_start(cmd_tx_start_strobe),
        .tx_strobe_busy(tx_busy_i),
        .tx_serial_data_out(serial_tx)
    );

    always_comb begin 
        
        next_control_reg    = control_reg;
        parallel_data_out   = {DATA_WIDTH{1'bx}};
        tx_data_in          = {DATA_WIDTH{1'bx}};
        cmd_tx_start_strobe = 1'b0;

        if ( cmd_enable) begin
            case (address_offset)
                UART_REG_CONTROL: begin
                    if(cmd_write) 
                        next_control_reg = parallel_data_in;
                    else if (cmd_read)
                        parallel_data_out = control_reg;
                end
                UART_REG_STATUS: begin
                    if(cmd_read)
                        parallel_data_out = status_reg_i;
                        
                end
                UART_REG_DATA: begin
                    if (cmd_write) begin
                        tx_data_in = parallel_data_in;
                        cmd_tx_start_strobe = 1'b1;
                    end else if(cmd_read)
                        parallel_data_out = rx_data_out; 
                end
                default: begin
                    parallel_data_out = {DATA_WIDTH{1'bx}};
                end
            endcase
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            control_reg <= CONTROL_REG_DEFAULT;
        end else begin
            control_reg <= next_control_reg;
        end
    end

endmodule