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
    input  logic [DATA_WIDTH-1:0] parallel_data_in,
    output logic [DATA_WIDTH-1:0] parallel_data_out,
    
    // Hardware Interface
    input  serial_rx,
    output serial_tx

);

    localparam STATUS_TX_BUFFER_EMPTY_BIT  = 0;
    localparam STATUS_RX_DATA_READY_BIT  = 1;
    localparam STATUS_ERROR_FRAME_BIT      = 2;
    localparam STATUS_ERROR_OVERSHOOT_BIT  = 3;
    
    localparam CONFIG_REG_DEFAULT  = {DATA_WIDTH{1'b0}};
    
    localparam CMD_REG_CLEAR_FRAME_ERR_BIT = 0;
    localparam CMD_REG_CLEAR_OVERSHOOT_ERR_BIT = 1;

    
    // =======================================================
    // Config Register
    // TODO: add control logic in future, for now just a place holder
    // =======================================================
    logic [DATA_WIDTH-1:0] config_reg, next_config_reg;


    // =======================================================
    // (Virtual) Command Register 
    // control signals activated for one pulse on CPU write to relevant address offset
    // External API: 
    // — Clear Frame Error
    // — Clear Overshoot Error
    // =======================================================
    logic cmd_clear_frame_error;
    logic cmd_clear_overshoot_error;
    

    // =======================================================
    // Status Register
    // 0: Tx Buffer Empty
    // 1: Rx Data Ready
    // 2: Frame Error
    // 3: Overshoot Error
    // =======================================================
    logic [3:0] status_reg_i;

    // pass through level signals from TX and RX
    logic rx_data_ready_i;
    logic tx_busy_i;
    assign status_reg_i[STATUS_TX_BUFFER_EMPTY_BIT] = ~tx_busy_i;
    assign status_reg_i[STATUS_RX_DATA_READY_BIT] = rx_data_ready_i;

    // Internal FFs to capture RX error pulses
    logic frame_error_flag_i;
    logic overshoot_error_flag_i;
    assign status_reg_i[STATUS_ERROR_FRAME_BIT] = frame_error_flag_i;
    assign status_reg_i[STATUS_ERROR_OVERSHOOT_BIT] = overshoot_error_flag_i;
    
    logic [1:0] rx_status_reg;
    logic cmd_set_frame_error, cmd_set_overshoot_error; 
    assign cmd_set_frame_error = rx_status_reg[0];
    assign cmd_set_overshoot_error = rx_status_reg[1];

    // ========================================================
    // READ_ACKNOWLEDGEMENT 
    // ========================================================
    logic cpu_read_signal, cpu_read_signal_dly;
    assign cpu_read_signal = cmd_enable && cmd_read && (address_offset == UART_REG_DATA);

    always_ff @(posedge clk) begin
        if (reset) begin
            cpu_read_signal_dly <= 1'b0;
        end else begin
            cpu_read_signal_dly <= cpu_read_signal;
        end
    end

    logic cpu_read_ack_pulse;
    assign cpu_read_ack_pulse = cpu_read_signal && !cpu_read_signal_dly;

    // =======================================================
    // UART_RECEIVER 
    // =======================================================
    logic [DATA_WIDTH-1:0] rx_data_out;
    uart_receiver u_receiver (
        .clk(clk),
        .reset(reset),
        .rx_serial_in_data(serial_rx),
        .cpu_read_data_ack_pulse(cpu_read_ack_pulse),
        .rx_strobe_data_ready_level(rx_data_ready_i),
        .rx_parallel_data_out(rx_data_out),
        .rx_status_reg(rx_status_reg)
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
        
        next_config_reg             = config_reg;
        parallel_data_out           = {DATA_WIDTH{1'bx}};
        tx_data_in                  = {DATA_WIDTH{1'bx}};
        cmd_tx_start_strobe         = 1'b0;
        cmd_clear_frame_error       = 1'b0;
        cmd_clear_overshoot_error   = 1'b0;
        
        if ( cmd_enable) begin
            case (address_offset)
                UART_REG_CONFIG: begin
                    if(cmd_write) 
                        next_config_reg = parallel_data_in;
                    else if (cmd_read)
                        parallel_data_out = config_reg;
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
                
                UART_REG_COMMAND: begin
                    if (cmd_write) begin
                        if(parallel_data_in[CMD_REG_CLEAR_FRAME_ERR_BIT])
                            cmd_clear_frame_error = 1'b1;
                        if(parallel_data_in[CMD_REG_CLEAR_OVERSHOOT_ERR_BIT])
                            cmd_clear_overshoot_error = 1'b1;
                    end
                end
                
                default: begin
                    parallel_data_out = {DATA_WIDTH{1'bx}};
                end
            endcase
        end
    end

    // Handle Config Register
    always_ff @(posedge clk) begin
        if (reset) begin
            config_reg <= CONFIG_REG_DEFAULT;
        end else begin
            config_reg <= next_config_reg;
        end
    end

    // Handle error flags in Status Register
    always_ff @(posedge clk) begin
        if (reset) begin
             frame_error_flag_i <= 1'b0;
             overshoot_error_flag_i <= 1'b0;
        end else begin

            if(cmd_clear_frame_error)
                frame_error_flag_i <= 1'b0;
            else if(cmd_set_frame_error)
                frame_error_flag_i <= 1'b1;

            if(cmd_clear_overshoot_error)
                overshoot_error_flag_i <= 1'b0;
            else if(cmd_set_overshoot_error)
                overshoot_error_flag_i <= 1'b1;

        end
    end

endmodule