`timescale 1ns / 1ps

module mode_fsm(
    input wire i_clk,
    input wire i_rst,                 // 동기식 하드 리셋 (SW15 소스)
    input wire [1:0] i_sw_mode,       // 스위치 기반 모드 (SW1, SW0 직접 매핑)
    input wire i_btn_save,            // BTNC (외부 edge_detector를 거친 1클럭 펄스)
    input wire i_target_reached,      // B파트 보간 모듈 피드백 계약 신호 (1클럭 펄스)
    
    output wire [1:0] o_mode,         // 현재 시스템 확정 모드 (LED 표시용)
    output wire o_play_mode,          // angle_ctrl 상태 오버라이드용 플래그
    output wire o_we,                 // reg_bank 쓰기 활성화 신호 (조합 논리)
    output wire [2:0] o_addr,         // reg_bank 읽기/쓰기 주소 버스 (조합 논리)
    output wire [3:0] o_pose_count    // ★추가: 저장된 자세 개수 (seg_display 7세그 표시용)
);

    // 기획서 및 표준 규격에 따른 PARAM 대문자 정의
    localparam PARAM_MODE_MANUAL = 2'b00;
    localparam PARAM_MODE_RECORD = 2'b01;
    localparam PARAM_MODE_PLAY   = 2'b10;

    reg [1:0] r_mode       = PARAM_MODE_MANUAL;
    reg [3:0] r_pose_count = 4'd0;  // 저장된 자세 개수 (최대 8개)
    reg [2:0] r_play_seq   = 3'd0;  // 재생 중인 현재 시퀀스 포인터
    reg [1:0] r_sw_mode_d  = PARAM_MODE_MANUAL;

    // 모드 진입 시점의 엣지 검출을 위한 동기화 레지스터
    always @(posedge i_clk) begin
        if (i_rst) begin
            r_sw_mode_d <= PARAM_MODE_MANUAL;
        end else begin
            r_sw_mode_d <= i_sw_mode;
        end
    end

    // 모드 전환 순간에 포인터를 초기화하기 위한 내부 제어 와이어
    wire w_enter_record = (i_sw_mode == PARAM_MODE_RECORD) && (r_sw_mode_d != PARAM_MODE_RECORD);
    wire w_enter_play   = (i_sw_mode == PARAM_MODE_PLAY)   && (r_sw_mode_d != PARAM_MODE_PLAY);

    // 순수 동기식 상태 제어 및 카운터 레지스터 갱신 블록
    always @(posedge i_clk) begin
        if (i_rst) begin
            r_mode       <= PARAM_MODE_MANUAL;
            r_pose_count <= 4'd0;
            r_play_seq   <= 3'd0;
        end else begin
            case (i_sw_mode)
                PARAM_MODE_MANUAL: begin
                    r_mode <= PARAM_MODE_MANUAL;
                end

                PARAM_MODE_RECORD: begin
                    r_mode <= PARAM_MODE_RECORD;
                    if (w_enter_record) begin
                        r_pose_count <= 4'd0; // RECORD 진입 시 기존 카운터 및 포인터 클리어
                    end else if (i_btn_save && (r_pose_count < 4'd8)) begin
                        r_pose_count <= r_pose_count + 1; // always 블록 내부에서는 증가만 수행
                    end
                end

                PARAM_MODE_PLAY: begin
                    // [치명 1 해결] PLAY 가드 로직: 저장된 자세가 없으면 진입을 차단하고 MANUAL 유지
                    if (r_pose_count == 4'd0) begin
                        r_mode <= PARAM_MODE_MANUAL;
                    end else begin
                        r_mode <= PARAM_MODE_PLAY;
                        if (w_enter_play) begin
                            r_play_seq <= 3'd0; // 재생 시작 시 무조건 0번 주소부터 시작
                        end else if (i_target_reached) begin
                            // [치명 3 검증 완료] 1틱 펄스를 받아 마지막 자세 도달 시 롤오버 처리
                            if (r_play_seq == (r_pose_count - 1)) begin
                                r_play_seq <= 3'd0;
                            end else begin
                                r_play_seq <= r_play_seq + 1;
                            end
                        end
                    end
                end

                default: r_mode <= PARAM_MODE_MANUAL;
            endcase
        end
    end

    // [치명 2 해결] 데이터 유실 방지를 위한 출력단 조합 논리 버스 타이밍 정렬
    assign o_mode      = r_mode;
    assign o_play_mode = (r_mode == PARAM_MODE_PLAY);
    
    // 쓰기 시점에는 카운터가 증가하기 전 주소를 그대로 유지하여 슬롯 0부터 유실 없이 정확히 기록됨
    assign o_addr      = (r_mode == PARAM_MODE_PLAY) ? r_play_seq : r_pose_count[2:0];
    assign o_we        = (r_mode == PARAM_MODE_RECORD) && i_btn_save && (r_pose_count < 4'd8);
    
    // 저장된 자세 개수를 외부로 노출 (seg_display.i_pose_count 연결용)
    assign o_pose_count = r_pose_count;

endmodule