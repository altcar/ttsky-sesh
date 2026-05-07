module cordic_core (
    input  wire clk,
    input  wire rst_n,
    input  wire [1:0] mode,      // uio_in[7:6]
    input  wire [7:0] theta_in,  // From ui_in
    output reg [15:0] x_out,     // COS / COSH
    output reg [15:0] y_out,     // SIN / SINH
    output reg [15:0] z_out,     // ATAN / ATANH
    output reg done
);
    // Reduced to 12-bit: [S][I][FFFFFFFFFF] (1 bit sign, 1 bit int, 10 bit frac)
    // Range is approx -2 to +1.999
    reg signed [11:0] x, y, z;
    reg [3:0] step; // 0 to 9 fits in 4 bits
    reg repeat_step;
    
    wire is_hyperbolic = (mode == 2'b10);
    wire is_vectoring  = (mode == 2'b11);

    wire signed [11:0] current_lut_val;
    atan_lut my_lut(
        .step(step),
        .is_hyperbolic(is_hyperbolic),
        .lut_value(current_lut_val)
    );

    reg [1:0] state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            step <= 0;
            state <= 0;
            done <= 0;
            repeat_step <= 0;
            x_out <= 0; y_out <= 0; z_out <= 0;
        end else begin
            if (mode == 2'b00) begin
                state <= 0;
                done <= 0;
            end else begin
                case (state)
                    0: begin // Initialization
                        // z scaling (127 -> approx 1.0 rad = 1024 in Q2.10)
                        // Shift by 3
                        z <= theta_in[7] ? {4'b1111, theta_in} << 3 : {4'b0000, theta_in} << 3; 
                        repeat_step <= 0;
                        if (is_hyperbolic) begin
                            x <= 12'h4D4; // 1/K' ~ 1.2074 * 1024 = 1236
                            y <= 0;
                            step <= 1; 
                        end else if (is_vectoring) begin
                            x <= 12'h400; // 1.0 * 1024
                            y <= theta_in[7] ? {4'b1111, theta_in} << 3 : {4'b0000, theta_in} << 3;
                            z <= 0;
                            step <= 0; 
                        end else begin // Circular
                            x <= 12'h26E; // 1/K ~ 0.6072 * 1024 = 622
                            y <= 0;
                            step <= 0; 
                        end
                        state <= 1;
                        done <= 0;
                    end
                    
                    1: begin // Iteration steps
                        if (is_hyperbolic) begin
                            if (z >= 0) begin
                                x <= x + (y >>> step);
                                y <= y + (x >>> step);
                                z <= z - current_lut_val;
                            end else begin
                                x <= x - (y >>> step);
                                y <= y - (x >>> step);
                                z <= z + current_lut_val;
                            end
                            
                            if (step == 4 && !repeat_step) begin
                                repeat_step <= 1;
                            end else begin
                                repeat_step <= 0;
                                if (step == 9) state <= 2;
                                else step <= step + 1;
                            end
                        end else begin
                            if (is_vectoring ? (y < 0) : (z >= 0)) begin
                                x <= x - (y >>> step);
                                y <= y + (x >>> step);
                                z <= z - current_lut_val;
                            end else begin
                                x <= x + (y >>> step);
                                y <= y - (x >>> step);
                                z <= z + current_lut_val;
                            end
                            if (step == 9) state <= 2;
                            else step <= step + 1;
                        end
                    end

                    2: begin // Output Ready
                        // Sign extend to 16-bit
                        x_out <= { {4{x[11]}}, x };
                        y_out <= { {4{y[11]}}, y };
                        z_out <= { {4{z[11]}}, z };
                        done <= 1;
                        state <= 0;
                    end
                    default: state <= 0;
                endcase
            end
        end
    end
endmodule