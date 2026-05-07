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
    reg signed [15:0] x, y, z;
    reg [4:0] step;
    reg repeat_step;
    
    wire is_hyperbolic = (mode == 2'b10);
    wire is_vectoring  = (mode == 2'b11);

    wire [15:0] current_lut_val;
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
                        // Treat theta_in as signed, scale 127 -> 1.0 rad (approx 4096 in Q4.12)
                        // So we shift by 5.
                        z <= {{8{theta_in[7]}}, theta_in} << 5; 
                        repeat_step <= 0;
                        if (is_hyperbolic) begin
                            x <= 16'h1351; // 1/K' ~ 1.2074
                            y <= 0;
                            step <= 1; 
                        end else if (is_vectoring) begin
                            x <= 16'h1000;
                            y <= {{8{theta_in[7]}}, theta_in} << 5;
                            z <= 0;
                            step <= 0; 
                        end else begin // Circular
                            x <= 16'h09B7; // 1/K ~ 0.6072
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
                            
                            // Repeat step 4 once
                            if (step == 4 && !repeat_step) begin
                                repeat_step <= 1;
                            end else begin
                                repeat_step <= 0;
                                if (step == 12) state <= 2;
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
                            if (step == 12) state <= 2;
                            else step <= step + 1;
                        end
                    end

                    2: begin // Output Ready
                        x_out <= x;
                        y_out <= y;
                        z_out <= z;
                        done <= 1;
                        state <= 0;
                    end
                    default: state <= 0;
                endcase
            end
        end
    end
endmodule