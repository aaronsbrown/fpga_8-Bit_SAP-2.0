import arch_defs_pkg::*;


module uart_transmitter #(
    parameter CLOCK_SPEED = 20_000_000,
    parameter BAUD_RATE = 9600
) (

    input logic clk,
    input logic reset,

    input logic [DATA_WIDTH-1:0] data_in,
    input logic start_strobe,

    output logic busy_flag,
    output logic data_out
);

    localparam CYCLES_PER_BIT = CLOCK_SPEED / BAUD_RATE;
    localparam DATA_OUT_DEFAULT = 1'b1; 

    uart_fsm_state_t current_state, next_state;
    
    logic [DATA_WIDTH-1: 0] tx_shift_reg;
    logic [3:0] bit_count, next_bit_count;
    logic [11:0] baud_count, next_baud_count;


    always_comb begin

        // default to remaning in current state
        next_state = current_state;
        next_bit_count = bit_count;
        next_baud_count = baud_count;
        data_out = DATA_OUT_DEFAULT;
        busy_flag = 1'b0;

        case (current_state)
        
            S_UART_TX_IDLE: begin
                if(start_strobe) begin
                    
                    busy_flag = 1'b1;
                    
                    next_state = S_UART_TX_START;
                    next_baud_count = 1'b0;
                    next_bit_count = 1'b0;
                end
            end

            S_UART_TX_START: begin
                busy_flag = 1'b1;
                data_out = 1'b0;
                
                if( baud_count < CYCLES_PER_BIT - 1) begin
                    next_state = S_UART_TX_START;
                    next_baud_count = baud_count + 1;    
                end else begin 
                    next_state = S_UART_TX_SEND_DATA;
                    next_bit_count = 1'b0;
                    next_baud_count = 1'b0;
                end
            end

            S_UART_TX_SEND_DATA: begin

                busy_flag = 1'b1;
                data_out = tx_shift_reg[0];
                
                if( baud_count < CYCLES_PER_BIT - 1 ) begin
                    next_state = S_UART_TX_SEND_DATA;
                    next_baud_count = baud_count + 1;
                end else begin
                    next_baud_count = 1'b0; 
                    next_bit_count = bit_count + 1;
                    if (next_bit_count == DATA_WIDTH)
                        next_state = S_UART_TX_STOP;
                end

            end

            S_UART_TX_STOP: begin
                busy_flag = 1'b1;
                data_out = 1'b1;

                if( baud_count < CYCLES_PER_BIT - 1) begin
                    next_state = S_UART_TX_STOP;
                    next_baud_count = baud_count + 1;    
                end else begin 
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
            bit_count <= 1'b0;
            baud_count <= 1'b0;
            data_out <= DATA_OUT_DEFAULT;
            tx_shift_reg <= {DATA_WIDTH{ 1'bx }};
        end else begin
            current_state <= next_state;
            bit_count <= next_bit_count;
            baud_count <= next_baud_count;
            
            if( current_state == S_UART_TX_IDLE && start_strobe)
                    tx_shift_reg <= data_in;
            
            if( current_state == S_UART_TX_SEND_DATA && baud_count == CYCLES_PER_BIT - 1 )
                tx_shift_reg <= { DATA_OUT_DEFAULT, tx_shift_reg[DATA_WIDTH-1:1] };
        end            


    end

endmodule