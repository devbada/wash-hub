import SwiftUI
import Combine

/// 앱 전역 색상 팔레트를 적용하고 기존 저장값을 마이그레이션하는 매니저
///
/// - 앱 시작 시 기존 파스텔 테마 저장값을 Neutral + Olive로 교체한다.
/// - `current` 변경 시 앱 루트(`WashHubApp`)가 `.id(themeManager.current)` 로
///   뷰 트리를 리빌드하여 전역 `Color.theme` 의 새 값이 즉시 반영된다.
@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    private static let storageKey = "washhub_theme"

    /// 현재 적용 중인 테마
    @Published private(set) var current: AppTheme

    private init() {
        let theme = AppTheme.readableNeutral
        current = theme
        Color.theme = theme.colors
        // TODO-minam: 기존 테마가 저장된 설치본에서 첫 실행 후 새 테마로 바뀌는지 확인해 주세요.
        migrateSavedTheme(to: theme)
    }

    /// 레거시 테마 화면 호환용. 사용자 진입점에서는 더 이상 노출하지 않는다.
    func select(_ theme: AppTheme) {
        guard theme != current else { return }
        Color.theme = theme.colors
        current = theme
        UserDefaults.standard.set(theme.rawValue, forKey: Self.storageKey)
    }

    private func migrateSavedTheme(to theme: AppTheme) {
        guard UserDefaults.standard.string(forKey: Self.storageKey) != theme.rawValue else {
            return
        }
        UserDefaults.standard.set(theme.rawValue, forKey: Self.storageKey)
    }
}
