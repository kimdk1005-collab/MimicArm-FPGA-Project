`timescale 1ns / 1ps

module interp #(
    parameter PARAM_INIT_ANGLE = 8'd90
)(
    input  wire       i_clk,
    input  wire       i_rst,
    input  wire       i_interp_tick,
    input  wire [7:0] i_target_angle,
    output reg  [7:0] o_cur_angle = 8'd90
);
    always @(posedge i_clk) begin
        if (i_rst) begin
            o_cur_angle <= PARAM_INIT_ANGLE;
        end else if (i_interp_tick) begin
            if (o_cur_angle < i_target_angle)
                o_cur_angle <= o_cur_angle + 1'b1;
            else if (o_cur_angle > i_target_angle)
                o_cur_angle <= o_cur_angle - 1'b1;
        end
    end
endmodule