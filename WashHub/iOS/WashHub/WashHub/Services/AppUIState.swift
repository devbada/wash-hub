import SwiftUI
import Combine

/// 전역 UI 상태 — FAB/탭바 숨김 제어
@MainActor
final class AppUIState: ObservableObject {
    static let shared = AppUIState()

    /// true이면 FAB + 탭바를 숨김 (부드러운 애니메이션 적용)
    @Published var hideBottomUI = false
}
