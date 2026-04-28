import SwiftUI
import Supabase

@main
struct WashHubApp: App {
    @StateObject private var authManager = AuthManager()
    @Environment(\.scenePhase) private var scenePhase

    /// 앱 시작 시 1.5초간 SplashView 노출 — 동적 아이콘 + 앱명
    @State private var isSplashVisible: Bool = true

    /// 스플래시 노출 시간 (초)
    private static let splashDuration: TimeInterval = 1.5

    var body: some Scene {
        WindowGroup {
            ZStack {
                // 메인 컨텐츠 — 스플래시 뒤에서 미리 마운트되어 전환 시 즉시 표시 가능
                ContentView()
                    .environmentObject(authManager)
                    .preferredColorScheme(.light)
                    .onOpenURL { url in
                        Task { await authManager.handleDeepLink(url: url) }
                    }

                // 스플래시 오버레이 — 시작 시 화면 전체를 덮고 페이드아웃
                if isSplashVisible {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .task {
                // 1.5초 노출 후 페이드아웃
                try? await Task.sleep(nanoseconds: UInt64(Self.splashDuration * 1_000_000_000))
                withAnimation(.easeOut(duration: 0.4)) {
                    isSplashVisible = false
                }
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
