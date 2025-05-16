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
    output logic rx_data_ready_strobe,
    output logic [DATA_WIDTH-1:0] data_out
    output logic [1:0] status_reg;
);

    localparam CYCLES_PER_BIT = CLOCK_SPEED / BAUD_RATE;
    localparam CYCLES_PER_SAMPLE = CLOCK_SPEED / (BAUD_RATE * OVERSAMPLING_RATE );
    localparam DATA_OUT_DEFAULT = 8'b0;
    localparam SIGNAL_START_BIT = 1'b0;
    localparam SINAL_END_BIT = 1'b1;
    
    logic [DATA_WIDTH-1:0] i_rx_shift_reg;
    logic [1:0]            i_status_reg;
    
    // ====================================================================== 
    // SYNCHRONIZATION REGISTERS: align incoming signal with internal clock
    // ====================================================================== 
    logic sync_ff1;
    logic synced_serial_in;
    
    always @(posedge clk) begin
        sync_ff1 <= rx_serial_in_data;
        synced_serial_in <= sync_ff1;
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
    always_comb begin
        
        next_state = current_state;

        case(current_state)

            S_UART_RX_IDLE: begin
                // TODO data_ready reset?
                if( synced_serial_in == 1'b0 ) begin
                    next_state = S_UART_RX_VALIDATE_START;
                    next_internal_timer = 8'b0;
                    next_sample_count = 3'b0; 
                    next_bit_count = 3'b0;
                end
            end

            S_UART_RX_VALIDATE_START: begin
                if( event_middle_of_bit && !synced_serial_in ) begin
                    next_state = S_UART_RX_READ_DATA;
                    next_internal_timer = 8'b0;
                    next_sample_count = 3'b0;
                end else if (event_middle_of_bit && synced_serial_in ) begin
                    next_state = S_UART_RX_IDLE;                  
                end
            end

            S_UART_RX_READ_DATA: begin
                
                latch_input = 1'b0;

                if ( event_end_of_bit ) begin
                    
                    latch_input = 1'b1; // sample
                    next_bit_count = bit_count + 1; // start new bit count
                    next_sample_count = 3'b0;
                    
                    if ( bit_count == DATA_WIDTH - 1) begin // sampled 8 bits!
                        next_state = S_UART_RX_STOP;
                        next_internal_timer = 8'b0;
                        next_sample_count = 3'b0; 
                        next_bit_count = 3'b0;
                        latch_input = 1'b0;
                    end
                end 
               
            end

            S_UART_RX_STOP: begin

                if( event_end_of_bit) begin
                    if( synced_serial_in ) begin // STOP BIT VALID
                        next_state = S_UART_RX_DATA_READY; 
                    end else begin
                       next_state = S_UART_RX_IDLE; 
                    end
                end 
            end

            S_UART_RX_DATA_READY: begin
                next_state = S_UART_RX_IDLE; 
                rx_data_ready_strobe = 1'b1;
            end

            default: begin
                next_state = S_UART_RX_IDLE;
            end
            
        endcase

    end

    always_ff @(posedge clk) begin
        if(reset) begin
            current_state <= S_UART_RX_IDLE; 
            data_out <= 8'b0;
            rx_shift_reg <= 8'b0;
            bit_count <= 3'b0;
            rx_data_ready_strobe <=1'b0;
        end else begin
            current_state <= next_state;
            bit_count <= next_bit_count;
            
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
        
        if(cmd_inc_sample_count) begin
            next_sample_count = sample_count + 1;
            next_internal_timer = 8'b0;
        end else begin
            if( enable_internal_timer ) begin
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