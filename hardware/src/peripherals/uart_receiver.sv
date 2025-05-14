import arch_defs_pkg::*;

module uart_receiver #(
    parameter CLOCK_SPEED = 20_000_000,
    parameter BAUD_RATE = 9600
) (
    input logic clk,
    input logic reset,

    input logic rx_serial_in_data,

    output logic rx_data_ready_strobe,
    output logic [DATA_WIDTH-1:0] data_out
);

    localparam CYCLES_PER_BIT = CLOCK_SPEED / BAUD_RATE;
    localparam DATA_IN_DEFAULT = 1'b1;

    uart_fsm_state_t current_state, next_state;

    logic [DATA_WIDTH-1:0] rx_shift_reg;
    logic [3:0] bit_count, next_bit_count;
    logic [11:0] baud_count, next_baud_count;

    always_comb begin
        
        case(current_state)

            S_UART_RX_IDLE: begin
            end

            S_UART_RX_VALIDATE_START: begin
                
            end

            S_UART_RX_READ_DATA: begin
            end

            S_UART_RX_STOP: begin
            end

            default: begin
            
            end
            
        endcase

    end

    always_ff @(posedge clk) begin
        if(reset) begin
            rx_data_ready_strobe <= 1'b0;
            data_out <= 8'b0;
            rx_shift_reg <= {DATA_WIDTH{1'bx}};
            bit_count <=1'b0;
        end else begin
            current_state <= next_state;
            bit_count <= next_bit_count;
            baud_count <= next_baud_count;

            // TODO add logic to deserialize into rx_shift_reg
        end
    end

endmodule