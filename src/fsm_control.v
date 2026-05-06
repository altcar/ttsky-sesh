/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
RESET: Clear the accumulator.
FETCH: Trigger SPI to grab a weight from external memory.
MULTIPLY: Take ui_in (Data) $\times$ weight (from SPI).
ACCUMULATE: Add result to the 16-bit register.
REPEAT: Do this for $N$ inputs in the layer.
ACTIVATE: Apply ReLU (if result is negative, set to 0).
OUTPUT: Send 16-bit result out over the 8-bit uo_out pins in two cycles.
 */

`default_nettype none

module tt_um_example (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  // All output pins must be assigned. If not used, assign to 0.
  assign uo_out  = ui_in + uio_in;  // Example: ou_out is the sum of ui_in and uio_in
  assign uio_out = 0;
  assign uio_oe  = 0;

  // List all unused inputs to prevent warnings
  wire _unused = &{ena, clk, rst_n, 1'b0};

endmodule
