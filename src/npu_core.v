/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0

 folded MAC with a Shift-and-Add Multiplier
 */
module npu_core (
    input wire clk,
    input wire reset,      // System reset (active high)
    input wire clear,      // User-triggered reset
    input wire [7:0] input_data,   // data from pin
    input wire [7:0] weight_data,  // weight from SPI
    input wire enable,     // Start MAC operation pulse
    output wire [15:0] out
);
    reg [15:0] acc;
    reg [15:0] shift_in;
    reg [7:0] shift_weight;
    reg [3:0] bit_count;
    reg computing;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            acc <= 0;
            shift_in <= 0;
            shift_weight <= 0;
            bit_count <= 0;
            computing <= 0;
        end else begin
            if (clear) begin
                acc <= 0;
                computing <= 0;
            end else if (enable && !computing) begin
                // Start a new signed MAC operation
                shift_in <= {{8{input_data[7]}}, input_data};
                shift_weight <= weight_data;
                bit_count <= 0;
                computing <= 1;
            end else if (computing) begin
                if (bit_count == 7) begin
                    // 8th bit (sign bit of weight): subtract if 1
                    if (shift_weight[0]) begin
                        acc <= acc - shift_in;
                    end
                    computing <= 0;
                end else begin
                    // First 7 bits: add if 1
                    if (shift_weight[0]) begin
                        acc <= acc + shift_in;
                    end
                    shift_in <= shift_in << 1;
                    shift_weight <= shift_weight >> 1;
                    bit_count <= bit_count + 1;
                end
            end
        end
    end
    
    // Output ReLU: if MSB is 1 (negative), output 0
    assign out = acc[15] ? 16'h0000 : acc;
endmodule