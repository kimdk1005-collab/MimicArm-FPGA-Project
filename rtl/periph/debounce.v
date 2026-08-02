`timescale 1ns / 1ps
// =============================================================
// 모듈명 : debounce
// 역할   : 물리 버튼 입력(채터링 포함)을 안정화하여
//          ① 상태 유지 신호(o_btn_level)
//          ② 1클럭 상승엣지 펄스(o_btn_edge)
//          두 가지로 분리 출력한다.
// 담당   : C영역 (입력/표시)
// 참고   : RTL_프로젝트.md 7-5절 인터페이스 명세와 포트명 100% 일치
// =============================================================
module debounce (
    input  wire i_clk,        // 100MHz 시스템 클럭
    input  wire i_rst,        // Active-High, 동기식 리셋 (SW15)
    input  wire i_btn_raw,    // 물리 버튼 원신호 (채터링 포함, 비동기)
    output wire o_btn_level,  // 떨림 제거된 '상태 유지' 신호 (BTNU/BTND에서 사용)
    output wire o_btn_edge    // 0→1 상승엣지에서 1클럭만 켜지는 펄스 (BTNL/BTNR/BTNC에서 사용)
);

    // -----------------------------------------------------
    // 1단계: 메타스테이블 방지를 위한 2단 동기화(synchronizer)
    //        비동기 입력(i_btn_raw)을 클럭 도메인으로 안전하게 가져온다.
    // -----------------------------------------------------
    reg r_sync0, r_sync1;
    always @(posedge i_clk) begin
        if (i_rst) begin
            r_sync0 <= 1'b0;
            r_sync1 <= 1'b0;
        end else begin
            r_sync0 <= i_btn_raw;  // 1차 동기화
            r_sync1 <= r_sync0;    // 2차 동기화 (이 값을 이후 로직에서 사용)
        end
    end

    // -----------------------------------------------------
    // 2단계: 카운터 기반 디바운스
    //        동기화된 입력(r_sync1)이 현재 안정 상태(r_level)와
    //        다르게 유지되는 시간이 PARAM_DEBOUNCE_MAX_COUNT(약 10ms)를
    //        넘으면 그제서야 r_level을 갱신한다.
    //        => 짧은 채터링(튐)은 카운터가 끝까지 못 차서 무시됨.
    // -----------------------------------------------------
    reg [19:0] r_cnt;
    reg        r_level;    // 디바운스된 최종 '상태' 신호
    reg        r_level_d;  // r_level의 1클럭 지연본 (엣지 검출용)

    // 100MHz 기준 1,000,000 클럭 = 10ms. 디바운스 판정 시간 임계값.
    localparam PARAM_DEBOUNCE_MAX_COUNT = 20'd1_000_000;

    // 카운터가 임계값에 도달했는지 여부 (조합 신호)
    wire w_max_tick = (r_cnt == PARAM_DEBOUNCE_MAX_COUNT);

    always @(posedge i_clk) begin
        if (i_rst) begin
            r_cnt   <= 20'd0;
            r_level <= 1'b0;
        end else if (r_sync1 != r_level) begin
            // 입력이 현재 레벨과 다름 -> 안정화 카운트 진행
            if (w_max_tick) begin
                r_level <= r_sync1;  // 충분히 오래 유지됐으니 레벨 갱신
                r_cnt   <= 20'd0;    // 카운터 초기화
            end else begin
                r_cnt <= r_cnt + 1'b1;  // 아직 부족, 카운트 계속
            end
        end else begin
            // 입력이 현재 레벨과 같음 -> 채터링 없음, 카운터 리셋 유지
            r_cnt <= 20'd0;
        end
    end

    // -----------------------------------------------------
    // 3단계: 엣지 검출
    //        r_level의 0→1 전환 순간에만 1클럭짜리 펄스를 만든다.
    // -----------------------------------------------------
    always @(posedge i_clk) begin
        if (i_rst) begin
            r_level_d <= 1'b0;
        end else begin
            r_level_d <= r_level;  // 1클럭 지연
        end
    end

    // 최종 출력 연결
    assign o_btn_level = r_level;                 // 상태 유지형 출력
    assign o_btn_edge  = r_level & ~r_level_d;     // 0->1 순간만 1, 그 외는 0

endmodule