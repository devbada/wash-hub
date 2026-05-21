import SwiftUI

extension Color {
    /// 세차 리듬 화면 전용 액센트 — 현재 테마의 primary 를 따른다.
    ///
    /// 구버전은 고정 오렌지(#F97316)였으나, v3 다중 테마(12종) 도입으로
    /// 테마와 무관하게 튀던 문제가 있어 테마 종속 색으로 전환했다.
    /// - 노선도 정거장 + 연결선
    /// - 다음 세차 D-N 카드 액센트
    /// - 주기 설정 라디오 + 저장 버튼
    /// - 차량 picker 활성 상태
    static var rhythmAccent: Color { Color.theme.primary }
}
