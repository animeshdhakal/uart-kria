from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, FallingEdge
from cocotb_tools.runner import get_runner

CLK_FREQUENCY = 100_000_000
BAUD_RATE = 115_200
CLK_PERIOD = round(1e9 / CLK_FREQUENCY)
CLKS_PER_BIT = CLK_FREQUENCY // BAUD_RATE


async def reset_dut(dut):
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)


async def receive_uart_byte(dut) -> int:
    await FallingEdge(dut.tx)

    await ClockCycles(dut.clk, CLKS_PER_BIT // 2)
    assert dut.tx.value == 0, "Glitch detected on tx; expected valid start bit"

    rx_byte = 0
    for bit_idx in range(8):
        await ClockCycles(dut.clk, CLKS_PER_BIT)
        bit_val = int(dut.tx.value)
        rx_byte |= bit_val << bit_idx

    await ClockCycles(dut.clk, CLKS_PER_BIT)
    assert dut.tx.value == 1, (
        f"Framing error on byte 0x{rx_byte:02X}: stop bit not high"
    )

    return rx_byte


@cocotb.test(timeout_time=2, timeout_unit="ms")
async def test_top(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD, unit="ns").start())
    await reset_dut(dut)

    expected_msg = "Animesh"
    received_chars = []

    for _ in range(len(expected_msg)):
        byte_val = await receive_uart_byte(dut)
        received_chars.append(chr(byte_val))

    received_msg = "".join(received_chars)
    dut._log.info(f"Received UART string: {received_msg!r}")
    assert received_msg == expected_msg, (
        f"Expected {expected_msg!r}, got {received_msg!r}"
    )


def test_top_runner():
    proj_path = Path(__file__).resolve().parent.parent
    runner = get_runner("verilator")

    parameters = {
        "CLK_FREQUENCY": CLK_FREQUENCY,
        "BAUD_RATE": BAUD_RATE,
        "DELAY_CYCLES": 100,
    }
    build_dir = proj_path / "sim_build" / "top"

    runner.build(
        sources=[proj_path / "rtl/top.sv", proj_path / "rtl/uart_tx.sv"],
        hdl_toplevel="top",
        always=True,
        parameters=parameters,
        waves=True,
        build_dir=build_dir,
    )

    runner.test(
        hdl_toplevel="top",
        test_module="test_top",
        parameters=parameters,
        waves=True,
        build_dir=build_dir,
    )


if __name__ == "__main__":
    test_top_runner()
