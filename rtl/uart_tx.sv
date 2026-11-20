module uart_tx #(
    parameter int CLK_FREQUENCY = 100_000_000,
    parameter int BAUD_RATE = 115_200
)(
    input logic clk,
    input logic rst_n,
    input logic [7:0] tx_data,
    input logic tx_start,
    output logic tx_done,
    output logic tx_busy,
    output logic tx
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

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            baud_counter <= '0;
            shift_reg <= '0;
            bit_index <= '0;
            tx <= 1'b1;
            tx_done <= 1'b0;
            tx_busy <= 1'b0;
        end
        else begin
            tx_done <= 1'b0;

            case (state)
                IDLE: begin
                    tx <= 1'b1;
                    tx_busy <= 1'b0;
                    baud_counter <= '0;
                    bit_index <= '0;

                    if (tx_start) begin
                        shift_reg <= tx_data;
                        state <= START;
                        tx <= 1'b0;
                        tx_busy <= 1'b1;
                    end
                end

                START: begin
                    if (baud_counter == COUNTER_WIDTH'(CLKS_PER_BIT - 1)) begin
                        baud_counter <= '0;
                        tx <= shift_reg[0];
                        state <= DATA;
                    end
                    else begin
                        baud_counter <= baud_counter + 1'b1;
                    end
                end

                DATA: begin
                    if (baud_counter == COUNTER_WIDTH'(CLKS_PER_BIT - 1)) begin
                        baud_counter <= '0;
                        if (bit_index == 3'd7) begin
                            tx <= 1'b1;
                            state <= STOP;
                        end
                        else begin
                            bit_index <= bit_index + 1'b1;
                            tx <= shift_reg[bit_index+1'b1];
                        end
                    end
                    else begin
                        baud_counter <= baud_counter + 1'b1;
                    end
                end

                STOP: begin
                    if (baud_counter == COUNTER_WIDTH'(CLKS_PER_BIT - 1)) begin
                        tx_done <= 1'b1;
                        tx_busy <= 1'b0;
                        baud_counter <= '0;
                        state <= IDLE;
                    end
                    else begin
                        baud_counter <= baud_counter + 1'b1;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule: uart_tx
