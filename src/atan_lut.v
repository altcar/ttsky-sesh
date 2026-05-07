module atan_lut (
    input  wire [3:0] step,
    input  wire is_hyperbolic,
    output reg  [11:0] lut_value
);
    always @(*) begin
        if (is_hyperbolic) begin
            case (step)
                4'd1: lut_value = 12'h232;
                4'd2: lut_value = 12'h106;
                4'd3: lut_value = 12'h081;
                4'd4: lut_value = 12'h040;
                4'd5: lut_value = 12'h020;
                4'd6: lut_value = 12'h010;
                4'd7: lut_value = 12'h008;
                4'd8: lut_value = 12'h004;
                4'd9: lut_value = 12'h002;
                4'd10: lut_value = 12'h001;
                default: lut_value = 12'h000;
            endcase
        end else begin
            case (step)
                4'd0: lut_value = 12'h324;
                4'd1: lut_value = 12'h1DB;
                4'd2: lut_value = 12'h0FB;
                4'd3: lut_value = 12'h07F;
                4'd4: lut_value = 12'h040;
                4'd5: lut_value = 12'h020;
                4'd6: lut_value = 12'h010;
                4'd7: lut_value = 12'h008;
                4'd8: lut_value = 12'h004;
                4'd9: lut_value = 12'h002;
                default: lut_value = 12'h000;
            endcase
        end
    end
endmodule
