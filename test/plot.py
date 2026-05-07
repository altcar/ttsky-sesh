import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles
import math
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
plt.switch_backend('Agg')
import os

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

async def hw_npu_matrix_mul(dut, A, B):
    N, M = A.shape
    M2, P = B.shape
    res = np.zeros((N, P))
    # Start of layer: pulse clear
    dut.ui_in.value = 64 # ui_in[6] = 1
    await ClockCycles(dut.clk, 2)
    dut.ui_in.value = 0
    await ClockCycles(dut.clk, 2)

    for i in range(N):
        for j in range(P):
            # We must clear manually before each dot product if we want independent ones,
            # but usually NPU accumulates. Since it's a matrix-matrix multiply,
            # we clear before each dot product.
            dut.ui_in.value = 64
            await ClockCycles(dut.clk, 2)
            dut.ui_in.value = 0
            
            for k in range(M):
                input_val = int(A[i, k]) & 0xFF
                weight_val = int(B[k, j]) & 0xFF
                dut.ui_in.value = input_val
                await send_spi_byte(dut, weight_val)
                # Wait for BUSY to finish
                await ClockCycles(dut.clk, 15)
            
            # Read 16-bit result
            dut.ui_in.value = 0 # Low byte
            await ClockCycles(dut.clk, 1)
            low = dut.uo_out.value.integer
            dut.ui_in.value = 1 # High byte
            await ClockCycles(dut.clk, 1)
            high = dut.uo_out.value.integer
            val = (high << 8) | low
            if val >= 32768: val -= 65536
            res[i, j] = val if val > 0 else 0 # ReLU
    return res

async def get_cordic_result(dut, theta_in, mode, select_z=False):
    dut.ui_in.value = theta_in
    dut.uio_in.value = (mode << 6) | 0b100
    await ClockCycles(dut.clk, 35) # Wait for FSM
    
    # Select output
    uio_val = (mode << 6) | (0 << 4) # X
    if select_z: uio_val = (mode << 6) | (1 << 4) # Z (Vectoring)
    
    results = []
    for sel in [0, 1]: # X then Y (or X then Z)
        dut.uio_in.value = (mode << 6) | (sel << 4)
        dut.ui_in.value = 0 # low byte
        await ClockCycles(dut.clk, 1)
        low = dut.uo_out.value.integer
        dut.ui_in.value = 1 # high byte
        await ClockCycles(dut.clk, 1)
        high = dut.uo_out.value.integer
        val = (high << 8) | low
        if val >= 32768: val -= 65536
        results.append(val / 4096.0)
    return results # [X, Y] or [X, Z]

@cocotb.test()
async def generate_plots(dut):
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())
    dut.ena.value = 1
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)

    # --- 1. CORDIC Comparison ---
    angles = np.linspace(0, 1.0, 15)
    data = {'angles': angles, 'sin': [], 'cos': [], 'sinh': [], 'cosh': [], 'tan': [], 'tanh': [],
            'sin_hw': [], 'cos_hw': [], 'sinh_hw': [], 'cosh_hw': [], 'tan_hw': [], 'tanh_hw': []}
    
    for a in angles:
        # Scale: 127 = 1.0 rad
        theta_val = int(round(a * 127)) & 0xFF
        
        # Circular
        x_hw, y_hw = await get_cordic_result(dut, theta_val, 0b01)
        data['cos_hw'].append(x_hw)
        data['sin_hw'].append(y_hw)
        data['tan_hw'].append(y_hw / x_hw if x_hw != 0 else 0)
        
        # Hyperbolic
        xh_hw, yh_hw = await get_cordic_result(dut, theta_val, 0b10)
        data['cosh_hw'].append(xh_hw)
        data['sinh_hw'].append(yh_hw)
        data['tanh_hw'].append(yh_hw / xh_hw if xh_hw != 0 else 0)
        
        # Python
        data['sin'].append(math.sin(a))
        data['cos'].append(math.cos(a))
        data['sinh'].append(math.sinh(a))
        data['cosh'].append(math.cosh(a))
        data['tan'].append(math.tan(a))
        data['tanh'].append(math.tanh(a))

    # --- 2. 4x 6x6 Matrix Multiplication ---
    matrix_results = []
    for m_idx in range(4):
        A = np.random.randint(-3, 4, (6, 6)) # Small values
        B = np.random.randint(-3, 4, (6, 6))
        hw_res = await hw_npu_matrix_mul(dut, A, B)
        pd_res = np.where(A @ B > 0, A @ B, 0)
        matrix_results.append((hw_res, pd_res))

    # --- 3. Plotting ---
    fig = plt.figure(figsize=(15, 20))
    
    # SIN/COS Plot
    ax1 = fig.add_subplot(4, 2, 1)
    ax1.plot(angles, data['sin'], 'r-', label='Py SIN')
    ax1.plot(angles, data['sin_hw'], 'bo', label='HW SIN')
    ax1.plot(angles, data['cos'], 'g-', label='Py COS')
    ax1.plot(angles, data['cos_hw'], 'kx', label='HW COS')
    ax1.set_title('Circular: SIN & COS')
    ax1.legend(); ax1.grid(True)

    # SINH/COSH Plot
    ax2 = fig.add_subplot(4, 2, 2)
    ax2.plot(angles, data['sinh'], 'r-', label='Py SINH')
    ax2.plot(angles, data['sinh_hw'], 'bo', label='HW SINH')
    ax2.plot(angles, data['cosh'], 'g-', label='Py COSH')
    ax2.plot(angles, data['cosh_hw'], 'kx', label='HW COSH')
    ax2.set_title('Hyperbolic: SINH & COSH')
    ax2.legend(); ax2.grid(True)

    # TAN/TANH Plot
    ax3 = fig.add_subplot(4, 2, 3)
    ax3.plot(angles, data['tan'], 'r-', label='Py TAN')
    ax3.plot(angles, data['tan_hw'], 'bo', label='HW TAN')
    ax3.set_title('TAN Comparison')
    ax3.legend(); ax3.grid(True)

    ax4 = fig.add_subplot(4, 2, 4)
    ax4.plot(angles, data['tanh'], 'g-', label='Py TANH')
    ax4.plot(angles, data['tanh_hw'], 'kx', label='HW TANH')
    ax4.set_title('TANH Comparison')
    ax4.legend(); ax4.grid(True)

    # Matrix Errors
    for i in range(4):
        ax = fig.add_subplot(4, 2, 5 + i)
        hw, pd_r = matrix_results[i]
        err = np.abs(hw - pd_r)
        im = ax.imshow(err, cmap='hot', interpolation='nearest')
        ax.set_title(f'Matrix {i+1} Absolute Error')
        plt.colorbar(im, ax=ax)

    plt.tight_layout()
    plt.savefig('comparison_results.png')
    dut._log.info("Results saved to comparison_results.png")
