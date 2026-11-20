// -----------------------------------------------------------------------------
// kria_top.sv - Top-level module for AMD Xilinx Kria K26 SOM (KV260 / KR260)
//
// Bridges the Zynq UltraScale+ MPSoC Processing System (PS) clock and reset
// to the UART top logic, driving PMOD Pin 1 (H12).
// -----------------------------------------------------------------------------

`timescale 1ns / 1ps

module kria_top(
    output logic uart_tx
);

    // Clock (100 MHz) and active-low reset from Zynq UltraScale+ PS
    logic pl_clk0;
    logic pl_resetn0;

    // Block Design wrapper instantiating zynq_ultra_ps_e
    system_wrapper u_system(
        .pl_clk0(pl_clk0),
        .pl_resetn0(pl_resetn0)
    );

    // UART core transmitting "Animesh" repeatedly every 1 second
    top #(.CLK_FREQUENCY(100_000_000), .BAUD_RATE(115_200), .DELAY_CYCLES(100_000_000)) u_uart_top(
        .clk(pl_clk0),
        .rst_n(pl_resetn0),
        .tx(uart_tx)
    );

endmodule
