import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.theme.surface
                .ignoresSafeArea()

            // Pristine Lens — 하단 Emerald ambient
            VStack {
                Spacer()
                Circle()
                    .fill(Color.theme.primaryContainer.opacity(0.08))
                    .frame(width: 320, height: 320)
                    .blur(radius: 90)
                    .offset(y: 120)
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // 로고 영역
                VStack(spacing: 16) {
                    Text("WASHHUB")
                        .font(.headline(42))
                        .tracking(4)
                        .foregroundColor(.theme.primary)

                    Text("비가 와도 세차")
                        .font(.bodyMedium(16))
                        .foregroundColor(.theme.textSecondary)
                }

                Spacer()

                // 로그인 버튼 영역
                VStack(spacing: 12) {
                    // Apple 로그인 — Apple HIG 가이드라인 준수
                    SignInWithAppleButton(.signIn) { request in
                        let appleRequest = authManager.prepareAppleSignIn()
                        request.requestedScopes = appleRequest.requestedScopes
                        request.nonce = appleRequest.nonce
                    } onCompletion: { result in
                        handleAppleLogin(result: result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 52)
                    .cornerRadius(12)
                    .disabled(isLoading)

                    // Google 로그인 — Surface 카드 스타일
                    Button(action: handleGoogleLogin) {
                        HStack(spacing: 10) {
                            Image(systemName: "g.circle.fill")
                                .font(.system(size: 18))
                            Text("Google로 시작하기")
                                .font(.appBodyBold)
                        }
                        .foregroundColor(.theme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.theme.surfaceLowest)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.theme.outlineVariant.opacity(0.5), lineWidth: 1)
                        )
                    }
                    .disabled(isLoading)

                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.appSmall)
                            .foregroundColor(.theme.error)
                            .multilineTextAlignment(.center)
                    }

                    // 둘러보기
                    Button(action: { authManager.enterGuestMode() }) {
                        Text("먼저 둘러볼게요")
                            .font(.appCaption)
                            .foregroundColor(.theme.textSecondary)
                            .underline()
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: 400)
                .padding(.horizontal, 24)
                .padding(.bottom, 60)
            }

            // 로딩 오버레이
            if isLoading {
                Color.theme.textPrimary.opacity(0.15)
                    .ignoresSafeArea()
                ProgressView()
                    .tint(.theme.primary)
                    .scaleEffect(1.2)
            }
        }
        // 탈퇴 처리된 계정으로 재로그인 시도 시 안내 alert
        // (AuthManager.loadProfile 에서 deletedAt 감지 → signOut + deletedAccountAlertMessage 세팅)
        .alert("계정 사용 불가", isPresented: Binding(
            get: { authManager.deletedAccountAlertMessage != nil },
            set: { if !$0 { authManager.deletedAccountAlertMessage = nil } }
        )) {
            Button("확인", role: .cancel) {
                authManager.deletedAccountAlertMessage = nil
            }
        } message: {
            Text(authManager.deletedAccountAlertMessage ?? "")
        }
    }

    // MARK: - Apple 로그인 처리
    private func handleAppleLogin(result: Result<ASAuthorization, Error>) {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                switch result {
                case .success(let authorization):
                    guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                        errorMessage = "Apple 인증 정보를 가져올 수 없습니다."
                        isLoading = false
                        return
                    }
                    try await authManager.handleAppleCredential(credential)
                case .failure(let error):
                    // 사용자가 취소한 경우는 에러 메시지 표시하지 않음
                    if (error as? ASAuthorizationError)?.code != .canceled {
                        errorMessage = "Apple 로그인에 실패했습니다. 다시 시도해주세요."
                    }
                    print("Apple Sign-In error: \(error)")
                }
            } catch {
                print("Apple login error: \(error)")
                errorMessage = "Apple 로그인에 실패했습니다. 다시 시도해주세요."
            }
            isLoading = false
        }
    }

    // MARK: - Google 로그인 처리
    private func handleGoogleLogin() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await authManager.signInWithGoogle()
                await authManager.checkSession()
            } catch {
                print("OAuth flow: \(error)")
                await authManager.checkSession()
                if !authManager.isAuthenticated {
                    errorMessage = "로그인에 실패했습니다. 다시 시도해주세요."
                }
            }
            isLoading = false
        }
    }
}
