module top #(
    parameter int CLK_FREQUENCY = 100_000_000,
    parameter int BAUD_RATE = 115_200,
    parameter int DELAY_CYCLES = CLK_FREQUENCY
)(
    input logic clk,
    input logic rst_n,
    output logic tx
);

    localparam int CLKS_PER_BIT = CLK_FREQUENCY / BAUD_RATE;

    logic tx_done;
    logic tx_busy;
    logic [7:0] tx_data;
    logic tx_start;

    localparam int MSG_LEN = 7;
    localparam logic [7:0] to_be_sent [0:MSG_LEN-1] = '{8'h41, 8'h6E, 8'h69, 8'h6D, 8'h65, 8'h73, 8'h68};
    logic [2:0] char_idx;

    localparam int DELAY_WIDTH = $clog2(DELAY_CYCLES);
    logic [DELAY_WIDTH-1:0] delay_cnt;

    typedef enum logic [1:0] {
        IDLE_WAIT,
        SEND_CHAR,
        WAIT_DONE
    } state_t;

    state_t state;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE_WAIT;
            delay_cnt <= '0;
            char_idx <= '0;
            tx_start <= 1'b0;
            tx_data <= 8'h00;
        end
        else begin
            tx_start <= 1'b0;

            case (state)
                IDLE_WAIT: begin
                    if (delay_cnt == DELAY_WIDTH'(DELAY_CYCLES - 1)) begin
                        delay_cnt <= '0;
                        char_idx <= '0;
                        state <= SEND_CHAR;
                    end
                    else begin
                        delay_cnt <= delay_cnt + 1'b1;
                    end
                end

                SEND_CHAR: begin
                    if (!tx_busy) begin
                        tx_data <= to_be_sent[char_idx];
                        state <= WAIT_DONE;
                        tx_start <= 1'b1;
                    end
                end

                WAIT_DONE: begin
                    if (tx_done) begin
                        if (char_idx == 3'(MSG_LEN - 1)) begin
                            state <= IDLE_WAIT;
                        end
                        else begin
                            state <= SEND_CHAR;
                            char_idx <= char_idx + 1'b1;
                        end
                    end
                end

                default: state <= IDLE_WAIT;
            endcase
        end
    end

    uart_tx #(.BAUD_RATE(BAUD_RATE), .CLK_FREQUENCY(CLK_FREQUENCY)) _uart_tx(
        .clk(clk),
        .rst_n(rst_n),
        .tx(tx),
        .tx_busy(tx_busy),
        .tx_data(tx_data),
        .tx_done(tx_done),
        .tx_start(tx_start)
    );
endmodule
