`timescale 1ns / 1ps

module reg_bank(
    input wire i_clk,
    input wire i_rst,          // SW15 소스, 동기식 리셋
    input wire i_we,           // 쓰기 활성화 (RECORD 모드에서 1)
    input wire [2:0] i_addr,   // 최대 8개 자세 저장 (0~7)
    input wire [24:0] i_pose_data, // {집게 1bit, elbow 8bit, shoulder 8bit, base 8bit}
    output wire [24:0] o_pose_data
);

    // BRAM이 아닌 순수 D-FF 레지스터 뱅크 선언 (최대 8개 자세 저장)
    reg [24:0] r_mem [0:7];

    // 기획서 7-4: 메모리 데이터 자체는 리셋하지 않음 (라우팅 최적화). 
    // 저장된 개수(pose_count)와 포인터 리셋은 외부(mode_fsm)에서 담당함.
    always @(posedge i_clk) begin
        if (i_rst) begin
            // 의도적으로 배열을 초기화하지 않음
        end else if (i_we) begin
            r_mem[i_addr] <= i_pose_data;
        end
    end

    // 비동기 읽기: 주소가 들어오면 즉시 해당 레지스터 값을 출력
    assign o_pose_data = r_mem[i_addr];

endmodule