/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
  Fetch the weights through SPI
 */
module spi_receiver (
    input wire clk,          // System clock
    input wire rst_n,        // Reset, active low
    input wire sclk,         // SPI clock from external source
    input wire mosi,         // Data bit
    input wire cs,           // Chip Select Active low
    output reg [7:0] weight, // The full byte
    output reg done          // Signal to NPU that weight is ready 1= complete
);
    reg [2:0] bit_cnt;
    reg [7:0] shift_reg;
    reg ready_sync;

    always @(posedge sclk or negedge rst_n) begin
        if (rst_n) begin
            bit_cnt <= 0;
            shift_reg <= 0;
            ready_sync <= 0;
        end else if (!cs) begin
            shift_reg <= {shift_reg[6:0], mosi};
            bit_cnt <= bit_cnt + 1;
            if (bit_cnt == 7) begin
                shift_reg <= {shift_reg[6:0], mosi};
                ready_sync <= 1; //<=(bit_cnt == 3'd7)
            end else begin
                ready_sync <= 0;
            end
        end
    end

        // Pulse 'ready' in the main clock domain
    always @(posedge clk) begin
        weight <= shift_reg;
        done <= ready_sync;
    end
endmodule