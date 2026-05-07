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
    // Reduced to 14-bit: [S][I][FFFFFFFFFFFF] (1 bit sign, 1 bit int, 12 bit frac)
    // Range is approx -2 to +1.999
    reg signed [13:0] x, y, z;
    reg [3:0] step; // 0 to 12 fits in 4 bits
    reg repeat_step;
    
    wire is_hyperbolic = (mode == 2'b10);
    wire is_vectoring  = (mode == 2'b11);

    wire [15:0] current_lut_val_16;
    atan_lut my_lut(
        .step({1'b0, step}),
        .is_hyperbolic(is_hyperbolic),
        .lut_value(current_lut_val_16)
    );
    wire signed [13:0] current_lut_val = current_lut_val_16[13:0];

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
                        // z scaling remains same (127 -> 1.0 rad = 4096 in Q.12)
                        z <= theta_in[7] ? {6'b111111, theta_in} << 5 : {6'b000000, theta_in} << 5; 
                        repeat_step <= 0;
                        if (is_hyperbolic) begin
                            x <= 14'h1351; // 1/K' ~ 1.2074
                            y <= 0;
                            step <= 1; 
                        end else if (is_vectoring) begin
                            x <= 14'h1000; // 1.0
                            y <= theta_in[7] ? {6'b111111, theta_in} << 5 : {6'b000000, theta_in} << 5;
                            z <= 0;
                            step <= 0; 
                        end else begin // Circular
                            x <= 14'h09B7; // 1/K ~ 0.6072
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
                        x_out <= { {2{x[13]}}, x }; // Sign extend to 16-bit
                        y_out <= { {2{y[13]}}, y };
                        z_out <= { {2{z[13]}}, z };
                        done <= 1;
                        state <= 0;
                    end
                    default: state <= 0;
                endcase
            end
        end
    end
endmodule