import SwiftUI
import Combine

/// 탭별 NavigationStack 의 path 와 스크롤 동작을 중앙에서 관리.
///
/// 도입 이유: 기존에 `.onReceive(.requestScrollToTop)` 알림으로 NavigationPath 를 비우려 했으나,
/// `.onReceive` 가 NavigationStack 의 root view 에 적용되어 있을 때 push 된 화면이 위에 있으면
/// 알림을 못 받는 케이스가 있었음. ObservableObject 의 @Published 로 직접 path 를 mutate 하면
/// SwiftUI 가 view tree 의 위치와 무관하게 즉시 반응.
///
/// 사용 패턴:
/// ```swift
/// // App 최상단에서 1회 주입
/// HomeTabView()
///     .environmentObject(NavigationCoordinator())
///
/// // ListView 에서 path 바인딩
/// @EnvironmentObject var navCoordinator: NavigationCoordinator
/// NavigationStack(path: $navCoordinator.feedPath) { ... }
///
/// // ScrollViewReader 안에서 scroll-to-top 감지
/// .onChange(of: navCoordinator.scrollToTopTokens[0]) { _, _ in
///     scrollProxy.scrollTo("top", anchor: .top)
/// }
///
/// // 탭바 재탭 시
/// navCoordinator.popAndScrollToTop(tab: tag)
/// ```
@MainActor
final class NavigationCoordinator: ObservableObject {
    /// 피드 탭(0) NavigationStack 경로
    @Published var feedPath = NavigationPath()
    /// 루틴 탭(2) NavigationStack 경로
    @Published var routinePath = NavigationPath()
    /// 케미컬 탭(3) NavigationStack 경로
    @Published var equipmentPath = NavigationPath()
    /// 내차 탭(4) NavigationStack 경로
    @Published var myCarPath = NavigationPath()

    /// 탭별 scroll-to-top 트리거 토큰. ListView 가 `.onChange` 로 변화 감지하여 스크롤 최상단 이동.
    /// (탭 번호 → UUID. UUID 가 바뀌면 새 트리거)
    @Published var scrollToTopTokens: [Int: UUID] = [:]

    /// 같은 탭을 다시 탭했을 때 호출 — NavigationStack 을 root 로 pop + 스크롤 최상단.
    /// path 는 동일 인스턴스 mutate (`removeLast(count)`) 로 처리 — 새 인스턴스 할당
    /// (`= NavigationPath()`) 보다 SwiftUI 의 변경 감지가 안정적.
    func popAndScrollToTop(tab: Int) {
        switch tab {
        case 0:
            if feedPath.count > 0 { feedPath.removeLast(feedPath.count) }
        case 2:
            if routinePath.count > 0 { routinePath.removeLast(routinePath.count) }
        case 3:
            if equipmentPath.count > 0 { equipmentPath.removeLast(equipmentPath.count) }
        case 4:
            if myCarPath.count > 0 { myCarPath.removeLast(myCarPath.count) }
        default:
            break
        }
        // 스크롤 최상단 트리거 — 각 ListView 가 .onChange(of: scrollToTopTokens[N]) 로 감지
        // (사용자 요청: 스크롤 후 같은 탭 재탭 시 최상단으로 복귀)
        scrollToTopTokens[tab] = UUID()
    }
}
