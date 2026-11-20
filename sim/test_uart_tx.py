from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, FallingEdge, RisingEdge
from cocotb_tools.runner import get_runner

CLK_FREQUENCY = 50_000_000
BAUD_RATE = 115200
CLK_PERIOD = int(1e9 // CLK_FREQUENCY)
CLKS_PER_BIT = int(CLK_FREQUENCY // BAUD_RATE)


async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.tx_data.value = 0
    dut.tx_start.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)

    assert dut.tx.value == 1, "tx line must be HIGH after reset"
    assert dut.tx_busy.value == 0, "tx_busy must be LOW after reset"


async def uart_rx_monitor(dut, expected_byte):
    await FallingEdge(dut.tx)
    assert dut.tx_busy.value == 1, "tx_busy must be HIGH during transmission"

    await ClockCycles(dut.clk, (CLKS_PER_BIT // 2) - 1)
    assert dut.tx.value == 0, "tx line must be LOW during start bit"

    transmitted_byte = 0x0

    for i in range(8):
        await ClockCycles(dut.clk, CLKS_PER_BIT)
        transmitted_byte |= int(dut.tx.value) << i

    await ClockCycles(dut.clk, CLKS_PER_BIT)
    assert dut.tx.value == 1, "tx line must be HIGH during stop bit"

    assert transmitted_byte == expected_byte

    while dut.tx_busy.value:
        await RisingEdge(dut.clk)

    assert dut.tx_busy.value == 0, "tx_busy must be LOW after the stop bit"


@cocotb.test(timeout_time=1, timeout_unit="ms")
async def test_uart_tx(dut):
    print("Clock Period in NS is", CLK_PERIOD)
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD, unit="ns").start())
    await reset_dut(dut)

    test_vectors = [0x55, 0x66, 0x12, 0x05, 0x12, 0x87]

    for test_vector in test_vectors:
        monitor_task = cocotb.start_soon(uart_rx_monitor(dut, test_vector))

        dut.tx_data.value = test_vector
        dut.tx_start.value = 1
        await RisingEdge(dut.clk)
        dut.tx_start.value = 0

        await monitor_task


def test_uart_tx_runner():
    proj_path = Path(__file__).resolve().parent.parent
    runner = get_runner("verilator")

    parameters = {"CLK_FREQUENCY": CLK_FREQUENCY, "BAUD_RATE": BAUD_RATE}
    build_dir = proj_path / "sim_build" / "uart_tx"

    runner.build(
        sources=[proj_path / "rtl/uart_tx.sv"],
        hdl_toplevel="uart_tx",
        always=True,
        parameters=parameters,
        waves=True,
        build_dir=build_dir,
    )

    runner.test(
        hdl_toplevel="uart_tx",
        test_module="test_uart_tx",
        parameters=parameters,
        waves=True,
        build_dir=build_dir,
    )
