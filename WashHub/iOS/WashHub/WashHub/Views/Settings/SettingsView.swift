import SwiftUI

/// v2 — 전용 설정 화면 (햄버거 드로어 → 설정)
///
/// 차단 관리·이용약관·개인정보처리방침·로그아웃을 한 곳에 모았다.
/// 회원 탈퇴는 계정 단위 작업이라 마이페이지에 그대로 유지한다.
struct SettingsView: View {
    /// 화면 닫기 — 드로어에서 풀스크린으로 진입하므로 명시적 닫기 콜백을 받는다
    let onClose: () -> Void

    @EnvironmentObject var authManager: AuthManager
    @ObservedObject private var themeManager = ThemeManager.shared

    @State private var showTerms = false
    @State private var showPrivacy = false
    @State private var showLogoutConfirm = false

    var body: some View {
        ZStack {
            Color.theme.surface.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(spacing: 8) {
                        // 테마 변경
                        NavigationLink {
                            ThemeSelectionView()
                        } label: {
                            settingRow(icon: "paintpalette", label: "테마 변경",
                                       value: themeManager.current.nameKo)
                        }
                        .buttonStyle(.plain)

                        // 차단 관리
                        NavigationLink {
                            BlockedUsersListView()
                        } label: {
                            settingRow(icon: "person.slash", label: "차단 관리")
                        }
                        .buttonStyle(.plain)

                        // 이용약관
                        Button(action: { showTerms = true }) {
                            settingRow(icon: "doc.text", label: "이용약관")
                        }
                        .buttonStyle(.plain)

                        // 개인정보처리방침
                        Button(action: { showPrivacy = true }) {
                            settingRow(icon: "lock.shield", label: "개인정보처리방침")
                        }
                        .buttonStyle(.plain)

                        // 로그아웃
                        Button(action: { showLogoutConfirm = true }) {
                            settingRow(icon: "rectangle.portrait.and.arrow.right", label: "로그아웃")
                        }
                        .buttonStyle(.plain)

                        // 앱 버전
                        HStack(spacing: 14) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 16))
                                .foregroundColor(.theme.textPrimary)
                                .frame(width: 34, height: 34)
                                .background(Color.theme.surfaceLow)
                                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                            Text("앱 버전")
                                .font(.appBody)
                                .foregroundColor(.theme.textPrimary)
                            Spacer()
                            Text(appVersionText)
                                .font(.appCaption)
                                .foregroundColor(.theme.textDisabled)
                        }
                        .padding(16)
                        .cardStyle()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showTerms) {
            LegalDocumentView(title: "이용약관", url: LegalURLs.termsOfService)
        }
        .sheet(isPresented: $showPrivacy) {
            LegalDocumentView(title: "개인정보처리방침", url: LegalURLs.privacyPolicy)
        }
        .alert("로그아웃", isPresented: $showLogoutConfirm) {
            Button("취소", role: .cancel) {}
            Button("로그아웃", role: .destructive) {
                Task { try? await authManager.signOut() }
            }
        } message: {
            Text("로그아웃 하시겠어요?")
        }
    }

    // MARK: - 헤더
    private var header: some View {
        HStack(spacing: 12) {
            Button(action: onClose) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.theme.textPrimary)
            }
            Text("설정")
                .font(.appHeadline2)
                .foregroundColor(.theme.textPrimary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(Color.theme.surface.ignoresSafeArea(edges: .top))
    }

    // MARK: - 설정 행
    private func settingRow(icon: String, label: String, value: String? = nil) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.theme.textPrimary)
                .frame(width: 34, height: 34)
                .background(Color.theme.surfaceLow)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            Text(label)
                .font(.appBody)
                .foregroundColor(.theme.textPrimary)
            Spacer()
            if let value {
                Text(value)
                    .font(.appCaption)
                    .foregroundColor(.theme.textSecondary)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(.theme.textDisabled)
        }
        .padding(16)
        .cardStyle()
        .contentShape(Rectangle())
    }

    // MARK: - 앱 버전 (Bundle)
    private var appVersionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
