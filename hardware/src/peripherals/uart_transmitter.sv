import arch_defs_pkg::*;

module uart_transmitter #(
    parameter CLOCK_SPEED   = 20_000_000,
    parameter BAUD_RATE     = 9600,
    parameter WORD_SIZE     = DATA_WIDTH
) (

    input logic clk,
    input logic reset,

    // INPUTS
    input logic [DATA_WIDTH-1:0]    tx_parallel_data_in,
    input logic                     tx_strobe_start,

    // OUTPUTS
    output logic                    tx_strobe_busy,
    output logic                    tx_serial_data_out
);

    localparam CYCLES_PER_BIT = CLOCK_SPEED / BAUD_RATE;
    localparam DATA_OUT_DEFAULT = '1; 
    localparam SIGNAL_IDLE = '1;
    localparam SIGNAL_START_BIT = '0;
    localparam SIGNAL_STOP_BIT = '1;

    
    // =======================================================================
    // OUTPUT ASSIGNMENTS
    // ======================================================================= 
    assign tx_strobe_busy = i_tx_strobe_busy;

    // =======================================================================
    // DATA PATH
    // ======================================================================= 
    logic [WORD_SIZE-1: 0] i_tx_shift_reg;
    logic i_tx_strobe_busy, i_tx_strobe_busy_next;


    // ======================================================================
    // CONTROL UNIT: state transitions and control signal management
    // ====================================================================== 
    
    uart_fsm_state_t current_state, next_state;
    
    localparam DATA_COUNTER_SIZE = $clog2(WORD_SIZE);
    logic [DATA_COUNTER_SIZE-1:0] bit_count, next_bit_count;
    
    logic cmd_enable_baud_count;
    logic cmd_reset_baud_count;
    logic cmd_latch_input_data;
    logic cmd_shift_input_data;

    always_comb begin

        next_state              = current_state;
        next_bit_count          = bit_count;
        
        tx_serial_data_out      = SIGNAL_IDLE;
        i_tx_strobe_busy_next = '0; 
        
        cmd_enable_baud_count   = '0;
        cmd_reset_baud_count    = '0;
        cmd_latch_input_data    = '0;
        cmd_shift_input_data    = '0;

        case (current_state)
        
            S_UART_TX_IDLE: begin

                if(tx_strobe_start) begin  
                    i_tx_strobe_busy_next = '1;
                    cmd_latch_input_data = '1;

                    next_state = S_UART_TX_START;
                    next_bit_count = '0;
                    cmd_reset_baud_count = '1;
                end
            end

            S_UART_TX_START: begin
               
                tx_serial_data_out = SIGNAL_START_BIT;
                i_tx_strobe_busy_next = '1;
                cmd_enable_baud_count = '1;     
                
                if ( event_end_of_bit ) begin
                    next_state = S_UART_TX_SEND_DATA;
                    cmd_reset_baud_count = '1;
                end 
                    
            end

            S_UART_TX_SEND_DATA: begin

                tx_serial_data_out = i_tx_shift_reg[0];
                i_tx_strobe_busy_next = 1'b1;
                cmd_enable_baud_count = '1;     

                if ( event_end_of_bit ) begin
                    
                    cmd_shift_input_data = '1;
                    cmd_reset_baud_count = '1; 
                   
                    if ( bit_count == WORD_SIZE - 1 ) begin
                        next_state = S_UART_TX_STOP;
                        next_bit_count = '0;
                    end else begin
                        next_bit_count = bit_count + 1;
                    end
                end 
            end

            S_UART_TX_STOP: begin
                
                tx_serial_data_out = SIGNAL_STOP_BIT;
                i_tx_strobe_busy_next = '1;
                cmd_enable_baud_count = '1;    
                
                if ( event_end_of_bit ) begin
                    next_state = S_UART_TX_IDLE;
                end
            end

        default:
            next_state = S_UART_TX_IDLE;
        
        endcase
    
    end



    always_ff @(posedge clk) begin

        if(reset) begin
            current_state <= S_UART_TX_IDLE;
            i_tx_strobe_busy <= '0;
            i_tx_shift_reg <= 'x;
            bit_count <= 1'b0;

        end else begin
            current_state <= next_state;
            i_tx_strobe_busy <= i_tx_strobe_busy_next;
            bit_count <= next_bit_count;
            
            if( cmd_latch_input_data ) begin
                i_tx_shift_reg <= tx_parallel_data_in;
            end else if( cmd_shift_input_data ) begin
                i_tx_shift_reg <= { DATA_OUT_DEFAULT, i_tx_shift_reg[WORD_SIZE-1:1] };
            end
        end            


    end


    // ===========================================
    // BAUD COUNTER
    // ===========================================
    
    localparam BAUD_COUNTER_SIZE = $clog2(CYCLES_PER_BIT);
    logic [BAUD_COUNTER_SIZE-1:0] baud_count, next_baud_count;

    logic event_end_of_bit;

    always_comb begin
        next_baud_count = baud_count;

        if( cmd_reset_baud_count ) begin
            next_baud_count = '0;
        end else if ( cmd_enable_baud_count ) begin
            next_baud_count = baud_count + 1;
        end
    end

    always_ff @(posedge clk) begin

        if(reset) begin
            baud_count <= '0;    
        end else begin
            baud_count <= next_baud_count;

            if ( baud_count == CYCLES_PER_BIT - 1 ) begin
                event_end_of_bit <='1;
            end else begin
                event_end_of_bit <= '0;
            end
        end

    end

endmodule