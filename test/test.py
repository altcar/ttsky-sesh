import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_npu_basic(dut):
    dut.input_data.value = 10
    dut.weight_data.value = 5
    dut.enable.value = 1
    
    await Timer(10, units="ns")
    # 10 * 5 = 50
    assert dut.accumulator.value == 50