import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        Group {
            if authManager.isLoading {
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
        .task {
            await authManager.checkSession()
        }
    }
}

struct SplashView: View {
    var body: some View {
        ZStack {
            // Carbon & Citrus 페이지 베이스
            Color.theme.surface
                .ignoresSafeArea()

            // Citrus Accent — 우하단 코너 Ambient
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Circle()
                        .fill(Color.theme.tertiary.opacity(0.10))
                        .frame(width: 360, height: 360)
                        .blur(radius: 100)
                        .offset(x: 120, y: 120)
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 14) {
                Text("WASHHUB")
                    .font(.custom("SpaceGrotesk-Bold", size: 36))
                    .tracking(4)
                    .foregroundColor(.theme.primary)

                Text("비가 와도 세차")
                    .font(.custom("Manrope-Medium", size: 16))
                    .foregroundColor(.theme.textSecondary)
            }
        }
    }
}
