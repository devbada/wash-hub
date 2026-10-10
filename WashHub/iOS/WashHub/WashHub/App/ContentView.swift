import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    /// 종료 안내는 1.1.3 이상을 처음 실행한 모든 설치자에게 한 번 표시한다.
    @AppStorage("serviceSunsetNoticeAcknowledged") private var hasAcknowledgedServiceSunsetNotice = false

    var body: some View {
        Group {
            if authManager.isLoading {
                // 인증 로딩 중에도 동일 SplashView 노출 — 일관된 시각 경험
                SplashView()
            } else if authManager.isAuthenticated {
                if authManager.needsTermsAgreement {
                    TermsAgreementView()
                } else if authManager.needsNicknameSetup {
                    NicknameSetupView()
                } else {
                    HomeTabView()
                }
            } else if authManager.isGuestMode {
                HomeTabView()
            } else {
                LoginView()
            }
        }
        .overlay {
            if !authManager.isLoading && !hasAcknowledgedServiceSunsetNotice {
                ServiceSunsetNoticeView {
                    hasAcknowledgedServiceSunsetNotice = true
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .task {
            await authManager.checkSession()
        }
    }
}

// 정의는 Views/Common/SplashView.swift 로 이동 — 동적 아이콘 + 앱명을 공통으로 사용
