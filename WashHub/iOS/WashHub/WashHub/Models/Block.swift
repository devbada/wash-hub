import Foundation

// MARK: - 차단
struct Block: Codable {
    let blockerId: String
    let blockedId: String
    let reason: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case blockerId = "blocker_id"
        case blockedId = "blocked_id"
        case reason
        case createdAt = "created_at"
    }
}

// MARK: - 차단 목록 (profiles JOIN)
struct BlockedUser: Identifiable, Codable {
    let blockedId: String
    let reason: String?
    let createdAt: String

    /// JOIN된 프로필 정보
    var profiles: BlockedUserProfile?

    var id: String { blockedId }

    enum CodingKeys: String, CodingKey {
        case blockedId = "blocked_id"
        case reason
        case createdAt = "created_at"
        case profiles
    }
}

struct BlockedUserProfile: Codable {
    let id: String
    let nickname: String?
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case nickname
        case avatarUrl = "avatar_url"
    }

    var displayName: String {
        nickname ?? "사용자"
    }
}
