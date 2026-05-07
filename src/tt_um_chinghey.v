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
        .clear_in(uio_in[3]), // Use uio_in[3] for clear
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

    wire [15:0] cordic_x, cordic_y, cordic_z;
    wire cordic_done;

    cordic_core my_cordic (
        .clk(clk),
        .rst_n(rst_n),
        .mode(uio_in[7:6]),
        .theta_in(ui_in),
        .x_out(cordic_x),
        .y_out(cordic_y),
        .z_out(cordic_z),
        .done(cordic_done)
    );

    wire [15:0] final_result;
    assign final_result = (uio_in[7:6] == 2'b00) ? nlp_result :
                          (uio_in[7:6] == 2'b11) ? cordic_z : // Output Z in Vectoring mode
                          (uio_in[3] == 1'b0) ? cordic_x : cordic_y; 

    // 3. Output logic (Muxing the 16-bit result to 8-bit pins)
    // uio_in[4] is byte_sel: 0=LowByte, 1=HighByte
    assign uo_out = uio_in[4] ? final_result[15:8] : final_result[7:0];

    // Configure Bidirectional pins: 0,1,2,3,4,6,7 are inputs, 5 is output
    assign uio_oe  = 8'b00100000; 
    assign uio_out = {1'b0, 1'b0, cordic_done | done_pulse, 5'b0};

    // List all unused inputs to prevent warnings
    wire _unused = &{ena, uio_in[5], 1'b0};

endmodule

