/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0

 folded MAC with a Shift-and-Add Multiplier
 */
module npu_core (
    input wire clk,
    input wire reset,
    input wire clear,      // User-triggered reset
    input wire [7:0] input_data,   //data from pin
    input wire [7:0] weight_data,  //weight from SPI
    input wire enable,
    output wire [15:0] out
);
    // ReLU Activation logic
    reg [15:0] acc;
    wire [15:0] mult = input_data * weight_data;

    always @(posedge clk or negedge reset) begin
        if (!reset || clear) acc <= 0;
        else if (enable) begin
            // ReLU check integrated: only add if result is positive 
            // (Standard ReLU is applied at the end, but we keep it simple here)
            acc <= acc + mult;
        end
    end
    
    // Output ReLU: if MSB is 1 (negative), output 0
    assign out = acc[15] ? 16'h0000 : acc;
endmodule