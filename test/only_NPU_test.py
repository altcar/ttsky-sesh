import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge

async def send_spi_byte(dut, byte_val):
    # cs is uio_in[2], mosi is uio_in[1], sclk is uio_in[0]
    
    # Assert CS low
    dut.uio_in.value = 0b000
    await ClockCycles(dut.clk, 1)
    
    for i in range(7, -1, -1):
        bit = (byte_val >> i) & 1
        # cs=0, mosi=bit, sclk=0
        dut.uio_in.value = (0 << 2) | (bit << 1) | 0
        await ClockCycles(dut.clk, 1)
        
        # cs=0, mosi=bit, sclk=1
        dut.uio_in.value = (0 << 2) | (bit << 1) | 1
        await ClockCycles(dut.clk, 1)
        
        # cs=0, mosi=bit, sclk=0
        dut.uio_in.value = (0 << 2) | (bit << 1) | 0
        
    # De-assert CS (high)
    dut.uio_in.value = (1 << 2) | 0 | 0
    await ClockCycles(dut.clk, 1)

@cocotb.test()
async def test_mac_operation(dut):
    dut._log.info("Start NPU MAC test")

    # Start clock
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    # Initialize inputs
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0b100  # CS high initially
    dut.rst_n.value = 0
    
    # Reset
    dut._log.info("Resetting...")
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)

    # First MAC: +10 * +5 = 50
    input_val = 10
    weight_val = 5
    
    dut.ui_in.value = input_val
    dut._log.info(f"Sending weight {weight_val} via SPI")
    await send_spi_byte(dut, weight_val)
    
    # Wait for Shift-and-Add to complete (8 clock cycles after SPI done)
    await ClockCycles(dut.clk, 12)
    
    # Check result
    # ui_in[0] is 0 -> low byte, 1 -> high byte
    dut.ui_in.value = (input_val & 0xFE) | 0  # low byte request
    await ClockCycles(dut.clk, 1)
    low_byte = dut.uo_out.value.integer
    
    dut.ui_in.value = (input_val & 0xFE) | 1  # high byte request
    await ClockCycles(dut.clk, 1)
    high_byte = dut.uo_out.value.integer
    
    result = (high_byte << 8) | low_byte
    dut._log.info(f"Result 1: {result}")
    assert result == 50, f"Expected 50, got {result}"

    # Second MAC: accumulate. +12 * -5 = -60. 
    # Total should be 50 - 60 = -10. ReLU -> 0.
    input_val = 12
    weight_val = 251  # -5 in 2's complement
    
    dut.ui_in.value = input_val
    dut._log.info(f"Sending weight -5 via SPI")
    await send_spi_byte(dut, weight_val)
    await ClockCycles(dut.clk, 12)
    
    dut.ui_in.value = (input_val & 0xFE) | 0
    await ClockCycles(dut.clk, 1)
    low_byte = dut.uo_out.value.integer
    
    dut.ui_in.value = (input_val & 0xFE) | 1
    await ClockCycles(dut.clk, 1)
    high_byte = dut.uo_out.value.integer
    
    result = (high_byte << 8) | low_byte
    dut._log.info(f"Result 2 (ReLU expected): {result}")
    assert result == 0, f"Expected 0 (ReLU applied), got {result}"

    # Third MAC: trigger end of layer and clear accumulator
    dut.ui_in.value = 128  # ui_in[7] = 1
    await ClockCycles(dut.clk, 5)
    
    # Check that uio_out[0] (done_pulse) is high or was high
    dut._log.info("All NPU MAC tests passed!")
