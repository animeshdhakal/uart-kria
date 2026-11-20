from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, with_timeout
from cocotb_tools.runner import get_runner

CLK_FREQUENCY = 50_000_000
BAUD_RATE = 115200
CLK_PERIOD = int(1e9 // CLK_FREQUENCY)
CLKS_PER_BIT = int(CLK_FREQUENCY // BAUD_RATE)


async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.rx.value = 1
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)

    assert dut.rx_busy.value == 0, "rx_busy must be LOW after reset"
    assert dut.rx_done.value == 0, "rx_done must be LOW after reset"
    assert dut.rx_data.value == 0, "rx_data must be zero after reset"


async def send(dut, value):
    dut.rx.value = 0
    await ClockCycles(dut.clk, CLKS_PER_BIT)

    for i in range(8):
        dut.rx.value = (value >> i) & 1
        await ClockCycles(dut.clk, CLKS_PER_BIT)

    dut.rx.value = 1
    await ClockCycles(dut.clk, CLKS_PER_BIT)


async def check_rx(dut, expected):
    timeout_ns = CLK_PERIOD * CLKS_PER_BIT * 11
    await with_timeout(RisingEdge(dut.rx_done), timeout_ns, "ns")

    received = int(dut.rx_data.value)
    assert received == expected, (
        f"Data mismatch: expected 0x{expected:02X}, got 0x{received:02X}"
    )


@cocotb.test(timeout_time=1, timeout_unit="ms")
async def test_uart_rx(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD, unit="ns").start())

    await reset_dut(dut)

    for test_byte in [0x11, 0x55, 0xAA, 0x00, 0xFF]:
        checker = cocotb.start_soon(check_rx(dut, test_byte))
        await send(dut, test_byte)
        await checker


def test_uart_rx_runner():
    proj_path = Path(__file__).resolve().parent.parent
    runner = get_runner("verilator")

    parameters = {"CLK_FREQUENCY": CLK_FREQUENCY, "BAUD_RATE": BAUD_RATE}
    build_dir = proj_path / "sim_build" / "uart_rx"

    runner.build(
        sources=[proj_path / "rtl/uart_rx.sv"],
        hdl_toplevel="uart_rx",
        always=True,
        parameters=parameters,
        waves=True,
        build_dir=build_dir,
    )

    runner.test(
        hdl_toplevel="uart_rx",
        test_module="test_uart_rx",
        parameters=parameters,
        waves=True,
        build_dir=build_dir,
    )
