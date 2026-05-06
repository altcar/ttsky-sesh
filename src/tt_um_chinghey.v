/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_chinghey (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);


    // Internal Signals
    wire [7:0] weight_from_spi;
    wire weight_ready, mac_en, acc_clr, done_pulse;
    wire [15:0] nlp_result;

    // 1. SPI Receiver (Uses the Bidirectional Pins)
    // uio[0] = SCLK, uio[1] = MOSI, uio[2] = CS
    spi_receiver my_spi (
        .clk(clk),
        .rst_n(rst_n),
        .sclk(uio_in[0]),
        .mosi(uio_in[1]),
        .cs(uio_in[2]),
        .weight(weight_from_spi),
        .done(weight_ready)
    );

    control_fsm fsm_inst (
        .clk(clk),
        .rst_n(rst_n),
        .spi_ready(weight_ready),
        .ui_in(ui_in),
        .mac_en(mac_en),
        .acc_clr(acc_clr),
        .done_pulse(done_pulse)
    );

    // 2. NPU Core
    npu_core my_npu (
        .clk(clk),
        .reset(!rst_n),
        .clear(acc_clr),
        .input_data(ui_in),
        .weight_data(weight_from_spi),
        .enable(weight_ready),
        .out(nlp_result)
    );

    // 3. Output logic (Muxing the 16-bit result to 8-bit pins)
    // If ui_in[0] is high, show high byte; if low, show low byte
    assign uo_out = ui_in[0] ? nlp_result[15:8] : nlp_result[7:0];

    // Configure Bidirectional pins: 0,1,2 are inputs (SPI), others are outputs
    assign uio_oe  = 8'b11111000; 
    assign uio_out = {done_pulse, mac_en, 6'b0};

endmodule
  // // All output pins must be assigned. If not used, assign to 0.
  // assign uo_out  = ui_in + uio_in;  // Example: ou_out is the sum of ui_in and uio_in
  // assign uio_out = 0;
  // assign uio_oe  = 0;

  // // List all unused inputs to prevent warnings
  // wire _unused = &{ena, clk, rst_n, 1'b0};

