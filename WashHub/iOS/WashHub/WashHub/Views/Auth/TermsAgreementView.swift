import SwiftUI

/// 회원가입 시 약관 동의 화면
/// 플로우: OAuth 로그인 → TermsAgreementView → NicknameSetupView → HomeTabView
struct TermsAgreementView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var agreedTerms = false
    @State private var agreedPrivacy = false
    @State private var agreedAge = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showTermsDetail = false
    @State private var showPrivacyDetail = false
    @State private var showLogoutAlert = false

    /// 전체 동의 여부
    private var allAgreed: Bool {
        agreedTerms && agreedPrivacy && agreedAge
    }

    /// 전체 동의 토글
    private var isAllChecked: Bool {
        agreedTerms && agreedPrivacy && agreedAge
    }

    var body: some View {
        ZStack {
            Color.theme.surface
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 헤더
                VStack(spacing: 8) {
                    Text("약관 동의")
                        .font(.appHeadline1)
                        .foregroundColor(.theme.textPrimary)

                    Text("WashHub 서비스 이용을 위해\n아래 약관에 동의해주세요")
                        .font(.appCaption)
                        .foregroundColor(.theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 60)
                .padding(.bottom, 32)

                // 전체 동의
                Button(action: {
                    let newValue = !isAllChecked
                    agreedTerms = newValue
                    agreedPrivacy = newValue
                    agreedAge = newValue
                }) {
                    HStack(spacing: 12) {
                        checkIcon(isChecked: isAllChecked, accent: true)
                        Text("전체 동의")
                            .font(.appBodyBold)
                            .foregroundColor(.theme.textPrimary)
                        Spacer()
                    }
                    .padding(16)
                    .background(Color.theme.surfaceHigh)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 24)

                Divider()
                    .background(Color.theme.border)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)

                // 개별 동의 항목
                VStack(spacing: 8) {
                    // 이용약관
                    agreementRow(
                        isChecked: $agreedTerms,
                        title: "[필수] 이용약관 동의",
                        action: { showTermsDetail = true }
                    )

                    // 개인정보처리방침
                    agreementRow(
                        isChecked: $agreedPrivacy,
                        title: "[필수] 개인정보처리방침 동의",
                        action: { showPrivacyDetail = true }
                    )

                    // 만 14세 이상
                    agreementRow(
                        isChecked: $agreedAge,
                        title: "[필수] 만 14세 이상입니다",
                        action: nil
                    )
                }
                .padding(.horizontal, 24)

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.appSmall)
                        .foregroundColor(.theme.error)
                        .padding(.top, 12)
                        .padding(.horizontal, 24)
                }

                Spacer()

                // 동의 버튼
                Button(action: submitAgreement) {
                    if isLoading {
                        ProgressView()
                            .tint(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    } else {
                        Text("동의하고 계속하기")
                            .primaryButtonStyle()
                    }
                }
                .disabled(!allAgreed || isLoading)
                .opacity(allAgreed ? 1.0 : 0.4)
                .padding(.horizontal, 24)

                // 다른 계정으로 로그인
                Button(action: { showLogoutAlert = true }) {
                    Text("다른 계정으로 로그인")
                        .font(.appCaption)
                        .foregroundColor(.theme.textDisabled)
                        .underline()
                }
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showTermsDetail) {
            LegalDocumentView(
                title: "이용약관",
                url: LegalURLs.termsOfService
            )
        }
        .sheet(isPresented: $showPrivacyDetail) {
            LegalDocumentView(
                title: "개인정보처리방침",
                url: LegalURLs.privacyPolicy
            )
        }
        .alert("다시 로그인하시겠습니까?", isPresented: $showLogoutAlert) {
            Button("로그아웃", role: .destructive) {
                Task { try? await authManager.signOut() }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("현재 세션을 종료하고 로그인 화면으로 돌아갑니다.")
        }
    }

    // MARK: - 개별 동의 행
    private func agreementRow(
        isChecked: Binding<Bool>,
        title: String,
        action: (() -> Void)?
    ) -> some View {
        HStack(spacing: 12) {
            Button(action: { isChecked.wrappedValue.toggle() }) {
                checkIcon(isChecked: isChecked.wrappedValue, accent: false)
            }

            Button(action: { isChecked.wrappedValue.toggle() }) {
                Text(title)
                    .font(.appBody)
                    .foregroundColor(.theme.textSecondary)
            }

            Spacer()

            if let action = action {
                Button(action: action) {
                    Text("보기")
                        .font(.appSmall)
                        .foregroundColor(.theme.textDisabled)
                        .underline()
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - 체크 아이콘
    private func checkIcon(isChecked: Bool, accent: Bool) -> some View {
        Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 22))
            .foregroundColor(
                isChecked
                    ? (accent ? Color.theme.secondary : Color.theme.tertiary)
                    : Color.theme.textDisabled
            )
    }

    // MARK: - 동의 처리
    private func submitAgreement() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await authManager.agreeToTerms()
            } catch {
                errorMessage = "약관 동의 처리에 실패했습니다. 다시 시도해주세요."
                print("Terms agreement error: \(error)")
            }
            isLoading = false
        }
    }
}

// MARK: - 약관 URL 상수
// 호스팅: Vercel (workspace/docs/ → project-wash-hub 프로젝트)
// 이전: GitHub Pages (devbada.github.io/wash-hub) → 2026-05 마케팅 사이트로 통합
enum LegalURLs {
    static let privacyPolicy = URL(string: "https://project-wash-hub.vercel.app/privacy-policy.html")!
    static let termsOfService = URL(string: "https://project-wash-hub.vercel.app/terms-of-service.html")!
}
