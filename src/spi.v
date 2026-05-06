/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
  Fetch the weights through SPI
 */
module spi_receiver (
    input wire clk,          // System clock
    input wire sclk,         // SPI clock from external source
    input wire mosi,         // Data bit
    input wire cs,           // Active low
    output reg [7:0] weight, // The full byte
    output reg done          // Signal to NPU that weight is ready
);
    reg [2:0] bit_cnt;
    reg [7:0] shift_reg;

    always @(posedge sclk or posedge cs) begin
        if (cs) begin
            bit_cnt <= 0;
            done <= 0;
        end else begin
            shift_reg <= {shift_reg[6:0], mosi};
            bit_cnt <= bit_cnt + 1;
            if (bit_cnt == 7) begin
                weight <= {shift_reg[6:0], mosi};
                done <= 1;
            end else begin
                done <= 0;
            end
        end
    end
endmodule