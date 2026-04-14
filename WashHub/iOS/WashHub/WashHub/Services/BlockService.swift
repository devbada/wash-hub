import Foundation
import Combine
import Supabase

@MainActor
final class BlockService: ObservableObject {
    /// 앱 전역 공유 인스턴스 — 차단 상태를 모든 뷰에서 일관되게 유지
    static let shared = BlockService()

    @Published var blockedUsers: [BlockedUser] = []
    @Published var blockedIds: Set<String> = []
    @Published var isLoading = false

    // MARK: - 사용자 차단
    func blockUser(blockedId: String, reason: String? = nil) async throws {
        struct BlockInsert: Encodable {
            let blocker_id: String
            let blocked_id: String
            let reason: String?
        }

        guard let userId = supabase.auth.currentUser?.id.uuidString else { return }

        let insert = BlockInsert(
            blocker_id: userId,
            blocked_id: blockedId,
            reason: reason
        )

        try await supabase
            .from("blocks")
            .insert(insert)
            .execute()

        // 로컬 상태 즉시 반영
        blockedIds.insert(blockedId)

        // 차단 변경 알림 — 피드/댓글 목록 갱신용
        NotificationCenter.default.post(name: .blockStatusChanged, object: nil)
    }

    // MARK: - 차단 해제
    func unblockUser(blockedId: String) async throws {
        guard let userId = supabase.auth.currentUser?.id.uuidString else { return }

        try await supabase
            .from("blocks")
            .delete()
            .eq("blocker_id", value: userId)
            .eq("blocked_id", value: blockedId)
            .execute()

        // 로컬 상태 즉시 반영
        blockedIds.remove(blockedId)
        blockedUsers.removeAll { $0.blockedId == blockedId }

        // 차단 변경 알림
        NotificationCenter.default.post(name: .blockStatusChanged, object: nil)
    }

    // MARK: - 차단 목록 조회 (프로필 포함)
    /// blocks → blocked_id 목록 조회 후, profiles를 별도 쿼리로 로드
    /// (blocks.blocked_id FK가 auth.users를 가리키므로 profiles 직접 JOIN 불가)
    func loadBlockedUsers() async {
        isLoading = true
        do {
            // 1단계: 차단 목록 조회
            struct BlockRow: Codable {
                let blockedId: String
                let reason: String?
                let createdAt: String
                enum CodingKeys: String, CodingKey {
                    case blockedId = "blocked_id"
                    case reason
                    case createdAt = "created_at"
                }
            }

            let persistBlocks: [BlockRow] = try await supabase
                .from("blocks")
                .select("blocked_id, reason, created_at")
                .order("created_at", ascending: false)
                .execute()
                .value

            guard !persistBlocks.isEmpty else {
                blockedUsers = []
                blockedIds = []
                isLoading = false
                return
            }

            // 2단계: 차단된 사용자 프로필 조회
            let ids = persistBlocks.map { $0.blockedId }
            let persistProfiles: [BlockedUserProfile] = try await supabase
                .from("profiles")
                .select("id, nickname, avatar_url")
                .in("id", values: ids)
                .execute()
                .value

            let profileMap = Dictionary(uniqueKeysWithValues: persistProfiles.map { ($0.id, $0) })

            // 3단계: 조합
            blockedUsers = persistBlocks.map { block in
                BlockedUser(
                    blockedId: block.blockedId,
                    reason: block.reason,
                    createdAt: block.createdAt,
                    profiles: profileMap[block.blockedId]
                )
            }
            blockedIds = Set(ids)
        } catch {
            print("Load blocked users error: \(error)")
        }
        isLoading = false
    }

    // MARK: - 차단 ID 목록만 로드 (필터링용, 가벼운 쿼리)
    func loadBlockedIds() async {
        do {
            struct BlockIdRow: Codable {
                let blockedId: String
                enum CodingKeys: String, CodingKey {
                    case blockedId = "blocked_id"
                }
            }
            let persistIds: [BlockIdRow] = try await supabase
                .from("blocks")
                .select("blocked_id")
                .execute()
                .value
            blockedIds = Set(persistIds.map { $0.blockedId })
        } catch {
            print("Load blocked ids error: \(error)")
        }
    }

    // MARK: - 차단 여부 확인
    func isBlocked(_ userId: String) -> Bool {
        blockedIds.contains(userId)
    }
}

// MARK: - 차단 상태 변경 Notification
extension Notification.Name {
    static let blockStatusChanged = Notification.Name("blockStatusChanged")
}
