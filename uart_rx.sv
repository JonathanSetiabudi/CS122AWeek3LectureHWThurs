`include "clock_mul.sv"

module uart_rx (
    input clk,
    input rx,
    output reg rx_ready,
    output reg [7:0] rx_data
);

parameter SRC_FREQ = 76800;
parameter BAUDRATE = 9600;
reg UART_clk;
reg [2:0] bit_index = 3'd0;
reg [1:0] state = 2'd1;

// Cross-clock domain synchronization
reg rx_ready_uart;           // Flag in UART clock domain
reg sync_stage1, sync_stage2; // Synchronizer chain
reg sync_prev;               // For edge detection

// STATES: State of the state machine
localparam DATA_BITS = 8;
localparam 
    INIT = 0, 
    IDLE = 1,
    RX_DATA = 2,
    STOP = 3;

// CLOCK MULTIPLIER: Instantiate the clock multiplier
clock_mul #(.SRC_FREQ(SRC_FREQ), .OUT_FREQ(BAUDRATE)) clock_mul_inst (.src_clk(clk), .out_clk(UART_clk));
// CROSS CLOCK DOMAIN: The rx_ready flag should only be set 1 one for one source 
// clock cycle. Use the cross clock domain technique discussed in class to handle this.

// STATE MACHINE: Use the UART clock to drive that state machine that receves a byte from the rx signal

always @(posedge UART_clk) begin
    //state transition
    case (state)
        2'd0 : state <= IDLE;
        2'd1 : state <= (rx == 1'b0) ? RX_DATA : IDLE;
        2'd2 : state <= (bit_index == 3'd7) ? STOP : RX_DATA;
        // 2d'3 : (rx == 1b'1) ? state <= IDLE : 
        2'd3 : state <= IDLE;
        default : state <= IDLE;
    endcase

    // state actions
    case (state)
        2'd0 : begin
            rx_ready_uart <= 1'b0;
            bit_index <= 3'd0;
        end
        2'd1 : begin
            rx_ready_uart <= 1'b0;
        end
        2'd2 : begin
            rx_data[bit_index] <= rx;
            bit_index <= bit_index + 1;
        end
        2'd3 : begin
            rx_ready_uart <= 1'b1;
        end
        default : begin
            rx_ready_uart <= 1'b0;
            bit_index <= 3'd0;
        end
    endcase
end

// Synchronizer chain: move rx_ready_uart from UART clock to source clock
always @(posedge clk) begin
    sync_stage1 <= rx_ready_uart;
    sync_stage2 <= sync_stage1;
    sync_prev <= sync_stage2;
end

// Edge detection: pulse rx_ready for one source clock cycle
always @(posedge clk) begin
    rx_ready <= (sync_stage2 == 1'b1 && sync_prev == 1'b0) ? 1'b1 : 1'b0;
end

endmodule