`timescale 1ns / 1ps
// =============================================================
// 모듈명 : seg_display
// 역할   : Basys3의 4자리 7세그먼트와 LED를 이용해
//            - 1번째 자리(가장 우측, w_digit_sel=00) : 저장된 자세 개수
//            - 4번째 자리(가장 좌측, w_digit_sel=11) : 현재 모드(M/R/P)
//            - 2,3번째 자리(w_digit_sel=01,10)        : 현재는 blank 처리
//          를 멀티플렉싱(시분할)으로 표시하고,
//          LED 3개로 현재 선택된 관절(base/shoulder/elbow)을 표시한다.
// 담당   : C영역 (입력/표시)
// =============================================================
module seg_display(
    input  wire       i_clk,           // 100MHz 시스템 클럭
    input  wire       i_rst,           // Active-High, 동기식 리셋
    input  wire [1:0] i_mode,          // 현재 모드: 00=MANUAL, 01=RECORD, 10=PLAY
    input  wire [3:0] i_pose_count,    // 저장된 자세 개수 (0~8)
    input  wire [1:0] i_joint_idx,     // 현재 선택된 관절 인덱스 (0=base,1=shoulder,2=elbow)
    output wire [3:0] o_an,            // 7세그 자릿수 선택(active-low, 4자리 중 1개만 0)
    output wire [6:0] o_seg,           // 7세그 세그먼트 패턴(active-low, a~g)
    output wire [2:0] o_led            // 선택된 관절을 나타내는 LED 3개 (원-핫)
);

    // -----------------------------------------------------
    // 자릿수 멀티플렉싱용 리프레시 카운터
    // 상위 2비트(r_refresh_cnt[17:16])를 이용해 약 1.5kHz로 4자리를 순환 전환
    // (사람 눈에는 4자리가 동시에 켜진 것처럼 보임)
    // -----------------------------------------------------
    reg [17:0] r_refresh_cnt;

    always @(posedge i_clk) begin
        if (i_rst) begin
            r_refresh_cnt <= 18'd0;
        end else begin
            r_refresh_cnt <= r_refresh_cnt + 1'b1;
        end
    end

    // 현재 어떤 자리를 켤지 선택하는 신호 (00,01,10,11 순환)
    wire [1:0] w_digit_sel = r_refresh_cnt[17:16];

    reg  [3:0] r_an;   // 자릿수 선택 출력 (디코딩 결과)
    reg  [6:0] r_seg;  // 세그먼트 패턴 출력 (디코딩 결과)

    // -----------------------------------------------------
    // 자릿수별 표시 내용 결정 (조합 로직)
    // -----------------------------------------------------
    always @(*) begin
        // 기본값: 모든 자리 꺼짐(active-low라 1111), 세그먼트도 전부 꺼짐
        r_an  = 4'b1111;
        r_seg = 7'b1111111;

        case (w_digit_sel)
            // ---- 1번째 자리: 저장된 자세 개수 표시 ----
            2'b00: begin
                r_an = 4'b1110;  // 최우측 자리만 활성(0)
                case (i_pose_count)
                    4'd0: r_seg = 7'b1000000; // "0"
                    4'd1: r_seg = 7'b1111001; // "1"
                    4'd2: r_seg = 7'b0100100; // "2"
                    4'd3: r_seg = 7'b0110000; // "3"
                    4'd4: r_seg = 7'b0011001; // "4"
                    4'd5: r_seg = 7'b0010010; // "5"
                    4'd6: r_seg = 7'b0000010; // "6"
                    4'd7: r_seg = 7'b1111000; // "7"
                    4'd8: r_seg = 7'b0000000; // "8"
                    default: r_seg = 7'b0111111; // 범위 밖 값 -> "-" 표시
                endcase
            end

            // ---- 2번째 자리: 현재 미사용, 항상 꺼짐 ----
            2'b01: begin
                r_an = 4'b1101;
                r_seg = 7'b1111111;
            end

            // ---- 3번째 자리: 현재 미사용, "-" 고정 표시 ----
            2'b10: begin
                r_an = 4'b1011;
                r_seg = 7'b0111111;
            end

            // ---- 4번째 자리(좌측 끝): 모드 글자(M/R/P) 표시 ----
            2'b11: begin
                r_an = 4'b0111;
                case (i_mode)
                    2'b00: r_seg = 7'b0111111; // MANUAL -> "M" 형태 패턴
                    2'b01: r_seg = 7'b0101111; // RECORD -> "R" 형태 패턴
                    2'b10: r_seg = 7'b0001100; // PLAY   -> "P" 형태 패턴
                    default: r_seg = 7'b1111111; // 정의되지 않은 모드 -> 꺼짐
                endcase
            end
        endcase
    end

    // -----------------------------------------------------
    // 선택된 관절을 LED 3개로 원-핫(one-hot) 표시
    // -----------------------------------------------------
    reg [2:0] r_led;
    always @(*) begin
        case (i_joint_idx)
            2'd0: r_led = 3'b001; // base
            2'd1: r_led = 3'b010; // shoulder
            2'd2: r_led = 3'b100; // elbow
            default: r_led = 3'b000; // 정의되지 않은 값 -> 전부 꺼짐
        endcase
    end

    // 최종 출력 연결
    assign o_an  = r_an;
    assign o_seg = r_seg;
    assign o_led = r_led;

endmodule