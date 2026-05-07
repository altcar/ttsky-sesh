module control_fsm (
    input  wire clk,
    input  wire rst_n,
    input  wire spi_ready,    // From spi_controller
    input  wire clear_in,     // Manual clear input (from uio_in[3])
    output reg mac_en,
    output reg acc_clr,
    output reg done_pulse
);
    typedef enum reg [2:0] {IDLE, START, BUSY, WAIT_SPI, DONE} state_t;
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
                if (clear_in) acc_clr = 1; // Manual clear
                if (spi_ready) next_state = START;
                // Wait, if ui_in[7] was used for 'DONE', we lost it!
                // Let's just do a 36-element count? Or let the user clear manually between layers.
                // Actually, the FSM doesn't strictly need a DONE state if we clear manually.
                // But let's keep it simple.
            end
            START: begin
                mac_en = 1; // Pulse for 1 cycle
                next_state = BUSY;
            end
            BUSY: begin
                if (!spi_ready) next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end
endmodule