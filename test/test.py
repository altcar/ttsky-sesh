import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles
import math

async def send_spi_byte(dut, byte_val):
    # Preserve mode/control bits (7:3)
    base_uio = dut.uio_in.value.integer & 0xF8
    
    # CS low (bit 2 = 0)
    dut.uio_in.value = base_uio | 0b000
    await ClockCycles(dut.clk, 1)
    for i in range(7, -1, -1):
        bit = (byte_val >> i) & 1
        # sclk=0, mosi=bit
        dut.uio_in.value = base_uio | (0 << 2) | (bit << 1) | 0
        await ClockCycles(dut.clk, 1)
        # sclk=1, mosi=bit
        dut.uio_in.value = base_uio | (0 << 2) | (bit << 1) | 1
        await ClockCycles(dut.clk, 1)
        # sclk=0, mosi=bit
        dut.uio_in.value = base_uio | (0 << 2) | (bit << 1) | 0
    
    # CS high (bit 2 = 1)
    dut.uio_in.value = base_uio | 0b100
    await ClockCycles(dut.clk, 1)

@cocotb.test()
async def test_npu_basic(dut):
    dut._log.info("Start Basic NPU MAC Test")
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0b00000100 # CS=1, Mode=00
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)

    # 1. Clear MAC
    dut.uio_in.value = 0b00001100 # clear=1, CS=1
    await ClockCycles(dut.clk, 5)
    dut.uio_in.value = 0b00000100 # clear=0, CS=1
    await ClockCycles(dut.clk, 5)

    # 2. Perform 5 * 10
    dut.ui_in.value = 5
    await send_spi_byte(dut, 10)
    await ClockCycles(dut.clk, 15) # Wait for FSM

    # 3. Read 16-bit result using uio_in[4] as byte_sel
    # Low byte (uio_in[4]=0)
    dut.uio_in.value = 0b00000100
    await ClockCycles(dut.clk, 2)
    low = dut.uo_out.value.integer
    
    # High byte (uio_in[4]=1)
    dut.uio_in.value = 0b00010100
    await ClockCycles(dut.clk, 2)
    high = dut.uo_out.value.integer
    
    result = (high << 8) | low
    dut._log.info(f"NPU MAC Result: {result}")
    assert result == 50, f"Expected 50, got {result}"

@cocotb.test()
async def test_cordic_basic(dut):
    dut._log.info("Start Basic CORDIC SIN/COS Test")
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0b00000100
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)

    # 0.5 rad approx (64 * 1.0/127)
    theta_val = 64 
    dut.ui_in.value = theta_val
    # Mode = 01 (Circular), CS=1
    dut.uio_in.value = (0b01 << 6) | 0b00000100
    await ClockCycles(dut.clk, 40)
    
    # Read COS (uio_in[3]=0)
    # Low byte (uio_in[4]=0)
    dut.uio_in.value = (0b01 << 6) | 0b00000100 # bit4=0, bit3=0
    await ClockCycles(dut.clk, 2)
    low = dut.uo_out.value.integer
    
    # High byte (uio_in[4]=1)
    dut.uio_in.value = (0b01 << 6) | 0b00010100 # bit4=1, bit3=0
    await ClockCycles(dut.clk, 2)
    high = dut.uo_out.value.integer
    
    cos_hw = ((high << 8) | low) / 1024.0
    dut._log.info(f"CORDIC COS(0.5): {cos_hw:.4f}")
    
    # Comparison (theta_val/128 approx radians)
    expected = math.cos(theta_val/128.0) 
    assert abs(cos_hw - expected) < 0.1, f"COS failed: {cos_hw} vs {expected}"
