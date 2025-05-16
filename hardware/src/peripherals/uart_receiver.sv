import arch_defs_pkg::*;

module uart_receiver #(
    parameter CLOCK_SPEED = 20_000_000,
    parameter BAUD_RATE = 9600,
    parameter OVERSAMPLING_RATE = 16

) (
    input logic clk,
    input logic reset,

    // INPUTS
    input logic rx_serial_in_data,

    // OUTPUTS
    output logic rx_strobe_data_ready,
    output logic [DATA_WIDTH-1:0] rx_parallel_data_out,
    output logic [1:0] rx_status
);

    localparam CYCLES_PER_BIT = CLOCK_SPEED / BAUD_RATE;
    localparam CYCLES_PER_SAMPLE = CLOCK_SPEED / (BAUD_RATE * OVERSAMPLING_RATE );
    localparam RX_PARALLEL_DATA_OUT_DEFAULT = 8'b0;
    localparam SIGNAL_START_BIT = 1'b0;
    localparam SIGNAL_END_BIT = 1'b1;
    
    logic [DATA_WIDTH-1:0] i_rx_shift_reg;
    logic [1:0]            i_status_reg; // [0] => Frame Error; [1] => Overshoot Error

    // ====================================================================== 
    // SYNCHRONIZATION REGISTERS: align incoming signal with internal clock
    // ====================================================================== 
    logic sync_ff1;
    logic synced_serial_in;
    
    always_ff @(posedge clk) begin
        if( reset) begin
            sync_ff1 <= 1'b0;
            synced_serial_in <= 1'b0;
        end else begin
            sync_ff1 <= rx_serial_in_data;
            synced_serial_in <= sync_ff1;
        end
    end


    // ======================================================================
    // CONTROL UNIT: state transitions and control signal management
    // ====================================================================== 
    
    uart_fsm_state_t current_state, next_state;
    logic [3:0] bit_count, next_bit_count; // Counts sampled message bits, [0, DATA_WIDTH - 1]
    
    logic cmd_enable_sample_timer;
    logic cmd_reset_internal_timer;
    logic cmd_reset_sample_count;
    logic cmd_latch_serial_input;
    logic cmd_flag_frame_error;
    
    always_comb begin
        
        next_state = current_state;
        next_bit_count = bit_count;
        cmd_enable_sample_timer = 1'b0;
        cmd_reset_internal_timer = 1'b0;
        cmd_reset_sample_count = 1'b0;
        cmd_latch_serial_input = 1'b0;
        cmd_flag_frame_error = 1'b0;

        case(current_state)

            S_UART_RX_IDLE: begin
                
                i_status_reg <= 'b0; // TODO rethin
                i_rx_shift_reg <= 'b0; // TODO remove
                rx_strobe_data_ready = 1'b0;

                if( synced_serial_in == SIGNAL_START_BIT ) begin
                    next_state = S_UART_RX_VALIDATE_START;
                    next_bit_count = 3'b0;
                    cmd_reset_internal_timer = 1'b1;
                    cmd_reset_sample_count = 1'b1; 
                end
            end

            S_UART_RX_VALIDATE_START: begin
                cmd_enable_sample_timer = 1'b1;
                if( event_middle_of_bit && (synced_serial_in == SIGNAL_START_BIT )) begin
                    next_state = S_UART_RX_READ_DATA;
                    cmd_reset_internal_timer = 1'b1;
                    cmd_reset_sample_count = 1'b1;
                end else if (event_middle_of_bit && ( synced_serial_in == SIGNAL_END_BIT ) ) begin
                    next_state = S_UART_RX_IDLE;                  
                end
            end

            S_UART_RX_READ_DATA: begin
                cmd_enable_sample_timer = 1'b1; 
                cmd_latch_serial_input = 1'b0;

                if ( event_end_of_bit ) begin
                    
                    cmd_latch_serial_input = 1'b1; // sample
                    next_bit_count = bit_count + 1; // start new bit count
                    cmd_reset_sample_count = 3'b1;
                    
                    if ( bit_count == DATA_WIDTH - 1) begin // sampled 8 bits!
                        next_state = S_UART_RX_STOP;
                        next_bit_count = 3'b0;
                        cmd_reset_internal_timer = 1'b1;
                        cmd_reset_sample_count = 1'b1;
                    end
                end 
               
            end

            S_UART_RX_STOP: begin
                cmd_latch_serial_input = 1'b0;
                cmd_enable_sample_timer = 1'b1;
                if( event_end_of_bit ) begin
                    if( synced_serial_in == SIGNAL_END_BIT ) begin // STOP BIT VALID
                        next_state = S_UART_RX_DATA_READY; 
                    end else begin
                        next_state = S_UART_RX_IDLE; 
                        cmd_flag_frame_error = 1'b1;
                    end
                end 
            end

            S_UART_RX_DATA_READY: begin
                next_state = S_UART_RX_IDLE; 
                rx_strobe_data_ready = 1'b1;
            end

            default: begin
                next_state = S_UART_RX_IDLE;
            end
            
        endcase

    end

    always_ff @(posedge clk) begin
        
        if(reset) begin
        
            current_state <= S_UART_RX_IDLE; 
            rx_strobe_data_ready <=1'b0;
            rx_parallel_data_out <= RX_PARALLEL_DATA_OUT_DEFAULT;
            rx_status <= 2'b0;

            i_rx_shift_reg <= 8'b0;
            i_status_reg <= 2'b0;
            
            bit_count <= 3'b0;
        
        end else begin
            current_state <= next_state;
            bit_count <= next_bit_count;

            if(cmd_latch_serial_input) begin
                i_rx_shift_reg = { synced_serial_in, i_rx_shift_reg[DATA_WIDTH - 1: 1] };
            end

            if( cmd_flag_frame_error ) begin
                i_status_reg[0] <= 1'b1;
            end

            if ( next_state == S_UART_RX_DATA_READY ) begin
                rx_parallel_data_out <= i_rx_shift_reg;
                rx_status <= i_status_reg;
            end
            
        end
    end


    // ============================================= 
    // (OVER)SAMPLE COUNTER
    // ============================================= 

    logic [3:0] sample_count, next_sample_count; // Counts samples, [0, OVERSAMPLING_RATE - 1] 
    logic [8:0] internal_timer, next_internal_timer;     // Counts clock cycles, [0, CYCLES_PER_SAMPLE - 1]
    
    logic cmd_inc_sample_count;
    logic event_middle_of_bit, event_end_of_bit; 
    

    assign cmd_inc_sample_count = ( internal_timer == CYCLES_PER_SAMPLE - 1);
    
    always_comb begin 
        
        next_sample_count = sample_count;
        next_internal_timer = internal_timer;
        
        if( cmd_enable_sample_timer) begin // Timer Enabled vis FSM state logic
          
            // Reset timer directly
            if( cmd_reset_internal_timer) begin
                next_internal_timer = 'b0;
            end else if (cmd_inc_sample_count) begin // Reset sample count, and by implication timer
                next_sample_count = sample_count + 1;
                next_internal_timer = 'b0;
            end else if (cmd_reset_sample_count) begin
                next_sample_count = 'b0;
                next_internal_timer = 'b0;                
            end else begin // Count!
                next_internal_timer = internal_timer + 1;
            end
        end

    end

    always_ff @( posedge clk ) begin 
        if(reset) begin
            internal_timer <= 8'b0;
            sample_count <= 3'b0;
        end else begin
            sample_count <= next_sample_count;
            internal_timer <= next_internal_timer; 

            if(cmd_inc_sample_count && ( sample_count == (OVERSAMPLING_RATE / 2) - 1 )) begin
                event_middle_of_bit <= 1;
            end else begin
                event_middle_of_bit <= 0;
            end

            if(cmd_inc_sample_count && ( sample_count == (OVERSAMPLING_RATE - 1) )) begin
                event_end_of_bit <= 1;
            end else begin
                event_end_of_bit <= 0;
            end

        end
    end

endmodule