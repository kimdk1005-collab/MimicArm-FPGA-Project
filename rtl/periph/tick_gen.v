`timescale 1ns / 1ps

module tick_gen #(
    parameter PARAM_JOG_MAX    = 21'd1_999_999,   // 50Hz  = 20ms @ 100MHz
    parameter PARAM_INTERP_MAX = 20'd999_999,     // 100Hz = 10ms @ 100MHz
    parameter PARAM_DWELL_MAX  = 27'd99_999_999   // 1Hz   = 1s @ 100MHz
)(
    input  wire i_clk,
    input  wire i_rst,
    output reg  o_jog_tick,
    output reg  o_interp_tick,
    output reg  o_dwell_tick
);
    reg [20:0] r_cnt_jog;
    reg [19:0] r_cnt_interp;
    reg [26:0] r_cnt_dwell;

    always @(posedge i_clk) begin
        if (i_rst) begin
            r_cnt_jog  <= 21'd0;
            o_jog_tick <= 1'b0;
        end else if (r_cnt_jog == PARAM_JOG_MAX) begin
            r_cnt_jog  <= 21'd0;
            o_jog_tick <= 1'b1;
        end else begin
            r_cnt_jog  <= r_cnt_jog + 1'b1;
            o_jog_tick <= 1'b0;
        end
    end

    always @(posedge i_clk) begin
        if (i_rst) begin
            r_cnt_interp  <= 20'd0;
            o_interp_tick <= 1'b0;
        end else if (r_cnt_interp == PARAM_INTERP_MAX) begin
            r_cnt_interp  <= 20'd0;
            o_interp_tick <= 1'b1;
        end else begin
            r_cnt_interp  <= r_cnt_interp + 1'b1;
            o_interp_tick <= 1'b0;
        end
    end

    always @(posedge i_clk) begin
        if (i_rst) begin
            r_cnt_dwell  <= 27'd0;
            o_dwell_tick <= 1'b0;
        end else if (r_cnt_dwell == PARAM_DWELL_MAX) begin
            r_cnt_dwell  <= 27'd0;
            o_dwell_tick <= 1'b1;
        end else begin
            r_cnt_dwell  <= r_cnt_dwell + 1'b1;
            o_dwell_tick <= 1'b0;
        end
    end
endmodule