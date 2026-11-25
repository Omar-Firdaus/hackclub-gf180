import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, Timer


def pin(sig):
    try:
        return int(sig.value)
    except ValueError:
        return None


async def sram(dut, mem):
    while True:
        await RisingEdge(dut.clk)
        await Timer(2, unit="ns")
        uo = pin(dut.uo_out)
        if uo is None:
            continue
        addr = uo & 0x7F
        we = (uo >> 7) & 1
        if we:
            if addr != 0x7F:
                data = pin(dut.uio_out)
                if data is not None:
                    mem[addr] = data
        else:
            if addr != 0x7F:
                dut.uio_in.value = mem[addr]


@cocotb.test()
async def test_bus_program(dut):
    mem = [0] * 128
    prog = {
        0x00: 0x01, 0x01: 0x61,
        0x02: 0x01, 0x03: 0x62,
        0x04: 0x08, 0x05: 0x86,
        0x06: 0xFF, 0x07: 0x63,
        0x08: 0xC0, 0x09: 0x06,
        0x0A: 0x20, 0x0B: 0x53,
        0x0C: 0x20, 0x0D: 0x41,
        0x0E: 0x7F, 0x0F: 0x42,
        0x10: 0x10, 0x11: 0x70,
    }
    for a, b in prog.items():
        mem[a] = b

    expect = [
        0x01, 0x01, 0x02, 0x03, 0x03, 0x04, 0x05, 0x05,
        0x08, 0x09, 0x09, 0x0A, 0x0B, 0x0B, 0xA0, 0xA1,
        0x0C, 0x0D, 0x0D, 0x20, 0x21, 0x0E, 0x0F, 0x0F,
        0x7F, 0x10, 0x11, 0x11, 0x10,
    ]

    cocotb.start_soon(Clock(dut.clk, 100, unit="ns").start())
    cocotb.start_soon(sram(dut, mem))

    dut.rst_n.value = 0
    dut.ena.value = 1
    dut.ui_in.value = 0x5A
    dut.uio_in.value = mem[0]

    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1

    for i, exp in enumerate(expect):
        await RisingEdge(dut.clk)
        await Timer(2, unit="ns")
        got = pin(dut.uo_out)
        assert got == exp, f"cycle {i}: uo_out {got} != {exp:02X}"
        if exp & 0x80:
            assert pin(dut.uio_oe) == 0xFF
            if exp == 0xA0:
                assert pin(dut.uio_out) == 0x02
            if exp == 0xA1:
                assert pin(dut.uio_out) == 0x00
        else:
            assert pin(dut.uio_oe) == 0x00

    await Timer(2, unit="ns")
    assert mem[0x20] == 0x02
    assert mem[0x21] == 0x00

    try:
        r1 = int(dut.user_project.cpu.rf.registers[1].value)
        r2 = int(dut.user_project.cpu.rf.registers[2].value)
        r3 = int(dut.user_project.cpu.rf.registers[3].value)
    except AttributeError:
        return

    assert r1 == 0x0002
    assert r2 == 0x005A
    assert r3 == 0x0002
