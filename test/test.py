import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles
import math
import pandas as pd
import numpy as np

async def send_spi_byte(dut, byte_val):
    dut.uio_in.value = 0b000
    await ClockCycles(dut.clk, 1)
    for i in range(7, -1, -1):
        bit = (byte_val >> i) & 1
        dut.uio_in.value = (0 << 2) | (bit << 1) | 0
        await ClockCycles(dut.clk, 1)
        dut.uio_in.value = (0 << 2) | (bit << 1) | 1
        await ClockCycles(dut.clk, 1)
        dut.uio_in.value = (0 << 2) | (bit << 1) | 0
    dut.uio_in.value = (1 << 2) | 0 | 0
    await ClockCycles(dut.clk, 1)

@cocotb.test()
async def test_npu_matrix_multiply(dut):
    dut._log.info("Start NPU Matrix Multiply Test")
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0b100  # NPU mode
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)

    A = np.array([[10, 5], [2, 12]])
    B = np.array([[-3], [4]])
    df_A = pd.DataFrame(A)
    df_B = pd.DataFrame(B)
    expected_result = df_A.dot(df_B).values.flatten()

    hw_result = []
    for row in range(2):
        for col in range(2):
            input_val = int(A[row][col]) & 0xFF
            weight_val = int(B[col][0]) & 0xFF
            dut.ui_in.value = input_val
            await send_spi_byte(dut, weight_val)
            await ClockCycles(dut.clk, 12)
        
        # Read low byte
        dut.ui_in.value = 0
        await ClockCycles(dut.clk, 1)
        low_byte = dut.uo_out.value.integer
        # Read high byte
        dut.ui_in.value = 1
        await ClockCycles(dut.clk, 1)
        high_byte = dut.uo_out.value.integer
        
        result = (high_byte << 8) | low_byte
        if result >= 32768:
            result -= 65536 # two's complement
            
        # ReLU will zero out negative results in NPU
        if expected_result[row] < 0:
            assert result == 0, f"Expected ReLU 0, got {result}"
        else:
            assert result == expected_result[row], f"Expected {expected_result[row]}, got {result}"
            
        hw_result.append(result)
        
        # Clear MAC
        dut.ui_in.value = 128
        await ClockCycles(dut.clk, 5)

    dut._log.info(f"Pandas matrix multiply expected: {expected_result.tolist()}")
    dut._log.info(f"Hardware MAC + ReLU result: {hw_result}")

@cocotb.test()
async def test_cordic_functions(dut):
    dut._log.info("Start CORDIC SIN/COS/SINH/COSH/TAN/TANH Test")
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())
    dut.ena.value = 1
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)

    theta_val = 32 # 32 << 4 = 512. 512/4096 = 0.125 rad.
    dut.ui_in.value = theta_val
    
    # 1. Circular Mode (SIN/COS)
    dut.uio_in.value = (0b01 << 6) | 0b100 # uio_in[7:6] = 01 (Circular)
    await ClockCycles(dut.clk, 25) # Wait for computation
    
    # Read X (COS)
    dut.uio_in.value = (0b01 << 6) | (0 << 4) # uio_in[4] = 0 -> X
    dut.ui_in.value = (theta_val & 0xFE) | 0 # Low byte
    await ClockCycles(dut.clk, 1)
    cos_low = dut.uo_out.value.integer
    dut.ui_in.value = (theta_val & 0xFE) | 1 # High byte
    await ClockCycles(dut.clk, 1)
    cos_high = dut.uo_out.value.integer
    cos_hw = (cos_high << 8) | cos_low
    if cos_hw >= 32768: cos_hw -= 65536
    
    # Read Y (SIN)
    dut.uio_in.value = (0b01 << 6) | (1 << 4) # uio_in[4] = 1 -> Y
    dut.ui_in.value = (theta_val & 0xFE) | 0 # Low byte
    await ClockCycles(dut.clk, 1)
    sin_low = dut.uo_out.value.integer
    dut.ui_in.value = (theta_val & 0xFE) | 1 # High byte
    await ClockCycles(dut.clk, 1)
    sin_high = dut.uo_out.value.integer
    sin_hw = (sin_high << 8) | sin_low
    if sin_hw >= 32768: sin_hw -= 65536
    
    # 2. Hyperbolic Mode (SINH/COSH)
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    
    dut.ui_in.value = theta_val
    dut.uio_in.value = (0b10 << 6) | 0b100 # uio_in[7:6] = 10 (Hyperbolic)
    await ClockCycles(dut.clk, 25)
    
    dut.uio_in.value = (0b10 << 6) | (0 << 4)
    dut.ui_in.value = (theta_val & 0xFE) | 0
    await ClockCycles(dut.clk, 1)
    cosh_low = dut.uo_out.value.integer
    dut.ui_in.value = (theta_val & 0xFE) | 1
    await ClockCycles(dut.clk, 1)
    cosh_high = dut.uo_out.value.integer
    cosh_hw = (cosh_high << 8) | cosh_low
    if cosh_hw >= 32768: cosh_hw -= 65536
    
    dut.uio_in.value = (0b10 << 6) | (1 << 4)
    dut.ui_in.value = (theta_val & 0xFE) | 0
    await ClockCycles(dut.clk, 1)
    sinh_low = dut.uo_out.value.integer
    dut.ui_in.value = (theta_val & 0xFE) | 1
    await ClockCycles(dut.clk, 1)
    sinh_high = dut.uo_out.value.integer
    sinh_hw = (sinh_high << 8) | sinh_low
    if sinh_hw >= 32768: sinh_hw -= 65536
    
    # Calculate values
    angle_rad = (theta_val << 4) / 4096.0
    
    cos_val = cos_hw / 4096.0
    sin_val = sin_hw / 4096.0
    cosh_val = cosh_hw / 4096.0
    sinh_val = sinh_hw / 4096.0
    
    tan_val = sin_val / cos_val if cos_val != 0 else 0
    tanh_val = sinh_val / cosh_val if cosh_val != 0 else 0
    
    dut._log.info(f"Hardware CORDIC: SIN={sin_val:.4f}, COS={cos_val:.4f}, TAN={tan_val:.4f}")
    dut._log.info(f"Hardware CORDIC: SINH={sinh_val:.4f}, COSH={cosh_val:.4f}, TANH={tanh_val:.4f}")
    
    dut._log.info(f"Python Math:     SIN={math.sin(angle_rad):.4f}, COS={math.cos(angle_rad):.4f}, TAN={math.tan(angle_rad):.4f}")
    dut._log.info(f"Python Math:     SINH={math.sinh(angle_rad):.4f}, COSH={math.cosh(angle_rad):.4f}, TANH={math.tanh(angle_rad):.4f}")
