module atan_lut(
    input  wire [4:0] step,
    input  wire is_hyperbolic,
    output reg [15:0] lut_value
);
    always @(*) begin
        if (is_hyperbolic) begin
            case (step)
                5'd1:  lut_value = 16'h08C9;
                5'd2:  lut_value = 16'h0416;
                5'd3:  lut_value = 16'h0202;
                5'd4:  lut_value = 16'h0100;
                5'd5:  lut_value = 16'h0080;
                5'd6:  lut_value = 16'h0040;
                5'd7:  lut_value = 16'h0020;
                5'd8:  lut_value = 16'h0010;
                5'd9:  lut_value = 16'h0008;
                5'd10: lut_value = 16'h0004;
                5'd11: lut_value = 16'h0002;
                5'd12: lut_value = 16'h0001;
                default: lut_value = 16'd0;
            endcase
        end else begin
            case (step)
                5'd0:  lut_value = 16'h0C90;
                5'd1:  lut_value = 16'h076B;
                5'd2:  lut_value = 16'h03EB;
                5'd3:  lut_value = 16'h01FD;
                5'd4:  lut_value = 16'h00FF;
                5'd5:  lut_value = 16'h007F;
                5'd6:  lut_value = 16'h003F;
                5'd7:  lut_value = 16'h001F;
                5'd8:  lut_value = 16'h000F;
                5'd9:  lut_value = 16'h0007;
                5'd10: lut_value = 16'h0003;
                5'd11: lut_value = 16'h0001;
                5'd12: lut_value = 16'h0000;
                default: lut_value = 16'd0;
            endcase
        end
    end
endmodule
