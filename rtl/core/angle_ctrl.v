`timescale 1ns / 1ps

module angle_ctrl(
    input wire i_clk,
    input wire i_rst,               // 동기식 리셋 (SW15)
    input wire i_tick_en,           // tick_gen에서 오는 느린 jog 속도 펄스
    input wire i_btn_up,            // BTNU (각도 증가, level 유지)
    input wire i_btn_down,          // BTND (각도 감소, level 유지)
    input wire [1:0] i_joint_sel,   // 선택된 관절 (0:base, 1:shoulder, 2:elbow)
    input wire i_play_mode,         // PLAY 모드 상태 플래그 (mode_fsm에서 입력)
    input wire [24:0] i_play_pose_data, // PLAY 모드 시 레지스터 뱅크에서 읽어올 목표 자세
    
    output wire [7:0] o_target_base,
    output wire [7:0] o_target_shoulder,
    output wire [7:0] o_target_elbow
);

    // 1. 레지스터 선언 및 초기값(INIT) 할당 (기획서 7-7-2 필수 조건)
    // 보드가 켜지는 찰나의 순간에도 0도로 튀는 것을 막기 위해 선언과 동시에 8'd90(중립) 초기화
    reg [7:0] r_target_base     = 8'd90;
    reg [7:0] r_target_shoulder = 8'd90;
    reg [7:0] r_target_elbow    = 8'd90;

    // 2. 동기식 목표 각도 제어 (순수 순차회로)
    always @(posedge i_clk) begin
        if (i_rst) begin
            // 하드 리셋 시에도 무조건 90도 중립 자세로 복귀
            r_target_base     <= 8'd90;
            r_target_shoulder <= 8'd90;
            r_target_elbow    <= 8'd90;
            
        end else if (i_play_mode) begin
            // [PLAY 모드] 메모리에서 불러온 자세를 목표 각도로 즉시 업데이트
            r_target_base     <= i_play_pose_data[7:0];
            r_target_shoulder <= i_play_pose_data[15:8];
            r_target_elbow    <= i_play_pose_data[23:16];
            
        end else if (i_tick_en) begin
            // [MANUAL/RECORD 모드] 조작 틱(Tick)마다 1도씩 증감
            if (i_btn_up) begin
                case (i_joint_sel)
                    2'd0: if (r_target_base < 8'd180)     r_target_base     <= r_target_base + 1;
                    2'd1: if (r_target_shoulder < 8'd180) r_target_shoulder <= r_target_shoulder + 1;
                    2'd2: if (r_target_elbow < 8'd180)    r_target_elbow    <= r_target_elbow + 1;
                endcase
            end else if (i_btn_down) begin
                case (i_joint_sel)
                    2'd0: if (r_target_base > 8'd0)       r_target_base     <= r_target_base - 1;
                    2'd1: if (r_target_shoulder > 8'd0)   r_target_shoulder <= r_target_shoulder - 1;
                    2'd2: if (r_target_elbow > 8'd0)      r_target_elbow    <= r_target_elbow - 1;
                endcase
            end
        end
    end

    // 3. 출력 연결
    assign o_target_base     = r_target_base;
    assign o_target_shoulder = r_target_shoulder;
    assign o_target_elbow    = r_target_elbow;

endmodule