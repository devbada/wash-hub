import Foundation
import Supabase
import Combine

@MainActor
final class AuthManager: ObservableObject {
    @Published var isLoading = true
    @Published var isAuthenticated = false
    @Published var isGuestMode = false
    @Published var needsNicknameSetup = false
    @Published var currentUser: Profile?

    /// 게스트 모드 여부 (로그인 없이 둘러보기)
    var isGuest: Bool { isGuestMode && !isAuthenticated }

    // MARK: - 게스트 모드 진입
    func enterGuestMode() {
        isGuestMode = true
    }

    // MARK: - 게스트 모드 종료 (로그인 화면으로)
    func exitGuestMode() {
        isGuestMode = false
    }

    // MARK: - 세션 확인
    func checkSession() async {
        isLoading = true
        do {
            let session = try await supabase.auth.session
            isAuthenticated = true
            await loadProfile(userId: session.user.id.uuidString)
        } catch {
            isAuthenticated = false
        }
        isLoading = false
    }

    // MARK: - 구글 로그인
    func signInWithGoogle() async throws {
        try await supabase.auth.signInWithOAuth(
            provider: .google,
            redirectTo: URL(string: "\(AppConfig.bundleID)://callback")
        )
    }

    // MARK: - 딥링크 세션 처리
    func handleDeepLink(url: URL) async {
        print("Deep link received: \(url.absoluteString.prefix(80))")
        do {
            let session = try await supabase.auth.session(from: url)
            print("Session from deep link: \(session.user.id)")
            isAuthenticated = true
            await loadProfile(userId: session.user.id.uuidString)
        } catch {
            print("Deep link session error: \(error)")
            // 딥링크 실패 시 기존 세션 재확인
            await checkSession()
        }
    }

    // MARK: - 프로필 로드
    func loadProfile(userId: String) async {
        do {
            let persistProfile: Profile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value

            currentUser = persistProfile
            // 닉네임이 이메일과 같거나 nil이면 닉네임 설정 필요
            needsNicknameSetup = (persistProfile.nickname == nil
                || persistProfile.nickname == persistProfile.username)
        } catch {
            print("Profile load error: \(error)")
            needsNicknameSetup = true
        }
    }

    // MARK: - 닉네임 업데이트
    func updateNickname(_ nickname: String) async throws {
        guard let userId = currentUser?.id else { return }

        try await supabase
            .from("profiles")
            .update(["nickname": nickname])
            .eq("id", value: userId)
            .execute()

        await loadProfile(userId: userId)
        needsNicknameSetup = false
    }

    // MARK: - 닉네임 중복 검사
    func checkNicknameDuplicate(_ nickname: String) async throws -> Bool {
        let persistProfiles: [Profile] = try await supabase
            .from("profiles")
            .select()
            .eq("nickname", value: nickname)
            .execute()
            .value

        return !persistProfiles.isEmpty
    }

    // MARK: - 로그아웃
    func signOut() async throws {
        try await supabase.auth.signOut()
        isAuthenticated = false
        currentUser = nil
        needsNicknameSetup = false
    }

    // MARK: - 회원 탈퇴
    func withdraw() async throws {
        let session = try await supabase.auth.session

        _ = try await supabase.functions
            .invoke(
                "withdraw-user",
                options: .init(
                    headers: ["Authorization": "Bearer \(session.accessToken)"]
                )
            )

        try await signOut()
    }
}
