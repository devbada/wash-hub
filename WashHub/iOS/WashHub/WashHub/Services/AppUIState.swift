import SwiftUI
import Combine

/// 전역 UI 상태 — FAB/탭바 숨김 제어
@MainActor
final class AppUIState: ObservableObject {
    static let shared = AppUIState()

    /// 강제 숨김 — 댓글 입력/루틴 따라하기 등에서 사용
    @Published var hideBottomUI = false

    /// 스크롤 기반 자동 숨김 — 피드 목록에서 아래로 스크롤하면 true, 위로 스크롤하면 false
    @Published var scrollHidesBottom = false

    /// 둘 중 하나라도 true 이면 하단 UI 숨김 — HomeTabView 가 이 값을 봄
    var shouldHideBottom: Bool {
        hideBottomUI || scrollHidesBottom
    }
}
