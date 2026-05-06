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
module control_fsm (
    input  wire clk,
    input  wire rst_n,
    input  wire spi_ready,    // From spi_controller
    input  wire [7:0] ui_in,  // Control bits (ui_in[7] = end of layer)
    output reg mac_en,
    output reg acc_clr,
    output reg done_pulse
);
    typedef enum reg [1:0] {IDLE, FETCH, COMPUTE, DONE} state_t;
    state_t state, next_state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else state <= next_state;
    end

    always @(*) begin
        next_state = state;
        mac_en = 0;
        acc_clr = 0;
        done_pulse = 0;

        case (state)
            IDLE: begin
                if (spi_ready) begin
                    next_state = COMPUTE;
                    acc_clr = 0;
                end else begin
                    acc_clr = 1;
                end
            end
            COMPUTE: begin
                mac_en = 1;
                if (ui_in[7]) next_state = DONE; // User signals end of vector
                else if (spi_ready) next_state = COMPUTE;
            end
            DONE: begin
                done_pulse = 1;
                next_state = IDLE;
            end
        endcase
    end
endmodule