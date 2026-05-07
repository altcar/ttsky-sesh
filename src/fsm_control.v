module control_fsm (
    input  wire clk,
    input  wire rst_n,
    input  wire spi_ready,    // From spi_controller
    input  wire [7:0] ui_in,  // Control bits
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
                if (ui_in[6]) acc_clr = 1; // Manual clear
                if (spi_ready) next_state = START;
                else if (ui_in[7]) next_state = DONE;
            end
            START: begin
                mac_en = 1; // Pulse for 1 cycle
                next_state = BUSY;
            end
            BUSY: begin
                // Wait for bit_count to finish (8 cycles + 1)
                // For simplicity, we can just wait for spi_ready to go low
                if (!spi_ready) next_state = IDLE;
            end
            DONE: begin
                done_pulse = 1;
                if (!ui_in[7]) next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    wire _unused = &{ui_in[5:0], 1'b0};
endmodule