import Foundation
import Supabase
import Combine
import AuthenticationServices
import CryptoKit

@MainActor
final class AuthManager: ObservableObject {
    @Published var isLoading = true
    @Published var isAuthenticated = false
    @Published var isGuestMode = false
    @Published var needsTermsAgreement = false
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

    // MARK: - Apple 로그인
    /// Apple Sign-In nonce (CSRF 방지)
    private var currentNonce: String?

    /// Apple Sign-In 요청 시작
    func prepareAppleSignIn() -> ASAuthorizationAppleIDRequest {
        let nonce = randomNonceString()
        currentNonce = nonce

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        return request
    }

    /// Apple credential 수신 후 Supabase 로그인
    func handleAppleCredential(_ credential: ASAuthorizationAppleIDCredential) async throws {
        guard let identityTokenData = credential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            throw AppleSignInError.missingToken
        }
        guard let nonce = currentNonce else {
            throw AppleSignInError.missingNonce
        }

        // Supabase Auth — Apple ID Token으로 로그인
        try await supabase.auth.signInWithIdToken(
            credentials: .init(
                provider: .apple,
                idToken: identityToken,
                nonce: nonce
            )
        )

        currentNonce = nil
        await checkSession()
    }

    /// 랜덤 nonce 생성 (Secure Coding)
    private func randomNonceString(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        while remainingLength > 0 {
            var randomBytes = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
            guard status == errSecSuccess else { continue }
            randomBytes.forEach { byte in
                if remainingLength == 0 { return }
                if byte < charset.count {
                    result.append(charset[Int(byte)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }

    /// SHA256 해시 (nonce → Apple 전달용)
    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    enum AppleSignInError: LocalizedError {
        case missingToken
        case missingNonce

        var errorDescription: String? {
            switch self {
            case .missingToken: return "Apple 인증 토큰을 가져올 수 없습니다."
            case .missingNonce: return "인증 요청이 올바르지 않습니다. 다시 시도해주세요."
            }
        }
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
            // 약관 미동의 시 약관 동의 화면으로
            needsTermsAgreement = (persistProfile.agreedTermsAt == nil)
            // 닉네임이 이메일과 같거나 nil이면 닉네임 설정 필요
            needsNicknameSetup = (persistProfile.nickname == nil
                || persistProfile.nickname == persistProfile.username)
        } catch {
            print("Profile load error (profiles 행 미존재 가능): \(error)")
            // profiles 행이 없어도 임시 Profile 으로 currentUser 를 채워 NicknameSetupView 가 동작하도록 함
            // updateNickname 에서 upsert 로 실제 행이 생성됨
            let fallbackProfile = buildFallbackProfile(userId: userId)
            currentUser = fallbackProfile
            needsTermsAgreement = true
            needsNicknameSetup = true
        }
    }

    /// Auth 세션에서 최소한의 임시 Profile을 구성 (profiles 행 미존재 시 방어)
    private func buildFallbackProfile(userId: String) -> Profile {
        // auth session에서 메타데이터 추출 시도
        var email: String? = nil
        var avatarUrl: String? = nil
        if let session = try? supabase.auth.currentSession {
            email = session.user.email
            avatarUrl = session.user.userMetadata["avatar_url"]?.stringValue
                ?? session.user.userMetadata["picture"]?.stringValue
        }
        return Profile(
            id: userId,
            username: email,
            nickname: nil,
            avatarUrl: avatarUrl,
            bio: nil,
            carCount: nil,
            washCount: nil,
            followerCount: 0,
            followingCount: 0,
            isActive: true,
            titleBadgeId: nil,
            agreedTermsAt: nil,
            createdAt: nil,
            updatedAt: nil
        )
    }

    // MARK: - 약관 동의 처리
    func agreeToTerms() async throws {
        let session = try await supabase.auth.session
        let userId = session.user.id.uuidString

        // agreed_terms_at을 현재 시각으로 업데이트
        try await supabase
            .from("profiles")
            .update(["agreed_terms_at": ISO8601DateFormatter().string(from: Date())])
            .eq("id", value: userId)
            .execute()

        needsTermsAgreement = false
    }

    // MARK: - 닉네임 업데이트
    // TODO-minam: currentUser 가 nil 이어도 auth session 에서 userId 를 직접 가져옴
    // upsert 유지 (트리거 실패 시 profiles 행 자동 생성) + agreed_terms_at 포함 (유실 방지)
    func updateNickname(_ nickname: String) async throws {
        let session = try await supabase.auth.session
        let userId = session.user.id.uuidString

        struct ProfileUpsert: Encodable {
            let id: String
            let nickname: String
            let username: String?
            let avatar_url: String?
            let agreed_terms_at: String
        }

        let email = session.user.email
        let avatarUrl = session.user.userMetadata["avatar_url"]?.stringValue
            ?? session.user.userMetadata["picture"]?.stringValue

        let payload = ProfileUpsert(
            id: userId,
            nickname: nickname,
            username: email,
            avatar_url: avatarUrl,
            agreed_terms_at: ISO8601DateFormatter().string(from: Date())
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
