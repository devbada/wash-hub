import SwiftUI

extension Color {
    /// 세차 리듬 화면 전용 액센트 — 오렌지 (#F97316)
    ///
    /// 디자인 시스템의 Citrus(`Color.theme.secondary`) 와 차별화하여
    /// "리듬/시간/습관" 도메인의 시그니처 색상으로 사용한다.
    /// - 노선도 정거장 + 연결선
    /// - 다음 세차 D-N 카드 액센트
    /// - 주기 설정 라디오 + 저장 버튼
    /// - 차량 picker 활성 상태
    static let rhythmAccent = Color(red: 249.0 / 255.0, green: 115.0 / 255.0, blue: 22.0 / 255.0)
}
