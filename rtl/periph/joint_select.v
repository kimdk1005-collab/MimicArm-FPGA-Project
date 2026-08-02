`timescale 1ns / 1ps

module joint_select (
    input  wire       i_clk,
    input  wire       i_rst,
    input  wire       i_btn_left_edge,
    input  wire       i_btn_right_edge,
    output reg  [1:0] o_sel_joint = 2'd0 // 0: Base, 1: Shoulder, 2: Elbow
);
    always @(posedge i_clk) begin
        if (i_rst) begin
            o_sel_joint <= 2'd0;
        end else if (i_btn_left_edge) begin
            if (o_sel_joint == 2'd0)
                o_sel_joint <= 2'd2;
            else
                o_sel_joint <= o_sel_joint - 1'b1;
        end else if (i_btn_right_edge) begin
            if (o_sel_joint == 2'd2)
                o_sel_joint <= 2'd0;
            else
                o_sel_joint <= o_sel_joint + 1'b1;
        end
    end
endmodule