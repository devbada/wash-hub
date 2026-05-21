import SwiftUI
import Supabase

@main
struct WashHubApp: App {
    @StateObject private var authManager = AuthManager()
    /// 탭별 NavigationStack path + scroll-to-top 트리거를 중앙 관리
    /// (탭 재탭 시 pop-to-root 동작 — CONVENTIONS.md 6.1 참조)
    @StateObject private var navCoordinator = NavigationCoordinator()
    /// 테마 선택 상태 — 변경 시 .id 로 뷰 트리를 리빌드해 즉시 반영
    @StateObject private var themeManager = ThemeManager.shared
    @Environment(\.scenePhase) private var scenePhase

    /// 앱 시작 시 1.5초간 SplashView 노출 — 동적 아이콘 + 앱명
    @State private var isSplashVisible: Bool = true
    /// 페이드아웃 완료 후 SplashView 를 메모리에서 완전히 해제하기 위한 플래그
    @State private var splashRemoved: Bool = false

    /// 스플래시 노출 시간 (초)
    private static let splashDuration: TimeInterval = 1.5
    /// 펼쳐지는 트랜지션 시간 (초) — 종료 후 메모리 해제까지 대기
    private static let transitionDuration: Double = 0.55

    var body: some Scene {
        WindowGroup {
            ZStack {
                // 메인 컨텐츠 — 스플래시 뒤에서 미리 마운트
                // 등장 시 미세하게 zoom-in (0.96 → 1.0) + 페이드인으로 자연스러운 전환
                ContentView()
                    .environmentObject(authManager)
                    .environmentObject(navCoordinator)
                    .environmentObject(themeManager)
                    // 테마 변경 시 뷰 트리 전체를 새 정체성으로 리빌드 → Color.theme 즉시 반영
                    .id(themeManager.current)
                    .preferredColorScheme(.light)
                    .scaleEffect(isSplashVisible ? 0.96 : 1.0)
                    .opacity(isSplashVisible ? 0 : 1)
                    .onOpenURL { url in
                        Task { await authManager.handleDeepLink(url: url) }
                    }

                // 스플래시 오버레이 — 직접 scaleEffect/opacity 로 isSplashVisible 에 binding
                // (.transition 은 ZStack 내 다른 view 변화로 무시될 수 있어 명시적 effect 사용)
                if !splashRemoved {
                    SplashView()
                        .scaleEffect(isSplashVisible ? 1.0 : 1.2)
                        .opacity(isSplashVisible ? 1.0 : 0.0)
                        .allowsHitTesting(isSplashVisible)
                        .zIndex(1)
                }
            }
            .task {
                // 1.5초 노출
                try? await Task.sleep(nanoseconds: UInt64(Self.splashDuration * 1_000_000_000))
                // 펼쳐지듯 페이드아웃 + ContentView zoom-in
                withAnimation(.easeOut(duration: Self.transitionDuration)) {
                    isSplashVisible = false
                }
                // 트랜지션 완료 후 SplashView 자체를 view tree 에서 제거 (메모리 회수)
                try? await Task.sleep(nanoseconds: UInt64(Self.transitionDuration * 1_000_000_000) + 100_000_000)
                splashRemoved = true
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task {
                    await DynamicIconService.shared.updateIconIfNeeded()
                }
            }
        }
    }
}
