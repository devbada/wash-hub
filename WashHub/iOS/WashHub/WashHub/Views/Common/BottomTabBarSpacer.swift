import SwiftUI

/// 스크롤 콘텐츠 끝에 배치하는 빈 가상 아이템.
///
/// `HomeTabView` 의 ZStack overlay 패턴(콘텐츠 풀스크린 + 탭바/FAB 위에 떠있음)에서
/// 스크롤 마지막 아이템이 탭바에 가려지는 문제를 해결하기 위해,
/// **각 세로 스크롤 화면의 content 끝에 이 view 를 추가**하면 됩니다.
///
/// 사용 예:
/// ```swift
/// ScrollView {
///     LazyVStack {
///         ForEach(items) { ... }
///         BottomTabBarSpacer()   // ← 마지막에 한 줄
///     }
/// }
/// ```
///
/// 또는 List 안:
/// ```swift
/// List {
///     ForEach(items) { ... }
///     BottomTabBarSpacer()
///         .listRowBackground(Color.clear)
///         .listRowSeparator(.hidden)
/// }
/// ```
///
/// - Note: 높이 96pt 는 탭바 자체(약 52pt) + safe area bottom(약 34pt) + 여백(약 10pt) 합산.
///         특정 화면에서 더 큰 여유가 필요하면 `height` 파라미터로 조정 가능.
struct BottomTabBarSpacer: View {
    /// 하단 여유 높이. 기본값 96pt (탭바 + safe area + 여백)
    var height: CGFloat = 96

    var body: some View {
        Color.clear
            .frame(height: height)
            .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: 0) {
        Color.red.frame(height: 50)
        BottomTabBarSpacer()
        Color.blue.frame(height: 50)
    }
}
