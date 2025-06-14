import arch_defs_pkg::*;

module uart_receiver #(
    parameter CLOCK_SPEED       = 20_000_000,
    parameter BAUD_RATE         = 9600,
    parameter OVERSAMPLING_RATE = 16,
    parameter WORD_SIZE         = DATA_WIDTH

) (
    input logic                     clk,
    input logic                     reset,
    input logic                     rx_serial_in_data,
    input logic                     cpu_read_data_ack_pulse,
    output logic                    rx_strobe_data_ready_level,
    output logic [WORD_SIZE-1:0]    rx_parallel_data_out,
    output logic [1:0]              rx_status_reg
);

    localparam CYCLES_PER_SAMPLE = CLOCK_SPEED / (BAUD_RATE * OVERSAMPLING_RATE );
    localparam RX_PARALLEL_DATA_OUT_DEFAULT = '0;
    localparam SIGNAL_IDLE = '1;
    localparam SIGNAL_START_BIT = '0;
    localparam SIGNAL_END_BIT = '1;

    localparam STATUS_REG_DEFAULT = {WORD_SIZE{1'b0}};
    localparam STATUS_ERROR_FRAME_BIT = 0;
    localparam STATUS_ERROR_OVERSHOOT_BIT = 1;

    
    // =======================================================================
    // OUTPUT ASSIGNMENT
    // ======================================================================= 
    assign rx_parallel_data_out = rx_shift_reg_i;
    assign rx_status_reg = status_reg_i;


    // =======================================================================
    // DATA PATH
    // ======================================================================= 
    logic [WORD_SIZE-1:0]  rx_shift_reg_i;
    logic [1:0]            status_reg_i; // [0] => Frame Error; [1] => Overshoot Error


    // ====================================================================== 
    // SYNCHRONIZATION REGISTERS: align incoming signal with internal clock
    // ====================================================================== 
    logic sync_ff1;
    logic synced_serial_in;
    
    always_ff @(posedge clk) begin
        if( reset) begin
            sync_ff1 <= SIGNAL_IDLE;
            synced_serial_in <= SIGNAL_IDLE;
        end else begin
            sync_ff1 <= rx_serial_in_data;
            synced_serial_in <= sync_ff1;
        end
    end


    // ======================================================================
    // CONTROL UNIT: state transitions and control signal management
    // ====================================================================== 
    
    uart_fsm_state_t current_state, next_state;
    logic data_ready_flag_i;
    
    localparam DATA_COUNTER_SIZE = $clog2(WORD_SIZE);
    logic [DATA_COUNTER_SIZE-1:0] bit_count, next_bit_count; // Counts sampled message bits, [0, WORD_SIZE - 1]
    
    logic cmd_clear_data_ready_flag;
    logic cmd_set_data_ready_flag; 
    logic cmd_enable_internal_timer;
    logic cmd_reset_internal_timer;
    logic cmd_reset_sample_count;
    logic cmd_latch_serial_input;
    logic cmd_flag_frame_error;
    logic cmd_flag_overshoot_error;
    logic cmd_clear_status_reg;
    logic cmd_clear_rx_shift_reg;

    assign rx_strobe_data_ready_level = data_ready_flag_i; 

    always_comb begin
        
        next_state                  = current_state;
        next_bit_count              = bit_count;
        cmd_enable_internal_timer   = '0;
        cmd_reset_internal_timer    = '0;
        cmd_reset_sample_count      = '0;
        cmd_latch_serial_input      = '0;
        cmd_flag_frame_error        = '0;
        cmd_flag_overshoot_error    = '0;
        cmd_clear_status_reg        = '0;
        cmd_clear_rx_shift_reg      = '0;
        cmd_set_data_ready_flag     = '0;
        cmd_clear_data_ready_flag   = '0;

        case(current_state)

            S_UART_RX_IDLE: begin
                
                if( synced_serial_in == SIGNAL_START_BIT ) begin
                    next_state = S_UART_RX_VALIDATE_START;
                    next_bit_count = '0;
                    cmd_reset_internal_timer = '1;
                    cmd_reset_sample_count = '1; 
                    cmd_clear_status_reg = '1;
                    cmd_clear_rx_shift_reg = '1;
                end
            end

            S_UART_RX_VALIDATE_START: begin
                
                cmd_enable_internal_timer = '1;
                
                if( event_middle_of_bit && (synced_serial_in == SIGNAL_START_BIT )) begin
                    next_state = S_UART_RX_READ_DATA;
                    cmd_reset_internal_timer = '1;
                    cmd_reset_sample_count = '1;
                end else if (event_middle_of_bit && ( synced_serial_in == SIGNAL_END_BIT ) ) begin
                    next_state = S_UART_RX_IDLE;                  
                end
            end

            S_UART_RX_READ_DATA: begin
                
                cmd_enable_internal_timer = '1; 
                cmd_latch_serial_input = '0;

                if ( event_end_of_bit ) begin
                    
                    next_bit_count = bit_count + 1; // start new bit count
                    cmd_latch_serial_input = '1; // sample
                    cmd_reset_sample_count = '1;
                    cmd_reset_internal_timer = '1;
                    
                    if ( bit_count == WORD_SIZE - 1) begin // sampled 8 bits!
                        next_state = S_UART_RX_STOP;
                        next_bit_count = '0;
                    end
                end 
               
            end

            S_UART_RX_STOP: begin
                cmd_latch_serial_input = '0;
                cmd_enable_internal_timer = '1;
                if( event_end_of_bit ) begin
                    if( synced_serial_in == SIGNAL_END_BIT ) begin // STOP BIT VALID
                        
                        if (data_ready_flag_i)
                            cmd_flag_overshoot_error = '1;

                        next_state = S_UART_RX_IDLE;
                        cmd_set_data_ready_flag = '1;
                    end else begin
                        next_state = S_UART_RX_IDLE; 
                        cmd_flag_frame_error = '1;
                    end
                end 
            end

            default: begin
                next_state = S_UART_RX_IDLE;
            end
            
        endcase

    end

    always_ff @(posedge clk) begin
        
        if(reset) begin
        
            current_state <= S_UART_RX_IDLE; 
            
            rx_shift_reg_i <= RX_PARALLEL_DATA_OUT_DEFAULT;
            status_reg_i <= STATUS_REG_DEFAULT;
            data_ready_flag_i <= '0;

            bit_count <= '0;
        
        end else begin
            current_state <= next_state;
            bit_count <= next_bit_count;

            if (cmd_clear_rx_shift_reg)
                rx_shift_reg_i <= '0;
            else if (cmd_latch_serial_input) 
                rx_shift_reg_i <= { synced_serial_in, rx_shift_reg_i[WORD_SIZE - 1: 1] };
            
            if (cmd_clear_status_reg) 
                status_reg_i <= STATUS_REG_DEFAULT;
            else if( cmd_flag_frame_error ) 
                status_reg_i[STATUS_ERROR_FRAME_BIT] <= '1;
            else if ( cmd_flag_overshoot_error )
                status_reg_i[STATUS_ERROR_OVERSHOOT_BIT] <= '1;

            if (cpu_read_data_ack_pulse)
                data_ready_flag_i <= '0;
            else if (cmd_set_data_ready_flag)
                data_ready_flag_i <= '1;
 
        end
    end


    // ============================================= 
    // (OVER)SAMPLE COUNTER
    // ============================================= 

    localparam SAMPLE_COUNTER_SIZE = $clog2(OVERSAMPLING_RATE);
    logic [SAMPLE_COUNTER_SIZE-1:0] sample_count, next_sample_count; // Counts samples, [0, OVERSAMPLING_RATE - 1] 
    
    localparam TIMER_SIZE = $clog2(CYCLES_PER_SAMPLE); 
    logic [TIMER_SIZE-1:0] internal_timer, next_internal_timer;     // Counts clock cycles, [0, CYCLES_PER_SAMPLE - 1]
    
    logic cmd_inc_sample_count;
    logic event_middle_of_bit, event_end_of_bit;  

    assign cmd_inc_sample_count = ( internal_timer == CYCLES_PER_SAMPLE - 1);
    
    always_comb begin 
        
        next_sample_count = sample_count;
        next_internal_timer = internal_timer;

        if ( cmd_reset_sample_count ) begin
            next_sample_count = '0;
        end else if ( cmd_inc_sample_count ) begin
            next_sample_count = sample_count + 1; 
        end

        if ( cmd_reset_internal_timer || cmd_reset_sample_count || cmd_inc_sample_count ) begin
            next_internal_timer = '0;
        end else begin
            if (cmd_enable_internal_timer)
                next_internal_timer = internal_timer + 1;
        end
    end

    always_ff @( posedge clk ) begin 
        if(reset) begin
            internal_timer <= '0;
            sample_count <= '0;
        end else begin
            sample_count <= next_sample_count;
            internal_timer <= next_internal_timer; 

            // Check for middle of data bit 
            if(cmd_inc_sample_count && ( sample_count == (OVERSAMPLING_RATE / 2) - 1 )) begin
                event_middle_of_bit <= '1;
            end else begin
                event_middle_of_bit <= '0;
            end

            // Check for end of data bit
            if(cmd_inc_sample_count && ( sample_count == (OVERSAMPLING_RATE - 1) )) begin
                event_end_of_bit <= '1;
            end else begin
                event_end_of_bit <= '0;
            end

        end
    end

endmodule