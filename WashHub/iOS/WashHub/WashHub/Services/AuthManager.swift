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
    // TODO-minam: .single() 이 실패하면 currentUser = nil 이 되어 닉네임 설정 등 후속 로직이 막힘
    // 방어: profiles 행이 없으면 auth session 에서 임시 Profile 을 구성해 최소 동작 보장
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
            print("Profile load error (profiles 행 미존재 가능): \(error)")
            // profiles 행이 없어도 임시 Profile 으로 currentUser 를 채워 NicknameSetupView 가 동작하도록 함
            // updateNickname 에서 upsert 로 실제 행이 생성됨
            do {
                let session = try await supabase.auth.session
                let email = session.user.email
                let avatarUrl = session.user.userMetadata["avatar_url"]?.stringValue
                    ?? session.user.userMetadata["picture"]?.stringValue
                currentUser = Profile(
                    id: userId,
                    username: email,
                    nickname: nil,
                    avatarUrl: avatarUrl,
                    bio: nil,
                    carCount: nil,
                    washCount: nil,
                    isActive: true,
                    createdAt: nil,
                    updatedAt: nil
                )
            } catch {
                print("Auth session 도 없음 — 미인증 상태: \(error)")
            }
            needsNicknameSetup = true
        }
    }

    // MARK: - 닉네임 업데이트
    // TODO-minam: currentUser 가 nil 이어도 auth session 에서 userId 를 직접 가져옴
    // profiles 행이 없으면 upsert 로 자동 생성 (트리거 실패 시 방어)
    func updateNickname(_ nickname: String) async throws {
        let session = try await supabase.auth.session
        let userId = session.user.id.uuidString

        // upsert — profiles 행이 이미 있으면 nickname 만 갱신, 없으면 신규 생성
        struct ProfileUpsert: Encodable {
            let id: String
            let nickname: String
            let username: String?
            let avatar_url: String?
        }

        let email = session.user.email
        let avatarUrl = session.user.userMetadata["avatar_url"]?.stringValue
            ?? session.user.userMetadata["picture"]?.stringValue

        let payload = ProfileUpsert(
            id: userId,
            nickname: nickname,
            username: email,
            avatar_url: avatarUrl
        )

        try await supabase
            .from("profiles")
            .upsert(payload, onConflict: "id")
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
