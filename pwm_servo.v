`timescale 1ns / 1ps

module pwm_servo #(
    parameter PARAM_PERIOD_CNT = 21'd2_000_000, // 20ms @ 100MHz
    parameter PARAM_MIN_DUTY   = 21'd100_000,   // 1.0ms: 0 degree, manual standard
    parameter PARAM_STEP       = 21'd556,       // (2.0ms - 1.0ms) / 180
    parameter PARAM_MAX_ANGLE  = 8'd180
)(
    input  wire       i_clk,
    input  wire       i_rst,
    input  wire [7:0] i_angle,
    output reg        o_pwm_out
);
    reg [20:0] r_cnt_period;

    wire [7:0]  w_angle_clamped;
    wire [28:0] w_duty_calc;
    wire [20:0] w_duty_target;

    assign w_angle_clamped = (i_angle > PARAM_MAX_ANGLE) ? PARAM_MAX_ANGLE : i_angle;
    assign w_duty_calc     = PARAM_MIN_DUTY + ({21'd0, w_angle_clamped} * PARAM_STEP);
    assign w_duty_target   = w_duty_calc[20:0];

    always @(posedge i_clk) begin
        if (i_rst) begin
            r_cnt_period <= 21'd0;
        end else if (r_cnt_period >= PARAM_PERIOD_CNT - 1'b1) begin
            r_cnt_period <= 21'd0;
        end else begin
            r_cnt_period <= r_cnt_period + 1'b1;
        end
    end

    always @(posedge i_clk) begin
        if (i_rst) begin
            o_pwm_out <= 1'b0;
        end else begin
            o_pwm_out <= (r_cnt_period < w_duty_target);
        end
    end
endmodule