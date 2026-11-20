module uart_rx #(
    parameter int CLK_FREQUENCY = 100_000_000,
    parameter int BAUD_RATE = 115_200
)(
    input logic clk,
    input logic rst_n,
    input logic rx,
    output logic rx_busy,
    output logic rx_done,
    output logic [7:0] rx_data
);
    localparam int CLKS_PER_BIT = CLK_FREQUENCY / BAUD_RATE;
    localparam int COUNTER_WIDTH = $clog2(CLKS_PER_BIT);

    typedef enum logic [1:0] {
        IDLE,
        START,
        DATA,
        STOP
    } uart_state_t;

    uart_state_t state;

    logic [COUNTER_WIDTH-1:0] baud_counter;
    logic [7:0] shift_reg;
    logic [2:0] bit_index;

    (* ASYNC_REG = "TRUE" *) logic rx_sync_0;
    (* ASYNC_REG = "TRUE" *) logic rx_sync;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync <= 1'b1;
            rx_sync_0 <= 1'b1;
        end
        else begin
            rx_sync_0 <= rx;
            rx_sync <= rx_sync_0;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;

            baud_counter <= 0;
            bit_index <= 0;
            shift_reg <= 0;

            rx_busy <= 1'b0;
            rx_done <= 1'b0;
        end
        else begin
            rx_done <= 1'b0;

            case (state)
                IDLE: begin
                    baud_counter <= 0;
                    bit_index <= 0;

                    rx_busy <= 1'b0;
                    rx_done <= 1'b0;

                    if (rx_sync == 1'b0) begin
                        rx_busy <= 1'b1;
                        state <= START;
                    end
                end

                START: begin
                    if (baud_counter == COUNTER_WIDTH'((CLKS_PER_BIT / 2) - 1)) begin
                        if (rx_sync == 1'b0) begin
                            state <= DATA;
                        end
                        else begin
                            state <= IDLE;
                        end
                        baud_counter <= '0;
                    end
                    else begin
                        baud_counter <= baud_counter + 1'b1;
                    end
                end

                DATA: begin
                    if (baud_counter == COUNTER_WIDTH'(CLKS_PER_BIT - 1)) begin
                        shift_reg[bit_index] <= rx_sync;
                        if (bit_index == 3'd7) begin
                            state <= STOP;
                        end
                        bit_index <= bit_index + 1'b1;
                        baud_counter <= '0;
                    end
                    else begin
                        baud_counter <= baud_counter + 1'b1;
                    end
                end

                STOP: begin
                    if (baud_counter == COUNTER_WIDTH'(CLKS_PER_BIT - 1)) begin
                        baud_counter <= '0;
                        rx_busy <= 1'b0;
                        state <= IDLE;

                        if (rx_sync == 1'b1) begin
                            rx_done <= 1'b1;
                        end
                    end
                    else begin
                        baud_counter <= baud_counter + 1'b1;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

    assign rx_data = shift_reg;
endmodule: uart_rx
