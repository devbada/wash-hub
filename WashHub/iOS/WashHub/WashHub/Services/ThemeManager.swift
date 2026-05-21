import SwiftUI
import Combine

/// 앱 테마 선택 상태를 보관 / 영속화하는 전역 매니저
///
/// - 선택값을 UserDefaults(`washhub_theme`)에 저장하고 앱 시작 시 즉시 적용한다.
/// - `current` 변경 시 앱 루트(`WashHubApp`)가 `.id(themeManager.current)` 로
///   뷰 트리를 리빌드하여 전역 `Color.theme` 의 새 값이 즉시 반영된다.
@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    private static let storageKey = "washhub_theme"

    /// 현재 적용 중인 테마
    @Published private(set) var current: AppTheme

    private init() {
        let saved = UserDefaults.standard.string(forKey: Self.storageKey)
        let theme = saved.flatMap(AppTheme.init(rawValue:)) ?? .periwinkle
        current = theme
        // 앱 시작 시점에 전역 팔레트 즉시 적용
        Color.theme = theme.colors
    }

    /// 테마 선택 — 즉시 적용 + 저장
    func select(_ theme: AppTheme) {
        guard theme != current else { return }
        Color.theme = theme.colors
        current = theme
        UserDefaults.standard.set(theme.rawValue, forKey: Self.storageKey)
    }
}
