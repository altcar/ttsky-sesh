/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */
module npu_core (
    input wire clk,
    input wire reset,
    input wire [7:0] input_data,
    input wire [7:0] weight_data,
    input wire enable,
    output reg [15:0] accumulator
);
    // ReLU Activation logic
    wire [15:0] next_acc = accumulator + (input_data * weight_data);

    always @(posedge clk) begin
        if (reset) begin
            accumulator <= 16'b0;
        end else if (enable) begin
            // ReLU check: if the MSB is 1 (negative), stay at 0
            accumulator <= next_acc[15] ? 16'b0 : next_acc;
        end
    end
endmodule