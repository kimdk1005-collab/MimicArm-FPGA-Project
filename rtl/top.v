`timescale 1ns / 1ps
// =============================================================
// 모듈명 : top  (수정판 — dwell 로직만 교체)
// 변경점 : 자유진행 dwell_tick 의존 제거 → '이벤트 정렬' dwell 카운터
//          도달이 연속 유지될 때만 카운트, 풀리면 즉시 0.
//          → 팔이 실제 도달하기 전에는 절대 다음 자세로 넘어가지 않음.
// =============================================================

module top #(
    parameter PARAM_DWELL_CNT     = 27'd99_999_999, // 1초 머무름 @100MHz (도달 후 유지시간)
    parameter PARAM_GRIPPER_OPEN  = 8'd10,   // 0에서 조금씩 ↑ - 버즈가 멈추는 값이 진짜 '열림'
    parameter PARAM_GRIPPER_CLOSE = 8'd160    // 90 근처부터 ↑ - 실제로 물리는 각 (180 아닐 가능성 큼)
)(
    input  wire        i_clk,
    input  wire        i_rst,
    input  wire  [1:0] i_sw_mode,
    input  wire        i_sw_gripper,

    input  wire        i_btn_c,
    input  wire        i_btn_u,
    input  wire        i_btn_d,
    input  wire        i_btn_l,
    input  wire        i_btn_r,

    output wire        o_pwm_base,
    output wire        o_pwm_shoulder,
    output wire        o_pwm_elbow,
    output wire        o_pwm_gripper,

    output wire [3:0]  o_an,
    output wire [6:0]  o_seg,
    output wire [15:0] o_led
);

    wire w_jog_tick, w_interp_tick, w_dwell_tick; // w_dwell_tick 는 의도적으로 미사용
    wire w_btn_c_level, w_btn_c_edge;
    wire w_btn_u_level, w_btn_u_edge;
    wire w_btn_d_level, w_btn_d_edge;
    wire w_btn_l_level, w_btn_l_edge;
    wire w_btn_r_level, w_btn_r_edge;
    wire [1:0]  w_joint_sel;
    wire [1:0]  w_mode;
    wire        w_play_mode;
    wire        w_we;
    wire [2:0]  w_addr;
    wire [3:0]  w_pose_count;
    wire [24:0] w_pose_to_bank;
    wire [24:0] w_pose_from_bank;
    wire [7:0]  w_target_base, w_target_shoulder, w_target_elbow;
    wire [7:0]  w_cur_base, w_cur_shoulder, w_cur_elbow;

    // tick_gen: jog/interp 만 사용. dwell_tick 은 본 설계에서 미사용(이벤트 정렬 카운터로 대체)
    tick_gen u_tick_gen (
        .i_clk(i_clk), .i_rst(i_rst),
        .o_jog_tick(w_jog_tick), .o_interp_tick(w_interp_tick), .o_dwell_tick(w_dwell_tick)
    );

    debounce u_deb_c (.i_clk(i_clk), .i_rst(i_rst), .i_btn_raw(i_btn_c), .o_btn_level(w_btn_c_level), .o_btn_edge(w_btn_c_edge));
    debounce u_deb_u (.i_clk(i_clk), .i_rst(i_rst), .i_btn_raw(i_btn_u), .o_btn_level(w_btn_u_level), .o_btn_edge(w_btn_u_edge));
    debounce u_deb_d (.i_clk(i_clk), .i_rst(i_rst), .i_btn_raw(i_btn_d), .o_btn_level(w_btn_d_level), .o_btn_edge(w_btn_d_edge));
    debounce u_deb_l (.i_clk(i_clk), .i_rst(i_rst), .i_btn_raw(i_btn_l), .o_btn_level(w_btn_l_level), .o_btn_edge(w_btn_l_edge));
    debounce u_deb_r (.i_clk(i_clk), .i_rst(i_rst), .i_btn_raw(i_btn_r), .o_btn_level(w_btn_r_level), .o_btn_edge(w_btn_r_edge));

    joint_select u_joint_select (
        .i_clk(i_clk), .i_rst(i_rst),
        .i_btn_left_edge(w_btn_l_edge), .i_btn_right_edge(w_btn_r_edge),
        .o_sel_joint(w_joint_sel)
    );

    // --------------------------------------------------
    // 도달 검출 + 이벤트 정렬 Dwell 카운터  (★수정 핵심)
    // --------------------------------------------------
    wire w_all_reached_comb = (w_target_base == w_cur_base) &&
                              (w_target_shoulder == w_cur_shoulder) &&
                              (w_target_elbow == w_cur_elbow);
    reg r_all_reached;
    reg [26:0] r_dwell_cnt;
    reg r_target_reached_pulse;

    always @(posedge i_clk) begin
        if (i_rst) begin
            r_all_reached          <= 1'b0;
            r_dwell_cnt            <= 27'd0;
            r_target_reached_pulse <= 1'b0;
        end else begin
            r_all_reached          <= w_all_reached_comb; // 7-6: 조합비교 1클럭 동기화
            r_target_reached_pulse <= 1'b0;               // 기본값: 펄스 1클럭

            if (w_play_mode && r_all_reached) begin
                // 도달이 '연속 유지'되는 동안에만 카운트
                if (r_dwell_cnt >= PARAM_DWELL_CNT) begin
                    r_target_reached_pulse <= 1'b1;  // dwell 완료 → 다음 자세 1펄스
                    r_dwell_cnt            <= 27'd0;  // 펄스 후 리셋(중복펄스 방지)
                end else begin
                    r_dwell_cnt <= r_dwell_cnt + 1'b1;
                end
            end else begin
                // 도달 풀림(목표 이동 중) 또는 PLAY 아님 → 즉시 0
                r_dwell_cnt <= 27'd0;
            end
        end
    end

    mode_fsm u_mode_fsm (
        .i_clk(i_clk), .i_rst(i_rst), .i_sw_mode(i_sw_mode),
        .i_btn_save(w_btn_c_edge), .i_target_reached(r_target_reached_pulse),
        .o_mode(w_mode), .o_play_mode(w_play_mode),
        .o_we(w_we), .o_addr(w_addr), .o_pose_count(w_pose_count)
    );

    assign w_pose_to_bank = {i_sw_gripper, w_target_elbow, w_target_shoulder, w_target_base};

    reg_bank u_reg_bank (
        .i_clk(i_clk), .i_rst(i_rst),
        .i_we(w_we), .i_addr(w_addr),
        .i_pose_data(w_pose_to_bank), .o_pose_data(w_pose_from_bank)
    );

    angle_ctrl u_angle_ctrl (
        .i_clk(i_clk), .i_rst(i_rst),
        .i_tick_en(w_jog_tick), .i_btn_up(w_btn_u_level), .i_btn_down(w_btn_d_level),
        .i_joint_sel(w_joint_sel), .i_play_mode(w_play_mode), .i_play_pose_data(w_pose_from_bank),
        .o_target_base(w_target_base), .o_target_shoulder(w_target_shoulder), .o_target_elbow(w_target_elbow)
    );

    interp u_interp_base (.i_clk(i_clk), .i_rst(i_rst), .i_interp_tick(w_interp_tick), .i_target_angle(w_target_base),     .o_cur_angle(w_cur_base));
    interp u_interp_sh   (.i_clk(i_clk), .i_rst(i_rst), .i_interp_tick(w_interp_tick), .i_target_angle(w_target_shoulder), .o_cur_angle(w_cur_shoulder));
    interp u_interp_el   (.i_clk(i_clk), .i_rst(i_rst), .i_interp_tick(w_interp_tick), .i_target_angle(w_target_elbow),    .o_cur_angle(w_cur_elbow));

    pwm_servo u_pwm_base (.i_clk(i_clk), .i_rst(i_rst), .i_angle(w_cur_base),     .o_pwm_out(o_pwm_base));
    pwm_servo u_pwm_sh   (.i_clk(i_clk), .i_rst(i_rst), .i_angle(w_cur_shoulder), .o_pwm_out(o_pwm_shoulder));
    pwm_servo u_pwm_el   (.i_clk(i_clk), .i_rst(i_rst), .i_angle(w_cur_elbow),    .o_pwm_out(o_pwm_elbow));

    wire       w_gripper_target_bit = w_play_mode ? w_pose_from_bank[24] : i_sw_gripper;
    wire [7:0] w_gripper_angle      = w_gripper_target_bit ? PARAM_GRIPPER_CLOSE : PARAM_GRIPPER_OPEN;
    pwm_servo u_pwm_grip (.i_clk(i_clk), .i_rst(i_rst), .i_angle(w_gripper_angle), .o_pwm_out(o_pwm_gripper));

    seg_display u_seg_display (
        .i_clk(i_clk), .i_rst(i_rst),
        .i_mode(w_mode), .i_pose_count(w_pose_count), .i_joint_idx(w_joint_sel),
        .o_an(o_an), .o_seg(o_seg)
    );

    assign o_led[15:14] = w_mode;
    assign o_led[13:3]  = 11'b0;
    assign o_led[2:0]   = (w_joint_sel == 2'd0) ? 3'b001 :
                          (w_joint_sel == 2'd1) ? 3'b010 :
                          (w_joint_sel == 2'd2) ? 3'b100 : 3'b000;
endmodule