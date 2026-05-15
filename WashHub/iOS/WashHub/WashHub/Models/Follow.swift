import Foundation

// MARK: - 팔로우 관계
struct Follow: Codable {
    let followerId: String
    let followingId: String
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case followerId = "follower_id"
        case followingId = "following_id"
        case createdAt = "created_at"
    }
}

// MARK: - 팔로워/팔로잉 목록 아이템 (profiles JOIN)
struct FollowUser: Identifiable, Codable {
    let id: String
    let nickname: String?
    let avatarUrl: String?
    let bio: String?
    let followerCount: Int?
    let followingCount: Int?
    let titleBadgeId: String?
    /// 탈퇴자 식별 — placeholder 표시 + 인터랙션 비활성용
    let deletedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case nickname
        case avatarUrl = "avatar_url"
        case bio
        case followerCount = "follower_count"
        case followingCount = "following_count"
        case titleBadgeId = "title_badge_id"
        case deletedAt = "deleted_at"
    }

    var isDeleted: Bool { deletedAt != nil }

    var displayName: String {
        if isDeleted { return "[탈퇴한 사용자]" }
        return nickname ?? "사용자"
    }
}

// MARK: - 팔로워 조회 응답 (follows + profiles JOIN)
// select 쿼리 별칭: follower:profiles!follows_follower_id_fkey(...)
// → JSON 응답 키는 "follower" (콜론 이전 부분만)
struct FollowerRow: Codable {
    let followerId: String
    let followingId: String
    let createdAt: String?
    let follower: FollowUser

    enum CodingKeys: String, CodingKey {
        case followerId = "follower_id"
        case followingId = "following_id"
        case createdAt = "created_at"
        case follower
    }
}

// MARK: - 팔로잉 조회 응답 (follows + profiles JOIN)
struct FollowingRow: Codable {
    let followerId: String
    let followingId: String
    let createdAt: String?
    let following: FollowUser

    enum CodingKeys: String, CodingKey {
        case followerId = "follower_id"
        case followingId = "following_id"
        case createdAt = "created_at"
        case following
    }
}
